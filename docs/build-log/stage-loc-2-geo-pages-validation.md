# Stage LOC-2 — geo page generation + admin UX pass — validation [DONE]

> Point-in-time validation record, 2026-07-06. Verified against `cloud-spark-setup` `origin/main` @ `7d56557`. Specs: `docs/phase-loc-2-geo-pages-build-spec.md`, `docs/phase-seo-admin-ux-matrix-toggles-and-type-badges-build-spec.md`.

## What shipped
- **Schema (the ONE additive touch):** migration `20260705234246_*` = `alter table public.content_pages add column if not exists area_served text;` — additive, nullable. Anon RPCs `get_client_page`/`get_client_pages` are `select cp.*` → `area_served` auto-flows (zero RPC change); template already reads `page.area_served` (zero template change). **First schema touch since `content_pages.images`.**
- **`seedGeoPages`** (`seo.functions.ts`) — mirrors `seedCoreThirty`: input `{ clientId, cells:[{locationSlug, subjectKind:'primary'|'category'|'service', subjectSlug?}] }`. **Skips the primary city** (home owns it). Keyed by the **frozen location slug**: default (primary-category) geo slug = the town slug (`/service-area/akron`); deeper cells = `${subjectSlug}-${locationSlug}`. `area_served` = town display name. `type='geo'`, `status='draft'`, idempotent upsert `onConflict client_id,slug ignoreDuplicates`, `{written,skipped,total}`, `statusCode:400` wrapper.
- **Coverage-matrix UI** (`admin.seo.tsx` `GeoCoverageMatrix`) — subjects × towns; primary-category row checked by default per town; category/service rows opt-in; already-generated cells locked+disabled; "generate geo pages (N)".
- **Deletion-block guard** (`updateClientAreas`) — removing a location whose deterministic candidate geo-slug set (`[slug] ∪ ${cat.slug}-${slug} ∪ ${svc.slug}-${slug}`) matches existing `type='geo'` rows is **BLOCKED** ("delete them in the SEO tab first") — no silent orphaning.
- **Admin UX pass:** matrix **select-all / per-row / per-column** toggles (indeterminate-aware, respect locked cells); pages-list **per-type colored badges** (home/category/service/geo) for fast scanning.

## Validation (PASS — live-confirmed)
- Geo pages generate (one per town, primary city skipped), publish, and **RENDER LIVE**: `akron` confirmed at `professional-landscpaing-template.lovable.app/service-area/akron`. ✅
- The earlier "404" was **backend-URL-vs-template-URL confusion** in the admin "view live" link (see the follow-up fix) — the pages themselves were correct all along. ✅
- Migration additive; `audit_tenant_rls()` → **0** (RLS keyed by `client_id`, no policy change). ✅
- Idempotent re-seed (skips existing); deletion guard blocks referenced-location deletes. ✅

## Roadmap
**LOC-1 + LOC-1b + LOC-1b-final + LOC-2 → DONE.** Slice 3 last piece = **LOC-3**: geo-aware `aiWritePage` (`case "geo"`, `area_served` as the local city context, stricter no-invented-local-details guard) + **wave-publish** control (publish geo drafts in controlled topical-first batches). Plus a quick **view-live URL fix** (admin builds the marketing-site URL, template-base fallback when a client has no domain).
