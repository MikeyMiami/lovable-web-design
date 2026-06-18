# Phase B-backend Build Spec — additive v1.7 pass (`golden-master-v1.7`)

> **Status:** SPEC FOR APPROVAL — **Revision 2** (2026-06-18, post-audit). From `main` @ this commit; target backend = `cloud-spark-setup` @ `golden-master-v1.6`. **Nothing opens the backend until the migration SQL below is signed off.** Part of `docs/pathway-to-completion.md` Phase B-backend.
>
> **R2 changelog (audit findings A–E applied):**
> - **A (security):** ticket tables (`tickets`/`ticket_messages`/`ticket_attachments`) are now **SELECT-only for `authenticated`**; ALL writes go through role-verified **service-role server fns** (§4c) that set `sender_side`/`status`/`resolution`/`created_by`/`assigned_to` authoritatively. A client can no longer self-approve or spoof an agency reply via direct PostgREST. Same tenant membership expression on the read policy → still passes `audit_tenant_rls()`.
> - **B (accuracy):** corrected `clients_public` view → `get_client_public` RPC (the view was dropped in `…225655…sql`).
> - **C (robustness):** migration is now idempotent (`DO`-guarded enums, `IF NOT EXISTS` tables/columns/indexes, `DROP … IF EXISTS` before policies/triggers) **and** must be applied transactionally — both documented.
> - **D:** the attachment fn validates `message_id` belongs to the same `ticket_id`.
> - **E:** the attachment fn builds `storage_path` with the row's `client_id` as `folder[1]` (bucket ACL ↔ metadata coherence).

## 1. What this pass adds (all ADDITIVE)
1. **Ticketing** (Features A "edit request" + B "support") — unified 3-table model: `tickets` (`kind` discriminator) + `ticket_messages` + `ticket_attachments`, reusing the `client-assets` storage bucket. **Read = tenant-scoped RLS; write = service-role server fns only.**
2. **Consent ledger** — append-only `consent_records` + immutability trigger (mirrors `audit_log`); `discount.ts` writes it on both branches.
3. **Payment-access gate** — `clients.access_suspended` boolean + write-guard trigger (admin/agency-only) + the `setClientAccessSuspended` admin server fn.
4. **A2P core columns** — `clients.a2p_brand_id` / `a2p_campaign_id` / `a2p_status` (enum). Extended step-6 set deferred to Phase D.

## 2. Grounding (verified against frozen `v1.6`)
- **Tenant RLS read pattern** = `contacts_all`'s membership expression: `is_admin OR client_id IN user_client_ids` (`migrations/20260609034320…sql:254-262`). (We use it in `USING` for SELECT-only policies.)
- **`audit_tenant_rls()`** scans every `public` base table with a `client_id` column and flags any policy whose `USING`/`WITH CHECK` lacks `(user_client_ids|is_admin)\s*\(` (`…222357…sql:58-148`). For `cmd='SELECT'` only the `USING` (qual) is checked — so SELECT-only tenant policies pass.
- **Anon projection = `get_client_public(_slug)` RPC** — an explicit **13-named-column** SECURITY DEFINER function (`…225655…sql:4-43`), NOT `SELECT *`; the `clients_public` **view was dropped** in that same migration (`:2`). New `clients` columns cannot reach anon. Anon also has `REVOKE ALL ON public.clients` (`…225630…sql:4`).
- **Storage:** `client-assets` bucket already tenant-scoped by `((storage.foldername(name))[1])::uuid IN user_client_ids OR is_admin` (`…222357…sql:39-55`) → ticket uploads reuse it, **no new bucket/policy**.
- **`clients_select`** lets a `client_owner` read their own row (`…034320…sql:158-163`) → PWA reads `access_suspended`. **`clients_update`** (`:170-179`) lets a `client_owner` update their own row → hence the write-guard trigger on the new column.
- **Suspension ≠ stop automations:** `claim_due_enrollments` filters `e.status='active' AND e.next_run_at<=_now` on `enrollments` and **never references `clients.access_suspended`** (`…052815…sql:27-29`).
- **Reuse:** `tg_set_updated_at`, `is_admin`/`user_client_ids` helpers, `audit_log_immutable` pattern. `provider_subaccount_sid`/`provider_webhook_secret` already exist; `a2p_*`/`access_suspended` absent; `contacts.consent_at/basis` exist (`discount.ts:128-129` writes them on INSERT only — `:110-117` is the gap). `events.contact_id`/`created_by` nullable (`…034320…sql:451-459`).

