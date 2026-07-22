# SLICE 3 — Multi-location / geo pages — READ-ONLY SCOPE

> Serviceable towns beyond the primary GBP city get their own geo pages ("Landscaping in Dublin") so the business ranks there. The **home stays anchored to the primary city** (method-correct); geo pages cover the rest. Grounded on `cloud-spark-setup` @ `ae8d325` + template `professional-landscpaing-template` @ current. **No build.** Commits held.

## Read-only-verify — what exists today
- **`SeoMap`** (`template_vars.seo`) = `{ primary_category, categories:[{name,slug,services:[{name,slug}]}] }` — **no `city`, no `locations`.**
- **`seo.city` is ALREADY READ** by `aiWritePage` + `seedCoreThirty` — `city = seo.city ?? service_area[0] ?? address` (`seo.functions.ts:607/970`). ⇒ making the primary city explicit is just **populating** `seo.city` (UI + `proposeSeoMap`), not a read change.
- **`content_pages`** — `type` is free text (supports `'geo'`); **NO `geo_area`/`area_served` column.** `seedCoreThirty` writes **home/category/service only** (no geo). `aiWritePage` `typeBrief` has home/category/service/default (**no geo case**).
- **Template geo render ALREADY BUILT (STORE-2):** `service-area.$slug.tsx` renders `type==='geo'` via `ContentPageView`, using **`page.area_served`** ("Serving {area_served}"); `locations.tsx` lists all `type==='geo'` pages; `ContentPage.area_served?: string` exists. ⇒ the template renders geo pages **as soon as real geo rows exist** (with `area_served` + published).

