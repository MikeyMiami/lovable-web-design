# Stage — Infra Phase 1 (SMS runner: parallel sends + crash-safety) — validation [DONE]

> 2026-07-09. Built at ZERO clients (lowest-risk window to touch the send path). Verified against `cloud-spark-setup` `origin/main` + **runtime-proven in-app against the real `runDripTick()`**. Additive migrations only; `audit_tenant_rls()=0`. Frozen master re-tagged **`golden-master-v1.8`** (@ `7371493`). Part of `docs/phase-infra-overhaul-1k-clients-plan.md`.

## What shipped (`runner.server.ts` `RUNNER_VERSION=v20260708-1` + `send.server.ts` + 3 additive migrations)
Parallel per-client send batches, cap-safe + exactly-once, with the four mandatory guardrails from `stage-capacity-expansion-safety-audit.md`:
1. **Reserve-before-send** — `reserve = min(queue, sliceRemaining, capRemaining)`; `dailyCount`+`sliceCount` pre-incremented before any send fires; refunded on failure. Cap can't be overshot under concurrency.
2. **Batch reservation** — per client, `Promise.allSettled(≤ reserved)`; round-robin fairness across clients preserved.
3. **Idempotency** — `send_attempts (enrollment_id, step)` inserted BEFORE send; on conflict: `status='sent'` → skip+advance, `status='sending'` → resend with same key (provider dedup + `uq_messages_twilio_sid_out` unique index). Closes the pre-existing crash-window double-send.
4. **Crash-safe advance** — `send_attempts.status='sent'` set FIRST, then `logEvent`→message→`advanceStep`; a crash re-claim skips the resend.
Plus: 25s per-tick time budget (unprocessed stay leased +5min), batched per-send reads, `runner_ticks` instrumentation (feeds `/admin/health`). **Client-visible behavior identical** (same messages/caps/timing).

## Runtime validation — all 6 PASS
Run in-app via a temporary agency-admin action (`phase1ValidationStep`) that seeds namespaced no-provider fixtures, runs the **real `runDripTick()`** in stub mode, asserts, and self-cleans:
- **canary** — stub mode confirmed (1 `STUB-` message). ✅
- **(a1)** cap=3, 6 concurrent due → **`sms_sent=3`** (≤ cap) — reserve-before-send stops the parallel cap race. ✅
- **(a2)** 30 due → **25** (≤ `PER_CLIENT_SLICE`). ✅
- **(b)** tick×2 → **4 events / 4 messages, all distinct** — no double-send; unique `twilio_sid` index holds. ✅
- **(c)** pre-seeded `send_attempts='sent'` on un-advanced step → **`new_sms_sent=0`, `current_step=1`** — crash-safe: no resend + advances exactly once. ✅
- **(d)** `runner_ticks` **`duration_ms=327`** + counters — instrumentation logs. ✅
- Fixtures removed: 0 leftover (self-cleaned). `audit_tenant_rls()=0`.

## Notes
- pg_cron cadence intentionally left **UNSCHEDULED** (flip to `* * * * *` at SMS go-live, post-A2P — the "unscheduled until last" convention).
- The temporary validation action (`phase1-validation.functions.ts` + the marked `/admin/health` TEMP card) was a one-time proof — **REMOVED 2026-07-09** (commit `768918f`); `/admin/health` still renders the real dashboard; permanent Phase-1 objects untouched. **`golden-master-v1.8` re-pointed to the clean post-removal tree** (`768918f` == `origin/main`; frozen send-path identical to the validated baseline).

## Roadmap
Phase 1 DONE + frozen at `golden-master-v1.8`. Phases 2 (DB hygiene) / 3 (site hosting) remain dashboard-triggered (`backlogDue` amber/red, `rate_limit_hits` estimate, etc.). Next action: remove the temp validation scaffolding.
