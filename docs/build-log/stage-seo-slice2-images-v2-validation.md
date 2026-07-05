# Stage SEO Slice 2 — images v2 (`images jsonb`) — validation

> Point-in-time validation record, 2026-07-04. **Part A (storage + per-page panel) — one additive migration + panel; verified against `cloud-spark-setup` `origin/main` @ `ad33789`.** Part B (template interleave render) is **PENDING** (see below). Build spec: `docs/phase-seo-slice2-images-v2-build-spec.md`. Roadmap: `docs/seo-completion-roadmap.md` (Slice 2).

## Part A — what shipped + validated (against real code)
- **Migration `20260704235805`:** `alter table public.content_pages add column if not exists images jsonb;` — additive, nullable. **`audit_tenant_rls()` unaffected** (no policy change; anon RPCs return `cp.*` so `images` auto-flows; no new grant). ✅
- **`updatePage` `.strict()` patch gained `images`** (`seo.functions.ts:571-579`) — array of `{url, alt, position:hero|inline-1|inline-2, width?, height?}`; `og_image` derived from the hero at save (`admin.seo.tsx:977-990`). ✅
- **`deleteAllClientPages(clientId)`** (`seo.functions.ts:667`) — Reset Core-30: admin-gated, `statusCode`-on-throw, **client-scoped** delete; panel button with the destructive confirm. ✅
- **Per-page `ImagesManager`** (`admin.seo.tsx:1209`) — 3 slots (hero/inline-1/inline-2), **auto-suggest** per slot + all (`flattenAssets` over `HERO_SOURCES`/`INLINE_SOURCES`), **client-side natural dims** (`readImageDims` via `new Image()`, `:508-522`), **deterministic alt** `buildAlt = "{business} {heading}"` (`:1232`), pool helper `allAssetsFlat` (`:501`). ✅
- **AI-write safety preserved:** images live in `images`/`og_image` only; `aiWritePage` still body-only → images survive AI-write. ✅
- **Drift:** one additive migration + `seo.functions.ts` (patch + `deleteAllClientPages`) + `admin.seo.tsx` (ImagesManager + Reset). **`audit_tenant_rls()=0`.** ✅

## Part B — template interleave render — **PENDING (required for images to show)**
Part A **stores** images + builds the assignment panel, but **nothing renders them on published pages yet.** Part B (the marketing-TEMPLATE change: hero above/below H1 + inline images interleaved by splitting body on `<h2>`, `og:image` from hero, alt/dims/lazy) goes to the separate template project (no local clone → operator-side) and **has not been sent.** **Until Part B ships, images are stored but invisible on-site.** Prompt B is in `docs/phase-seo-slice2-images-v2-build-spec.md`; snapshot the template first (STORE-2 safety note), then send + operator-validate (hero + 2 inline between sections, no CLS, `og:image` in head).

## Status
**Part A (storage + per-page panel) = DONE + verified. Part B (template render) = PENDING.** The per-page `ImagesManager` is a usable v1 for assignment; the **operator Photo-Board is Slice 2.5** (assignment UX upgrade), **AI-fill is Slice 2.6** (post image-gen spike), and **onboarding per-service capture** is an independent data-quality slice — all added to the roadmap. Reconcile: `docs/phase-seo-image-assignment-reconcile.md`.
