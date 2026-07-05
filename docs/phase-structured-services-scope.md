# Structured per-service records (pricing + per-service photos + asset organizer) — READ-ONLY SCOPE

> Scope + recommend only, **no build.** Three gaps sharing one theme: **services should be structured per-service records, not a flat string.** Grounded on `cloud-spark-setup` @ `3433f9f` + template `professional-landscpaing-template` @ `e1ff928`. **Zero DB schema** (everything lives in the existing `template_vars` / `site_assets` jsonb). Commits held.

## The core insight — services ALREADY exist in TWO forms today
1. **`template_vars.services`** — a **flat free-text comma string** (raw onboarding textarea). Read by `proposeSeoMap` to AI-seed the map.
2. **`template_vars.seo.categories[].services[]`** — **structured `{name, slug}`**, grouped under categories — the AI-derived + agency-curated **Core-30 map** that actually drives the pages (`seedCoreThirty` reads it).

The proposed `[{name, price_min, price_max, photos}]` is a **third** structure. So the real question isn't "add a structured list" — it's **how the three reconcile.** Answer below: keep the map as the page-structure, add a per-service **owner-data** record, link them **by slug** (don't merge).

## Recommended data shape [Arch 1 — structured list = source of owner data; map = page structure; linked by slug]
- **`template_vars.services_structured: [{ name: string, slug: string, price_min?: string, price_max?: string }]`** — the OWNER's per-service data, captured at onboarding, editable in Settings (CONTENT-EDIT). `slug` = slugified name (the join key). Price stored as strings (e.g. `"$150"`, `"$5k"`) to allow "$5k"/"$50k" freeform; blank = omitted.
- **Per-service photos → `site_assets.by_service[slug]: [{ url, path }]`** — additive to the existing `site_assets` jsonb (alongside the current `work`/`gallery`/`about`/`services`/`staff` broad buckets).
- **The SEO map (`template_vars.seo`) is UNCHANGED in shape** — it stays the page-grouping (categories→services with slugs). It **references** the structured list by shared **`slug`**; it does NOT absorb price/photos.
- **Why link-by-slug, not merge:** the map is **AI-derived + agency-curated** (grouping changes independently — split/rename/regroup services), while price/photos are **owner facts** (stable). Keeping them separate means: (a) the map stays a clean page-structure; (b) **price/photos survive map regeneration** (they live outside the map — re-running Generate can't wipe them); (c) each is edited in its own surface. They meet only at the **slug**.
- *(Alt considered — Arch 2: put price/photos ON the map's service records. Rejected as primary: onboarding runs before the map exists (needs a buffer anyway), and it couples owner data to the regenerated/curated map. Arch 1 is additive + regeneration-safe.)*

## Reconciliation with the free-text `services` string + the SEO map
- **`services_structured` becomes canonical**; the flat **`services` string is kept as a DERIVED/back-compat field** (write `services = services_structured.map(s=>s.name).join(", ")` on save). Anything still reading the string keeps working.
- **`proposeSeoMap`** prefers `services_structured[].name` when present; **falls back** to parsing the flat `services` string (existing clients). No pricing needed here.
- **The map ↔ structured list link:** the map's service `slug` should match the structured `slug`. Because the AI may rename/split/merge, the match is **slug-first, then normalized-name**, and the **admin.seo map editor surfaces each map-service's matched price/photos (from `services_structured` by slug/name) for operator confirmation** — bridging the fuzziness. Source = the structured list; the map just points at it.

## Onboarding UX (GAP 2 pricing + GAP 3 per-service photos — one structured step)
Replace the single "Services offered" textarea with a **structured service list**:
- The owner adds services one at a time → each becomes a **pill/row**: `name` input + **two price inputs with a "–" between**, labeled *"price range for this service (optional) — e.g. $150 – $500, $5k – $50k"* (`price_min` – `price_max`) + a **per-service photo dropzone** ("add photos of this service") with an **"I don't have photos of this service"** checkbox.
- **Blank price → omitted, no error** (page just won't state pricing). **Blank photos → fine** (Photo-Board falls back to the broad pool / AI-fill later).
- Photos upload into **`site_assets.by_service[slug]`** (reuse the existing onboarding upload proxy → `public-assets`).
- On submit: build `services_structured` from the rows + write the derived `services` string. Keep the broad `site_assets` buckets (work/gallery/about/staff) for general photos.

## Downstream changes (what reads services)
- **`proposeSeoMap`** — prefer `services_structured` names; else parse `services` string (back-compat).
- **`seedCoreThirty`** — unchanged (reads the map). *(Optional later: pre-fill a service page's images from `site_assets.by_service[slug]` at seed — but that's the Photo-Board's job; keep seed as-is.)*
- **`aiWritePage` PROVIDED CONTEXT (pricing)** — when writing a **service** page (identified by `page.slug`), look up `services_structured` by slug (then normalized name) → if `price_min`/`price_max` present, add a line: *"Price range for this service: {min} – {max} — you MAY state THIS range; do not invent any other prices."* If no match/price → omit (as today). **The anti-hallucination guard stays** — only the provided range is allowed (this is exactly the method's "pricing where available" without invention).
- **Photo-Board pre-fill** — for a service page, auto-suggest slots from **`site_assets.by_service[slug]` first** (the per-service tagged photos), falling back to the broad merged pool. This is the GAP-3 "pre-fill per-page assignment" win.

## GAP 1 — asset viewer/organizer (view all photos by category + post-onboarding upload)
- **Reuse the Photo-Board's pool** — it already merges + dedups `site_assets` by category with chips/filter (`allAssetsFlat`). Factor it into a shared **`AssetPool`** component (view + filter) and add **per-category upload** (into `site_assets[category]` or `site_assets.by_service[slug]`), reusing the onboarding upload path (→ `public-assets`) via a new admin fn `addSiteAsset(clientId, category, file)` (or `deleteSiteAsset`) that read-merge-writes `site_assets`.
- **Where it lives:** a dedicated **"Assets" admin tab** (asset management is broader than SEO — logos, general photos), with the SAME `AssetPool` component reused inside the Photo-Board (assignment). One component, two surfaces: **Assets tab = manage (view/upload/delete); Photo-Board = assign.** Both read/write `site_assets` via the safe-merge pattern. *(Once GAP 3 lands, the Assets view also shows the `by_service` folders.)*

## Backward compatibility / migration [ZERO schema]
- **Existing clients** (flat `services` string, broad `site_assets`, no structured list / no pricing): keep working unchanged — `proposeSeoMap` falls back to the string; `aiWritePage` omits pricing (no structured data, as today); Photo-Board uses the broad pool. **No breakage, no migration.**
- **New clients** (post-change): onboarding captures `services_structured` + `site_assets.by_service` → full pricing + pre-filled photo assignment.
- **Optional backfill:** a one-time **"Structure my services"** action (Settings/admin.seo) that parses an existing client's flat string into `services_structured` (names only; the operator adds prices/photos). Not required — the fallback keeps old clients working.
- **All additive JSON** in the existing `template_vars` (`services_structured`) + `site_assets` (`by_service`) — **no DB column, no migration** (`audit_tenant_rls()` untouched).

## Slice plan
- **SVC-1 — the structured shape + safe read/write + back-compat (foundation).** Define `services_structured` (+ derived `services` string); a server-side-merge `updateClientServices(clientId, list)` (saveSeoMap posture); `proposeSeoMap` prefers structured-else-string. No UX yet; existing clients unaffected. *(Do first — everything else builds on the shape.)*
- **SVC-2 — onboarding structured capture (pills + price inputs + per-service photo categories).** OnboardWizard change + submit writes `services_structured` + `site_assets.by_service`. (GAP 2 + GAP 3 capture.)
- **SVC-3 — pricing into `aiWritePage` PROVIDED CONTEXT** (per-service range lookup by slug; guard stays). Delivers the method's price-range pages.
- **SVC-4 — Photo-Board pre-fill from `site_assets.by_service`** (auto-suggest per-service photos onto their page). Delivers the GAP-3 pre-fill.
- **SVC-5 — Assets tab (GAP 1):** shared `AssetPool` (view/filter) + `addSiteAsset`/`deleteSiteAsset` (post-onboarding upload/manage), reused in the Photo-Board.
- **(with CONTENT-EDIT)** the Settings editor for `services_structured` (name/price rows) rides along with the earlier template_vars editors scope.

---
**Recommended: `services_structured` (owner per-service data: name/price) + `site_assets.by_service[slug]` (per-service photos), BOTH additive JSON (zero schema). The SEO map stays the page-structure; the structured list is the owner-data source; they link by SLUG (not merged) so pricing/photos survive map regeneration. Flat `services` string kept as a derived back-compat field (proposeSeoMap falls back to it). Existing clients unaffected. Slices SVC-1..5 + the Assets tab reuses the Photo-Board pool. No build; commits held.**
