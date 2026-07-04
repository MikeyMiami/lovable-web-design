# SEO System Audit & Re-scope — 2026-07-03

> Read-only audit against `cloud-spark-setup` `origin/main` @ `d51ba38` + the `seo-build`/`seo-content` skills (the transcript-derived expert methodology). **No build.** Decides sequence for multi-location, images, content depth, ongoing content. Commits held.

## PART 1 — Multi-location (the biggest gap)

### a) Is any multi-location infra built? NO — the whole Core-30 is single-city.
Hard evidence:
- **The map has no location dimension.** `SeoMap` = `{ primary_category, categories:[{name,slug,services:[{name,slug}]}] }` (`seo.functions.ts:67-83`). Purely topical. No `locations`/`geos`.
- **The seed uses exactly ONE city.** `seedCoreThirty` resolves `city = seo.city ?? service_area[0] ?? address-segment` and stamps every title/H1/keyword with that single city. **`service_area[1..n]` (the other towns) is never read.** We capture up to 14 service areas at onboarding and use one.
- **No geo rows are ever created.** `seedCoreThirty` writes only `home`/`category`/`service`. It is the **ONLY `content_pages` writer in the codebase** (grep: every other `.insert`/`.upsert` is events/tokens/enrollments — none write `content_pages`).
- **Render exists, creation doesn't.** STORE-2's `/service-area/$slug` route + the `resolvedUrl` `geo` branch (`admin.seo.tsx:472`) render geo pages, but nothing writes them. `admin.seo.tsx:34` literally comments "no content_pages writes, no geo/location pages here." `type` is read-only; there is **no "Add Page" action.**
- **Net: multi-location = 0% built.** We have the *plumbing to render* geo pages and *the data to target them* (`service_area[]`), but zero connective tissue (map → seed → write → manage).

