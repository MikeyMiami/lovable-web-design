# Build Log — 1f-prep: Deploy-Lag Root-Cause + Cron-Schedule Closeout

> Closes the owed deploy-lag root-cause from the spec §12 `[PRE-FREEZE / 1f — INFRA]` note (sub-checks (2)–(4)). The `runner_version` stamp (1) was already proven at 3f. Validated against the real frozen code (`cloud-spark-setup`), the Lovable deploy setup, and a live `cron.job` introspection. Recorded 2026-06-16 (Claude Code).
> **Verdict: CLOSED.** (2) ✅ resolved — no separate worker. (3) ✅ ruled out — `cron.job` empty, no scheduled caller exists. (4) inherent Lovable edge-propagation lag — handled procedurally by the `runner_version` + `?ping=1` confirm-promoted gate. Net-new: an explicit "schedule pg_cron LAST in 1f" build step, and the `?ping=1` health-check re-validated + re-tagged `golden-master-v1.1`.

## Why this mattered (the launch risk)
At BOTH 3c and 3f the published app kept serving pre-change runner code after a publish (bodies still `[stub]`, materialization absent, until a re-publish promoted the new bundle). 1f deploys the **real TextGrid runner** down this same path, so an unresolved deploy lag would make a 1f failure ambiguous — "is the swap broken, or is stale code running?" Goal: make a 1f provider-swap failure **unambiguously the swap**.

## Architecture (verified from the frozen repo)
There is **no separate cron worker**. Stack = TanStack Start → **Nitro**, one app bundle, Lovable-hosted at `cloud-spark-setup.lovable.app`.
- Cron entrypoint is an **in-app route** — `src/routes/api/public/cron/sequences.ts` (`createFileRoute`), importing `runDripTick` from `@/lib/cron/runner.server`. Same route tree, same Nitro output as the published site.
- No `supabase/functions/` (no Edge Function), no `wrangler.toml`, no second deploy target. `.lovable/project.json` = a single TanStack Start app.
- Intended drive path: pg_cron → pg_net `net.http_post` → `https://cloud-spark-setup.lovable.app/api/public/cron/sequences` with the `x-cron-secret` header (route checks `process.env.CRON_SECRET`).
- Supabase project: `onbhnkylzadyldpziapo`.

## Sub-check verdicts
**(2) Same deploy target — ✅ RESOLVED (structural, from code).**
The runner is not a separable artifact: `runner.server.ts` is imported by the in-app cron route and compiled into the same Nitro bundle as the published site. No second deploy target exists. A publish that promotes the site necessarily promotes the runner → there is physically no "separate/stale cron worker" to diverge. The 3c/3f lag is **not** a divergent-target problem.

**(3) Production URL — ✅ RULED OUT BY ABSENCE (live query).**
The `cron.schedule(...)` + `net.http_post(url := …)` is in **no migration** — the only cron migration (`20260609032253`) does just `CREATE EXTENSION pg_cron; CREATE EXTENSION pg_net;`, and `.lovable/plan.md` confirms "No cron jobs scheduled yet." Live introspection:
```sql
SELECT jobid, jobname, schedule, command FROM cron.job;
-- (0 rows)
```
`cron.job` is **empty** — there is no scheduled caller at all. Nothing is POSTing to the route on a schedule; every tick to date has been MANUAL (us/curl invoking the route). So "wrong/preview URL" is ruled out by absence — there is no URL to mistarget.

**(4) Cached/staged script — inherent Lovable publish-flow lag.**
The cron route is a POST with no cache-control (POST responses aren't CDN-cached) → not response caching. What lags is **bundle promotion at Lovable's edge**: the build completes asynchronously and the `.lovable.app` alias flips to the new bundle after a manual tick may already have hit the old one. That's Lovable-managed infra, not representable or fixable in the frozen code — eventual consistency in the publish pipeline. Mitigated procedurally (below).

## The `?ping=1` health-check (verified against real code)
Shipped at `cloud-spark-setup@5e41f41` ("Added ping health check"). Verified by reading the actual file + diff vs `golden-master-v1`:
- The `?ping=1` branch is the **first** statement in the `POST` handler — before the `x-cron-secret` auth and before `runDripTick()`. Returns `{ ok: true, ping: true, runner_version: RUNNER_VERSION }`. No claim, no send.
- `RUNNER_VERSION` now imported into the route; bumped `v20260615-2` → **`v20260616-1`**.
- Diff is purely additive (the import + a 6-line early-return); no tick-logic touched.
- **Correction to Lovable's prose:** the route defines **only a `POST` handler** — there is no `GET`. `GET …?ping=1` will 404. The confirm gate must use **POST**. The pre-auth ping intentionally needs no secret and exposes only the non-sensitive version string.

## Confirm-promoted gate (run after EVERY backend-touching deploy)
1. Bump `RUNNER_VERSION` in the **same commit** as the runner/route change (convention: `runner.server.ts:28–39`).
2. Publish.
3. Poll the prod URL directly (bypasses pg_cron; no tick, no SMS):
   ```bash
   curl -s -X POST "https://cloud-spark-setup.lovable.app/api/public/cron/sequences?ping=1" | jq .runner_version
   ```
   Until this echoes the new version, the bundle is **not** promoted — do not interpret any send behavior.
4. Once pg_cron is scheduled (1f, last), cross-check the same version is appearing in fresh `events` from the scheduled path:
   ```sql
   SELECT DISTINCT payload->>'runner_version'
   FROM events WHERE created_at > now() - interval '10 min';
   ```
5. Only when the prod URL reports the new version do you evaluate the swap → any failure is unambiguously the swap.

## 1f action item (added to spec §12)
**Schedule the drip runner via pg_cron — DO LAST in 1f.** After the TextGrid swap + net-new inbound are validated on MANUAL ticks, install:
```sql
SELECT cron.schedule('drip-runner','* * * * *', $$
  SELECT net.http_post(
    url := 'https://cloud-spark-setup.lovable.app/api/public/cron/sequences',
    headers := '{"x-cron-secret":"<CRON_SECRET>","Content-Type":"application/json"}'::jsonb
  )
$$);
```
Canonical PRODUCTION host only — never a preview/`*-preview--*` alias. Scheduling last is deliberate: an empty `cron.job` means nothing auto-fires real SMS during the build.

## Re-validate + re-tag (post-freeze contract)
`?ping=1` touched the frozen route, so per the post-freeze contract it was re-validated (additive early-return, no tick-logic change, RUNNER_VERSION bumped) and re-tagged **`golden-master-v1.1`** @ `5e41f41`. `golden-master-v1` remains at the original frozen `1266804` (untouched).

## Status
- **Deploy-lag root-cause CLOSED.** §12 INFRA note updated: (2) ✅ resolved, (3) ✅ ruled out, (4) inherent + procedurally handled.
- **Net-new 1f step recorded:** schedule pg_cron last, at the canonical prod URL.
- **Clear for 1f** on the deploy-verification front: the `runner_version` + `?ping=1` gate makes each 1f backend deploy's promotion deterministic.
