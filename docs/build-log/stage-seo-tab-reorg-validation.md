# Stage — SEO-tab reorg (consolidate inputs + collapsibles + geo-reset) — validation [DONE]

> Point-in-time validation record, 2026-07-07. Verified against `cloud-spark-setup` `origin/main` @ `0eb6286`. **UI placement + reuse of existing write paths + one delete fn. ZERO schema, ZERO new write paths.**

## What shipped
- **4 editors MOVED (verbatim) from Settings → SEO tab**, each writing via its **existing** server fn (no new write path, no data copy): Services & Pricing (`updateClientServices`), Competitor URLs (`updateCompetitorUrls`), Business & SEO Content (`updateClientContent`), Service Area & Locations (`updateClientAreas`, the LOC-1b-final names-only/slug-frozen editor). **Removed from `admin.settings.tsx`** (0 refs left → no double-edit surface).
- **Single edit surface reconciled:** the SEO tab's LOC-1b read-only "service area (read-only)" card + "edit in settings →" link **replaced** by the editable Service Area editor. SEO tab is now the single edit surface for these inputs.
- **Collapsible panels:** a new **"business & seo inputs"** `<details>` (collapsed by default) holds the 4 moved editors; the **cadence + topical-signal** panel wrapped in a collapsible (collapsed by default); the map-editor `<details>` + the **Pages tree** unchanged/prominent.
- **Geo-reset parity:** new `deleteGeoPages({clientId})` (mirror `deleteAllClientPages`, scoped `type='geo'`) + a "reset geo pages" button (confirm dialog, admin-gated). **BLOCK guard** — refuses if any supporting page's `parent_slug` points at a geo page (no silent orphaning of supporting content/FAQ links); matches the LOC-2 BLOCK decision.

## Validation (PASS)
- Inputs edit in the SEO tab + persist via their existing fns; SEO map / `seedCoreThirty` / page-gen / template / `get_client_public` all read the same `template_vars.*`/`service_area` unchanged — nothing broke; round-trip values byte-identical. ✅
- Gone from Settings (no double-edit); read-only area card replaced by the editable one. ✅
- Collapsibles collapsed by default (clean tab); Pages tree prominent. ✅
- `deleteGeoPages` scoped to geo + BLOCKS on supporting children. ✅ ZERO schema.

## Roadmap
SEO-tab reorg DONE. Deep-writer track: S4-D0..D4 + scope-hardening done; **next: the manual x3 map-restructure test** (validate the structural theory) → decide category-page fix (Layer-1 `proposeSeoMap` structural vs Layer-2 prompt) → S4-D5 (deep-write UI). Held: Slice-5 one-click build.
