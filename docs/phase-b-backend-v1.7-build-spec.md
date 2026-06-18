# Phase B-backend Build Spec — additive v1.7 pass (`golden-master-v1.7`)

> **Status:** SPEC FOR APPROVAL 2026-06-18. From `main` @ this commit; target backend = `cloud-spark-setup` @ `golden-master-v1.6`. **Nothing opens the backend until the migration SQL below is signed off.** Part of `docs/pathway-to-completion.md` Phase B-backend (the single additive pass that unblocks B's features + the payment gate + D's A2P columns). All 8 scoping decisions approved per the recommended set.

## 1. What this pass adds (all ADDITIVE)
1. **Ticketing** (Features A "edit request" + B "support") — unified 3-table model: `tickets` (`kind` discriminator) + `ticket_messages` + `ticket_attachments`, reusing the `client-assets` storage bucket.
2. **Consent ledger** — append-only `consent_records` + immutability trigger (mirrors `audit_log`); `discount.ts` writes it on both branches.
3. **Payment-access gate** — `clients.access_suspended` boolean + a write-guard trigger (admin/agency-only) + the `setClientAccessSuspended` admin server fn.
4. **A2P core columns** — `clients.a2p_brand_id` / `a2p_campaign_id` / `a2p_status` (enum). Extended step-6 set deferred to Phase D.

## 2. Grounding (verified against frozen `v1.6`)
- **Tenant RLS pattern** = `contacts_all`: `FOR ALL … USING/WITH CHECK (is_admin OR client_id IN user_client_ids)` (`migrations/20260609034320…sql:254`).
- **`audit_tenant_rls()`** scans every `public` base table with a `client_id` column and flags any policy whose `USING`/`WITH CHECK` lacks `(user_client_ids|is_admin)\s*\(` (`20260614222357…sql:58-148`). Every new table here carries `client_id` + the membership policy → must pass (=0).
- **Storage:** `client-assets` bucket already tenant-scoped by `((storage.foldername(name))[1])::uuid IN user_client_ids OR is_admin` (`20260614222357…sql:39-55`) → ticket uploads reuse it, **no new bucket/policy**.
- **`clients_select`** lets a `client_owner` read their own row (`…034320…sql:158-163`) → PWA reads `access_suspended`. **`clients_update`** (`:170-179`) lets a `client_owner` update their own row → hence the write-guard trigger.
- **Reuse:** `tg_set_updated_at` (updated-at trigger), `is_admin`/`user_client_ids` helpers, `audit_log_immutable` pattern (for the consent ledger).
- **`provider_subaccount_sid` + `provider_webhook_secret` already exist**; only `a2p_*` are missing. `access_suspended` absent. `contacts.consent_at/basis` exist; `discount.ts:128-129` writes them on INSERT only (`:110-117` update branch is the gap).
- **`events`** has nullable `contact_id` + `created_by` (`…034320…sql:451-459`) → the suspend-event row is safe.

---

## 3. THE MIGRATION (exact final SQL — additive only)

> **Additive-contract confirmation:** every statement is `CREATE TYPE` / `CREATE TABLE` / `ADD COLUMN` / a **new** policy on a **new** table / a **new** trigger. **No `ALTER` of existing column logic. No change to any existing RLS policy on any existing table. `audit_tenant_rls()` is NOT modified. `clients_public` view is NOT modified** (the new `clients` columns are internal and stay out of the anon projection). The only touches to an existing object are 4× `ADD COLUMN` on `clients` and one **new** `BEFORE UPDATE` trigger on `clients` (additive behavior, precedented by the `user_roles` audit trigger added in the `audit_log` pass).

