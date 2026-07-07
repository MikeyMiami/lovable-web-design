# Stage — SEO map editor unification + save/primary-service fixes — validation [DONE]

> Point-in-time record, 2026-07-07. Unification verified against `cloud-spark-setup` `origin/main` @ `9983adf`. **Save/primary-service fixes validated in the Lovable preview; pending Lovable→GitHub sync at record time (origin/main @ 9983adf is the unification; the bottom-save-button + hint were not yet synced — will confirm on next fetch).** ZERO schema.

## What shipped — unification (`9983adf`)
- **Segment merged into primary category:** the industry-segment input removed from the SEO-tab content editor; the map editor's **primary category prefills from `titleCase(tv.segment)`** when `seo.primary_category` is empty; `template_vars.segment` stays STORED (so `proposeSeoMap` keeps its niche hint — unchanged). Nothing that reads segment broke.
- **Services moved INTO the map editor with pricing:** categories → nested services, each with an optional **price range**; the standalone "Services & Pricing" panel removed. On save: `saveSeoMap` (category structure) **then** `updateClientServices` (rebuild `services_structured` = flattened `[{name, slug, price_min, price_max}]`). Prices **pre-seeded from `services_structured` by slug** on load → no price lost on first save. `updateClientServices` accepts the map's slug (services_structured stays slug-aligned). `priceLine`/template/`by_service` readers unchanged. Zero stored-shape change (services_structured already had price+slug).
- **Slugs hidden + frozen** in the map editor (category + service) — derive-once-on-add, never re-derive on name edit, `saveSeoMap` verbatim-keep + mint-on-empty (mirrors LOC-1b locations). Join keys (page slugs, `by_service`, `parent_slug`) stable.

## Fixes (validated in preview; sync pending)
- **BUG 1 — in-context save:** the "save map" button relocated to the **bottom of the map-editor content** (was above both collapsibles → scrolled off; LOC-1 class). Validation errors shown next to it. Wiring was already correct (`saveSeoMap` → `updateClientServices`); edits persist + round-trip (structure + prices).
- **BUG 2 — service placement (by design):** `SeoMap.primary_category` is a **string** — services live ONLY under **secondary categories** (`categories[].services[]`), method-correct (home → secondary categories → service pages). **No primary-category service adder** (correct); a **guiding hint** clarifies services go under a secondary category. The secondary-category adder works (name + price, slug frozen).

## Validation (PASS)
- Unification round-trips: edit categories/services/pricing → save → re-read shows saved structure + prices; `services_structured` rebuilt by frozen slug; segment prefill works; `proposeSeoMap` unchanged. ✅
- Fixes (preview): save button in-context at the bottom; primary category has no service adder + hint; secondary adder persists by frozen slug. ✅ (pending origin/main sync)

## Roadmap
SEO map editor is now the unified surface (primary category ← segment → secondary categories → services w/ pricing, slugs hidden). **Next: the manual x3 map-restructure test** (real secondary categories → deep-write a category page → does the sprawl resolve?) → decide the category-page fix (Layer-1 `proposeSeoMap` structural vs Layer-2 prompt). Then S4-D5. Held: Slice-5.
