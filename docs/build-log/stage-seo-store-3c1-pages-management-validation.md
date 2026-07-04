# Stage SEO-STORE-3c-1 — content_pages management UI (list/edit/publish/preview/delete) — validation

> Point-in-time validation record, 2026-07-03. **App-layer on `golden-master-v1.7`; ZERO schema/migration.** Reuses `content_pages` (STORE-1). Verified against `cloud-spark-setup` `origin/main` @ `b40c84e` (`git diff 9ec3a0c..origin/main -- supabase/migrations` = empty). Build spec: `docs/phase-seo-store-3c1-build-spec.md`. Scope: `docs/phase-seo-store-3c-scope.md`.

## What shipped
The `content_pages` **management UI** in `/admin/seo` — the "make the invisible pages visible" slice. LIST · edit · publish/unpublish · in-admin preview · delete. Three new service-role server fns; LIST via RLS.

## Validation (PASS — against real code + operator run)
- **Pages list** — all **9** rows for `test-landscaping` render: title · type · slug · resolved URL · status pill. The SQL-to-see-pages problem is solved. ✅
- **Publish** — home row → `status='published'` + `published_at` set (`setPageStatus` `seo.functions.ts:578`). **"Open live" correctly hidden** because `test-landscaping` has `allowed_origins={}` + no `company_website_link` (guard at `admin.seo.tsx:521`) — the link appears once a real client has a domain. ✅
- **Draft preview** — sandboxed iframe (`srcDoc` + `sandbox=""`, `admin.seo.tsx:877-878`) renders `h1` + body **with the editorial `<a>` links visible inside the prose** (the STORE-2 editorial-link mechanism, now eyeball-verifiable on a draft). ✅
- **Delete** — `window.confirm` with the "re-Generate resurrects Core-30 slugs" warning fires; `deletePage` hard-deletes (`:606`). ✅
- **Edit** — `UpdatePageInput.patch` is **`.strict()`** with only the 9 editable fields (`:521-535`) → **`slug`/`type`/`client_id` excluded AND rejected if sent** (stronger than spec's read-only). Writes via the service-role fns. ✅
- **Server-fn contract** — `updatePage`/`setPageStatus`/`deletePage` all `requireSupabaseAuth` + `assertAgencyAdmin` + **`statusCode`-on-throw** (3a gotcha applied: `:554/588/611`); LIST reads via authed RLS `supabase`. ✅
- **Drift** — `seo.functions.ts` (+`updatePage`/`setPageStatus`/`deletePage`), `admin.seo.tsx` (+Pages UI). **No schema/migration** (`git diff` empty). `content_pages` RLS unchanged since STORE-1 → **`audit_tenant_rls()` remains 0**. Test rows cleaned up. ✅

## Skill brought to parity (verbatim mirror handed)
- **`admin-view`** — the SEO tab gains the `content_pages` **Pages management surface**: LIST (title/type/slug/resolved URL/status) · edit (raw-HTML body textarea; `slug`/`type` immutable) · publish/unpublish (`setPageStatus`, sets `published_at`) · in-admin sandboxed preview (drafts can't use published-only STORE-2 RPCs) · hard delete. Read via RLS; writes via service-role fns.

## Next
**SEO-STORE-3c-2** (the last SEO slice) — per-page **`aiWritePage`** (real content via the AI gateway, one call/page = Worker-safe) + fold **title-case normalization** into `saveSeoMap` (service names currently carry lowercase "lawn care" into titles/H1).
