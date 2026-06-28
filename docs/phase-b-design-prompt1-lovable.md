# Phase B-design — Prompt 1 (write boundary, NO UI) — Lovable build prompt + validation runbook

> Slice 1 of `docs/phase-b-design-core-build-spec.md`. **Additive app-layer only — NO migration, NO schema change.** Baseline stays `golden-master-v1.7`. Three parts: **PROMPT 1a** (the 3 fn files) → build → **PROMPT 1b** (a throwaway validation-harness route — a SEPARATE Lovable message) → **VALIDATION** (SQL + drive the harness, then DELETE the harness route).

---

## ⚠️ Read before you start — how you'll validate this
- **Direct-DB write-lockout + read-isolation → Supabase SQL Editor** (no harness). Proves the ticket tables are write-locked so these fns are the ONLY write path.
- **The fn-logic checks (admin-only lockout, sender-side forcing, reopen rule, per-kind status rules, attachment Findings D/E + 25 MB/MIME) → the THROWAWAY harness route in PROMPT 1b** — these are TypeScript checks *inside* the server fns; pure SQL cannot exercise them. **Flagging up front: yes, this slice needs the harness.** It is a single authed route that invokes the fns as the logged-in user (run once as the client, once as the admin). **Same rule as the deleted B-0 harness: it is a throwaway — DELETE the route file after validation** (it's an authed self-test surface that shouldn't live in the product). It adds **no migration** and touches **only its own route file**.

---

# PROMPT 1a — paste into Lovable (the 3 fn files)

> **Build scope: additive app-layer only. Create exactly the 3 NEW files below. Do NOT create or run any database migration. Do NOT modify any existing file, RLS policy, table, enum, or trigger. Do NOT build any UI/route/component.** When done, report back the exact list of files you created and confirm nothing else was touched and no migration was generated.

We are adding the **server-side write boundary** for client support/edit-request ticketing. The tables already exist (`tickets`, `ticket_messages`, `ticket_attachments` — read-only RLS for `authenticated`, write grants only to `service_role`). All writes must go through these service-role server functions. Follow the existing repo conventions exactly: `createServerFn({ method: "POST" }).middleware([requireSupabaseAuth]).inputValidator(zod).handler(...)`; `context.userId` is the caller; `supabaseAdmin` from `@/integrations/supabase/client.server` is the service-role client; Zod-validate every input.

### File 1 (NEW): `src/lib/tickets/authz.ts`
Two shared role helpers (the repo currently inlines role checks — centralize these two):
```ts
import { supabaseAdmin } from "@/integrations/supabase/client.server";

/** caller has a platform role (admin or agency_owner). */
export async function isAdmin(callerId: string): Promise<boolean> {
  const { data, error } = await supabaseAdmin
    .from("user_roles").select("role").eq("user_id", callerId);
  if (error) throw new Error("Failed to verify caller roles");
  return (data ?? []).some((r) => r.role === "admin" || r.role === "agency_owner");
}

/** caller has an explicit role row scoping them to this client (client_owner/client_staff). */
export async function isMemberOf(callerId: string, clientId: string): Promise<boolean> {
  const { data, error } = await supabaseAdmin
    .from("user_roles").select("client_id").eq("user_id", callerId).eq("client_id", clientId);
  if (error) throw new Error("Failed to verify caller membership");
  return (data ?? []).length > 0;
}
```