---

## 3. THE MIGRATION (exact final SQL — additive, idempotent, transactional)

> **Apply requirement (Finding C):** run as a **single transaction** (`BEGIN; … COMMIT;`). The Supabase CLI wraps each migration file in a transaction automatically; if applied by pasting into the SQL Editor, wrap it manually so any failure rolls back atomically. The `IF NOT EXISTS` / `DROP … IF EXISTS` guards additionally make a partial re-run safe.
>
> **Additive-contract confirmation:** every object created is **new**. The only touches to existing objects are 4× `ADD COLUMN IF NOT EXISTS` on `clients` and one **new** trigger on `clients`. Every `DROP … IF EXISTS` targets **only this migration's own new policies/triggers** (re-run guards) — none references a pre-existing live policy or trigger (e.g. `trg_clients_updated_at`, `clients_select`, `contacts_all` are never named). No `ALTER` of existing column logic; no edit to existing RLS; `audit_tenant_rls()` and `get_client_public` are NOT modified.

```sql
BEGIN;
-- =====================================================================
-- golden-master-v1.7 — additive backend pass (Phase B-backend), Revision 2
-- Ticketing (A/B, read-only RLS + service-role writes) + consent ledger
-- + access_suspended gate + A2P core columns.
-- ADDITIVE ONLY. Idempotent. Apply in a single transaction.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. ENUMS  (DO-guarded for idempotent re-run)
-- ---------------------------------------------------------------------
DO $$ BEGIN
  CREATE TYPE public.ticket_kind AS ENUM ('edit_request','support');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.ticket_status AS ENUM ('open','in_progress','approved','denied','resolved','closed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.a2p_status AS ENUM ('not_started','brand_pending','brand_approved','campaign_pending','approved','rejected');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ---------------------------------------------------------------------
-- 2. CLIENTS — additive columns (payment gate + A2P core trio)
-- ---------------------------------------------------------------------
ALTER TABLE public.clients
  ADD COLUMN IF NOT EXISTS access_suspended boolean           NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS a2p_brand_id     text,
  ADD COLUMN IF NOT EXISTS a2p_campaign_id  text,
  ADD COLUMN IF NOT EXISTS a2p_status       public.a2p_status NOT NULL DEFAULT 'not_started';

-- ---------------------------------------------------------------------
-- 3. TICKETS (parent) — READ-ONLY for authenticated; writes via service-role fns
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tickets (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id       uuid NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  kind            public.ticket_kind   NOT NULL,
  status          public.ticket_status NOT NULL DEFAULT 'open',
  subject         text NOT NULL,
  created_by      uuid NOT NULL,                       -- set authoritatively by the open-ticket fn
  assigned_to     uuid,                                -- set by agency-reply / set-status fns
  resolution      text,                                -- set by set-status fn (approve/deny/resolve)
  last_message_at timestamptz NOT NULL DEFAULT now(),
  resolved_at     timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.tickets TO authenticated;          -- READ-ONLY; no write grant
GRANT ALL ON public.tickets TO service_role;
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tickets_tenant_read ON public.tickets;
CREATE POLICY tickets_tenant_read ON public.tickets
  FOR SELECT TO authenticated
  USING (
    public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  );
DROP TRIGGER IF EXISTS trg_tickets_updated_at ON public.tickets;
CREATE TRIGGER trg_tickets_updated_at BEFORE UPDATE ON public.tickets
  FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at();
CREATE INDEX IF NOT EXISTS idx_tickets_client_kind_status ON public.tickets(client_id, kind, status);
CREATE INDEX IF NOT EXISTS idx_tickets_client_lastmsg     ON public.tickets(client_id, last_message_at DESC);

-- ---------------------------------------------------------------------
-- 4. TICKET_MESSAGES (child) — denormalized client_id; READ-ONLY for authenticated
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ticket_messages (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id      uuid NOT NULL REFERENCES public.tickets(id)  ON DELETE CASCADE,
  client_id      uuid NOT NULL REFERENCES public.clients(id)  ON DELETE CASCADE,
  sender_user_id uuid NOT NULL,                         -- set authoritatively by the write fn
  sender_side    text NOT NULL CHECK (sender_side IN ('client','agency')),  -- set by the write fn, never client-supplied
  body           text NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.ticket_messages TO authenticated;  -- READ-ONLY
GRANT ALL ON public.ticket_messages TO service_role;
ALTER TABLE public.ticket_messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ticket_messages_tenant_read ON public.ticket_messages;
CREATE POLICY ticket_messages_tenant_read ON public.ticket_messages
  FOR SELECT TO authenticated
  USING (
    public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  );
CREATE INDEX IF NOT EXISTS idx_ticket_messages_ticket ON public.ticket_messages(ticket_id, created_at);
CREATE INDEX IF NOT EXISTS idx_ticket_messages_client ON public.ticket_messages(client_id);

-- ---------------------------------------------------------------------
-- 5. TICKET_ATTACHMENTS (child) — metadata; binaries live in client-assets bucket
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ticket_attachments (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id      uuid NOT NULL REFERENCES public.tickets(id)         ON DELETE CASCADE,
  message_id     uuid          REFERENCES public.ticket_messages(id) ON DELETE SET NULL,
  client_id      uuid NOT NULL REFERENCES public.clients(id)         ON DELETE CASCADE,
  storage_bucket text NOT NULL DEFAULT 'client-assets',
  storage_path   text NOT NULL,                       -- '<client_id>/tickets/<ticket_id>/<uuid>-<filename>' (Finding E)
  file_name      text NOT NULL,
  content_type   text,
  size_bytes     bigint,
  uploaded_by    uuid NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.ticket_attachments TO authenticated;  -- READ-ONLY
GRANT ALL ON public.ticket_attachments TO service_role;
ALTER TABLE public.ticket_attachments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ticket_attachments_tenant_read ON public.ticket_attachments;
CREATE POLICY ticket_attachments_tenant_read ON public.ticket_attachments
  FOR SELECT TO authenticated
  USING (
    public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  );
CREATE INDEX IF NOT EXISTS idx_ticket_attachments_ticket ON public.ticket_attachments(ticket_id);
CREATE INDEX IF NOT EXISTS idx_ticket_attachments_client ON public.ticket_attachments(client_id);

-- ---------------------------------------------------------------------
-- 6. CONSENT_RECORDS — append-only opt-in ledger (FK-free, like audit_log)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.consent_records (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id     uuid NOT NULL,                          -- NO FK (append-only ledger)
  contact_id    uuid,                                   -- NO FK
  consent_basis text NOT NULL,
  channel       text,
  evidence      jsonb NOT NULL DEFAULT '{}'::jsonb,     -- { origin, ip, user_agent, via, consent_text_version }
  created_at    timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.consent_records TO authenticated;    -- read-only; writes via service-role
GRANT ALL ON public.consent_records TO service_role;
ALTER TABLE public.consent_records ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS consent_records_tenant_read ON public.consent_records;
CREATE POLICY consent_records_tenant_read ON public.consent_records
  FOR SELECT TO authenticated
  USING (
    public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  );
CREATE INDEX IF NOT EXISTS idx_consent_records_client_contact ON public.consent_records(client_id, contact_id);
CREATE INDEX IF NOT EXISTS idx_consent_records_created        ON public.consent_records(created_at DESC);

-- ---------------------------------------------------------------------
-- 7. TRIGGERS (all NEW; functions are CREATE OR REPLACE = idempotent;
--    each CREATE TRIGGER guarded by DROP TRIGGER IF EXISTS on its OWN name)
-- ---------------------------------------------------------------------

-- 7a. Ticket child rows: client_id must equal the parent ticket's client_id.
CREATE OR REPLACE FUNCTION public.tg_ticket_child_client_match()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_parent_client uuid;
BEGIN
  SELECT client_id INTO v_parent_client FROM public.tickets WHERE id = NEW.ticket_id;
  IF v_parent_client IS NULL THEN
    RAISE EXCEPTION 'ticket % not found', NEW.ticket_id;
  END IF;
  IF NEW.client_id IS DISTINCT FROM v_parent_client THEN
    RAISE EXCEPTION 'child client_id % must equal parent ticket client_id %', NEW.client_id, v_parent_client;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_ticket_messages_client_match ON public.ticket_messages;
CREATE TRIGGER trg_ticket_messages_client_match
  BEFORE INSERT OR UPDATE ON public.ticket_messages
  FOR EACH ROW EXECUTE FUNCTION public.tg_ticket_child_client_match();
DROP TRIGGER IF EXISTS trg_ticket_attachments_client_match ON public.ticket_attachments;
CREATE TRIGGER trg_ticket_attachments_client_match
  BEFORE INSERT OR UPDATE ON public.ticket_attachments
  FOR EACH ROW EXECUTE FUNCTION public.tg_ticket_child_client_match();

-- 7b. access_suspended write-guard (admin/agency or service-role only; no-op if unchanged).
CREATE OR REPLACE FUNCTION public.tg_guard_access_suspended()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NEW.access_suspended IS DISTINCT FROM OLD.access_suspended THEN
    IF auth.uid() IS NOT NULL AND NOT public.is_admin(auth.uid()) THEN
      RAISE EXCEPTION 'access_suspended may only be changed by admin/agency_owner';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_clients_guard_access_suspended ON public.clients;
CREATE TRIGGER trg_clients_guard_access_suspended
  BEFORE UPDATE ON public.clients
  FOR EACH ROW EXECUTE FUNCTION public.tg_guard_access_suspended();

-- 7c. consent_records append-only (block UPDATE/DELETE for ALL roles).
CREATE OR REPLACE FUNCTION public.consent_records_immutable()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'consent_records is append-only (no % allowed)', TG_OP;
END;
$$;
DROP TRIGGER IF EXISTS consent_records_no_update ON public.consent_records;
CREATE TRIGGER consent_records_no_update BEFORE UPDATE ON public.consent_records
  FOR EACH ROW EXECUTE FUNCTION public.consent_records_immutable();
DROP TRIGGER IF EXISTS consent_records_no_delete ON public.consent_records;
CREATE TRIGGER consent_records_no_delete BEFORE DELETE ON public.consent_records
  FOR EACH ROW EXECUTE FUNCTION public.consent_records_immutable();

COMMIT;
```

