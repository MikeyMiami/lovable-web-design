# SEO Slice 2 — images v2 (`images jsonb`, 2-3/page, template interleave) — build spec [HELD]

> Roadmap Slice 2. ONE additive migration (`content_pages.images jsonb`) + panel images manager + template interleave. **AI-write-safe** (images live in `images`/`og_image`, never in `body`). Also folds in a **Reset Core-30** control (delete-all-pages) so the operator never needs SQL. Grounded on `cloud-spark-setup` `origin/main` @ `e5e7278`. Roadmap: `docs/seo-completion-roadmap.md` (Slice 2). Awaiting final review of Prompt A.

## Read-only-verify findings (against e5e7278)
- **`content_pages` has no `images` column** (`types.ts:250-269`; has `og_image`). Slice 2 = one additive column.
- **Anon RPCs return `cp.*`** (`get_client_page`/`get_client_pages`, STORE-1) → `images` **auto-flows to the template** with no RPC change.
- **`audit_tenant_rls()` stays 0** — adding a column adds no policy; `content_pages` keeps its STORE-1 tenant-read policy. No new grant (authenticated select is table-wide; anon via the RPC).
- **`updatePage`'s `.strict()` patch** (`seo.functions.ts:521-535`) needs an `images` field; the panel's raw `og_image` text input (`admin.seo.tsx:875/919`) becomes the images manager (derives `og_image` from hero).
- **Dims:** `site_assets` items are `{url, path}` (no dimensions) → panel reads natural `width`/`height` client-side (`new Image().onload`) at assign time (CLS, `seo-build` §5).
- **Reset control:** the only `content_pages` writer is `seedCoreThirty`; there is no bulk-delete/reset — clearing a client's pages required SQL during Slice 1 testing. Slice 2 adds `deleteAllClientPages` + a button.

---

# PROMPT A (Slice 2) — paste into Lovable (cloud-spark-setup) [backend + panel]

> **App-layer on `golden-master-v1.7` — ONE additive migration** (`content_pages.images jsonb`, nullable; no existing object altered) + `updatePage` patch extension + a new `deleteAllClientPages` fn + the SEO panel images manager + a Reset Core-30 control. Report the migration + confirm `audit_tenant_rls()` returns **0 rows**.

## 1. Migration (additive)
```sql
alter table public.content_pages add column if not exists images jsonb;
```
No RLS/grant/policy change (the STORE-1 tenant-read policy + anon RPCs returning `cp.*` cover the new column). **Post-migration gate: `select * from public.audit_tenant_rls();` must return 0 rows.**

## 2. Extend `updatePage` (`src/lib/seo/seo.functions.ts`)
Add `images` to the `.strict()` patch schema — nullable/optional array:
```ts
images: z.array(z.object({
  url: z.string(),
  alt: z.string(),
  position: z.enum(["hero", "inline-1", "inline-2"]),
  width: z.number().nullable().optional(),
  height: z.number().nullable().optional(),
})).nullable().optional(),
```
No handler change (it already spreads `patch`). `og_image` stays in the patch; the panel sets both in one call.

## 3. New fn `deleteAllClientPages` (`src/lib/seo/seo.functions.ts`) — Reset Core-30
Mirror `deletePage`'s shape: `createServerFn({method:"POST"}).middleware([requireSupabaseAuth]).inputValidator` on `{ clientId: z.string().uuid() }` → `assertAgencyAdmin(supabaseAdmin, context.userId)` → **delete ALL `content_pages` for that client** and return the count:
```ts
const { data, error } = await supabaseAdmin
  .from("content_pages").delete().eq("client_id", data.clientId).select("id");
if (error) propagateError(error.message);
return { ok: true as const, deleted: (data ?? []).length };
```
Wrap in the try/catch that rethrows with `statusCode` (3a gotcha). **Scoped to the one `client_id`** — never cross-tenant.

