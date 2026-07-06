# Stage S4-B — tier system + SEO cadence (gated to 497) — validation [DONE]

> Point-in-time validation record, 2026-07-06. Verified against `cloud-spark-setup` `origin/main` @ `cf6cb72`. Spec: `docs/phase-s4b-cadence-signal-build-spec.md` + the tier re-scope. Second sub-slice of the re-scoped Slice 4.

## What shipped
- **Tier system (net new):** additive `clients.tier text` (nullable, no default — existing clients = untiered null, NOT auto-497). Selector in Settings → Business Identity (`— none —` / 149 / 297 / 497), persisted via the direct `clients` update (`saveClient`). **Central entitlements helper** `src/lib/entitlements.ts` — `tierIncludes(tier, feature)`; the ONLY entitlement today is `seo_cadence → 497`. Adding future gated features = a one-line map edit (no scattered `tier===` checks).
- **30-day SEO cadence (additive `clients.seo_last_reviewed_at timestamptz`):** `markSeoReviewed` (sets now()), `listSeoStatus` (**filters `tier='497'`** + active + not-deleted; computes `due_at = coalesce(seo_last_reviewed_at, created_at)+30d`, due-first sort).
- **Dedicated SEO-status board** — `/agency/seo-status` route + `agency.tsx` nav tab with a **due-count badge**; table of 497 clients (last reviewed / next due / DUE|current chip) + "show due only" filter; rows open the client's SEO tab.
- **Per-client monthly-update panel — GATED to 497** (`tierIncludes(client.tier,'seo_cadence')`; non-497 shows nothing): "SEO Updated" button (green current / amber DUE), the B1/B2/B5 rank-check checklist, and the manual signal `topical_status` (building|established|dominating) + `close_towns[]` → `template_vars.seo` (merge-overlay, no clobber).

## Validation (PASS)
- Migration additive; **`audit_tenant_rls()` → 0** (both columns on the `clients` tenant root; no policy change). Existing clients read `tier=null` → untiered. ✅
- Tier selector persists on `clients.tier`. ✅
- **Gate at BOTH layers:** board + due badge list only 497 clients; the cadence panel renders only for 497, non-497 SEO tab shows no panel. ✅
- "SEO Updated" reset → green + drops off the due list + badge decrements; returns to DUE after 30 days. ✅
- Manual signal persists no-clobber (other `seo` keys intact). ✅

## Roadmap
**S4-B → DONE.** Slice 4 progress: S4-A (research) + S4-B (cadence/tier/signal) done. Next: **S4-C** — the expert's topical-authority engine (`ZKZnDORR0ds:334-347`): add-supporting-content (pick core page → AI-proposed question → new `type='supporting'` page + additive FAQ block + editorial link on the core page). Then S4-D (8-pass deep writer + job runner), S4-E (monthly scheduler driven by `topical_status`/`close_towns`).
