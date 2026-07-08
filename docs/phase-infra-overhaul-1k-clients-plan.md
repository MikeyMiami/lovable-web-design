# Master Infrastructure Overhaul — 1,000-client confidence — PLAN

> 2026-07-08. Goal: harden the platform to comfortably run **~1,000 active clients** with minimal risk + clean integration, and add real-time visibility so we see a choke coming. Grounded in `reference_platform_scaling_cost_analysis` + the four code probes. **NOT about onboarding speed** — steady-state runtime confidence only. Each backend-touching change follows the golden-master discipline (audit → build-spec → Lovable → validate vs real `origin/main` → re-tag).

## Scope decisions
- **IN:** SMS runner throughput (Phase 1), DB capacity + hygiene (Phase 2), health dashboard (Phase 0), site-hosting decision check (Phase 3).
- **OUT — A2P automation:** operator keeps A2P (brand/campaign/number) manual by design. No build.
- **OUT — direct-AI-provider swap:** the earlier "Forbidden" was a self-imposed monthly cap in Lovable, raisable at will — NOT an infra bottleneck. Action = raise the cap as clients grow + watch usage on the dashboard. No code change.
- **No change touches the onboarding wizard or the template-remix flow** — all work is engine-internal (invisible to the operator) or a read-only admin panel.

## Sequencing (safest first; each gated on the prior validating)

### Phase 0 — Health dashboard [FIRST, read-only, zero risk]
Self-contained agency-admin panel; touches no frozen logic (reads only). Ships first so we baseline before changing anything and get the trigger signals for later phases.
- `getSystemHealth` server fn (service-role, admin-gated) returning: **drip backlog** (active enrollments with `next_run_at ≤ now`), **sends last 5/60 min + today** (from `events`), **failed sends 24h**, **active clients / active enrollments**, **row-count estimates** for `messages`/`events`/`rate_limit_hits`/`tracked_links` (via `pg_class.reltuples` — cheap, scale-safe, NOT `COUNT(*)`), **content pages generated this month** (AI-load proxy).
- UI: green/amber/red vs configurable thresholds, auto-refresh ~30–60s.

### Phase 1 — SMS runner throughput [the one real runtime chokepoint]
- **1a. Cron cadence → 1 min** (config; ~5× headroom if currently 5-min).
- **1b. Parallelize sends** in `runner.server.ts`: fan out ~15–30 concurrent TextGrid POSTs under a **~25s time-budget guard** (stop + let the next tick continue; prevents the 30s Worker timeout) + **batch the per-send reads** (one RPC vs 4–6 REST calls). Preserves round-robin fairness + `PER_CLIENT_SLICE` + opt-out guard + idempotent `FOR UPDATE SKIP LOCKED`. **Content-identical** (same messages, faster). Frozen-master: re-validate + re-tag. Validation: same sends, no double-send, tick < 30s, backlog clears in-window.
- **1c. Durable worker off the 30s cap** (CF Queues / Durable Objects / Railway) — **DEFERRED**; build only if the dashboard shows 1a+1b+compute-upsize still can't clear the daytime backlog near 1k.
- **Instrument the runner** while we're in it: write a `runner_ticks` row per tick (duration, claimed, sent, failed) so the dashboard can show tick-duration-vs-cap.

### Phase 2 — DB capacity & hygiene
- **2a. `rate_limit_hits` TTL** — pg_cron job deleting windows older than ~7–30 days (additive migration, low risk). Do early.
- **2b. Supabase compute upsize + optional read replica** — operational ($, dashboard action, no code). Trigger when the dashboard shows QPS/latency climbing.
- **2c. Partition `messages`/`events` by month + archival** — DEFERRED; trigger when row-count estimates approach ~10M. Scoped now, built when the dashboard says so.

### Phase 3 — Marketing-site hosting [decision-gated, not a throughput choke]
- **3a. Discovery:** confirm the current host + its per-project/build limits + how client sites deploy today (per-client `VITE_CLIENT_SLUG` build).
- **3b. IF** ~1,000 separate deployments hit platform caps / cost / template-update pain → consolidate to ONE hostname-resolved multi-tenant deploy (content already fetched live by slug; only slug-resolution moves from build-env to runtime Host header) + edge-cache the public RPCs. **ELSE** stay per-client. Decide on 3a's data.

## Integration & risk notes
- Dashboard (0) is the instrument that decides the triggers for 1c / 2b / 2c / 3b — we act on data, not guesswork.
- Phase 1 is the only load-bearing runtime change; isolated to the send path; validated as behavior-identical.
- 2a additive; 2b/2c/3 are dashboard-triggered, deferrable.
- Cost/economics unchanged (~$40–50/client marginal); this is throughput + visibility, not unit cost.

## Status
Phase 0 building first. Then 1a→1b (+runner instrumentation), 2a, then 2b/2c/3 as the dashboard triggers them.
