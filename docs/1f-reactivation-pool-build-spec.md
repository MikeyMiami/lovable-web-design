# 1f — Reactivation Number Pool — Audit + Build Spec

> Net-new **agency-level** feature: finite, one-time reactivation campaigns for a client, sent from a pool of agency-owned pre-approved A2P numbers (agency "PierceWorks" campaign), with auto-release on completion. Requirements spec: `docs/reactivation-number-pool-spec.md`. Audited against real frozen code @ `golden-master-v1.5` (`cloud-spark-setup@838fbe8`). Audit + spec only.

## Audit findings (reconciled against real v1.5 code — the spec's open questions are now ANSWERED)

**A. The send seam supports the pool with ZERO modification.** `SendSmsArgs = {to, from, body, sendingAccountSid, auth, mode, statusCallback?}` (`send.server.ts`). The finite runner calls `sendSmsWithRetry` with `from`=the campaign's pool number, `sendingAccountSid`=the agency master/PierceWorks account, `auth`=the master creds (`getTextGridConfig()` `TEXTGRID_MASTER_*` — the pool numbers live under the master account, not a per-client subaccount). This is exactly the from-seam's design intent. ✓

**B. Placement = (a) separate agency-ops layer — FORCED by `claim_due_enrollments`.** The frozen claim fn (`20260615211906`) reads **only `public.enrollments`**, round-robins by `client_id`, with **no campaign/sequence filter**; the per-client runner then resolves `from=clients.twilio_number`. So pool enrollments in the frozen `enrollments` table would be **claimed by the per-client runner and sent from the wrong number**. → **Separate `reactivation_enrollments` table + a separate finite-campaign runner.** The frozen `enrollments` / `claim_due_enrollments` / per-client runner / cron route stay **untouched**. (Confirms the spec's lean and the 1f-prep decision against real code.)

**C. Runner = SEPARATE finite-campaign runner (not shared).** It claims from `reactivation_enrollments` (its own `FOR UPDATE SKIP LOCKED`), resolves `from`=pool number, sends via the unchanged primitive, advances, and runs the release-check. **No double-claim risk** — the two runners read disjoint tables (`enrollments` vs `reactivation_enrollments`). Reuses (read-only) `resolveTemplate` + `dripMergeVars` + the send primitive; does NOT modify them.

**D. RLS / `audit_tenant_rls()=0` — precise rules from the real audit fn:**
- `reactivation_numbers` → **no `client_id`** → outside the audit scan → RLS-on + **service-role-only (no policies)** is fine (like `rate_limit_hits`).
- `reactivation_campaigns` → **has `client_id`** ("for whom") → **IN scan** → MUST have ≥1 policy referencing **`is_admin(...)`** (the audit regex accepts it). RLS-on-no-policies would FAIL ("No RLS policies defined"). → give it an `is_admin()` ALL policy.
- `reactivation_enrollments` → **omit `client_id`** (reference the client via `campaign_id → reactivation_campaigns.client_id`) → **outside scan** → service-role-only. Keeps the audit surface to one table (`reactivation_campaigns`).
- These are **agency-scoped, NOT tenant-RLS** — `client_id` is "for whom," not "tenant of." No conflict with the frozen tenant model.

**E. Release-condition fits the enrollment structure.** After each finite tick, per `dripping` campaign: `COUNT(reactivation_enrollments WHERE campaign_id=X AND status='active' AND next_run_at IS NOT NULL) = 0` → campaign `completed` + release the number. A reactivation drip's follow-ups keep the number `in_use` until the LAST follow-up of the LAST contact fires. ✓

**F. Per-client reactivation deprecation holds.** `enrollReactivation` (`enroll.server.ts`) is intact, called ONLY by `admin.reactivation.tsx` (CSV upload), no auto-trigger → logically deprecated, routes zero real traffic. The pool is the sole real reactivation mechanism with **no frozen-code change**. ✓

## Scope
**IN:** 3 net-new agency tables + their RLS; a separate finite-campaign runner + its own cron route; assign/release state machine; agency-view UI (manage pool numbers + CSV→dropdown→assign + auto-release); additive migrations (`audit_tenant_rls()=0`); `RUNNER_VERSION` bump. **OUT / untouched:** frozen `enrollments`/`claim_due_enrollments`/per-client runner/cron route; the send primitive (reused as-is); `enrollReactivation` (left deprecated-intact); pg_cron scheduling of the new cron route (= the LAST 1f step). **No new TextGrid creds** (reuses master creds).

## Locked decisions (confirmed vs real code)
1. **Separate agency-ops layer** (tables + runner + cron route); frozen path untouched. [B/C]
2. **`is_admin()` RLS** on `reactivation_campaigns` (audit-passing); service-role-only on `reactivation_numbers`/`reactivation_enrollments` (no `client_id` → outside audit). [D]
3. **Reuse the send primitive** with `from`=pool number, `sendingAccountSid`/`auth`=agency master creds. [A]
4. **Reuse the `reactivation` sequence/templates** (the frozen global `reactivation` drip copy) via `resolveTemplate`. Pool enrollments use `sequence_key='reactivation'` but live in `reactivation_enrollments`.
5. **Apply the SMS send window** (9am–7pm client tz, like marketing SMS) in the finite runner — don't text past customers at 2am. (Reuse the window logic conceptually; agency/per-campaign default.)

## Change-set

### 1. Additive migration (`audit_tenant_rls()=0` after)
```sql
-- pool numbers (agency-owned; NO client_id → outside tenant-audit scope)
CREATE TABLE IF NOT EXISTS public.reactivation_numbers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_number text NOT NULL UNIQUE,
  status text NOT NULL DEFAULT 'available' CHECK (status IN ('available','in_use')),
  current_campaign_id uuid,
  date_added timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.reactivation_numbers ENABLE ROW LEVEL SECURITY;  -- service-role only (no client_id)

-- campaigns (HAS client_id="for whom" → MUST carry an is_admin() policy to pass the audit)
CREATE TABLE IF NOT EXISTS public.reactivation_campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES public.clients(id),
  pool_number_id uuid REFERENCES public.reactivation_numbers(id),
  status text NOT NULL DEFAULT 'dropping' CHECK (status IN ('dropping','dripping','completed')),
  total_contacts int NOT NULL DEFAULT 0,
  enrolled_count int NOT NULL DEFAULT 0,
  csv_uploaded_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz
);
ALTER TABLE public.reactivation_campaigns ENABLE ROW LEVEL SECURITY;
CREATE POLICY reactivation_campaigns_admin ON public.reactivation_campaigns
  FOR ALL TO authenticated
  USING (is_admin((SELECT auth.uid()))) WITH CHECK (is_admin((SELECT auth.uid())));

-- finite-campaign enrollments (NO client_id → outside audit; client via campaign join)
CREATE TABLE IF NOT EXISTS public.reactivation_enrollments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES public.reactivation_campaigns(id),
  contact_id uuid NOT NULL REFERENCES public.contacts(id),
  sequence_key text NOT NULL DEFAULT 'reactivation',
  current_step int NOT NULL DEFAULT 0,
  next_run_at timestamptz,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','completed','exited','failed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (campaign_id, contact_id)
);
ALTER TABLE public.reactivation_enrollments ENABLE ROW LEVEL SECURITY;  -- service-role only
CREATE INDEX IF NOT EXISTS ix_react_enr_due ON public.reactivation_enrollments (next_run_at) WHERE status='active';
```
*(All `GRANT`s: service_role; no anon/authenticated grants on `reactivation_numbers`/`reactivation_enrollments`. Run `audit_tenant_rls()` → expect 0: `reactivation_campaigns` passes via the `is_admin()` policy; the other two are out of scope.)*

### 2. Assign / release state machine
- **Assign (atomic, race-safe):** `UPDATE reactivation_numbers SET status='in_use', current_campaign_id=$campaign WHERE id=$picked AND status='available' RETURNING id` → 0 rows = "number just taken" (another admin won the race) → error, no campaign bound. Then create the `reactivation_campaigns` row (`dropping`), parse CSV → upsert `contacts` (client's, `source='import'`) → insert `reactivation_enrollments` (step 0, `next_run_at=now`) → campaign → `dripping`.
- **Release (after each tick, per `dripping` campaign):** `if COUNT(reactivation_enrollments WHERE campaign_id=X AND status='active' AND next_run_at IS NOT NULL)=0` → `reactivation_campaigns.status='completed', completed_at=now()`; `reactivation_numbers.status='available', current_campaign_id=NULL`.

### 3. Finite-campaign runner — `src/lib/reactivation/runner.server.ts` (net-new)
- `runReactivationTick()`: claim due `reactivation_enrollments` (`status='active', next_run_at<=now`, `FOR UPDATE SKIP LOCKED`, bounded; fairness across campaigns). For each: load campaign → pool number + client; resolve `to`=contact `phone_e164`; **SMS-window gate** (defer if outside 9–7 client tz); render `resolveTemplate(client_id, step.templateKey)` + `dripMergeVars`; `sendSmsWithRetry({to, from: poolNumber, body, sendingAccountSid: master, auth: master, mode})`; materialize via `insertOutboundMessageAdmin`; advance/reschedule (mirror the frozen advance). Then the **release-check** per touched campaign. Emit `events` (`reactivation_sent`, `reactivation_campaign_completed`).
- **Net-new cron route `src/routes/api/public/cron/reactivation.ts`** (server-to-server, `x-cron-secret`, mirrors the frozen cron route's auth) → `runReactivationTick()`. Scheduled by pg_cron at the LAST 1f step (separate job from the drip runner).

### 4. Agency-view UI (admin-view skill surface; is_admin server fns)
- **Settings → Reactivation Numbers:** list (number, status, + current client business_name via `current_campaign_id→reactivation_campaigns→clients` when `in_use`), add/remove.
- **CSV upload:** dropdown of pool numbers — `available`=selectable, `in_use`=greyed + "in use — {client}"; on submit → atomic assign + campaign create + enroll. Progress view of active campaigns (counts).

### 5. `RUNNER_VERSION` bump (→ `v20260617-5`) — cron bundle changes (new route).

## Validation walk (STUB)
1. Deploy → `?ping=1` echoes `v20260617-5`.
2. **Pool mgmt:** add 2 numbers (`available`); admin list shows status.
3. **Assign + race:** CSV upload → pick an `available` number → it flips `in_use`+campaign bound; a 2nd concurrent assign of the same number → "number just taken" (atomic `WHERE status='available'`). Dropdown shows the taken one greyed + client label.
4. **Finite tick (STUB):** `POST /api/public/cron/reactivation` (x-cron-secret) → stub sends with `from`=the POOL number (assert in the `messages`/event, NOT `clients.twilio_number`); enrollments advance.
5. **Frozen-runner isolation:** the per-client `runDripTick` does NOT touch any `reactivation_enrollments` (disjoint table) — confirm no pool enrollment is claimed by it.
6. **Release:** drive all enrollments to terminal → next reactivation tick → campaign `completed` + number flips `available` (ungreys).
7. `audit_tenant_rls()=0`.

## Blockers / edge cases (tagged)
- **🔴 [BLOCKER — handled by design] Pool enrollments must NOT enter the frozen `enrollments` table** — `claim_due_enrollments` has no campaign filter → would claim + send from `clients.twilio_number`. Separate `reactivation_enrollments` + separate runner is the structural fix. (THE driver.)
- **🟠 [FIX] `reactivation_campaigns` MUST have an `is_admin()` policy** (it has `client_id`) or `audit_tenant_rls()` fails ("No RLS policies defined"). `reactivation_numbers`/`reactivation_enrollments` (no `client_id`) are service-role-only.
- **[FIX] Premature release** — the release-check counts `active` enrollments with a non-null `next_run_at`; a straggler follow-up (future `next_run_at`) keeps the number `in_use`. A `failed`/`exited` enrollment doesn't block release. Verify the count semantics.
- **[FIX] Assign race** — atomic conditional UPDATE `WHERE status='available'` (above); never read-then-write.
- **[FIX] CSV for a non-existent/archived client** — validate `client_id` exists + `status='active'` before creating the campaign.
- **[FIX] Two runners double-claiming** — impossible (disjoint tables); but the finite runner needs its OWN `FOR UPDATE SKIP LOCKED` for overlapping reactivation ticks.
- **[FIX] Send-window** — apply 9–7 (decision 5); a finite campaign shouldn't text at 2am. (Caps optional — finite list, but a daily cap is reasonable.)
- **[BACKLOG] Dirty-list isolation** — one campaign per number at a time (structural via `current_campaign_id`); a flagged number cycles out. ✓ already enforced.
- **[BACKLOG] Contact source** — reuse `contact_source='import'` for CSV contacts (enum exists; no migration).

## Open / confirm items
- Pool numbers are registered under the agency PierceWorks campaign (provisioning/ops, not this build).
- The new cron route's `voiceUrl`-class URL-exactness + the `x-cron-secret` (shared with the drip cron) — pg_cron wiring at the LAST step.
- Whether the finite runner reuses `send_settings` window per the campaign's client, or an agency default (decision 5 — recommend the client's tz/window so it matches that client's customers' timezone).