### File 2 (NEW): `src/lib/tickets/notify.server.ts`
Fires the client's in-app notification + an owner-email stub when the agency acts. Reuse `resolveOwnerEmail` from `@/lib/notifications/write.server`. Compose the body inline (do NOT add to the automation notification template registry); `notifications.type` and `events.type` are `text`, so the new type strings need no enum/migration.
```ts
import { supabaseAdmin } from "@/integrations/supabase/client.server";
import { resolveOwnerEmail } from "@/lib/notifications/write.server";

type TicketLike = {
  id: string; client_id: string;
  kind: "edit_request" | "support";
  status: string; subject: string; resolution?: string | null;
};

const kindLabel = (k: TicketLike["kind"]) => (k === "edit_request" ? "edit request" : "support request");
const statusLabel = (s: string) =>
  ({ open: "Open", in_progress: "In progress", approved: "Approved", denied: "Denied", resolved: "Resolved", closed: "Closed" } as Record<string, string>)[s] ?? s;

export async function notifyTicketEvent(args: { kind: "agency_reply" | "status_changed"; ticket: TicketLike }) {
  const { kind, ticket } = args;
  const { data: client } = await supabaseAdmin
    .from("clients").select("template_vars").eq("id", ticket.client_id).maybeSingle();
  const owner = ((client?.template_vars as any)?.company_owner_first_name as string) ?? "there";
  const kl = kindLabel(ticket.kind);

  let ntype: string; let body: string;
  if (kind === "agency_reply") {
    ntype = "ticket_agency_reply";
    body = `Hey ${owner},\n\nYour agency replied to your ${kl}.\n\nSubject: ${ticket.subject}\n\nOpen the ${kl} to read the reply.`;
  } else {
    ntype = "ticket_status_changed";
    const resLine = ticket.resolution?.trim() ? `\n\nDetails: ${ticket.resolution.trim()}` : "";
    body = `Hey ${owner},\n\nYour ${kl} was updated to: ${statusLabel(ticket.status)}.\n\nSubject: ${ticket.subject}${resLine}`;
  }

  // in-app notification (the client PWA reads it later, RLS-scoped). action drives the open_ticket deep-link (rendered in Prompt 2).
  await supabaseAdmin.from("notifications").insert({
    client_id: ticket.client_id, type: ntype, body, related_contact_id: null,
    action: { open_ticket: true, ticket_id: ticket.id, kind: ticket.kind },
  });

  // owner-email stub — same pattern as src/routes/api/public/r/feedback.ts (the real send is the separate email layer).
  const recipient = await resolveOwnerEmail(ticket.client_id);
  await supabaseAdmin.from("events").insert({
    client_id: ticket.client_id, type: "owner_email_stub",
    payload: { template_key: ntype, subject: ticket.subject, body, recipient },
  });
}
```

