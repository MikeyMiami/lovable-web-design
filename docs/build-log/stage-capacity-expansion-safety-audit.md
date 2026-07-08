# Capacity-Expansion Safety Audit — will scaling affect live client data/enrollments? [PASS, with 1 Phase-1 design requirement]

> 2026-07-08. Audited `cloud-spark-setup` `origin/main` for whether expanding client capacity (the infra overhaul) can proceed WITHOUT affecting current clients' enrollments/data. Verdict: **the data layer is already safe for additive expansion; the only live-client risk vector is the Phase-1 send-parallelization cap-race, which is known and fixable.** Companion to `docs/phase-infra-overhaul-1k-clients-plan.md`.

## SAFE now (no action needed)
- **Migrations = additive (86%);** destructive ops are idempotent `DROP IF EXISTS` or test-data-only (`DELETE` of one hardcoded test UUID). No `DROP COLUMN`, no `ALTER TYPE`, no `SET NOT NULL` on populated tables, no `TRUNCATE`, no seed data in migrations.
- **No hard deletes of client data:** soft-delete (`clients.deleted_at`, `contacts.deleted_at`) + `archive_client()` (status→archived, timestamp) + `export_client_bundle()` (full portable JSON before offboarding). Cron filters `c.status='active' AND c.deleted_at IS NULL` → archived clients stop sending.
- **Tenant isolation:** `audit_tenant_rls()=0`; every client_id table RLS-scoped to `user_client_ids()`/`is_admin()`.
- **Cross-tick double-send PROTECTED:** `claim_due_enrollments` uses `FOR UPDATE SKIP LOCKED` + **leases** (`next_run_at = now + 5 min`), so overlapping ticks can't double-claim.
- **In-tick:** each enrollment dequeued exactly once (sequential shift from the round-robin queue).
- **Index-backed at scale:** `idx_enrollments_due (next_run_at) WHERE status='active'` (runner claim), `idx_events_client_type_created` (dashboard counts + daily-cap seed). No full scans in hot paths.
- **Phase-2 changes non-destructive:** `rate_limit_hits` is global/ephemeral (bucket,window_start) — old-window DELETE never touches enrollment data; `messages`/`events` are append-only, off the critical send path (written AFTER send) — RANGE-partition-by-month is online + query-transparent.
- **Phase 0 (health dashboard):** read-only; no frozen logic touched.

## The ONE real risk when expanding — Phase 1 send parallelization
Today sends are **sequential**; the per-client `dailyCount` + `sliceCount` are **in-memory check-then-increment**. If we naively fan out sends with `Promise.all`, N enrollments read the same pre-increment counter and all pass the cap check → **daily cap / PER_CLIENT_SLICE overshoot** (a live client texted beyond their cap). This is the only vector that could affect current clients.

### Phase-1 design requirements (BAKE INTO the Phase-1 build spec — do not parallelize without these)
1. **Reserve-before-send accounting:** decrement the client's available slot BEFORE firing the send; roll back on failure. (Or DB-atomic counting / advisory lock.) Guarantees cap + slice are never overshot under concurrency.
2. **Bounded fan-out** per client (respect `PER_CLIENT_SLICE`) — reserve the whole client-batch, then send concurrently within the reservation.
3. **Idempotency, closing a pre-existing gap:** add a unique partial index on `messages(twilio_sid) WHERE twilio_sid IS NOT NULL` for OUTBOUND (mirror the existing inbound dedup), and pass an idempotency key to TextGrid. Closes the today-existing crash-window double-send (crash between send and `advanceStep` → re-claim after lease → resend).
4. **Crash-safe advance:** mark/advance the enrollment as sent as close to the send as possible (or transactionally) so a mid-tick crash can't resend.
5. `Promise.allSettled` (not `all`) so one send failure doesn't drop the batch.

None of these change client-visible behavior — same messages, same caps, just concurrent + safer. They're contained to the runner/send path (golden-master → re-validate + re-tag).

## Bottom line
Expanding capacity will NOT affect current client data or enrollments **provided Phase 1 is built with the reserve-before-send guardrails above** (and Phases stay additive + dashboard-triggered). The data foundation is already safe; current clients keep running throughout (Phase 1 = behavior-identical concurrent sends; Phase 2 = append-log maintenance; neither pauses the drip). Safety nets: additive migrations, soft-delete/export, golden-master re-validate/re-tag, Supabase PITR (confirm retention in the Supabase dashboard).