## 4. SEO panel images manager (`src/routes/_authenticated/admin.seo.tsx`)
Replace the raw `og_image` text input in the page edit dialog with a **3-slot images manager** (Hero, Inline 1, Inline 2), sourced from `client.template_vars.site_assets` (`{ work[], gallery[], about[], services[], staff[] }`, items `{url, path}`):
- Each slot: **thumbnail** + **Auto-suggest** + **Choose photo** (modal grid of all site_assets by category) + **Clear**.
- **Auto-suggest per slot:** Hero → first from `gallery`→`work`→`services`; Inline → next distinct photo from `work`→`services`→`gallery` (avoid reusing a chosen url). An **"Auto-suggest all"** fills Hero + Inline-1 (+ Inline-2) from distinct photos.
- **On assign, compute + store** per filled slot: `url`; **deterministic `alt` = `` `${businessName} ${h1 || target_keyword}` ``**; `position`; **natural `width`/`height`** via `new Image()` `onload` (omit if load fails).
- **Save:** `images` = filled slots ordered [hero, inline-1, inline-2]; `og_image` = Hero url (or `null`); one call `updatePage({ data: { pageId, patch: { images, og_image } } })` → invalidate + toast.
- **List column:** hero/`og_image` thumbnail + a small count (e.g. "2 imgs") per row.
- **Photo-thin fallback:** fill available slots only; 0 photos → "No uploaded photos" state, `images` stays null.
- **AI-write safety:** images live ONLY in `images`/`og_image` — never `body`. `aiWritePage` untouched (still body-only) → images survive AI-write.

## 5. Reset Core-30 control (SEO panel)
Near the **Generate Core-30 (draft)** button, add a **"Reset Core-30 / Delete all pages"** button (destructive styling) →
`window.confirm("This permanently deletes ALL content_pages for this client — published and draft. Re-run Generate to recreate the Core-30.")` →
`deleteAllClientPages({ data: { clientId: activeClientId } })` → invalidate the pages query + toast `Deleted N pages.`; `onError` toast. Disable while pending. Admin-gated (fn + route).

## Guardrails (A)
- ONE additive column; no existing object altered; **`audit_tenant_rls()=0`**. Writes via service-role fns (`assertAgencyAdmin`, `statusCode`-on-throw). `body`/`aiWritePage` untouched. Images from existing `public-assets` urls (no upload/cost). `deleteAllClientPages` is `client_id`-scoped + confirm-gated.

## Drift check (A)
1. Migration = `add column images jsonb` only; `audit_tenant_rls()=0`.
2. `updatePage` patch gains `images`; new `deleteAllClientPages` (client-scoped, admin-gated, statusCode).
3. `admin.seo.tsx`: images manager (3 slots) + Reset Core-30 button.
4. `body`/`aiWritePage` untouched; images only in `images`/`og_image`.

## VALIDATION (A)
1. Migration applies; `select * from audit_tenant_rls()` → **0 rows**.
2. Edit a page → assign Hero + 2 inline → Save → row `images` has 3 entries (url/alt/position/width/height); `og_image` = hero url; `body` unchanged.
3. **Auto-suggest all** → distinct photos; alt = `"{business} {h1}"`.
4. **AI-write** the page → `images`/`og_image` survive (body rewritten only).
5. Photo-thin/empty client → graceful; `images` null.
6. **Reset Core-30** → confirm → all pages deleted, toast "Deleted N pages"; re-run Generate → Core-30 recreated. Scoped to the active client only.
7. Non-admin blocked.

---

# PROMPT B (Slice 2, companion) — paste into the MARKETING TEMPLATE project [operator-validated, no clone]

> **Frontend-only. No backend/schema change.** Render each page's **`images`** (returned by the anon RPCs alongside `og_image`) at SEO-correct positions, interleaved with the body.

- Read `images` (array of `{ url, alt, position, width, height }`) + `og_image` from the page row.
- **Hero:** the `images` entry with `position === "hero"` (fallback `og_image`) → a hero `<img>` near the top (above/below the H1). **Eager** (LCP); `alt`, explicit `width`/`height` (or a reserved aspect-ratio box if absent — no CLS), `style="max-width:100%;height:auto"`.
- **Inline interleave:** split the rendered `body` HTML on `<h2>` boundaries into sections; inject `inline-1` **after the 1st section** and `inline-2` **after the 3rd** (or after the last if fewer). Each: `loading="lazy"`, `alt`, `width`/`height` (or aspect-ratio box).
- **Empty `images`** → render body normally, no images (graceful).
- **`<head>`:** `og:image` from `og_image` (or hero url) + `og:image:alt` from the hero's alt.

## VALIDATION (B, operator-side)
A page with 3 images shows hero at top + 2 photos between content sections, correct alt/dims, no CLS (PageSpeed); `og:image`+`og:image:alt` in head; a no-image page renders cleanly.

## Guardrails (B)
Frontend-only; reads existing RPC data (`images`/`og_image`); no schema/backend change; deterministic alt (no AI); AI-write-safe (images never in body).

## Status
**HELD — awaiting final review of Prompt A (with the Reset Core-30 control).** Send A to cloud-spark first (drift-checkable: migration + `audit_tenant_rls()=0` + manager + reset), then B to the template (snapshot first). On validation: build-log + roadmap Slice 2 → DONE.