### File 3 (NEW): `src/lib/tickets/tickets.functions.ts`
The 5 write fns. **Trust fields (`sender_side`, `status`, `created_by`, `assigned_to`, `resolution`) are set authoritatively here — NEVER read from client input.**
```ts
import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { supabaseAdmin } from "@/integrations/supabase/client.server";
import { isAdmin, isMemberOf } from "./authz";
import { notifyTicketEvent } from "./notify.server";

const TERMINAL = ["resolved", "closed", "approved", "denied"];

// 1) openTicket — client OR admin/agency. First message sender_side derived from caller role.
const OpenTicketInput = z.object({
  clientId: z.string().uuid(),
  kind: z.enum(["edit_request", "support"]),
  subject: z.string().min(1).max(200),
  body: z.string().min(1).max(5000),
});
export const openTicket = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => OpenTicketInput.parse(d))
  .handler(async ({ data, context }) => {
    const caller = context.userId as string;
    const admin = await isAdmin(caller);
    if (!admin && !(await isMemberOf(caller, data.clientId))) throw new Error("Forbidden");
    const { data: client, error: cErr } = await supabaseAdmin
      .from("clients").select("id, status, deleted_at").eq("id", data.clientId).maybeSingle();
    if (cErr) throw new Error(cErr.message);
    if (!client || client.status !== "active" || client.deleted_at) throw new Error("Client not available");

    const { data: ticket, error: tErr } = await supabaseAdmin.from("tickets")
      .insert({ client_id: data.clientId, kind: data.kind, status: "open", subject: data.subject, created_by: caller, last_message_at: new Date().toISOString() })
      .select("id").single();
    if (tErr) throw new Error(tErr.message);

    const { error: mErr } = await supabaseAdmin.from("ticket_messages").insert({
      ticket_id: ticket.id, client_id: data.clientId, sender_user_id: caller,
      sender_side: admin ? "agency" : "client", body: data.body,
    });
    if (mErr) throw new Error(mErr.message);
    return { ticketId: ticket.id };
  });

// 2) postClientMessage — client side only (admins use postAgencyReply). Reopens a terminal ticket.
const PostClientMessageInput = z.object({ ticketId: z.string().uuid(), body: z.string().min(1).max(5000) });
export const postClientMessage = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => PostClientMessageInput.parse(d))
  .handler(async ({ data, context }) => {
    const caller = context.userId as string;
    const { data: ticket, error } = await supabaseAdmin
      .from("tickets").select("id, client_id, status").eq("id", data.ticketId).maybeSingle();
    if (error) throw new Error(error.message);
    if (!ticket) throw new Error("Ticket not found");
    if (!(await isMemberOf(caller, ticket.client_id))) throw new Error("Forbidden");

    const { data: msg, error: mErr } = await supabaseAdmin.from("ticket_messages")
      .insert({ ticket_id: ticket.id, client_id: ticket.client_id, sender_user_id: caller, sender_side: "client", body: data.body })
      .select("id").single();
    if (mErr) throw new Error(mErr.message);

    const patch: Record<string, unknown> = { last_message_at: new Date().toISOString() };
    if (TERMINAL.includes(ticket.status)) patch.status = "open";
    await supabaseAdmin.from("tickets").update(patch).eq("id", ticket.id);
    return { messageId: msg.id };
  });

// 3) postAgencyReply — admin only. Forces sender_side='agency'. Optional non-terminal status only.
const PostAgencyReplyInput = z.object({
  ticketId: z.string().uuid(), body: z.string().min(1).max(5000),
  newStatus: z.enum(["open", "in_progress"]).optional(), // terminal decisions go through setTicketStatus (need resolution)
});
export const postAgencyReply = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => PostAgencyReplyInput.parse(d))
  .handler(async ({ data, context }) => {
    const caller = context.userId as string;
    if (!(await isAdmin(caller))) throw new Error("Forbidden");
    const { data: ticket, error } = await supabaseAdmin
      .from("tickets").select("id, client_id, kind, status, subject, assigned_to").eq("id", data.ticketId).maybeSingle();
    if (error) throw new Error(error.message);
    if (!ticket) throw new Error("Ticket not found");

    const { data: msg, error: mErr } = await supabaseAdmin.from("ticket_messages")
      .insert({ ticket_id: ticket.id, client_id: ticket.client_id, sender_user_id: caller, sender_side: "agency", body: data.body })
      .select("id").single();
    if (mErr) throw new Error(mErr.message);

    const patch: Record<string, unknown> = { last_message_at: new Date().toISOString() };
    if (!ticket.assigned_to) patch.assigned_to = caller;
    if (data.newStatus) patch.status = data.newStatus;
    await supabaseAdmin.from("tickets").update(patch).eq("id", ticket.id);

    await notifyTicketEvent({ kind: "agency_reply", ticket });
    return { messageId: msg.id };
  });

// 4) setTicketStatus — admin only. Per-kind validation; approve/deny REQUIRE resolution.
const SetTicketStatusInput = z.object({
  ticketId: z.string().uuid(),
  status: z.enum(["open", "in_progress", "approved", "denied", "resolved", "closed"]),
  resolution: z.string().max(5000).optional(),
});
export const setTicketStatus = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => SetTicketStatusInput.parse(d))
  .handler(async ({ data, context }) => {
    const caller = context.userId as string;
    if (!(await isAdmin(caller))) throw new Error("Forbidden");
    const { data: ticket, error } = await supabaseAdmin
      .from("tickets").select("id, client_id, kind, status, subject").eq("id", data.ticketId).maybeSingle();
    if (error) throw new Error(error.message);
    if (!ticket) throw new Error("Ticket not found");

    if (ticket.kind === "edit_request") {
      if (!["open", "in_progress", "approved", "denied", "closed"].includes(data.status))
        throw new Error("Invalid status for edit_request");
      if ((data.status === "approved" || data.status === "denied") && !data.resolution?.trim())
        throw new Error("resolution required for approve/deny");
    } else {
      if (!["open", "in_progress", "resolved", "closed"].includes(data.status))
        throw new Error("Invalid status for support");
    }

    const terminal = ["approved", "denied", "resolved", "closed"].includes(data.status);
    const patch: Record<string, unknown> = { status: data.status, resolved_at: terminal ? new Date().toISOString() : null };
    if (data.resolution !== undefined) patch.resolution = data.resolution;
    await supabaseAdmin.from("tickets").update(patch).eq("id", data.ticketId);

    await notifyTicketEvent({ kind: "status_changed", ticket: { ...ticket, status: data.status, resolution: data.resolution ?? null } });
    return { ok: true };
  });

// 5) recordTicketAttachment — client OR admin. Findings D/E + 25MB/MIME.
const ATTACH_MAX = 25 * 1024 * 1024;
const mimeAllowed = (ct: string) =>
  ct.startsWith("image/") || ct === "application/pdf" || ["video/mp4", "video/quicktime", "video/webm"].includes(ct);
const RecordAttachmentInput = z.object({
  ticketId: z.string().uuid(),
  messageId: z.string().uuid().optional(),
  storagePath: z.string().min(1),
  fileName: z.string().min(1).max(300),
  contentType: z.string().min(1),
  sizeBytes: z.number().int().nonnegative(),
});
export const recordTicketAttachment = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => RecordAttachmentInput.parse(d))
  .handler(async ({ data, context }) => {
    const caller = context.userId as string;
    const { data: ticket, error } = await supabaseAdmin
      .from("tickets").select("id, client_id").eq("id", data.ticketId).maybeSingle();
    if (error) throw new Error(error.message);
    if (!ticket) throw new Error("Ticket not found");
    if (!(await isAdmin(caller)) && !(await isMemberOf(caller, ticket.client_id))) throw new Error("Forbidden");

    if (data.messageId) { // Finding D
      const { data: m } = await supabaseAdmin.from("ticket_messages").select("id, ticket_id").eq("id", data.messageId).maybeSingle();
      if (!m || m.ticket_id !== data.ticketId) throw new Error("message does not belong to ticket");
    }
    if (!data.storagePath.startsWith(`${ticket.client_id}/tickets/${data.ticketId}/`)) // Finding E
      throw new Error("storagePath outside ticket folder");
    if (!mimeAllowed(data.contentType)) throw new Error("content type not allowed"); // Decision 5
    if (data.sizeBytes > ATTACH_MAX) throw new Error("file exceeds 25MB");

    const { data: att, error: aErr } = await supabaseAdmin.from("ticket_attachments")
      .insert({ ticket_id: data.ticketId, message_id: data.messageId ?? null, client_id: ticket.client_id, storage_bucket: "client-assets", storage_path: data.storagePath, file_name: data.fileName, content_type: data.contentType, size_bytes: data.sizeBytes, uploaded_by: caller })
      .select("id").single();
    if (aErr) throw new Error(aErr.message);
    return { attachmentId: att.id };
  });
```

