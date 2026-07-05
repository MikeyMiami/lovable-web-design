# SEO Slice 2.5 — Operator Photo-Board (pool + drag-drop assignment) — build spec [HELD]

> Roadmap Slice 2.5. **UI/UX only — ZERO schema.** A fast visual assignment surface layered on the shipped `images jsonb` storage; reuses the existing write path + helpers. Grounded on `cloud-spark-setup` `origin/main` @ `ad33789`. Roadmap: `docs/seo-completion-roadmap.md`. Awaiting review.

## Read-only-verify findings (against ad33789 — all reusable, no rework)
In `src/routes/_authenticated/admin.seo.tsx`:
- **`allAssetsFlat(siteAssets)`** (`:501`) → `{category, url}[]` across ALL categories (work/gallery/services/about/staff) — the **pool source** (does NOT dedup across categories → the board dedups by url).
- **`readImageDims(url)`** (`:508`) — client-side natural `width`/`height` via `new Image()`.
- **`buildAlt`** (inside `ImagesManager`, `:1232`) = `"{businessName} {heading}"` — deterministic alt (heading = page `h1`||`title`||`target_keyword`).
- **`PageImage`** shape (`:472`), **`SLOT_ORDER`** (`:482`), **`flattenAssets`/`HERO_SOURCES`/`INLINE_SOURCES`** (auto-suggest, `:484-499`).
- **Write path** — `updatePage({ data:{ pageId, patch:{ images, og_image } } })`; `og_image` = hero url (mirrors the existing save, `:977-990`). `updatePage` patch is all-optional → a **minimal `{images, og_image}` patch updates ONLY those** (body/title/etc. untouched).
- The pages list + each row's `images` are already loaded by the Pages query. The per-page dialog `ImagesManager` stays as the single-page detail editor — the board **augments** it.
- **No new fn, no migration, no RPC/grant change.**

## Dependency note
The board **assigns** images (writes `images`/`og_image`). They only **display on published pages** once **Slice 2 Part B** (template interleave render) ships to the marketing template — still PENDING. The board is validated by the stored assignment + thumbnails in-panel; on-site rendering is Part B.

---

# PROMPT SEO Slice 2.5 — paste into Lovable (cloud-spark-setup)

> **App-layer, UI-only. ZERO schema change** — no migration/table/column/policy/fn. Adds an operator **Photo-Board** to the SEO panel: a photo pool → drag-and-drop onto per-page 3-slot drop-zones, writing the existing `images` jsonb via the existing `updatePage`. Reuses the shipped helpers. Report files changed + confirm no DB/schema change.

## What 2.5 delivers
A fast **visual assignment** surface (per active client): all the client's uploaded photos in one pool → drag onto each page's hero / inline-1 / inline-2 slots. Auto-suggest fills a first pass; the operator drags to override/fill. **Augments** the per-page dialog `ImagesManager` (keep it).

## Build (in `src/routes/_authenticated/admin.seo.tsx`)
- **A new "Photo Board" view** in the SEO panel (a tab/toggle alongside the existing Pages list), for the active client.
- **POOL:** `allAssetsFlat(client.template_vars.site_assets)` → **dedup by url** → a thumbnail grid; each thumb shows its **category chip**; a **category filter** (All / work / gallery / services / about / staff) + optional text filter. Thumbnails are **draggable**.
- **PAGES:** the client's `content_pages` rows (reuse the loaded pages query) as rows, each showing: title · type · resolved URL · an **"empty slots: N"** badge · **3 drop-zone slots** (Hero / Inline 1 / Inline 2) each rendering the current `row.images` thumbnail (or an empty drop target).
- **Drag-and-drop** (HTML5 DnD or `dnd-kit` — no backend change): drop a pool thumb on a slot →
  - compute `alt = "${businessName} ${row.h1 || row.title || row.target_keyword}"` (trimmed, collapse whitespace) + `dims = await readImageDims(url)`;
  - build the `PageImage` `{ url, alt, position, width?, height? }`; replace that slot in `row.images` (remove any existing entry at `position`); order [hero, inline-1, inline-2]; `og_image = hero?.url ?? null`;
  - write `updatePage({ data:{ pageId: row.id, patch:{ images: orderedImages, og_image } } })` → invalidate the pages query + toast (optimistic update optional). **Patch carries ONLY `images` + `og_image`** — never other page fields.
- **Per-slot clear** (× on a filled slot) → remove that position, recompute `og_image`, `updatePage` minimal patch.
- **Auto-suggest (first pass):** a per-row **"Auto-suggest"** (fill this row's empty slots from distinct pool photos, hero-first, via `flattenAssets`/`HERO_SOURCES`/`INLINE_SOURCES`) + a global **"Auto-suggest all pages"** (loop rows, fill empties, distinct-per-row) → then the operator drags to override.
- **Augments, not replaces:** the edit-dialog `ImagesManager` stays as the single-page detail editor.

## Guardrails
- **ZERO schema/DB change** — no migration/fn; reuses `updatePage` (its patch already accepts `images`+`og_image`) + `allAssetsFlat`/`readImageDims`/`flattenAssets`/`buildAlt` semantics.
- Writes **only** `images` + `og_image` (a minimal patch) — `body`/`title`/`aiWritePage` untouched → images survive AI-write.
- Admin-gated (the `_authenticated/admin/seo` route + the service-role `updatePage`). No AI (that's 2.6). Photos are existing `public-assets` urls (no upload/cost).

## Drift check (report back)
1. File: `admin.seo.tsx` only (+ maybe a DnD dep). No migration, no new fn, no `seo.functions.ts` change.
2. Board writes via the existing `updatePage` with a `{images, og_image}`-only patch.
3. Pool = deduped `allAssetsFlat`; alt/dims via the existing helpers; per-row "empty slots: N".

## VALIDATION
1. Photo Board shows the pool (all `site_assets` merged, **dedup'd**, category chips + filter) + all pages with 3 slots each + "empty slots: N".
2. **Drag** a pool photo onto a page's Hero slot → saves; thumbnail appears; reload persists; `og_image` = hero url; **`body`/`title` unchanged**.
3. **Auto-suggest all pages** → empty slots fill from distinct photos; dragging overrides.
4. **Clear** a slot → removed; `og_image` recomputed if hero cleared.
5. **AI-write** a page → its board image assignments **survive** (images untouched).
6. Photo-thin/empty client → graceful (empty pool message); non-admin blocked; **no migration** (no `audit_tenant_rls` change).

## Status
**HELD — awaiting review.** Assignment only; on-site display needs Slice 2 **Part B** (template render, pending). Next after 2.5: the image-gen spike → Slice 2.6 (AI-fill); onboarding per-service capture can run in parallel.
