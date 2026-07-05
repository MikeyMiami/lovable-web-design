# Stage LOC-1b-final — unified area capture + read-only SEO tab + hidden-slug — validation [DONE]

> Point-in-time validation record, 2026-07-05. **App-layer; ZERO schema.** Verified against `cloud-spark-setup` `origin/main` @ `1a9a0d4` (v2) — building on LOC-1 (`4fdb0a1`) and LOC-1b (`e859bf6`). Specs: `docs/phase-loc-1b-*` (final-v2 = the shipped one).

## The arc (LOC-1 → LOC-1b → LOC-1b-final)
- **LOC-1** (`4fdb0a1`) — added `city` + `locations[]` to the `SeoMap` zod (`template_vars.seo`); `proposeSeoMap` derives them from `service_area`; a map-editor UI. Discovered the primary-city read was **already** wired (`seedCoreThirty`/`aiWritePage`: `seo.city ?? service_area[0] ?? address`) — LOC-1 just populated it.
- **LOC-1b** (`e859bf6`) — **B1 unify**: one canonical writer `updateClientAreas` owns `seo.city` + `seo.locations` + the `service_area` mirror (`[city, ...locations]`, city-first, ≤14); `saveSeoMap` stopped touching city/locations (orthogonal-key merges, each re-reads → no clobber). Onboarding split into primary-city + additional-areas with a **day-one seo pre-seed in the shared `clientPatch` mapper** (one edit, both agency + public finalize). Settings got the friendly editor.
- **LOC-1b-final (v2)** (`1a9a0d4`) — **the shipped end state:**
  - **SEO tab fully READ-ONLY** (Option A): city/locations render as a read-only "service area (read-only)" card + "edit in settings →" link (matches the differentiators/CONTENT-EDIT-1 pattern). All edit controls removed. **This subsumed the LOC-1 save-bug** (the single "save map" button was `disabled` on `validation.length>0`, i.e. until the *entire topical map* was valid, and sat above the fields — so a primary city couldn't be saved until the whole map was valid).
  - **Slug hidden entirely** — Settings is **names-only**; the slug `Input` is gone. The location slug is **derived-once + frozen + invisible**: `updateClientAreas` keeps a non-empty (existing) slug **verbatim** and **mints** `slugify(name)` (uniquified) only for empty-slug (new) rows; a name edit never re-derives an existing slug. No `isNew` flag needed (no slug field ⇒ nothing to re-derive).

## Validation (PASS)
- **SEO tab:** only the read-only service-area card + working "edit in settings →"; no add/save/edit/remove for city or locations. ✅
- **Settings:** each location = name field + `×` only; no slug UI anywhere. Add "Westerville" → save → join key `westerville` exists but never shown; fixing the name typo leaves the slug unchanged. ✅
- **Server:** `updateClientAreas` verbatim-keeps existing slugs, mints-on-empty for new; single source `seo.city`/`seo.locations`; `service_area` mirror reflects names. No divergence path. ✅
- **Drift:** `admin.seo.tsx` (read-only), `admin.settings.tsx` (names-only), `seo.functions.ts` (`updateClientAreas` mint-on-empty). **No schema/migration**; `audit_tenant_rls()` unaffected. ✅

## LOCKED — location slug is the immutable join key
`seo.locations[].slug` is now set once and frozen (invisible). LOC-2 geo page slugs, future `by_location` assets, and geo internal links all join by it. One authoritative list (Settings). Closes the `by_service`-class divergence risk **before** any geo reference exists.

## ⚠️ LOC-2 REQUIREMENT (carried forward — deletion/cascade guard)
Location **delete** is currently a plain remove (fine — nothing references locations yet). **Once LOC-2's `seedGeoPages` (or `by_location` assets / geo internal links) reference a location slug, deleting or changing a REFERENCED location MUST be blocked or cascaded — no silent orphaning.** LOC-2 owns this guard.

## Roadmap
**LOC-1 + LOC-1b + LOC-1b-final → DONE.** Next: **LOC-2** — additive `content_pages.area_served` column (first schema touch since `content_pages.images`) + `seedGeoPages` + curated coverage-matrix UI + the deletion/cascade guard. Then **LOC-3** (geo-aware `aiWritePage` + publish-in-waves).