### Drift check (report back before finishing)
1. Files created — should be EXACTLY: `src/lib/tickets/authz.ts`, `src/lib/tickets/notify.server.ts`, `src/lib/tickets/tickets.functions.ts`.
2. Confirm: **no migration generated**, no existing file/table/RLS/enum/trigger modified, no route/UI added.
3. Confirm the build compiles (types resolve against the existing `tickets`/`ticket_messages`/`ticket_attachments`/`notifications`/`events`/`clients` types).

---

# PROMPT 1b — paste into Lovable AFTER 1a builds (throwaway validation harness)

> **Build scope: create exactly ONE new file — the route below. Do NOT create or run any migration. Do NOT modify any existing file, table, RLS, enum, or trigger. This is a throwaway self-test surface that will be deleted after validation.** When done, report back that only `src/routes/_authenticated/ticket-harness.tsx` was added and no migration was generated.

Create a throwaway authed route that invokes the 5 ticket write fns **as the logged-in user** (the same pattern as the old B-0 provisioning test) and renders a pass/fail list. It is run twice: once logged in as the **client_owner of client A**, once as a **platform admin**. It calls the server fns the normal client way (`fn({ data })`) so the caller identity = the logged-in user's JWT, and reads state back through the RLS-scoped browser `supabase` client. All fixtures it creates use a `HARNESS ` subject prefix for easy cleanup.

