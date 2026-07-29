# Software Constraints at Scale (Infrastructure Ceiling)

> **What this is:** the canonical record of where the platform's throughput ceiling actually is, what causes it, how timezone spread changes the math, and which lever to pull (with risk %) as the client count grows. Derived from the 2026-07-29 production-readiness audit (`docs/audits/production-readiness-audit-2026-07-29.md` §4 + §9); code anchors verified at `cloud-spark-setup@8b33707`. Re-verify the constants against `runner.server.ts` before trusting numbers after any runner change.

## 0. The constants that define the ceiling (runner.server.ts:57-65)

| Constant | Value | Meaning |
|---|---|---|
| cron cadence | `*/2 * * * *` | one tick every 2 min → 720 ticks/day, single-flight |
| `TICK_TIME_BUDGET_MS` | 25,000 | tick stops launching new client batches after 25s (deliberately < pg_net's 30,000 `timeout_milliseconds`) |
| `BATCH_LIMIT` | 500 | max enrollments claimed per tick |
| `PER_CLIENT_SLICE` | 25 | max enrollments per client per tick |
| claim lease | +5 min | crashed/slow ticks can't double-claim; unprocessed rows resurface |
| `DEFAULT_DAILY_CAP` | 500 | sends/client/day (from client-tz midnight) |
| send retry | 2× in-tick, then jitter 30-180s reschedule | 429 now retryable (shipped `8b33707`) |

## 1. The bottleneck mechanism (what actually caps throughput)

It is **not** CPU, not Postgres, not Supabase, not Telnyx. It is wall-clock arithmetic in one loop:

1. One tick every 2 minutes, single-flight, 25-second budget.
2. Inside a tick, **client batches run sequentially** (round-robin fairness, but one client's batch completes before the next starts).
3. Each enrollment costs **~12-18 sequential DB round-trips** (~20-50ms each). Within a client, up to 25 run concurrently, so a client batch ≈ one enrollment's wall time ≈ **~1 second per client**.
4. Therefore **one tick serves ~15-25 clients**. That is the entire ceiling.

Second-order cost: before any sends, the tick runs one daily-count query per client **sequentially** — at 300 due clients that alone consumes ~6 of the 25 seconds.

**Where it bites:** the **window-open pile-up**. Marketing sends deferred overnight (review / one-year / reactivation outside 9am-7pm) all come due at the client's 9:00 local. Lead-form and missed-call sends are transactional 24/7 and never pile. **The failure mode is LATENCY (morning sends slip later), never message loss** — deferred rows stay leased/active and drain tick by tick.

## 2. The numbers

**Single-timezone worst case** (all clients due at the same 9:00 — the correct model for a Florida-concentrated book):

| Active clients with 9am work | Morning drain time |
|---|---|
| 100 | ~10-14 min ✅ |
| 200 | ~20-30 min ✅ tolerable |
| 300 | ~30-45 min ⚠ soft ceiling |
| 500 | 1h+ ✖ |

**Timezone spread adjustment (2026-07-29):** the pile-up is **per-timezone wave** — each client's 9:00 is their own local instant, so ET/CT/MT/PT books drain as four independent waves an hour apart. US-population weights ≈ ET 47% / CT 29% / MT 7% / PT 17%:

- **Florida/ET-heavy book (the likely early reality): the single-wave numbers above apply unchanged.**
- **Nationally spread book:** the largest wave is ~47% of clients → 300 spread clients ≈ ~140 in the ET wave ≈ ~15-20 min drain. Geographic spread buys roughly **2× effective ceiling for free** (~500-600 spread clients before the ET wave alone hits the 300-single-tz behavior).
- DST is a correctness non-issue (`zonedWallTimeToUtc` converges across transitions, verified in audit); it shifts each wave's UTC instant but never stacks waves — ET/CT stay an hour apart in all seasons.
- Waves also self-spread naturally: only step-0/deferred sends land exactly at 9:00; later steps land at `prior-send + offset`, so a drained morning pushes that cohort's next step later, diffusing future mornings.

## 3. Levers, in pull order (gain / risk / trigger)

| # | Lever | Gain | Risk | Pull when |
|---|---|---|---|---|
| 1 | **Add 1-2 more pg_cron `drip-runner` jobs offset by ~40s** — zero code change; SKIP LOCKED + the 5-min lease already make overlapping ticks safe BY DESIGN | ~2-3× | **~10%** (per-tick daily-count snapshot → cap overshoot bounded at ≤ one batch ≈ ≤25 on a 500 cap) | ~150-200 active clients, or `hit_time_budget` recurring |
| 2 | **Per-tick caching** in the runner (sequence meta per client+key — currently re-queried PER ENROLLMENT; batch contact reads) | ~2× | **~10-15%** (pure refactor behind the idempotency layer; soak in stub mode) | ~200 clients |
| 3 | **Parallelize client batches** (3-5 clients concurrently inside the tick) — the reservation/refund cap math was explicitly built concurrency-safe, JS single-threading keeps counters coherent | ~3-5× | **~15-20%** (stub-mode soak before live) | ~250-300 clients |
| 4 | **Raise `TICK_TIME_BUDGET_MS` 25s→55s in LOCKSTEP with pg_net `timeout_milliseconds` 60s** | 2× | **~10-15%** (verify the Lovable/CF Workers execution limit first; the two timeouts must move together) | only if 1-3 insufficient |
| 5 | **Retention purges** (audit report SQL A-6: rate_limit_hits 2d / send_attempts 180d / runner_ticks 90d) + an `events` retention decision | health | **~5%** | now / by month 6 |
| 6 | **Ops automation** — Telnyx provisioning API onboarding + template-propagation tooling (parked backlog) | ~10× ops | product work, no platform risk | before ~client 30 |

Levers 1-4 combined put the software ceiling past **~1,000-1,500 active clients on the same architecture** — no redesign.

## 4. The ceiling that actually arrives first: OPERATIONS

Manual remix propagation (every template improvement × N client remixes), manual A2P registration (3-7 days per client, TCR), manual onboarding steps → **~50-100 clients per operator**. The runner will outscale the onboarding process by an order of magnitude. Lever 6 is the highest-leverage future-proofing on the board and carries no platform risk.

## 5. Non-bottlenecks (verified, stop worrying about these)

- **DB capacity:** enrollments/messages/contacts trivial at 10⁶-10⁷ rows; hot paths index-covered (`idx_enrollments_due` partial, `idx_events_client_type_created`). `events` is the only grower that needs a policy (~25M rows/yr at 100 clients).
- **Marketing-site reads:** `get_client_public` per page load is negligible QPS against Supabase; sites are CF-Workers-served. No practical ceiling before thousands of clients.
- **Provider throughput:** per-number ~6 SMS/min long-code is enforced by QUEUEING at Telnyx (not errors); per-client 10DLC brand/campaign daily caps scale per client; API-burst 429s are now retryable (jitter 30-180s + 2-min cadence exceeds any plausible `retry-after`). Voice concurrency is account-wide channel billing — pooled, not per-app.
- **Telnyx opt-out layer:** always on, profile-wide blocks (see /telnyx-provider §3 — cross-client scope is a business consideration, not a capacity one).

## 6. Trigger dashboard (run monthly, or when mornings feel slow)

```sql
-- How often did ticks hit the 25s budget? (recurring TRUE = pull lever 1)
SELECT count(*) FILTER (WHERE hit_time_budget) AS budget_hits, count(*) AS ticks
FROM runner_ticks WHERE started_at > now() - interval '7 days';

-- Morning drain time per day: window-open to the wave's last drip send (ET example)
SELECT date_trunc('day', created_at AT TIME ZONE 'America/New_York') AS day,
       min(created_at) AS first_send, max(created_at) AS last_send,
       round(extract(epoch FROM max(created_at)-min(created_at))/60) AS drain_minutes,
       count(*) AS sends
FROM events
WHERE type='sms_sent'
  AND (created_at AT TIME ZONE 'America/New_York')::time BETWEEN '09:00' AND '11:00'
  AND created_at > now() - interval '14 days'
GROUP BY 1 ORDER BY 1 DESC;
-- drain_minutes trending toward 30+ = pull the next lever.

-- Tick utilization trend
SELECT date_trunc('day', started_at) d, round(avg(duration_ms)) avg_ms, max(duration_ms) max_ms,
       sum(sent) sent, sum(claimed) claimed
FROM runner_ticks WHERE started_at > now() - interval '14 days' GROUP BY 1 ORDER BY 1 DESC;
```
