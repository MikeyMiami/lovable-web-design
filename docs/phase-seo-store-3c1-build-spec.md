# SEO-STORE-3c-1 — content_pages management UI (list/edit/publish/preview/delete) — build spec [HELD]

> App-layer on `golden-master-v1.7` in `cloud-spark-setup`. **ZERO schema** — reuses `content_pages` (STORE-1). LIST via RLS; edit/publish/delete via new service-role fns in `seo.functions.ts`. Preview = in-admin iframe srcdoc. Grounded on `origin/main` @ `9ec3a0c`. Scope: `docs/phase-seo-store-3c-scope.md`. AI-write = the separate 3c-2 slice. Awaiting user review.

---

# PROMPT SEO-STORE-3c-1 — paste into Lovable (cloud-spark-setup)

> **App-layer on `golden-master-v1.7`. ZERO schema change** — no migration, no new table/column/policy/grant. Adds the `content_pages` **management UI** to the SEO panel + three service-role server fns (edit / set-status / delete). LIST reads via RLS; writes go through admin-gated service-role fns. Report files changed + confirm no DB/migration change.

## What 3c-1 delivers
Makes the generated pages **visible + manageable** in `/admin/seo`: a LIST of the active client's `content_pages` (title, type, slug, resolved URL, draft/published), an **edit** form, **publish/unpublish**, an in-admin **preview**, and **delete**. (Per-page **AI-write** is the separate next slice — do NOT build it here.)

## 1. Server fns — add to `src/lib/seo/seo.functions.ts`
Mirror `seedCoreThirty`/`saveSeoMap`: `createServerFn({method:"POST"}).middleware([requireSupabaseAuth]).inputValidator(...).handler`, dynamic `supabaseAdmin` import, `assertAgencyAdmin(supabaseAdmin, context.userId)`, **attach `statusCode` on thrown errors** (3a gotcha).

- **`updatePage`** — input `{ pageId: uuid, patch: { title?, meta_description?, h1?, body?, target_keyword?, internal_links?, external_link?, og_image?, schema_jsonld? } }` (Zod; `internal_links`/`schema_jsonld` = jsonb). `supabaseAdmin.from('content_pages').update({ ...patch, updated_at: new Date().toISOString() }).eq('id', pageId)`. Do **not** allow editing `slug`/`type`/`client_id` (identity; changing a slug would orphan a route — keep immutable in v1). Return `{ ok: true }`.
- **`setPageStatus`** — input `{ pageId: uuid, status: 'published' | 'draft' }`. Update `status`; set `published_at = now()` when publishing (leave/keep when unpublishing). Return `{ ok: true, status }`.
- **`deletePage`** — input `{ pageId: uuid }`. `supabaseAdmin.from('content_pages').delete().eq('id', pageId)`. Return `{ ok: true }`. (Hard delete; note: re-running Generate Core-30 will re-seed a deleted Core-30 slug.)

## 2. Management UI — in `src/routes/_authenticated/admin.seo.tsx`
Add a **"Pages"** section below the map editor + Generate button (or a tab within the SEO panel).
- **LIST (RLS read):** `useQuery` → `supabase.from('content_pages').select('id, slug, type, title, status, h1, meta_description, body, target_keyword, internal_links, external_link, og_image, schema_jsonld, updated_at').eq('client_id', activeClientId).order('type').order('slug')`. Render a table: **title · type · slug · resolved URL · status pill** (amber draft / green published) + row actions.
  - **Resolved URL (path):** `home`→`/`; `category`/`service`→`/services/{slug}`; `geo`→`/service-area/{slug}`; `supporting`→`/{slug}`. Show the path; for **published** rows also an **"Open live"** link to `{origin}{path}` where `origin` = `client.allowed_origins?.[0]` ?? `client.template_vars?.company_website_link` (read the client row; hide "Open live" if no origin).
- **Edit** (drawer/modal): fields for `title`, `meta_description`, `h1`, `target_keyword`, `og_image`, `external_link`, **`body` as a raw-HTML `<textarea>`** (monospace; matches the `template_vars` JSON-textarea precedent), and `internal_links` / `schema_jsonld` as JSON `<textarea>`s (parse + validate on save; toast on bad JSON). `slug`/`type` shown **read-only**. Save → `updatePage({ data: { pageId, patch } })` → invalidate the query + success toast; `onError` toast.
- **Publish/Unpublish** button per row → `setPageStatus({ data: { pageId, status } })` → invalidate + toast.
- **Preview** (works for drafts too): a modal rendering the row in an **`<iframe srcdoc={...}>`** — compose minimal HTML: `<h1>{h1||title}</h1>` + the `body`. **Sandboxed** (`sandbox=""` — no scripts) so unsanitized body HTML can't execute in the admin origin. (Drafts can't use the STORE-2 live routes — anon RPCs are published-only — so preview is in-admin.)
- **Delete** button per row → `window.confirm` → `deletePage({ data: { pageId } })` → invalidate + toast. Note in the confirm that re-running Generate re-creates Core-30 slugs.

## 3. Guardrails
- **ZERO schema/DB change** — no migration, no new table/column/policy/grant. Only: server fns in `seo.functions.ts` + UI in `admin.seo.tsx`.
- **Read via RLS** (authed `supabase`, admin sees the active client's rows); **all writes via the service-role fns** (`assertAgencyAdmin`). The UI never writes `content_pages` directly.
- `slug`/`type`/`client_id` are **immutable** in the edit form.
- Preview `<iframe>` is **`sandbox=""`** (no script execution) — body HTML is not sanitized server-side.
- **No AI-write** here (3c-2). **No geo creation** (deferred).

## Drift check (report back)
1. Files: `seo.functions.ts` (+`updatePage`, `setPageStatus`, `deletePage`), `admin.seo.tsx` (+Pages list/edit/preview/delete). No migration.
2. LIST reads via RLS; the three writes via service-role fns (admin-gated, `statusCode` on error).
3. `slug`/`type` immutable; preview iframe sandboxed; "Open live" only for published.

## VALIDATION
1. `/admin/seo` (active client with seeded rows) → the **Pages** list shows the 9 rows: title/type/slug/resolved URL/status; all draft initially.
2. **Edit** a page's title + body → save → re-open: persisted; `updated_at` bumped. Bad JSON in `internal_links` → blocked + toast.
3. **Publish** a row → status pill green + `published_at` set → the **STORE-2** live route renders it (and "Open live" opens `{origin}{path}`). **Unpublish** → STORE-2 route 404s again.
4. **Preview** a **draft** → the modal renders `h1` + body in the sandboxed iframe (no live route needed).
5. **Delete** a row → gone from the list + `content_pages`; re-run **Generate Core-30** → the deleted Core-30 slug re-seeds as draft (others skipped).
6. Non-admin cannot load the panel or call the fns. `audit_tenant_rls()` unaffected; no migration in the diff.

## Status
**HELD — awaiting review (split vs whole; body-as-HTML-textarea; hard-delete).** Next: 3c-2 `aiWritePage` (per-page real content) + fold title-case normalization into `saveSeoMap`.