**Design note (consent ledger immutability vs. FKs):** the immutable trigger blocks ALL `UPDATE`/`DELETE`. Real FKs with cascade would let a client/contact delete trigger a cascade `DELETE`/`SET NULL` on `consent_records` → blocked → the parent delete fails. Mirroring `audit_log` (FK-free), the columns are plain `uuid`; the service-role write supplies real ids. Consent records are permanent (correct for opt-in proof).

---

## 4. App-layer changes (same batch, post-migration)

### 4a. `src/routes/api/public/discount.ts` — write `consent_records` on BOTH branches
**Edit 1 — returning-contact UPDATE branch (closes the `:110-117` gap): re-stamp consent.**
```ts
await supabaseAdmin
  .from("contacts")
  .update({
    first_name: parsed.data.first_name,
    last_name: parsed.data.last_name ?? null,
    notes: parsed.data.your_message ?? null,
    consent_basis: "discount_form_v1",          // + re-stamp on returning contact
    consent_at: new Date().toISOString(),       // +
  })
  .eq("id", contactId);
```
**Edit 2 — after the `if (existing) … else …` block (covers BOTH branches), append one ledger row** (before the existing `events` insert):
```ts
await supabaseAdmin.from("consent_records").insert({
  client_id: tenant.clientId,
  contact_id: contactId,
  consent_basis: "discount_form_v1",
  channel: "web_form",
  evidence: {
    origin: originHeader,
    ip,
    user_agent: request.headers.get("user-agent"),
    via: tenant.allowedOrigin ? "origin" : "slug",
    consent_text_version: "discount_form_v1",
  },
});
```
`intake.ts` is **unchanged** (asymmetric-consent model: the lead form has no required consent).