### File (NEW, throwaway): `src/routes/_authenticated/ticket-harness.tsx`
```tsx
import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import {
  openTicket, postClientMessage, postAgencyReply, setTicketStatus, recordTicketAttachment,
} from "@/lib/tickets/tickets.functions";

export const Route = createFileRoute("/_authenticated/ticket-harness")({ component: Harness });

type Res = { name: string; pass: boolean; detail: string };

async function expectThrow(name: string, fn: () => Promise<unknown>, contains?: string): Promise<Res> {
  try { await fn(); return { name, pass: false, detail: "expected throw, but it SUCCEEDED" }; }
  catch (e: any) {
    const msg = String(e?.message ?? e);
    const ok = contains ? msg.toLowerCase().includes(contains.toLowerCase()) : true;
    return { name, pass: ok, detail: ok ? `threw: ${msg}` : `threw WRONG error: ${msg}` };
  }
}
async function expectOk(name: string, fn: () => Promise<any>): Promise<{ r: Res; val: any }> {
  try { const val = await fn(); return { r: { name, pass: true, detail: "ok" }, val }; }
  catch (e: any) { return { r: { name, pass: false, detail: `unexpected throw: ${e?.message ?? e}` }, val: null }; }
}

async function myClientId(): Promise<string> {
  const { data } = await supabase.from("user_roles").select("client_id").not("client_id", "is", null).limit(1).maybeSingle();
  if (!data?.client_id) throw new Error("no client_id on this user — log in as the client_owner of A");
  return data.client_id as string;
}

// Run while logged in as CLIENT_OWNER(A). Creates HARNESS T1 (support) + T3 (edit_request).
async function clientBattery(): Promise<Res[]> {
  const out: Res[] = [];
  const clientId = await myClientId();

  const t1 = await expectOk("2a openTicket(support) as client", () =>
    openTicket({ data: { clientId, kind: "support", subject: "HARNESS support T1", body: "hello" } }));
  out.push(t1.r);
  const t1Id: string | null = t1.val?.ticketId ?? null;
  if (t1Id) {
    const { data: m } = await supabase.from("ticket_messages").select("sender_side").eq("ticket_id", t1Id).order("created_at").limit(1).maybeSingle();
    out.push({ name: "2a first message sender_side='client'", pass: m?.sender_side === "client", detail: `got ${m?.sender_side}` });
  }

  const t3 = await expectOk("openTicket(edit_request) as client", () =>
    openTicket({ data: { clientId, kind: "edit_request", subject: "HARNESS edit T3", body: "please change X" } }));
  out.push(t3.r);
  const t3Id: string | null = t3.val?.ticketId ?? null;

  if (t1Id) {
    out.push((await expectOk("3a postClientMessage as client", () =>
      postClientMessage({ data: { ticketId: t1Id, body: "follow up" } }))).r);
    out.push(await expectThrow("1a postAgencyReply as client → Forbidden", () =>
      postAgencyReply({ data: { ticketId: t1Id, body: "x" } }), "forbidden"));
    out.push(await expectThrow("1b setTicketStatus as client → Forbidden", () =>
      setTicketStatus({ data: { ticketId: t1Id, status: "in_progress" } }), "forbidden"));
  }

  if (t1Id && t3Id) {
    const { data: t3msg } = await supabase.from("ticket_messages").select("id").eq("ticket_id", t3Id).order("created_at").limit(1).maybeSingle();
    const okPath = `${clientId}/tickets/${t1Id}/u.png`;
    out.push(await expectThrow("5a Finding D (messageId from other ticket)", () =>
      recordTicketAttachment({ data: { ticketId: t1Id, messageId: t3msg?.id, storagePath: okPath, fileName: "u.png", contentType: "image/png", sizeBytes: 1024 } }), "belong"));
    out.push(await expectThrow("5b Finding E (wrong path prefix)", () =>
      recordTicketAttachment({ data: { ticketId: t1Id, storagePath: `${clientId}/tickets/00000000-0000-0000-0000-000000000000/u.png`, fileName: "u.png", contentType: "image/png", sizeBytes: 1024 } }), "outside"));
    out.push(await expectThrow("5c MIME (zip) rejected", () =>
      recordTicketAttachment({ data: { ticketId: t1Id, storagePath: okPath, fileName: "x.zip", contentType: "application/zip", sizeBytes: 1024 } }), "not allowed"));
    out.push(await expectThrow("5d >25MB rejected", () =>
      recordTicketAttachment({ data: { ticketId: t1Id, storagePath: okPath, fileName: "u.png", contentType: "image/png", sizeBytes: 26 * 1024 * 1024 } }), "25mb"));
    out.push((await expectOk("5e valid attachment accepted", () =>
      recordTicketAttachment({ data: { ticketId: t1Id, storagePath: okPath, fileName: "u.png", contentType: "image/png", sizeBytes: 1024 } }))).r);
  }
  out.push({ name: "→ now log in as ADMIN and run the Admin battery", pass: true, detail: "" });
  return out;
}

// Run while logged in as ADMIN. Acts on the HARNESS tickets the client created.
async function adminBattery(): Promise<Res[]> {
  const out: Res[] = [];
  const { data: t1 } = await supabase.from("tickets").select("id, client_id").eq("subject", "HARNESS support T1").order("created_at", { ascending: false }).limit(1).maybeSingle();
  const { data: t3 } = await supabase.from("tickets").select("id, client_id").eq("subject", "HARNESS edit T3").order("created_at", { ascending: false }).limit(1).maybeSingle();
  if (!t1 || !t3) { out.push({ name: "setup", pass: false, detail: "run the CLIENT battery first (HARNESS T1/T3 not found)" }); return out; }
  const clientId = t1.client_id as string;

  const t2 = await expectOk("2b openTicket(support) as admin", () =>
    openTicket({ data: { clientId, kind: "support", subject: "HARNESS support T2 admin", body: "agency-initiated" } }));
  out.push(t2.r);
  const t2Id: string | null = t2.val?.ticketId ?? null;
  if (t2Id) {
    const { data: m } = await supabase.from("ticket_messages").select("sender_side").eq("ticket_id", t2Id).order("created_at").limit(1).maybeSingle();
    out.push({ name: "2b first message sender_side='agency'", pass: m?.sender_side === "agency", detail: `got ${m?.sender_side}` });
  }

  out.push((await expectOk("postAgencyReply as admin", () => postAgencyReply({ data: { ticketId: t1.id, body: "we got it" } }))).r);
  const { data: notif } = await supabase.from("notifications").select("type").eq("client_id", clientId).eq("type", "ticket_agency_reply").order("created_at", { ascending: false }).limit(1).maybeSingle();
  out.push({ name: "#6 notifications ticket_agency_reply row written", pass: !!notif, detail: notif ? "found" : "missing" });
  const { data: ev } = await supabase.from("events").select("type").eq("client_id", clientId).eq("type", "owner_email_stub").order("created_at", { ascending: false }).limit(1).maybeSingle();
  out.push({ name: "#6 events owner_email_stub row written", pass: !!ev, detail: ev ? "found" : "missing" });

  out.push(await expectThrow("4a edit approve w/o resolution → reject", () =>
    setTicketStatus({ data: { ticketId: t3.id, status: "approved" } }), "resolution required"));
  out.push((await expectOk("4b edit approve w/ resolution", () =>
    setTicketStatus({ data: { ticketId: t3.id, status: "approved", resolution: "will implement" } }))).r);
  const { data: t3row } = await supabase.from("tickets").select("status, resolution, resolved_at").eq("id", t3.id).maybeSingle();
  out.push({ name: "4b status=approved + resolution + resolved_at set", pass: t3row?.status === "approved" && !!t3row?.resolution && !!t3row?.resolved_at, detail: JSON.stringify(t3row) });

  if (t2Id) {
    out.push((await expectOk("4c support in_progress accepted", () => setTicketStatus({ data: { ticketId: t2Id, status: "in_progress" } }))).r);
    out.push(await expectThrow("4d support approved → reject", () => setTicketStatus({ data: { ticketId: t2Id, status: "approved" } }), "invalid status for support"));
  }

  out.push((await expectOk("setup: resolve T1 for the reopen test", () => setTicketStatus({ data: { ticketId: t1.id, status: "resolved" } }))).r);
  out.push({ name: "→ now log back in as CLIENT_OWNER(A) and run the Reopen check", pass: true, detail: "" });
  return out;
}

// Run while logged in as CLIENT_OWNER(A), AFTER the admin battery resolved T1.
async function reopenCheck(): Promise<Res[]> {
  const out: Res[] = [];
  const { data: t1 } = await supabase.from("tickets").select("id, status").eq("subject", "HARNESS support T1").order("created_at", { ascending: false }).limit(1).maybeSingle();
  if (!t1) { out.push({ name: "reopen", pass: false, detail: "HARNESS T1 not found" }); return out; }
  if (t1.status !== "resolved") { out.push({ name: "reopen precondition", pass: false, detail: `T1 is ${t1.status}, expected resolved — run the Admin battery first` }); return out; }
  out.push((await expectOk("3b postClientMessage on resolved T1", () => postClientMessage({ data: { ticketId: t1.id, body: "one more thing" } }))).r);
  const { data: after } = await supabase.from("tickets").select("status").eq("id", t1.id).maybeSingle();
  out.push({ name: "3b ticket reopened resolved→open", pass: after?.status === "open", detail: `got ${after?.status}` });
  return out;
}

function Harness() {
  const [rows, setRows] = useState<Res[]>([]);
  const [busy, setBusy] = useState(false);
  const run = (label: string, fn: () => Promise<Res[]>) => async () => {
    setBusy(true);
    try { setRows(await fn()); } catch (e: any) { setRows([{ name: label, pass: false, detail: String(e?.message ?? e) }]); }
    setBusy(false);
  };
  return (
    <div style={{ padding: 24, fontFamily: "system-ui", maxWidth: 760 }}>
      <h1>Ticket write-boundary harness (THROWAWAY — delete after use)</h1>
      <p>Run <b>Client battery</b> logged in as client_owner(A) → then <b>Admin battery</b> as an admin → then <b>Reopen check</b> as client_owner(A) again.</p>
      <div style={{ display: "flex", gap: 8, margin: "12px 0" }}>
        <button disabled={busy} onClick={run("client", clientBattery)}>Run Client battery</button>
        <button disabled={busy} onClick={run("admin", adminBattery)}>Run Admin battery</button>
        <button disabled={busy} onClick={run("reopen", reopenCheck)}>Run Reopen check</button>
      </div>
      <ul style={{ lineHeight: 1.6 }}>
        {rows.map((r, i) => (
          <li key={i} style={{ color: r.pass ? "green" : "crimson" }}>
            {r.pass ? "✅" : "❌"} <b>{r.name}</b> — {r.detail}
          </li>
        ))}
      </ul>
    </div>
  );
}
```