```sql
-- =====================================================================
-- golden-master-v1.7 — additive backend pass (Phase B-backend)
-- Ticketing (A/B) + consent ledger + access_suspended gate + A2P core columns
-- ADDITIVE ONLY. No ALTER of existing object logic; no change to existing RLS.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. ENUMS
-- ---------------------------------------------------------------------
CREATE TYPE public.ticket_kind   AS ENUM ('edit_request','support');
CREATE TYPE public.ticket_status AS ENUM ('open','in_progress','approved','denied','resolved','closed');
CREATE TYPE public.a2p_status    AS ENUM ('not_started','brand_pending','brand_approved','campaign_pending','approved','rejected');

-- ---------------------------------------------------------------------
-- 2. CLIENTS — additive columns (payment gate + A2P core trio)
-- ---------------------------------------------------------------------
ALTER TABLE public.clients
  ADD COLUMN access_suspended boolean           NOT NULL DEFAULT false,
  ADD COLUMN a2p_brand_id     text,
  ADD COLUMN a2p_campaign_id  text,
  ADD COLUMN a2p_status       public.a2p_status NOT NULL DEFAULT 'not_started';

-- ---------------------------------------------------------------------
-- 3. TICKETS (parent)
-- ---------------------------------------------------------------------
CREATE TABLE public.tickets (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id       uuid NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  kind            public.ticket_kind   NOT NULL,
  status          public.ticket_status NOT NULL DEFAULT 'open',
  subject         text NOT NULL,
  created_by      uuid NOT NULL,                       -- auth.users id (client_owner/client_staff)
  assigned_to     uuid,                                -- agency handler (optional)
  resolution      text,                                -- approve/deny description (A) / resolution note (B)
  last_message_at timestamptz NOT NULL DEFAULT now(),  -- for polling/sort
  resolved_at     timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.tickets TO authenticated;
GRANT ALL ON public.tickets TO service_role;
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;
CREATE POLICY tickets_tenant ON public.tickets
  FOR ALL TO authenticated
  USING (
    public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  )
  WITH CHECK (
    public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  );
CREATE TRIGGER trg_tickets_updated_at BEFORE UPDATE ON public.tickets
  FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at();
CREATE INDEX idx_tickets_client_kind_status ON public.tickets(client_id, kind, status);
CREATE INDEX idx_tickets_client_lastmsg     ON public.tickets(client_id, last_message_at DESC);

-- ---------------------------------------------------------------------
-- 4. TICKET_MESSAGES (child) — denormalized client_id (RLS + audit-scan coverage)
-- ---------------------------------------------------------------------
CREATE TABLE public.ticket_messages (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id      uuid NOT NULL REFERENCES public.tickets(id)  ON DELETE CASCADE,
  client_id      uuid NOT NULL REFERENCES public.clients(id)  ON DELETE CASCADE,
  sender_user_id uuid NOT NULL,
  sender_side    text NOT NULL CHECK (sender_side IN ('client','agency')),
  body           text NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ticket_messages TO authenticated;
GRANT ALL ON public.ticket_messages TO service_role;
ALTER TABLE public.ticket_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY ticket_messages_tenant ON public.ticket_messages
  FOR ALL TO authenticated
  USING (
    public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  )
  WITH CHECK (
    public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  );
CREATE INDEX idx_ticket_messages_ticket ON public.ticket_messages(ticket_id, created_at);
CREATE INDEX idx_ticket_messages_client ON public.ticket_messages(client_id);

-- ---------------------------------------------------------------------
-- 5. TICKET_ATTACHMENTS (child) — metadata; binaries live in client-assets bucket
-- ---------------------------------------------------------------------
CREATE TABLE public.ticket_attachments (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id      uuid NOT NULL REFERENCES public.tickets(id)         ON DELETE CASCADE,
  message_id     uuid          REFERENCES public.ticket_messages(id) ON DELETE SET NULL,
  client_id      uuid NOT NULL REFERENCES public.clients(id)         ON DELETE CASCADE,
  storage_bucket text NOT NULL DEFAULT 'client-assets',
  storage_path   text NOT NULL,                       -- '<client_id>/tickets/<ticket_id>/<uuid>-<filename>'
  file_name      text NOT NULL,
  content_type   text,
  size_bytes     bigint,
  uploaded_by    uuid NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ticket_attachments TO authenticated;
GRANT ALL ON public.ticket_attachments TO service_role;
ALTER TABLE public.ticket_attachments ENABLE ROW LEVEL SECURITY;
CREATE POLICY ticket_attachments_tenant ON public.ticket_attachments
  FOR ALL TO authenticated
  USING (
    public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  )
  WITH CHECK (
    public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  );
CREATE INDEX idx_ticket_attachments_ticket ON public.ticket_attachments(ticket_id);
CREATE INDEX idx_ticket_attachments_client ON public.ticket_attachments(client_id);

-- ---------------------------------------------------------------------
-- 6. CONSENT_RECORDS — append-only opt-in ledger.
--    FK-FREE uuid refs (like audit_log) so the immutable trigger cannot be
--    defeated by a cascade UPDATE/DELETE from clients/contacts. Integrity is
--    enforced at write time by the service-role route (resolves real ids).
--    Retained permanently for compliance even if a client/contact is removed.
-- ---------------------------------------------------------------------
CREATE TABLE public.consent_records (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id     uuid NOT NULL,                          -- NO FK (append-only ledger)
  contact_id    uuid,                                   -- NO FK
  consent_basis text NOT NULL,                          -- e.g. 'discount_form_v1'
  channel       text,                                   -- 'web_form' | 'sms' | ...
  evidence      jsonb NOT NULL DEFAULT '{}'::jsonb,     -- { origin, ip, user_agent, via, consent_text_version }
  created_at    timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.consent_records TO authenticated;     -- read-only; writes via service-role
GRANT ALL ON public.consent_records TO service_role;
ALTER TABLE public.consent_records ENABLE ROW LEVEL SECURITY;
-- client_id present → audit_tenant_rls() requires the membership check on SELECT.
CREATE POLICY consent_records_tenant_read ON public.consent_records
  FOR SELECT TO authenticated
  USING (
    public.is_admin((SELECT auth.uid()))
    OR client_id IN (SELECT public.user_client_ids((SELECT auth.uid())))
  );
-- No INSERT/UPDATE/DELETE policy for authenticated → default-deny. Public routes
-- insert via supabaseAdmin (service_role bypasses RLS).
CREATE INDEX idx_consent_records_client_contact ON public.consent_records(client_id, contact_id);
CREATE INDEX idx_consent_records_created        ON public.consent_records(created_at DESC);

-- ---------------------------------------------------------------------
-- 7. TRIGGERS (all NEW)
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
CREATE TRIGGER trg_ticket_messages_client_match
  BEFORE INSERT OR UPDATE ON public.ticket_messages
  FOR EACH ROW EXECUTE FUNCTION public.tg_ticket_child_client_match();
CREATE TRIGGER trg_ticket_attachments_client_match
  BEFORE INSERT OR UPDATE ON public.ticket_attachments
  FOR EACH ROW EXECUTE FUNCTION public.tg_ticket_child_client_match();

-- 7b. access_suspended write-guard: only admin/agency_owner (is_admin) — or
--     service-role / direct SQL (auth.uid() IS NULL) — may change the flag.
--     A client_owner CANNOT self-unsuspend. No-op when the flag is unchanged,
--     so normal client-settings updates are unaffected.
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
CREATE TRIGGER trg_clients_guard_access_suspended
  BEFORE UPDATE ON public.clients
  FOR EACH ROW EXECUTE FUNCTION public.tg_guard_access_suspended();

-- 7c. consent_records append-only (block UPDATE/DELETE for ALL roles) — mirrors audit_log_immutable.
CREATE OR REPLACE FUNCTION public.consent_records_immutable()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'consent_records is append-only (no % allowed)', TG_OP;
END;
$$;
CREATE TRIGGER consent_records_no_update BEFORE UPDATE ON public.consent_records
  FOR EACH ROW EXECUTE FUNCTION public.consent_records_immutable();
CREATE TRIGGER consent_records_no_delete BEFORE DELETE ON public.consent_records
  FOR EACH ROW EXECUTE FUNCTION public.consent_records_immutable();
```