### 4b. `src/lib/clients/access.functions.ts` — NEW admin-gated server fn
```ts
import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

const SetAccessSuspendedInput = z.object({
  clientId: z.string().uuid(),
  suspended: z.boolean(),
  reason: z.string().max(500).optional(),
});

export const setClientAccessSuspended = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input: unknown) => SetAccessSuspendedInput.parse(input))
  .handler(async ({ data, context }) => {
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const callerId = context.userId;
    const { data: callerRoles, error: rolesErr } = await supabaseAdmin
      .from("user_roles").select("role").eq("user_id", callerId);
    if (rolesErr) throw new Error("Failed to verify caller");
    if (!(callerRoles ?? []).some((r) => r.role === "admin" || r.role === "agency_owner"))
      throw new Error("Forbidden");
    const { error } = await supabaseAdmin            // service-role → auth.uid() NULL → guard allows
      .from("clients").update({ access_suspended: data.suspended }).eq("id", data.clientId);
    if (error) throw new Error(error.message);
    await supabaseAdmin.from("events").insert({
      client_id: data.clientId,
      type: data.suspended ? "access_suspended" : "access_restored",
      created_by: callerId,
      payload: { reason: data.reason ?? null },
    });
    return { ok: true, clientId: data.clientId, suspended: data.suspended };
  });
```