### b) How multi-location SHOULD work per the methodology
- `seo-content` §7-8 + `seo-build` §2: geographic coverage = **genuinely-local geo/neighborhood pages**, targeting `service + landmark/neighborhood + city`, with REAL local content (that area's conditions, older-homes-vs-new-construction, driving routes, nearby businesses). **Never** city-swap ("we serve {city}" ×N) — §2 forbids it explicitly and §7 warns most agencies get it backwards (location pages before topical authority) → "wasted months."
- The method does **NOT** prescribe a blanket service×location matrix of thin pages. It prescribes: **ONE Core-30 topical foundation in the primary city**, then a **curated, genuinely-local set of geo pages** for additional serviceable locations/neighborhoods — added **deliberately, rank-map-driven** (§7), each a real local page.
- Nuance: "locations" in the method skews toward **neighborhoods/landmarks in/around the primary market** as much as "other towns." But serviceable **other cities** (Dublin, Westerville) are legitimate geo targets — each as its own genuinely-local page (that city's specifics), not a city-swap clone.

### c) The operational want — generate coverage across ALL locations in a manageable flow
- **Currently impossible.** No location dimension in map/seed/write; `service_area[1..n]` unused; no geo writer; no batch-across-locations; no coverage view.
- **What has to change:**
  1. **Map** — add a `locations[]` dimension to `template_vars.seo` (additive JSON, no schema): e.g. `[{ name, slug, kind: 'city'|'neighborhood' }]`, AI-seeded from `service_area` + agency-curated.
  2. **Geo row identity** — a geo row must know WHICH location it's for (for title/H1 + `aiWritePage`'s local context). Two options: **(i) additive column `content_pages.geo_area text`** [rec — clean per-row context; `aiWritePage` reads it instead of `service_area[0]`], or (ii) encode in slug + derive. (Additive column keeps `audit_tenant_rls()=0` — see Part 2 audit note.)
  3. **Geo seeder** — `seedGeoPages(clientId)` (or extend seed): for selected service×location (or per-location), write `type='geo'` **draft** rows — title/H1 = `{service} in {location}` (§2 geo formula), slug, `internal_links` (→ parent service + a Locations index), `geo_area = location`.
  4. **Geo-aware write** — `aiWritePage` uses the row's `geo_area` as the city/local context; the prompt must lean hard into that location's genuine specifics (this is where a single-pass writer with **no local research** is weakest — see Part 3b; geo pages are the ones most at risk of city-swap slop).
  5. **Manageable flow** — a **coverage matrix** (services × locations, what's covered/draft/published) + a **"generate geo drafts for selected locations"** batch (client-side sequential, Worker-safe, like AI-write-all) + publish-in-waves.

### d) Reconciling the want with the rank-map topical-vs-geographic rule (§7)
- The method: **topical Core-30 first**, geographic **only after** the topical top-3% threshold is met. **"Generate all locations at once and publish them" DOES conflict** with this — blindly publishing geo before topical authority is the exact "wasted months" anti-pattern.
- **Reconciliation — separate GENERATION from PUBLISHING:**
  - **Generation** can be batched/efficient across all locations as **drafts** (satisfies "don't do it one-at-a-time").
  - **Publishing** follows the method: Core-30 topical live at launch; geo drafts staged; geo **published in waves** as authority builds, prioritized by the rank-map CSV (§7 — Lead Snap; the content-tool's brain, not built).
  - So the operational want (efficient production) and the method (sequenced publishing) are **not in conflict** once split. For a brand-new client with no ranking history, the pragmatic default = Core-30 live + geo drafts staged; publish geo deliberately, not all-at-once-on-day-one.

### e) Recommended multi-location design + build plan
- **Sits AFTER** the built Core-30 arc; it **also delivers the geo/supporting creation** that ongoing content needs (Part 4).
- **Slices:**
  - **LOC-1 — locations in the map.** Add `locations[]` to `template_vars.seo` (+ `proposeSeoMap`/panel to seed from `service_area` + curate). Additive JSON, no schema.
  - **LOC-2 — geo creation.** Additive `content_pages.geo_area text` (one small migration) + `seedGeoPages` (draft geo rows per selected location/service) + the coverage matrix + batch-generate flow in the SEO panel. This is also the general **"create geo/supporting pages"** capability.
  - **LOC-3 — geo-aware AI-write.** `aiWritePage` reads `geo_area`; geo prompt variant emphasizes genuine local specificity; publish-in-waves controls.
- **Priority:** highest business-value gap (multi-location IS the model), but the largest build. See Part 5 for sequence.

---

## PART 2 — Images re-scope: 2-3 images/page (supersedes IMAGES-1 og_image-only)

### Recommendation: additive `images jsonb` — YES, over image-preserving-aiWritePage.
- **image-preserving-`aiWritePage`** (parse `<img>` out of the old body, re-inject into the regenerated body) is fragile: the AI may reposition/drop/duplicate; every rewrite risks loss; couples images to prose.
- **`images jsonb`** generalizes the exact pattern that made `og_image` AI-write-safe (separate field the writer never touches) to N images. Body stays pure text (AI-owned); images are structured data; the template composes. **Clean, robust — recommended.**

### Exact schema touch (additive; passes the audit)
- `alter table public.content_pages add column images jsonb;` — nullable, additive. Shape: `[{ url, alt, position: 'hero'|'inline-1'|'inline-2', width, height }]`.
- **`audit_tenant_rls()` stays 0:** the audit flags tenant tables (a `client_id` column) whose **policies** lack the tenant check. Adding a **column** adds no policy → `content_pages` keeps its single STORE-1 tenant-read policy → still passes. **No new grant** (table-level `select` to authenticated covers all columns) and **no RPC change** (`get_client_page`/`get_client_pages` return `cp.*` → `images` is included automatically).
- `og_image` = **derived from the `hero` entry** (kept for OG meta; a trigger/app-write sets it, or the template reads `images[hero].url` for `og:image`).

### Where images sit in the PAGE STRUCTURE (the crux — professional page, not a bolted-on photo)
- **Template interleaves by `position`, deterministically — no body coupling:** `hero` renders **above/below the H1** (eager LCP); `inline-1` after the **1st** body `<h2>` section; `inline-2` after the **3rd** (or last) section. The template splits the rendered `body` on `<h2>` boundaries and injects the positioned images between sections. Images carry `alt` + explicit `width`/`height` + `loading="lazy"` (`seo-build` §5).
- **`aiWritePage` prompt tweak:** require **≥3 `<h2>` sections** so interleaving reads naturally (hero → intro → [inline-1] → section → section → [inline-2] → CTA). The AI never emits `<img>` — it just writes well-sectioned prose; the template slots images in. **Fully AI-write-safe** (body has no images; images jsonb has no prose).
- **Result:** hero at top + 1-2 in-content photos between sections = a page that looks like a real local-business page.

### Panel + fallback
- Panel: **auto-suggest** 2-3 from `site_assets` by category (hero from `gallery`/`work`; inline from `work`/`services`) + **manual picker** per slot; **deterministic alt** `"{business_name} {h1||target_keyword}"`.
- **Photo-thin fallback:** assign what exists (hero only, or hero+1); pages beyond coverage get hero-only or none (graceful); Option B AI-gen is the later gap-filler.

### Verdict vs IMAGES-1
- The approved **IMAGES-1 (og_image-only, zero-schema)** was a correct MVP but **caps at one image**. For your stated "2-3 images, professional layout," the **`images jsonb`** version is right — cost is **one additive migration** + template interleave logic. **Recommend replacing IMAGES-1 with this (call it IMAGES-v2).**

---

## PART 3 — Content methodology fidelity

### a) Per-page-type differentiation — GAP (minimal).
`aiWritePage` interpolates `Page type: {type}` into the prompt but the instruction body is **identical** for home/category/service (`:714-746`). It does **not** implement `seo-content` §3's distinct patterns (home = talk-to-searcher + secondary-category H2s; category = list-its-services + links; service = one-service deep-dive: why/what's-included/timeline/what-to-expect). **Fix (cheap, high-ROI): branch the prompt by `type`** with the §3 pattern per type.

### b) Fidelity vs the 8-pass method — large, but largely BY DESIGN.
- `aiWritePage` = a **single `generateText` call.** The `seo-content` §4 **8-pass pipeline** (research→brief → outline → section-by-section → burstiness → perplexity → human-bookends → conversion → QC) is **not** done.
- **Research inputs (§5)** — PAA/Reddit/competitor/local research: **none.** **Local specificity (§2)** — the prompt *asks* for local content but supplies **no real local data**, so the model generalizes (bounded by the anti-hallucination guard → safe but **shallow/generic-local**).
- This matches the scoped intent: the per-client build is a **"lighter first pass"** (`seo-content` output note); the **full 8-pass + research + rank-map loop is the content-automation tool's job** (not built).
- **Rightly deferred to the tool:** 8-pass, research inputs, AI-detection scoring, monthly cadence, rank-map decisioning. **Should arguably be in the per-page write NOW (cheap wins):** (1) per-type prompt branching (§a); (2) better structure/formatting (§c); (3) a light local-context seed IF we have location data (feed known neighborhoods) — especially for geo pages (Part 1d).

### c) Structure/formatting — PARTIAL.
The prompt asks for `<h2>` headings, ~300-600 words, Title Case — it produces **headed prose**. It does **not** require H3 sub-structure, **bullets/lists, tables, callouts, or a CTA block** (`seo-content` §1 "well-formatted", §4 conversion pass). Output is scannable-ish but not full pro layout. **Fix (cheap): prompt upgrades** — short paragraphs, a bulleted "what's included," a closing CTA with the phone, ≥3 sections (also enables image interleaving, Part 2).

---

## PART 4 — Ongoing / blog content

- **`supporting` + `geo` pages:** the **types + render routes exist** (`/$slug`, `/service-area/$slug`), but there is **no creation/writer path** — `seedCoreThirty` writes only home/category/service, and the panel has no "Add Page" (type read-only). ⇒ **renderable but not creatable** today (except direct SQL). Effectively **not built** for real use.
- **Ongoing system** (monthly articles, content-automation tool, rank-map topical-vs-geographic loop, §7-8): **scoped-only** — described in `seo-content` + the master plan + this arc's "separate future module" notes. **Not built.** It's the post-arc module.
- **Full picture:** Core-30 topical = **built**; supporting/geo creation = **not built** (render-only); ongoing loop + tool = **scoped-only**.

---

## PART 5 — Honest assessment + punch-list + sequence

### Honest gap: "mechanically works" ≠ "follows the method."
The system genuinely works end-to-end (map → seed → manage → write → publish → render) and produces structurally-correct, factually-guarded **single-city topical** pages. But vs the full scoped method:
1. **Multi-location — the #1 gap.** The business model is multi-location; we capture `service_area[]` and build **one** city. **No geo pages exist or can be created.** The core geographic-relevance half of the method (§7-8) is entirely absent. **Biggest gap, correctly identified.**
2. **Geo/supporting creation — not built** (render routes exist, no writer/UI). Blocks BOTH multi-location AND ongoing content.
3. **Content depth — single-pass, no research, no per-type differentiation, shallow local specificity.** Fine as launch drafts; not ranking-grade (that's the tool). Some cheap wins are missing now (per-type, structure).
4. **Ongoing loop — not built** (scoped): no monthly cadence, no rank-map decisioning.
5. **Structure/formatting — partial** (headed prose, not fully pro-scannable).
6. **Images — in-flight** (re-scoped to `images jsonb`, Part 2).

### Prioritized punch-list
- **P0 — Multi-location** (LOC-1 map `locations[]` → LOC-2 `geo_area` + `seedGeoPages` + coverage flow → LOC-3 geo-aware write). Core to the model; also delivers geo/supporting **creation** (#2).
- **P1 — Cheap content-quality wins** (per-type prompt branching + structure/formatting/CTA/bullets). Tiny effort, lifts every page immediately.
- **P1 — Images v2** (`images jsonb`, 2-3/page, template interleave). Professional pages; a foundation geo pages will also use.
- **P2 — Ongoing content-automation tool + rank-map loop** (full 8-pass, research, monthly cadence). The big future module.

### Recommended sequence (before vs after images)
1. **First — the cheap content-quality wins (P1 prompts).** Hours, not days; improves Core-30 AND future geo pages. Do this immediately; it's almost free.
2. **Then — Images v2 (`images jsonb`).** Small (one additive migration + template interleave). Do it **before** multi-location because the template's multi-image rendering is then ready when geo pages arrive (geo pages want images too) — and it makes the *current* pages look professional now.
3. **Then — Multi-location (LOC-1→LOC-2→LOC-3), the flagship next arc.** Biggest value + unblocks geo/supporting creation.
4. **Then — the ongoing content-automation tool** (rank-map loop, full 8-pass).
- **If business urgency favors coverage over polish,** flip 2 and 3 (multi-location first; it doesn't strictly need images). Both orders are defensible — I lean images-then-locations for the template synergy + quick professional-look win, but locations-first is the pure business-value play.

---
**Audit only. Multi-location is the biggest gap (0% built; core to the model). Images re-scoped to additive `images jsonb` (2-3/page, template-interleaved, passes the audit). Content writer is a deliberate light first-pass with cheap per-type/structure wins available now; the full 8-pass + ongoing loop is the (unbuilt) content-automation tool. Recommended: cheap prompt wins → images v2 → multi-location → ongoing tool. Commits held; nothing built.**
