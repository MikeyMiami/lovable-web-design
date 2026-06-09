# Build Log — Stage 1e Validation (cron drip-runner)

> As-built validation of Stage 1e (cron drip-runner + claim fn) against `skills/scratch-foundation/SKILL.md` §7 (incl. the corrected claim-and-lease + windowed per-client claim) and isolation guardrail 2. Source: Lovable 1e build + the FIX 1–4 patch. Validated 2026-06-09 (Claude Code, independent review).
> **Verdict: PASS — foundation is CLEAR for Stage 1f (Twilio).** Hard blockers FIX 1 + FIX 2 closed. 3 non-blocking forward notes below. No secret values stored (the pg_cron schedule SQL — which carries the literal CRON_SECRET — is intentionally NOT in the repo; run it directly in Supabase).

## PASS — §7 + guardrail 2 (artifact-verified)
- **x-cron-secret** route check (401 mismatch / 500 unset); server-to-server, no CORS. ✓
- **Claim + lease + windowed fairness** (`claim_due_enrollments`, final form below): `ranked` (window fn) → `eligible` (≤K=25/client) → `locked` (plain join, `FOR UPDATE SKIP LOCKED` on base rows) → `leased` (`UPDATE next_run_at = now()+5min` same tx). Lock lands on real enrollment rows; one-statement/one-snapshot (no eligible↔lock race); lease updates exactly the locked set. EXECUTE revoked from PUBLIC/anon/authenticated, granted service_role only. ✓
- **Decision table**: blocked-window / blocked-cap / 5xx-jitter / 4xx-fail / completed / sms_sent — **blocked never advances `current_step`**. ✓
- **2× send retry**; stub `sendSms` writes `sms_sent` (`stub:true`) so the runner is testable pre-Twilio. ✓
- **Guardrail 2** — fairness enforced at BOTH layers; the claim-level window (K=25/client) prevents cross-tick starvation; processing round-robin/slice is belt-and-suspenders. Lease+window rotate fairness across ticks. ✓

## FIX 1–4 — all closed
- **FIX 1 (claim-and-lease) [hard blocker] ✓** — lease in the same tx pushes claimed rows +5min out of the due-window; overlapping/long ticks can't re-claim → no double-send. Processed rows overwrite the lease; crashed-mid-tick rows self-heal after 5min.
- **FIX 2 (cap client-tz + increment) [hard blocker] ✓** — count today's `sms_sent` from `startOfLocalDayUtc(now, tz)` (client-tz midnight, not UTC); in-memory `dailyCount` incremented after each send (no in-tick overshoot); blocked-cap reschedules to tomorrow's local window-open.
- **FIX 3 (nextWindowOpen direct tz) ✓** — probe loop replaced with direct `zonedWallTimeToUtc` computation; DST table (LA spring-forward + fall-back + UTC) passes 5 cases; `DEFAULT_DAILY_CAP=500` constant; `cur < end` (19:00 sharp = closed).
- **FIX 4 (windowed per-client claim) ✓** — `row_number() OVER (PARTITION BY client_id ORDER BY next_run_at) <= 25` balances the batch so one high-volume client can't monopolize it.

## As-built `claim_due_enrollments` (final form — pure DDL)
```sql
CREATE OR REPLACE FUNCTION public.claim_due_enrollments(
  _limit integer, _now timestamptz, _per_client integer DEFAULT 25
) RETURNS TABLE (id uuid, client_id uuid, contact_id uuid, sequence_key text, current_step integer)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH
    ranked AS (
      SELECT e.id, row_number() OVER (PARTITION BY e.client_id ORDER BY e.next_run_at) AS rn
      FROM public.enrollments e
      WHERE e.status = 'active' AND e.next_run_at IS NOT NULL AND e.next_run_at <= _now
    ),
    eligible AS (SELECT id FROM ranked WHERE rn <= _per_client),
    locked AS (
      SELECT e.id FROM public.enrollments e
      WHERE e.id IN (SELECT id FROM eligible)
      ORDER BY e.client_id, e.next_run_at
      LIMIT _limit
      FOR UPDATE SKIP LOCKED
    ),
    leased AS (
      UPDATE public.enrollments e SET next_run_at = _now + interval '5 minutes'
      WHERE e.id IN (SELECT id FROM locked)
      RETURNING e.id, e.client_id, e.contact_id, e.sequence_key, e.current_step
    )
  SELECT l.id, l.client_id, l.contact_id, l.sequence_key, l.current_step
  FROM leased l ORDER BY l.client_id, l.id;
END; $$;

REVOKE ALL ON FUNCTION public.claim_due_enrollments(integer, timestamptz, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_due_enrollments(integer, timestamptz, integer) TO service_role;
```
(Runner + cron route are TypeScript in the Lovable app repo, not the planning repo. The cron `cron.schedule(...)` SQL carries the literal CRON_SECRET → run in Supabase, never committed.)