**Design note (consent ledger immutability vs. FKs):** the immutable trigger blocks ALL `UPDATE`/`DELETE`. If `client_id`/`contact_id` were real FKs with cascade actions, hard-deleting a client/contact would attempt a cascade `DELETE`/`SET NULL` on `consent_records` → blocked → the parent delete would fail. Mirroring `audit_log` (which is FK-free), `consent_records` uses plain `uuid` columns; the service-role write path supplies real ids. Consequence: consent records are **permanent** (correct for opt-in proof); purging them later means temporarily dropping the immutability trigger (out of scope).

---

## 4. The two app-layer edits (same batch, post-migration)

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
    ip,                                          // already computed for rate-limit
    user_agent: request.headers.get("user-agent"),
    via: tenant.allowedOrigin ? "origin" : "slug",
    consent_text_version: "discount_form_v1",
  },
});
```
`intake.ts` is **unchanged** — per the locked asymmetric-consent model the lead form has no required consent, so it writes no consent record.

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

    // authz: platform admin / agency_owner only (same pattern as assignUserRole)
    const { data: callerRoles, error: rolesErr } = await supabaseAdmin
      .from("user_roles").select("role").eq("user_id", callerId);
    if (rolesErr) throw new Error("Failed to verify caller");
    if (!(callerRoles ?? []).some((r) => r.role === "admin" || r.role === "agency_owner"))
      throw new Error("Forbidden");

    // service-role update — auth.uid() is NULL here, so the guard trigger allows it.
    const { error } = await supabaseAdmin
      .from("clients")
      .update({ access_suspended: data.suspended })
      .eq("id", data.clientId);
    if (error) throw new Error(error.message);

    // observability (events.contact_id is nullable)
    await supabaseAdmin.from("events").insert({
      client_id: data.clientId,
      type: data.suspended ? "access_suspended" : "access_restored",
      created_by: callerId,
      payload: { reason: data.reason ?? null },
    });

    return { ok: true, clientId: data.clientId, suspended: data.suspended };
  });
```