> If the repo's server-fn client call convention differs (e.g. `openTicket({ data })` vs `openTicket(data)`), match the existing convention used by `enrollReviewFromMobile`/`sendReply` callers. Everything else is standard.

### Drift check (report back)
1. Only `src/routes/_authenticated/ticket-harness.tsx` was created.
2. No migration generated; no existing file/table/RLS/enum/trigger modified; the 5 fns + `authz.ts` + `notify.server.ts` from 1a are imported, not changed.

---

# VALIDATION — run after 1b builds (then DELETE the harness)

Seed/identify two clients (A, B) + a `client_owner` of A + a platform `admin`. Substitute the `<...>` UUIDs in the SQL.

## §1 — Supabase SQL Editor (no harness) — the table boundary still holds
Re-proves the v1.7 §5.4 write-lockout + read isolation (the fns are the ONLY write path). Seed one ticket via service role first:
```sql
-- seed (service-role context / SQL editor):
insert into public.tickets (client_id, kind, status, subject, created_by)
values ('<CLIENT_A_ID>','support','open','seed','<ADMIN_UUID>') returning id;   -- note <A_TICKET>

-- (1) WRITE-LOCKOUT as client_owner(A) — every statement must be DENIED:
begin;
  select set_config('request.jwt.claims', '{"sub":"<CLIENT_A_OWNER_UUID>"}', true);
  set local role authenticated;
  insert into public.ticket_messages(ticket_id,client_id,sender_user_id,sender_side,body)
    values ('<A_TICKET>','<CLIENT_A_ID>','<CLIENT_A_OWNER_UUID>','agency','spoof'); -- expect: violates RLS / no grant
  update public.tickets set status='approved' where id='<A_TICKET>';               -- expect: 0 rows / denied
rollback;

-- (2) READ-ISOLATION as client_owner(B) — must NOT see A's ticket:
begin;
  select set_config('request.jwt.claims', '{"sub":"<CLIENT_B_OWNER_UUID>"}', true);
  set local role authenticated;
  select count(*) from public.tickets where id='<A_TICKET>';   -- expect 0
rollback;
```
Pass = both writes denied + count 0. (Clean up the seed ticket after, or let it ride into §B-2.)

