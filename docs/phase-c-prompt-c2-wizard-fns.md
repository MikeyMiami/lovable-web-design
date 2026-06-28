# Phase C — C-2 (Wizard orchestration fns) — Lovable build prompt + validation

> Slice C-2 of `docs/phase-c-scope.md` — the wizard's server-side backbone: **`createClientFull`** + **`updateClientSettings`** + the immutable submission JSON, with **`provisionClientOwner`** wired in (unchanged). **Additive app-layer only — NO migration, NO schema change** (A2P columns deferred to Phase D per D5). Baseline stays `golden-master-v1.7`. **Contracts verified against LIVE v1.7** (origin/main `c8a56f9`).

## Verified live-v1.7 facts this prompt relies on
- **No `createClient` server fn exists** — client rows are created ad-hoc via RLS inserts in `admin.settings.tsx`. `createClientFull` is net-new and becomes the canonical create path.
- **`send_settings`** columns (`types.ts`): `client_id` (unique, 1:1), `timezone` (text), `sms_send_window` (jsonb `{start,end}`), `business_hours` (jsonb), `daily_send_cap` (int), `daily_enrollment_cap` (int), `sequence_overrides` (jsonb). **NOT auto-created on client insert** → the fn must upsert it (`onConflict: "client_id"`, the existing pattern).
- **`provisionClientOwner`** (`src/lib/auth/provisioning.functions.ts`): `{ email, clientId, reason? } → { ok, userId, invited }`; admin/agency_owner-gated; invites via `inviteUserByEmail` (`redirectTo = VITE_INVITE_REDIRECT_URL`) + `assign_user_role_audited` grant. **Unchanged here** — the wizard calls it AFTER `createClientFull`, with the returned `clientId`.
- **`clients`** write pattern: `supabase.from("clients").update(patch).eq("id", id)` (admin RLS) — `createClientFull`/`updateClientSettings` do the service-role equivalent. v1.7 columns `access_suspended` (default false) + `a2p_status` (default `not_started`) have DB defaults — **do not set them** (A2P prep goes in `template_vars` + the submission JSON, per D5).
- Storage buckets: **`public-assets`** (public; logos/hero) + **`client-assets`** (private; ticket attachments + the onboarding submission). Submission JSON → `client-assets` at `<clientId>/onboarding-submission.json` (service-role write, `upsert:false` = immutable).

> **Carried config items (not C-2 blockers):** `VITE_INVITE_REDIRECT_URL` still points at the B-0 temporary target — repoint it to the **client PWA set-password/callback route** before inviting a *real* client; and **custom SMTP** (B-0 invites land in spam on the default sender). Both belong with the C-3 "invite the client" step / launch, not here.

---

# PROMPT C-2 — paste into Lovable

> **Build scope: app-layer only. NO migration, NO schema/table/RLS change.** Add ONE new file with two service-role server fns. Do NOT modify `provisionClientOwner`, `admin.settings.tsx`, or any table. When done, report the file added + confirm no migration and no other file changed.

Add the onboarding wizard's server backbone. Both fns follow the established pattern: `createServerFn({method:"POST"}).middleware([requireSupabaseAuth])` → authz `admin`/`agency_owner` (via `user_roles`, same as `setClientAccessSuspended`/`provisionClientOwner`) → service-role writes via `supabaseAdmin`. Zod-validate all input.

