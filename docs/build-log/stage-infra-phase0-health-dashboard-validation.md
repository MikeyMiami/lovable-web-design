# Stage — Infra Phase 0 (system health dashboard) — validation [DONE]

> 2026-07-08. Verified against `cloud-spark-setup` `origin/main`. Read-only; ONE additive RPC (`estimate_table_rows`); `audit_tenant_rls()=0` (tenant isolation intact). Part of `docs/phase-infra-overhaul-1k-clients-plan.md`.

## What shipped
- **`estimate_table_rows(_tables text[])` RPC** — `pg_class.reltuples` planner estimates (O(1), scale-safe on billion-row tables); service-role only (revoked from public/anon/authenticated). Additive, no RLS surface change.
- **`getSystemHealth` server fn** — agency-admin gated (`requireSupabaseAuth` + `assertAgencyAdmin` + `supabaseAdmin`). Returns: `backlogDue` (active enrollments with `next_run_at ≤ now`, indexed), `activeEnrollments`, `activeClients`, `sentLast60m`/`sentToday` + `failed24h` (time-bounded `events` counts on the send event types), `rowEstimates` for `messages`/`events`/`rate_limit_hits`/`tracked_links` (via the RPC — no `COUNT(*)` on big tables).
- **`/admin/health` UI** — green/amber/red vs thresholds, 45s auto-refresh. Thresholds: backlogDue green <1k / amber 1–5k / red >5k; failed24h <1%/1–5%/>5%; rate_limit_hits <1M/1–10M/>10M; messages/events informational + trend.

## Validation (PASS)
- `/admin/health` live: backlog + send rate + failure rate + big-table planner estimates, 45s refresh. ✅
- `audit_tenant_rls()=0` — RPC additive, tenant isolation intact. ✅
- Read-only — no frozen send/schema logic touched; the monitor uses indexed bounded counts + the estimate RPC, so it never becomes its own bottleneck. ✅

## Roadmap
Phase 0 = the instrument. **Phases 1–3 PARKED**, dashboard-triggered:
- **Trigger:** `backlogDue` going amber/red under real load (runner can't clear the queue in the 9am–7pm window) → build **Phase 1** (1-min cadence + parallel sends under a 25s guard + batched per-send reads + `runner_ticks` instrumentation).
- **Phase 2a** (`rate_limit_hits` TTL) when its estimate goes amber; **2c** (partition messages/events) near ~10M; **2b** (compute upsize) on QPS/latency climb.
- **Phase 3** (site-hosting consolidation) only if per-client deploy limits/ops bind.
