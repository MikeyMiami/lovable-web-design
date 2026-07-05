# Stage SVC-5a — Assets tab (+ logo) — validation [CLOSES the structured-services + photo arc]

> Point-in-time validation record, 2026-07-05. **App-layer; ZERO schema.** Verified against `cloud-spark-setup` `origin/main` @ `ae8d325` (`git diff 0fa23d4..origin/main -- supabase/migrations` = empty). Build spec: `docs/phase-svc-5a-assets-tab-build-spec.md`.

## What shipped
Post-onboarding photo + logo management:
- **Shared `site-assets.ts`** (`SiteAsset`/`SiteAssets`/`SiteAssetCat`/`flattenAssets`/`allAssetsFlat`, incl. `by_service`) extracted from `admin.seo.tsx`; **Photo-Board is an import-swap only** (`admin.seo.tsx:34-35`) — rendering/drag unchanged.
- **`addSiteAsset` / `deleteSiteAsset`** (`seo.functions.ts`) — server-side-merge, overlay ONLY `site_assets` (broad cats + `service:<slug>` → `by_service`), `assertAgencyAdmin`/`statusCode`, best-effort storage remove on delete.
- **`AssetPool`** component (view/filter grid) + **`admin.assets.tsx`** Assets tab (per-category incl. `by_service` view + filter + upload/delete) + Assets **nav** entry (`admin.tsx:46`).
- **Logo section** — the top-level `clients.logo_url` (NOT `site_assets`) as its own single-image card: view current / "no logo"; upload-replace via `uploadSiteImage(…,"logo",…)` → **`updateClientSettings({fields:{logoUrl}})`** (existing admin-gated writer, no new fn, no clobber; `:125-127`) + best-effort old-file remove.

## Validation (PASS)
- Assets tab lists all photos by category (broad + per-service `by_service`) + filter; **upload/delete no-clobber** (other `site_assets`/`template_vars` keys intact). ✅
- **Logo:** shows current (or "no logo set"); replace updates `clients.logo_url`, **site header reflects it**, other fields/`template_vars` intact; no new fn. ✅
- **Photo-Board unchanged** (import-swap only; drag-assign works). ✅
- **Drift:** new `site-assets.ts` + `AssetPool.tsx` + `admin.assets.tsx`; `seo.functions.ts` (+2 fns); `admin.seo.tsx` (import-swap); `admin.tsx` (nav). **No schema/migration**; `audit_tenant_rls()` unaffected. ✅

## ARC COMPLETE — structured services + photos + the two live-bug fixes
This closes the arc: **SVC-1** (structured services shape + merge) · **SVC-2a** (onboarding capture) · **SVC-3** (pricing→aiWritePage) · **SVC-2b-rev** (onboarding per-service photos → `by_service`) · **SVC-2b-board/=SVC-4** (Photo-Board service-first pre-fill) · **SVC-5a** (Assets tab + logo). Plus the **two live-bug fixes** — real-client **chrome wiring** (`get_client_public` loader; was demo for all real clients) + real-client **photos rendering** (`by_service`/`gallery` vs dead `work_examples`) — and **per-page + filename photo dedup**.

## Roadmap
**SVC arc → DONE.** **5b** (Photo-Board reuse `AssetPool`) = optional-deferred (pure dedup, no user value, regression risk). **`byServiceFor` fuzzy match** = parked. Next major: **Slice 3 multi-location**, **Slice 4 content-automation tool**, **TextGrid/A2P** launch track.