### File (NEW): `src/lib/clients/onboarding.functions.ts`
```ts
import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

const SiteStyle = z.enum(["corporate", "standard", "family_owned", "owner_operated"]);
const ReviewToggle = z.enum(["gated", "direct"]);

// All client-config fields the wizard captures (camelCase → snake_case mapped in the handler).
const ClientFields = z.object({
  businessName: z.string().min(1).optional(),
  email: z.string().email().optional(),
  phoneDisplay: z.string().optional(),
  address: z.string().optional(),
  licenseNumber: z.string().optional(),
  tagline: z.string().optional(),
  logoUrl: z.string().url().optional(),
  brandColor: z.string().optional(),
  siteStyle: SiteStyle.optional(),
  serviceArea: z.array(z.string()).optional(),
  socialLinks: z.record(z.string()).optional(),
  callForwardingNumber: z.string().optional(),
  allowedOrigins: z.array(z.string()).optional(),
  reviewLink: z.string().optional(),
  reviewPlaceId: z.string().optional(),
  starThreshold: z.number().int().min(1).max(5).optional(),
  googleReviewToggle: ReviewToggle.optional(),
  notificationEmail: z.string().email().optional(),
  templateVars: z.record(z.any()).optional(),   // ALL merge values + segment + anon-safe A2P-prep
});

const SendSettingsFields = z.object({
  timezone: z.string().optional(),
  smsSendWindow: z.record(z.any()).optional(),    // { start, end }
  businessHours: z.record(z.any()).optional(),
  dailySendCap: z.number().int().optional(),
  dailyEnrollmentCap: z.number().int().optional(),
}).optional();

// camelCase → the actual clients columns (only set provided keys).
function clientPatch(f: z.infer<typeof ClientFields>) {
  const p: Record<string, unknown> = {};
  if (f.businessName !== undefined) p.business_name = f.businessName;
  if (f.email !== undefined) p.email = f.email;
  if (f.phoneDisplay !== undefined) p.phone_display = f.phoneDisplay;
  if (f.address !== undefined) p.address = f.address;
  if (f.licenseNumber !== undefined) p.license_number = f.licenseNumber;
  if (f.tagline !== undefined) p.tagline = f.tagline;
  if (f.logoUrl !== undefined) p.logo_url = f.logoUrl;
  if (f.brandColor !== undefined) p.brand_color = f.brandColor;
  if (f.siteStyle !== undefined) p.site_style = f.siteStyle;
  if (f.serviceArea !== undefined) p.service_area = f.serviceArea;
  if (f.socialLinks !== undefined) p.social_links = f.socialLinks;
  if (f.callForwardingNumber !== undefined) p.call_forwarding_number = f.callForwardingNumber;
  if (f.allowedOrigins !== undefined) p.allowed_origins = f.allowedOrigins;
  if (f.reviewLink !== undefined) p.review_link = f.reviewLink;
  if (f.reviewPlaceId !== undefined) p.review_place_id = f.reviewPlaceId;
  if (f.starThreshold !== undefined) p.star_threshold = f.starThreshold;
  if (f.googleReviewToggle !== undefined) p.google_review_toggle = f.googleReviewToggle;
  if (f.notificationEmail !== undefined) p.notification_email = f.notificationEmail;
  if (f.templateVars !== undefined) p.template_vars = f.templateVars;
  return p;
}
function sendPatch(s: NonNullable<z.infer<typeof SendSettingsFields>>) {
  const p: Record<string, unknown> = {};
  if (s.timezone !== undefined) p.timezone = s.timezone;
  if (s.smsSendWindow !== undefined) p.sms_send_window = s.smsSendWindow;
  if (s.businessHours !== undefined) p.business_hours = s.businessHours;
  if (s.dailySendCap !== undefined) p.daily_send_cap = s.dailySendCap;
  if (s.dailyEnrollmentCap !== undefined) p.daily_enrollment_cap = s.dailyEnrollmentCap;
  return p;
}
async function assertAgencyAdmin(supabaseAdmin: any, callerId: string) {
  const { data, error } = await supabaseAdmin.from("user_roles").select("role").eq("user_id", callerId);
  if (error) throw new Error("Failed to verify caller");
  if (!(data ?? []).some((r: any) => r.role === "admin" || r.role === "agency_owner")) throw new Error("Forbidden");
}

// ── createClientFull: clients row + send_settings + the immutable submission JSON ──
const CreateClientFullInput = z.object({
  slug: z.string().min(1).max(60).regex(/^[a-z0-9-]+$/, "slug = lowercase letters/digits/hyphens"),
  fields: ClientFields.extend({ businessName: z.string().min(1) }), // business_name required at create
  sendSettings: SendSettingsFields,
  submission: z.record(z.any()),   // raw as-submitted answers (PII allowed — stored PRIVATE + immutable)
});
export const createClientFull = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => CreateClientFullInput.parse(d))
  .handler(async ({ data, context }) => {
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    await assertAgencyAdmin(supabaseAdmin, context.userId as string);

    // 1) clients row (slug + business_name + any provided config). Other cols use DB defaults
    //    (brand_color, status='active', access_suspended=false, a2p_status='not_started', etc.).
    const insert = { slug: data.slug, ...clientPatch(data.fields) };
    const { data: client, error: cErr } = await supabaseAdmin
      .from("clients").insert(insert).select("id, slug").single();
    if (cErr) {
      if ((cErr as any).code === "23505") throw new Error(`Slug "${data.slug}" is already taken`);
      throw new Error(cErr.message);
    }
    const clientId = client.id as string;

    // 2) send_settings (1:1 upsert; not auto-created).
    if (data.sendSettings) {
      const { error: sErr } = await supabaseAdmin
        .from("send_settings").upsert({ client_id: clientId, ...sendPatch(data.sendSettings) }, { onConflict: "client_id" });
      if (sErr) throw new Error(sErr.message);
    }

    // 3) immutable submission record → client-assets (private; upsert:false so it can't be overwritten).
    const { error: upErr } = await supabaseAdmin.storage
      .from("client-assets")
      .upload(`${clientId}/onboarding-submission.json`,
        new Blob([JSON.stringify(data.submission, null, 2)], { type: "application/json" }),
        { contentType: "application/json", upsert: false });
    if (upErr) throw new Error(`submission record: ${upErr.message}`);

    return { clientId, slug: client.slug };
  });

// ── updateClientSettings: edit any §9b field (wizard pre-gen edits + adoptable by Settings) ──
const UpdateClientSettingsInput = z.object({
  clientId: z.string().uuid(),
  fields: ClientFields.optional(),
  sendSettings: SendSettingsFields,
});
export const updateClientSettings = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => UpdateClientSettingsInput.parse(d))
  .handler(async ({ data, context }) => {
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    await assertAgencyAdmin(supabaseAdmin, context.userId as string);

    if (data.fields) {
      const patch = clientPatch(data.fields);
      if (Object.keys(patch).length) {
        const { error } = await supabaseAdmin.from("clients").update(patch).eq("id", data.clientId);
        if (error) throw new Error(error.message);
      }
    }
    if (data.sendSettings) {
      const { error } = await supabaseAdmin
        .from("send_settings").upsert({ client_id: data.clientId, ...sendPatch(data.sendSettings) }, { onConflict: "client_id" });
      if (error) throw new Error(error.message);
    }
    return { ok: true, clientId: data.clientId };
  });
```

