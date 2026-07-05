# Stage SVC-2b-board (= SVC-4) — Photo-Board service-first pre-fill — validation

> Point-in-time validation record, 2026-07-05. **App-layer, UI-only; ZERO schema.** Verified against `cloud-spark-setup` `origin/main` @ `0fa23d4`. Build spec: `docs/phase-svc-2b-board-build-spec.md`.

## What shipped
The Photo-Board auto-suggests a **service** page's slots from `site_assets.by_service[slug]` (the matching service's photos) **first**, then the broad pool; `by_service` photos are included in the draggable pool.
- `SiteAssets` type + `by_service` (`admin.seo.tsx:482`); `serviceFirstCandidates` (`:504`, by_service[slug] first then `flattenAssets`); `allAssetsFlat` includes `by_service` (`:533`, url-deduped pool); board `autoSuggestRow` service-first (`:1668`); dialog `ImagesManager` `autoSuggestSlot`/`All` service-first via `pageType`/`pageSlug` (`:1413/1432`). `work`/`services`/`gallery` still read (back-compat).

## Validation (PASS)
- x3-landscaping: service pages auto-suggest their **matching `by_service` photos** — the hardscaping photo lands on the hardscaping page. Slugs match exactly across `by_service` keys / `services_structured` / SEO map (`flower`, `hardscaping`, `landscaping-services`). ✅
- Non-service pages → broad pool (unchanged); pre-rework clients (work/services only) → back-compat. ✅
- **Drift:** `admin.seo.tsx` only. **No schema/migration**; `audit_tenant_rls()` unaffected. ✅

## Parked (ready fix on the shelf) — slug-divergence fuzzy match
For **x3 the slugs match exactly**, so exact `by_service[row.slug]` works. **IF a future client's AI-map service page slug diverges from the `by_service` key** (= `slugify(onboarding service name)`) — e.g. page `hardscaping-services`/`hardscaping-columbus` vs key `hardscaping` — and photos stop auto-matching, the **ready fix is `byServiceFor` (exact → prefix-fuzzy, longest-key-first)** in `docs/phase-svc-2b-board-fuzzy-match-build-spec.md`. **Parked — not built** (adds complexity + an ambiguity guard for a divergence not yet hit). Pull it if divergence appears.

## Roadmap
**SVC-2b-board (= SVC-4) → DONE.** Onboarding per-service photos now auto-land on matching service pages. Last SVC slice: **SVC-5** (Assets tab — shared AssetPool + post-onboarding upload/delete).
