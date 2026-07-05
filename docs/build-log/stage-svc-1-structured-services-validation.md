# Stage SVC-1 — structured services foundation + minimal editor — validation

> Point-in-time validation record, 2026-07-05. **App-layer; ZERO schema** (additive JSON in `template_vars`). Verified against `cloud-spark-setup` `origin/main` @ `5fc7810` (`git diff 54dba6d..origin/main -- supabase/migrations` = empty). Build spec: `docs/phase-svc-1-structured-services-build-spec.md`. Scope: `docs/phase-structured-services-scope.md`.

## What shipped
Structured per-service records + the Settings editor to manage them:
- **`updateClientServices`** (`seo.functions.ts:396`) — server-side-merge writer: normalizes `services_structured = [{ name, slug, price_min?, price_max? }]` (slugs via `slugify` + dedupe/reserved-guard), derives the flat `services` string (`:426`), re-reads `template_vars` + overlays only `services_structured` + `services` (`:437`), `statusCode`-on-throw.
- **`proposeSeoMap` prefer-structured-else-flat** (`:106`).
- **"Services & Pricing"** structured editor in `admin.settings` (per-service name + price_min – price_max rows; add/remove; imports `updateClientServices` `:13`), seeded from `services_structured` else the flat string.

## Validation (PASS)
- Editor saved **5 rows** for `test-landscaping`; **flat `services` string auto-derived + in-sync**; `differentiators` / `seo` / `site_assets` all **intact** (no clobber — server-side merge). ✅
- **Price range persisted** — a price range added to one service → `price_min`/`price_max` stored in that `services_structured` entry (fn keeps them; empty omitted). ✅
- **Back-compat** — flat-`services`-only clients parse to name-only rows; `proposeSeoMap` falls back to the flat string until re-saved. ✅
- **Drift:** `seo.functions.ts` (+`updateClientServices`, proposeSeoMap fallback) + `admin.settings.tsx` (structured Services editor). **No schema/migration**; admin-gated; `audit_tenant_rls()` unaffected. ✅

## Roadmap
**SVC-1 → DONE.** Next requested: **SVC-3** (pricing → `aiWritePage` PROVIDED CONTEXT for service pages). SVC-2 (onboarding capture), SVC-4 (Photo-Board pre-fill), SVC-5 (Assets tab) remain planned. *(SVC-1's Settings editor already lets operators set per-service prices today — the twin of SVC-2's onboarding capture.)*