### 4c. Ticket write server fns — **the write boundary** (NEW; all service-role + `requireSupabaseAuth`)
Because the ticket tables are SELECT-only for `authenticated`, **every** mutation goes through one of these `createServerFn` fns using `supabaseAdmin`. Each resolves the caller's authority from `user_roles` and sets trust fields **authoritatively** — `sender_side`/`status`/`created_by`/`assigned_to`/`resolution` are NEVER taken from client input. Two shared helpers: `isAdmin(callerId)` = caller has `admin`/`agency_owner`; `isMemberOf(callerId, clientId)` = `clientId ∈ user_client_ids(callerId)`.

> These fns are *specced here* but **built in Phase-B design** (they need the PWA/admin UI). The migration + 4a/4b ship now; 4c lands with the surfaces. They are the security boundary, so their authz is locked here.

1. **`openTicket({ clientId, kind, subject, body })` → `{ ticketId }`**
   - authz: `isAdmin(caller) || isMemberOf(caller, clientId)`; else `Forbidden`. Validate `clientId` exists + not archived.
   - INSERT `tickets`: `client_id=clientId`, `kind` (enum-validated), `subject`, `status='open'`, `created_by=caller`.
   - INSERT first `ticket_messages`: `sender_side = isAdmin(caller) ? 'agency' : 'client'`, `sender_user_id=caller`, `client_id=clientId`, `body`. Set `last_message_at=now()`.

2. **`postClientMessage({ ticketId, body })` → `{ messageId }`**
   - Load ticket. authz: `isMemberOf(caller, ticket.client_id)` (client side); else `Forbidden`. (Admins use `postAgencyReply`.)
   - INSERT message: `sender_side='client'` (forced), `sender_user_id=caller`, `client_id=ticket.client_id`. Update `last_message_at`. If ticket was `resolved`/`closed`, reopen to `open` (client reply reopens — explicit design choice).

3. **`postAgencyReply({ ticketId, body, newStatus? })` → `{ messageId }`**
   - authz: `isAdmin(caller)` only.
   - INSERT message: `sender_side='agency'` (forced), `sender_user_id=caller`, `client_id=ticket.client_id`. Set `assigned_to=caller` if null; apply optional `newStatus` (validated); `last_message_at=now()`.

4. **`setTicketStatus({ ticketId, status, resolution? })` → `{ ok }`**
   - authz: `isAdmin(caller)` only — approve/deny/resolve are agency authority.
   - Validate per-kind: `edit_request` → `approved`/`denied` **require** `resolution` (the description returned to the client); `support` → `in_progress`/`resolved`/`closed`. Set `status`, `resolution`, and `resolved_at` when terminal.
   - *(A client-initiated transition, e.g. a client closing their own support ticket, would be a separate narrowly-scoped `clientCloseTicket` fn — never folded into this admin fn.)*

5. **`recordTicketAttachment({ ticketId, messageId?, storagePath, fileName, contentType, sizeBytes })` → `{ attachmentId }`**
   - authz: `isAdmin(caller) || isMemberOf(caller, ticket.client_id)`.
   - **Finding D:** if `messageId` given, verify it belongs to `ticketId` → else reject.
   - **Finding E:** verify `storagePath` starts with `<ticket.client_id>/tickets/<ticketId>/` so the bucket ACL (`client_assets_rw`, `folder[1] ∈ user_client_ids`) and the metadata row's `client_id` agree.
   - **Decision 5:** verify `contentType ∈ {image/*, application/pdf, common video}` and `sizeBytes ≤ 25*1024*1024`; else reject.
   - INSERT `ticket_attachments` with `client_id=ticket.client_id`, `uploaded_by=caller`.
   - Binary path: the client uploads the file to the tenant path in `client-assets` directly (authenticated; `client_assets_rw` authorizes `folder[1] ∈ their client_ids`), then calls this fn to register metadata — OR the fn proxies the upload via service-role. Either way the §E path invariant holds.

### 4d. Upload limits (Decision #5) — three layers
Allowed: images + PDF + common video; **25 MB cap.** (1) Supabase `client-assets` bucket file-size limit + allowed-MIME list (**Storage dashboard setting, not migration SQL** — applied alongside this batch); (2) client-side pre-upload validation; (3) `recordTicketAttachment` re-validates `content_type` + `size_bytes` (§4c-5).