## 1. LOC-1 — map foundation (primary city + locations) [ZERO schema]
Add to `SeoMap` (`template_vars.seo`, additive JSON):
- **`city: string`** — the **primary/GBP city** (the business's home city). The read path already prefers it; LOC-1 populates it (removes reliance on `service_area[0]` being home-first — the parked robustness).
- **`locations: [{ name: string, slug: string }]`** — the **serviceable towns** to build geo pages for (curated).
- **Relation to `service_area`:** `clients.service_area` (text[]) = the raw serviceable-areas list (SMS/schema/onboarding) — unchanged. **`seo.city` + `seo.locations` = the curated SEO-targeting layer** derived from it. `proposeSeoMap` proposes `city` (from `address`/`service_area[0]`) + `locations` (from `service_area[1..n]`); the agency confirms/edits in the map editor. `service_area` stays the source of truth; the SEO map is the curated view.
- **UI:** the admin.seo map editor gains a **"Primary city"** input + a **"Locations"** list (add/remove towns), AI-seeded from `service_area`.

## 2. Geo page storage — ONE additive column [⚠️ SCHEMA FLAG]
Geo pages are `content_pages` rows with `type='geo'`. The row must carry **which location** it targets.
- **RECOMMENDED: add `content_pages.area_served text`** (nullable, additive). **This is the first schema touch since `content_pages.images` (2026-07-04) — flagged explicitly.** Additive-only → passes `audit_tenant_rls()` (no policy change; anon RPCs return `cp.*` so it auto-flows), no new grant. **Name it `area_served`** to match the template's existing consumer (`ContentPage.area_served`, schema.org `areaServed`) — **zero template mapping** (the RPC returns `area_served`, the template already reads it).
  - *(Alt — zero-schema: encode location in the slug + look it up in `seo.locations` by slug. Rejected: the SVC-3 slug-divergence lesson — slug-parsing is fragile; an explicit column is robust.)*
- The **topical subject** (which service/category the geo page is about) is carried by `h1`/`target_keyword` + `internal_links` (→ parent service) — **no extra column** (same pattern as service pages).
- So a geo row = `type='geo'`, `area_served='Dublin'`, `h1='{subject} in Dublin'`, `target_keyword='{subject} {location}'`, `slug='{subject-slug}-{location-slug}'`, `internal_links` → parent service + Locations index, `status='draft'`.

## 3. `seedGeoPages` + the coverage matrix [scale-controlled by CURATION]
- **NOT a full service×location matrix** — 30 services × 14 locations = 420 pages (explodes; also violates "genuinely local, curated" — `seo-content` §2/§7). 
- **RECOMMENDED: agency-curated (subject × location) selection.** A **coverage matrix UI** (subjects down, locations across; subjects = the **primary category** by default, optionally selected categories/services) → the agency checks the cells to build → `seedGeoPages(clientId)` generates **only the checked** geo draft rows. Start small ("Landscaping in Dublin", "Landscaping in Westerville" — a handful), expand per rank-map. ~5-15 pages initially, not hundreds.
- **`seedGeoPages`** (mirror `seedCoreThirty`): for each selected (subject, location) → deterministic geo draft row (slug/type/area_served/title/h1/target_keyword/internal_links), `status='draft'`, **idempotent upsert on `(client_id, slug)`, no overwrite**. Reserved-slug guard.
- **Scale reconciliation (generate-all-drafts vs topical-first):** GENERATION is batched (all selected cells → drafts, efficient — satisfies "not one-at-a-time"); PUBLISHING is waves (§5). Never blanket-publish at launch (the §7 "wasted months" anti-pattern).

## 4. Geo-aware `aiWritePage` [`case "geo"` + guard]
- **City context = the location, not the primary city.** For a geo page, `aiWritePage` uses `page.area_served` as the city/location context (instead of `seo.city`).
- **New `case "geo"` in `typeBrief`:** genuinely-local content for `{area_served}` — the subject (`{h1}`) in that town: why locals need it, local conditions/neighborhoods/landmarks/routes (`seo-build` §2), a local FAQ; weave the editorial link back to the parent service. Add `area_served` to PROVIDED CONTEXT.
- **Anti-hallucination [LOCKED]:** the guard stays — **do NOT invent specific local landmarks, neighborhoods, or claims not in PROVIDED CONTEXT.** Without real local research data, the writer speaks to the location generally (never fabricating specific places) — the same lighter-first-pass caveat as service pages. **Deep, genuinely-local specifics = the Slice 4 content tool (§5 local research).** *(This is important: geo pages are the ones most at risk of city-swap slop; the guard keeps them honest but generic until the tool adds real local data.)*

## 5. Publish-in-waves [topical-first, method-correct]
- Geo pages are generated as **drafts**; published in **controlled waves**, not all at once (the §7 topical-first rule — build topical authority first, then geographic).
- **Mechanism (interim):** a publish control in the SEO panel — publish geo pages in batches (e.g. by location, N at a time), with a note on the rank-map cadence. The **rank-map decisioning** (which geos to publish when, based on the top-3% threshold) = the **Slice 4 tool**; for now the agency publishes waves manually + monitors.

## 6. Linking structure [LOCKED — home stays primary-city]
- **Home → geo: NO** (home anchors to the primary city; links to categories only — unchanged).
- **Locations index (`/locations`) → each geo page** (the hub; home/footer link to `/locations`). Already rendered by the template's `locations.tsx`.
- **Geo page → its parent service** (editorial in-content link, geo→service) via `internal_links`.
- **Category/service → geo: minimal/optional** (a service page could note "also serving {towns}" linking to geos — later; keep the core clean: Locations index → geo → service).

## 7. Slice plan
- **LOC-1 — map city + locations** (`SeoMap` +`city`+`locations`; `proposeSeoMap` proposes them; admin.seo map editor UI). **ZERO schema.** Populates the already-read `seo.city`.
- **LOC-2 — geo generation** (⚠️ **additive `content_pages.area_served` column** — first schema touch, flagged) + `seedGeoPages` + the **coverage-matrix + batch-generate UI**. Geo draft rows.
- **LOC-3 — geo-aware writer + publish-in-waves** (`aiWritePage` `case "geo"` + `area_served` context/guard; the publish-waves control).
- **Template: essentially DONE** (STORE-2 built `/service-area/$slug` + `/locations` reading `area_served`) — verify it renders real geo rows; a small polish at most (Locations index styling / home→/locations link if missing).

## Schema footprint
- **LOC-1 + LOC-3: ZERO schema** (map JSON + prompt). **LOC-2: ONE additive column** (`content_pages.area_served text`) — the only schema touch in the whole arc; additive, `audit_tenant_rls()=0` preserved, `area_served` name matches the template. Flagged.

---
**Recommended: `seo.city` (explicit primary city, already read) + `seo.locations[]` (curated towns) in the map [zero schema]; geo pages = `type='geo'` rows carrying the location in ONE additive `content_pages.area_served` column [the only schema touch — flagged]; `seedGeoPages` over an agency-curated subject×location matrix (NOT the full explosion) → drafts; geo-aware `aiWritePage` (`area_served` context + honest-local guard); publish-in-waves (topical-first; rank-map decisioning = Slice 4); linking = Locations-index→geo→service (home stays primary-city). Template geo render already built. Slices LOC-1 (zero schema) → LOC-2 (1 additive column) → LOC-3. No build; commits held.**
