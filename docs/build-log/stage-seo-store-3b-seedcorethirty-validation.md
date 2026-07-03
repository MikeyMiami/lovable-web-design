# Stage SEO-STORE-3b — seedCoreThirty (Core-30 draft writer) — validation

> Point-in-time validation record, 2026-07-02. **App-layer on `golden-master-v1.7`; ZERO schema/migration.** Writes rows into the existing `content_pages` (SEO-STORE-1). Verified against `cloud-spark-setup` `origin/main` @ `9ec3a0c` (`git diff 330d9ad..origin/main -- supabase/migrations` = empty). Build spec: `docs/phase-seo-store-3b-build-spec.md`.

## What shipped
**`seedCoreThirty`** (`src/lib/seo/seo.functions.ts`) — deterministic Core-30 draft writer: reads `template_vars.seo` (from 3a) + client data → draft `content_pages` rows. Triggered by a **"Generate Core-30 (draft)"** button + a persistent inline "last run" line on `admin.seo.tsx`.

## Validation (PASS — against real code + operator run)
- **Rows** — `test-landscaping` produced all **9** correct rows: 1 `home` + 3 `category` + 5 `service`, all `status='draft'`. ✅
- **City resolution** — resolved to **"Columbus"** from `service_area[0]` (code: `seo.city ?? service_area[0] ?? address`-segment, `seo.functions.ts:335-341`). ✅
- **§2 formulas** — titles/H1 follow city+keyword (`"Landscaping Services Columbus | Test Landscaping"`, `h1 = "… in Columbus"`). ✅
- **Editorial links [load-bearing]** — `internal_links` `[{href,anchor}]` populated AND **real inline `<a href="/services/{slug}">` emitted in the body paragraph prose** (verified `seo.functions.ts:394` home→category, `:425` category→service, `:455` service→parent). This is what closes STORE-2's editorial-link gap on publish. ✅
- **Idempotent** — re-run = `written:0, skipped:9` (pre-checks existing slugs; `.upsert(rows, { onConflict:'client_id,slug', ignoreDuplicates:true })` at `:485`) — no dupes, no overwrite of edited/published rows. ✅
- **Drift** — `seo.functions.ts` (+`seedCoreThirty`), `admin.seo.tsx` (+button+inline feedback), `__root.tsx` (+Toaster mount). **No schema/migration** (`git diff` empty). `content_pages` RLS unchanged since STORE-1 → **`audit_tenant_rls()` remains 0** (no DDL in the diff). ✅

## Real app-wide bug found + fixed (learning — scratch-foundation-worthy)
**`<Toaster/>` (`@/components/ui/sonner`) was NEVER mounted** → **every `toast()` across the entire codebase was a silent no-op** (AI-seed, `saveSeoMap`, `seedCoreThirty` — and any prior feature's toasts). Fixed: mounted `<Toaster position="top-right" richColors closeButton />` in `__root.tsx:129` + added a persistent inline "last run" line on the SEO panel as a belt-and-suspenders feedback channel. **This retroactively restores visible feedback app-wide** (save-map + AI-seed were silently succeeding/failing before). **Learning [captured in `scratch-foundation` §6]:** the toast host component must be mounted once at the root — an `onError`/success `toast()` is invisible without it; verify the host is present before relying on toasts for feedback. Pairs with the SEO-STORE-3a `errorMiddleware`/`statusCode` gotcha (both are "why is my feedback invisible" failure modes).

## Cosmetic (deferred to 3c / saveSeoMap)
Service **titles** carry the AI's lowercase service names ("hardscaping") vs the title-cased categories → fold a **title-case normalization** into 3c edit or `saveSeoMap` (anchors are intentionally lowercased for natural in-prose reading; titles/H1 should be title-cased). Not a blocker.

## Skills brought to parity (verbatim mirrors handed)
- **`scratch-foundation` §6** — the Toaster-never-mounted gotcha (toast host must be root-mounted or all toasts are silent no-ops).
- **`admin-view`** — the SEO tab gains the **"Generate Core-30 (draft)"** action (`seedCoreThirty`) + inline last-run feedback.

## Next
**SEO-STORE-3c** — the `content_pages` management UI in the SEO panel: LIST generated pages (title/type/slug/resolved URL/status), edit, publish/unpublish, preview, delete, + the per-page **"AI-write"** on-demand action (real content via the content pipeline). The slice that makes the pages **visible + manageable** (today they're invisible without SQL).