---

## 5. Validation plan (post-migration, before re-tag)

1. **`SELECT * FROM public.audit_tenant_rls();` → 0 rows.** Re-confirm the **SELECT-only** ticket policies still pass: for `cmd='SELECT'` the scan checks only the `USING` qual, and each contains `is_admin(`/`user_client_ids(` (same membership expression as before) → 0. `consent_records` likewise.
2. **Re-run the 4 isolation guardrails** (CORS/allowlist, per-client fairness, etc.) — none altered; confirm green.
3. **Ticketing READ isolation** (JWT-claims impersonation, B-0 step-d technique). Seed (via service-role) a ticket + message + attachment for client A and client B, then impersonate A's owner:
   ```sql
   begin;
   select set_config('request.jwt.claims', '{"sub":"<CLIENT_A_OWNER_UUID>"}', true);
   set local role authenticated;
   select count(*) from public.tickets;             -- only A's
   select count(*) from public.ticket_messages;     -- only A's
   select count(*) from public.ticket_attachments;  -- only A's
   rollback;
   ```
4. **Ticketing WRITE lockout (the Finding-A proof).** As an impersonated `client_owner`, attempt direct writes — all must FAIL (no write grant + no write policy):
   ```sql
   begin;
   select set_config('request.jwt.claims', '{"sub":"<CLIENT_A_OWNER_UUID>"}', true);
   set local role authenticated;
   update public.tickets set status='approved' where id='<A_TICKET>';                       -- expect 0 rows / denied
   insert into public.ticket_messages(ticket_id,client_id,sender_user_id,sender_side,body)
     values('<A_TICKET>','<CLIENT_A_ID>','<CLIENT_A_OWNER_UUID>','agency','spoof');          -- expect denied
   rollback;
   ```
   Confirms a client can neither self-approve nor spoof an `agency` message via direct DB access.
5. **Consent ledger:** impersonation → client sees only their own; admin sees all; `UPDATE`/`DELETE` on `consent_records` raises `append-only`.
6. **`access_suspended` tamper check:** impersonated `client_owner` `UPDATE clients SET access_suspended=true` → EXCEPTION; `setClientAccessSuspended` (admin) succeeds; a client settings update that leaves the flag unchanged still works.
7. **Storage isolation:** client A cannot read `B/tickets/...` paths (existing `client_assets_rw`).
8. **Consent-write check:** discount submit (new + returning contact) → a `consent_records` row each; `contacts.consent_at` refreshed on both.
9. **Additive re-confirm:** diff the live schema — only new objects + the 4 `clients` columns + the new `clients` guard trigger; no existing policy/trigger changed.

---

## 6. Re-tag
Single additive transactional migration + the 4a/4b edits (4c ships with the Phase-B surfaces) → run §5 → **`golden-master-v1.7`**.

## 7. Skill / doc updates (after build + validate)
- **`scratch-foundation`** — owns the data model; full v1.7 schema + **the read-only-RLS / service-role-write contract for ticketing** (the security boundary). Substantive edit.
- **`platform-spec-source-of-truth`** §9b/data-model — reflect v1.7 (ticketing/consent/suspend/A2P-core DONE-in-v1.7; ticket writes = service-role fns).
- **`mobile-app`** — pointer: ticket tables (read-only RLS) + the write fns + `access_suspended` read exist (surface build = Phase-B design).
- **`admin-view`** — pointer: edit-requests/support/history + A2P-prep panel + payment toggle back onto the real tables + `setTicketStatus`/`postAgencyReply` (build = Phase C).
- **`agency-view`** (NEW, Phase C) — pointer: cross-tenant pending lists + payment toggle.

## 8. Sequencing
- **Within the migration:** enums → `clients` columns → `tickets` → children → `consent_records` → trigger functions+triggers → indexes inline. All in one transaction.
- **App edits:** 4a/4b ship post-migration this batch; 4c ships with the Phase-B surfaces (the write boundary is specced + authz-locked here).
- **One known later re-open:** Phase D adds the finalized extended A2P columns (→ v1.8). Pure additive.
- **No cross-feature coupling:** ticketing + gate are authed surfaces, disjoint from the A2P flow / scheduling / live flip (pathway §55).

---
**Spec-only. Frozen backend untouched. Awaiting SQL sign-off before anything opens the backend.**