### Provisioning wiring (NO code change — call-site contract)
The C-3 wizard, at its explicit "invite the client" step (after the agency reviews the pre-gen console), calls the EXISTING fn with the `clientId` from `createClientFull`:
```ts
await provisionClientOwner({ data: { email: ownerEmail, clientId } });
```
Kept separate from `createClientFull` so creation/review happens before any invite email fires.

### Drift check (report back)
1. Added EXACTLY: `src/lib/clients/onboarding.functions.ts` (`createClientFull` + `updateClientSettings`).
2. No migration; no schema/table/RLS change; `provisionClientOwner` + `admin.settings.tsx` UNTOUCHED.
3. Build compiles against the live `clients` + `send_settings` types.

---

# VALIDATION

**Account:** your **`itsmikeymiami`** admin. These are admin-only server fns → invoke them via a **throwaway harness route** (same pattern as B-design Slice-1b — **delete it after**). It adds no migration and is the only file touching its route.

### PROMPT C-2b — throwaway harness route (paste as a second Lovable message, alongside C-2)
> **Build scope: create exactly ONE new file — the route below. NO migration, NO other change.** Throwaway self-test surface, **deleted after validation**. Report only `src/routes/_authenticated/onboard-harness.tsx` added + no migration.

```tsx
import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { createClientFull, updateClientSettings } from "@/lib/clients/onboarding.functions";
import { provisionClientOwner } from "@/lib/auth/provisioning.functions";

export const Route = createFileRoute("/_authenticated/onboard-harness")({ component: Harness });

type Res = { name: string; pass: boolean; detail: string };

const CREATE_PAYLOAD = {
  slug: "c2-test-co",
  fields: {
    businessName: "C2 Test Co",
    email: "c2-test-co@example.com",
    phoneDisplay: "(555) 010-2002",
    brandColor: "#123456",
    siteStyle: "standard",
    serviceArea: ["Miami", "Fort Lauderdale"],
    googleReviewToggle: "gated",
    starThreshold: 4,
    templateVars: {
      company_name: "C2 Test Co", company_owner_first_name: "Pat", segment: "plumbing",
      about_us: "Test about us.", services: "Test services.", differentiators: "Test differentiators.",
    },
  },
  sendSettings: { timezone: "America/New_York", smsSendWindow: { start: "09:00", end: "19:00" }, dailySendCap: 500, dailyEnrollmentCap: 50 },
  submission: { raw: "as-submitted answers", ein: "12-3456789", shipping_address: "123 Test St (agency-ops only)" },
} as const;

async function expectOk(name: string, fn: () => Promise<any>): Promise<{ r: Res; val: any }> {
  try { const val = await fn(); return { r: { name, pass: true, detail: "ok" }, val }; }
  catch (e: any) { return { r: { name, pass: false, detail: `threw: ${e?.message ?? e}` }, val: null }; }
}
async function expectThrow(name: string, fn: () => Promise<unknown>, contains?: string): Promise<Res> {
  try { await fn(); return { name, pass: false, detail: "expected throw, but it SUCCEEDED" }; }
  catch (e: any) {
    const m = String(e?.message ?? e);
    const ok = contains ? m.toLowerCase().includes(contains.toLowerCase()) : true;
    return { name, pass: ok, detail: ok ? `threw: ${m}` : `threw WRONG error: ${m}` };
  }
}

function Harness() {
  const [rows, setRows] = useState<Res[]>([]);
  const [clientId, setClientId] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function runCreateUpdate() {
    setBusy(true);
    const out: Res[] = [];
    const c = await expectOk("createClientFull(c2-test-co)", () => createClientFull({ data: CREATE_PAYLOAD as any }));
    out.push(c.r);
    const id: string | null = c.val?.clientId ?? null;
    setClientId(id);
    if (id) {
      out.push({ name: "returned clientId", pass: !!id, detail: id });
      out.push((await expectOk("updateClientSettings(tagline + dailySendCap=400)", () =>
        updateClientSettings({ data: { clientId: id, fields: { tagline: "Updated tagline" }, sendSettings: { dailySendCap: 400 } } }))).r);
    }
    out.push(await expectThrow("createClientFull same slug → 'already taken'", () =>
      createClientFull({ data: CREATE_PAYLOAD as any }), "already taken"));
    setRows(out); setBusy(false);
  }

  async function runProvision() {
    setBusy(true);
    const out = [...rows];
    if (!clientId) { out.push({ name: "provision", pass: false, detail: "run Create+Update first" }); setRows(out); setBusy(false); return; }
    const p = await expectOk("provisionClientOwner(c2-test+owner)", () =>
      provisionClientOwner({ data: { email: "c2-test+owner@example.com", clientId } }));
    out.push(p.r);
    if (p.val) out.push({ name: "provision result", pass: !!p.val.userId, detail: JSON.stringify(p.val) });
    setRows(out); setBusy(false);
  }

  return (
    <div style={{ padding: 24, fontFamily: "system-ui", maxWidth: 760 }}>
      <h1>Onboarding fns harness (THROWAWAY — delete after use)</h1>
      <p>Run as an admin (itsmikeymiami). 1) Create + Update + slug-collision. 2) (optional) Provision the login.</p>
      <div style={{ display: "flex", gap: 8, margin: "12px 0" }}>
        <button disabled={busy} onClick={runCreateUpdate}>Run Create + Update</button>
        <button disabled={busy} onClick={runProvision}>Provision login (optional)</button>
      </div>
      {clientId ? <p>clientId: <code>{clientId}</code></p> : null}
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
> If the repo's server-fn call convention differs (`fn({ data })` vs `fn(data)`), match the existing callers. The `c2-test+owner@example.com` invite won't deliver (fake domain) but still creates the auth user + grant — fine for confirming the call-site; swap in a real `+alias` if you want the email to land.

### Inspect (SQL editor) after the buttons:
```sql
select id, slug, business_name, brand_color, site_style, template_vars, status, access_suspended, a2p_status
  from public.clients where slug = 'c2-test-co';                       -- row exists; defaults correct