### 4c. Upload limits (enforced at all three layers — Decision #5)
Allowed: images + PDF + common video. **25 MB cap.** (1) Supabase bucket file-size limit + allowed MIME list on `client-assets`; (2) client-side validation before upload; (3) the upload server fn re-validates `content_type` + `size_bytes` before inserting the `ticket_attachments` row. *(Bucket-config caps are a dashboard/Storage setting, not migration SQL — applied alongside this batch.)*

---

## 5. Validation plan (post-migration, before re-tag)

1. **`SELECT * FROM public.audit_tenant_rls();` → 0 rows.** `tickets`, `ticket_messages`, `ticket_attachments`, `consent_records` all carry `client_id` + the membership policy.
2. **Re-run the 4 isolation guardrails** per the existing checklist (CORS/allowlist resolver, per-client fairness, etc.) — none altered; confirm still green.
3. **Ticketing RLS isolation** (JWT-claims impersonation, the B-0 step-d technique). Seed a ticket (+message +attachment) for client A and client B, then:
   ```sql
   begin;
   select set_config('request.jwt.claims', '{"sub":"<CLIENT_A_OWNER_UUID>"}', true);
   set local role authenticated;
   select id, client_id, kind from public.tickets;             -- only A's rows
   select count(*) from public.ticket_messages;                -- only A's
   select count(*) from public.ticket_attachments;             -- only A's
   rollback;
   ```
   Expect: zero rows belonging to client B across all three tables.
4. **Consent ledger isolation:** same impersonation → `select * from public.consent_records;` returns only client A's; admin (impersonate an admin sub) sees all. Confirm `UPDATE`/`DELETE` on `consent_records` raises `append-only`.
5. **`access_suspended` tamper check:**
   ```sql
   begin;
   select set_config('request.jwt.claims', '{"sub":"<CLIENT_A_OWNER_UUID>"}', true);
   set local role authenticated;
   update public.clients set access_suspended = true where id = '<CLIENT_A_ID>';  -- expect EXCEPTION
   rollback;
   ```
   Then confirm `setClientAccessSuspended` (as an admin) succeeds and flips the flag. Confirm a `client_owner` settings update that leaves `access_suspended` unchanged still works.
6. **Storage isolation:** confirm client A cannot read `B/tickets/...` paths (existing `client_assets_rw` enforces folder[1]=client_id; re-verify with the new path convention).
7. **Consent-write check:** submit the discount form for a NEW and a RETURNING contact → a `consent_records` row appears on each; `contacts.consent_at` refreshed on both.

---

## 6. Re-tag
Single additive migration + the 4a/4b app-layer edits → run §5 → **`golden-master-v1.7`**. This is the one backend open for B + C + D's A2P columns (pathway §55).

## 7. Skill / doc updates (after build + validate)
- **`scratch-foundation`** — **owns the data model**; full v1.7 schema (ticketing, `consent_records`, `access_suspended` + guard, `a2p_*`). Substantive edit.
- **`platform-spec-source-of-truth`** §9b/data-model — reflect v1.7 (mark ticketing/consent/suspend/A2P-core DONE-in-v1.7).
- **`mobile-app`** — one-line pointer: ticketing tables + `access_suspended` read exist (surface build = Phase-B design).
- **`admin-view`** — one-line pointer: edit-requests/support/history + A2P-prep panel + payment toggle back onto the real tables (build = Phase C).
- **`agency-view`** (NEW, Phase C) — one-line pointer: cross-tenant pending lists + payment toggle backed by these tables.

## 8. Sequencing
- **Within the migration:** enums → `clients` columns → `tickets` → children → `consent_records` → triggers → (indexes inline). FK + enum dependencies respected by this order.
- **App edits** (4a/4b) ship after the tables exist — same Lovable batch, post-migration.
- **Surfaces are NOT in this pass** (PWA/admin/agency UIs = Phase-B-design/C).
- **One known later re-open:** Phase D adds the finalized extended A2P columns (→ v1.8). Pure additive `ADD COLUMN`, re-tag-safe.
- **No cross-feature coupling:** ticketing + gate are authed surfaces, disjoint from the A2P flow / scheduling / live flip (pathway §55).

---
**Spec-only. Frozen backend untouched. Awaiting SQL sign-off before anything opens the backend.**