## §2 — Drive the harness (the PROMPT 1b route) — the fn logic
Open **`/ticket-harness`** and run the three buttons in order, switching login between them:
1. **Log in as `client_owner` of A** → **Run Client battery** (creates HARNESS T1/T3; checks 1a/1b lockout, 2a sender-side, 3a, 5a–5e).
2. **Log in as the `admin`** → **Run Admin battery** (2b sender-side, agency reply + notification/owner-email stub #6, 4a–4d per-kind, resolves T1).
3. **Log back in as `client_owner` of A** → **Run Reopen check** (3b resolved→open).

Every row must show ✅. For reference, the assertion matrix the harness implements:
| # | Call (as which user) | Expected |
|---|---|---|
| 1a | `postAgencyReply` as **client_owner(A)** | throws **Forbidden** |
| 1b | `setTicketStatus` as **client_owner(A)** | throws **Forbidden** |
| 2a | `openTicket{kind:'support', clientId:A}` as **client_owner(A)** | ok; first `ticket_messages.sender_side='client'` |
| 2b | `openTicket{kind:'support', clientId:A}` as **admin** | ok; first message `sender_side='agency'` |
| 3a | `postClientMessage` as **client_owner(A)** | ok; message `sender_side='client'` |
| 3b | `postClientMessage` on a **resolved** ticket | ok; ticket `status` flips to `open` |
| 4a | `setTicketStatus{edit_request, status:'approved', resolution:undefined}` as admin | throws **resolution required** |
| 4b | `setTicketStatus{edit_request, status:'approved', resolution:'will do X'}` as admin | ok; `status='approved'`, `resolution` set, `resolved_at` set |
| 4c | `setTicketStatus{support, status:'in_progress'}` as admin | ok |
| 4d | `setTicketStatus{support, status:'approved'}` as admin | throws **Invalid status for support** |
| 5a | `recordTicketAttachment{messageId:<from a DIFFERENT ticket>}` | throws (Finding D) |
| 5b | `recordTicketAttachment{storagePath:'<A>/tickets/<wrong>/x.png'}` (not under this ticket's prefix) | throws (Finding E) |
| 5c | `recordTicketAttachment{contentType:'application/zip'}` | throws (MIME) |
| 5d | `recordTicketAttachment{sizeBytes: 26*1024*1024}` | throws (>25MB) |
| 5e | `recordTicketAttachment{valid image, path '<A>/tickets/<ticket>/u.png', size 1MB}` | ok; row inserted |
| 6 (opt) | after `postAgencyReply` on A's ticket | a `notifications` row `type='ticket_agency_reply'` **and** an `events` row `type='owner_email_stub'` exist for client A |

Pass = every row ✅.

## §3 — Cleanup + DELETE the harness (required)
1. **Delete the harness route file** `src/routes/_authenticated/ticket-harness.tsx` (tell Lovable: "delete the ticket-harness route"). Same delete-after-use rule as the old B-0 test — it's an authed self-test surface, not product.
2. **Remove the throwaway fixtures** (SQL editor):
```sql
delete from public.tickets where subject like 'HARNESS %';   -- cascades messages + attachments
delete from public.notifications where type in ('ticket_agency_reply','ticket_status_changed') and body like '%HARNESS %';
delete from public.events where type = 'owner_email_stub' and payload->>'subject' like 'HARNESS %';
```
3. Record a build-log validation; then proceed to **Prompt 2 (client PWA)**.

---
**App-layer only. No migration (1a or 1b). Baseline `golden-master-v1.7` unchanged. Sequence: 1a → §1 SQL → 1b → §2 harness → §3 delete → Prompt 2.**