select * from public.send_settings where client_id = (select id from public.clients where slug='c2-test-co');  -- 1 row; caps/timezone set
-- submission JSON exists (private):
select name from storage.objects
  where bucket_id='client-assets' and name like (select id::text from public.clients where slug='c2-test-co') || '/onboarding-submission.json';
-- if you ran Provision: the audited grant landed
select ur.role, ur.client_id from public.user_roles ur
  join public.clients c on c.id = ur.client_id where c.slug='c2-test-co';  -- client_owner row
```
**Pass:** clients row created (with DB defaults: `status='active'`, `access_suspended=false`, `a2p_status='not_started'`); `send_settings` upserted; the submission JSON object exists under `<clientId>/`; update applied; (optional) `client_owner` granted. A second `createClientFull` with the same slug → "Slug … is already taken" (the 23505 path).

### Cleanup (required)
```sql
delete from storage.objects where bucket_id='client-assets'
  and name like (select id::text from public.clients where slug='c2-test-co') || '/%';
delete from public.clients where slug = 'c2-test-co';   -- cascades send_settings + any role rows
```
Then delete the **`onboard-harness.tsx`** route and (if you provisioned) the `c2-test+owner@…` auth user in Dashboard → Users.

### After C-2 is green
→ **C-3 (wizard UI)** — the stepper + capture steps + logo/photo upload + the pre-gen console (final review = calls `updateClientSettings`) + the read-only submission viewer, finishing with `provisionClientOwner` + the Remix handoff checklist.

---
**App-layer only. No migration. Baseline `golden-master-v1.7` unchanged. C-2 fns → harness validate → cleanup → C-3 wizard UI.**