## Forward notes (NON-blocking; address with/after 1f)
1. **At-least-once on crash → possible duplicate SMS.** If a tick crashes after a real send but before `next_run_at` advances, the +5min lease re-fires that step → one duplicate text. Inherent to the lease/at-least-once design. **Recommend with 1f:** idempotency — before sending step N, check no `sms_sent` event exists for (enrollment, current_step), or mark step-sent before the send. Not a 1e blocker (crash-mid-tick is rare; spec already accepts ~at-least-once via 2× retry).
2. **Configurable window.start + DST gap.** `sms_send_window.start` is per-client editable; if a client sets a start inside their tz's DST-gap hour (e.g. 02:30 where the 2am transition lands), `nextWindowOpen` would be ~1h off one day/year. 09:00 default is safe. Add a test/clamp if/when start becomes freely configurable in the UI.
3. **Per-tick throughput ceiling.** `LIMIT 500 ÷ K 25 = 20 clients/batch`. The lease rotates fairness so no starvation, but at 20+ clients all bursting the same minute, drain spreads over a few ticks. Fine at current scale; revisit `_limit`/K if the agency reaches many simultaneous high-volume clients.

## Post-1e correction — 0-offset terminal-detection bug (found at Stage 2a, 2026-06-09)
The runner's steps_json walker had `step.offsetMinutes ? addMinutes(...) : null` — **falsy on `0`**, so a step with `offsetMinutes: 0` (chained internal-notifications) was misread as terminal → the drip would silently `complete`. This was NOT visible in the 1e stub validation (the stub sequences had no 0-offset steps); it surfaced when 2a seeded the real sequences (One-Year after-SMS2/after-SMS5 internals, Missed-Call internal) and the 2a walk-test exercised them. Fixed (code-only, no migration):
```ts
const hasOffset = step.offsetMinutes !== undefined && step.offsetMinutes !== null;
const nextRun = hasOffset ? addMinutes(now, step.offsetMinutes as number) : null;
const nextStatus = nextRun ? "active" : "completed";
```
Would have truncated One-Year at SMS2 + SMS5 and Missed-Call at SMS1. Walk-test (all 5 assertions PASS) is in `stage-2a-validation.md`. Lesson: stub validation can't catch contract edges the stub data doesn't exercise — prove the walker against the real seeded shapes.

## Carry-forward status (foundation, not 1e)
- #1 duplicate-detection → upsert: ✅ CLOSED (this patch).
- #3 `audit_log` (role grants + revokes): open TODO (spec §12) — before go-live.
- self-lockout guard (last admin): open, low-priority — before admin UI.

## Verdict
Stage 1e validated PASS; FIX 1–4 confirmed; foundation **clear for Stage 1f (Twilio Option 1)**. Build 1f against `scratch-foundation` §8 (connector gateway / fetch-no-SDK, per-client From/SID, parent token runtime secret, inbound + voice-status webhooks routed by `To`, `X-Twilio-Signature` verified BEFORE any DB write) + add Turnstile + rate-limiting on public lead-intake (the §12 [GATE] / launch-check §E prerequisite to any client launch). Swap the stub `sendSms` for the gateway fetch; consider forward-note #1 (idempotency) at the same time.
