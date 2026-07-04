# SEO-STORE-3c — content_pages management UI (SEO panel) — READ-ONLY SCOPE

> Scope/plan only. The slice that makes the generated pages **visible + manageable** in `admin.seo.tsx` (today they're invisible without SQL). App-layer on `golden-master-v1.7` in `cloud-spark-setup`; **ZERO schema** (reuses `content_pages` from STORE-1). Grounded on `origin/main` @ `9ec3a0c`. Awaiting sign-off.

## Read-only-verify findings (against 9ec3a0c)
- **LIST reads via RLS** — STORE-1 granted `select` on `content_pages` to `authenticated` + the tenant-read policy (`is_admin OR client_id ∈ user_client_ids`). Admins read all rows for the active client via the authed browser `supabase`: `supabase.from('content_pages').select('*').eq('client_id', activeClientId).order('type').order('slug')`. **No new grant/policy.**
- **WRITES stay service-role** — `content_pages` has **no** authenticated write policy (writes were spec'd service-role-only). So edit / publish / unpublish / delete / AI-write = **new server fns in `seo.functions.ts`**, each `requireSupabaseAuth` + `assertAgencyAdmin` + `supabaseAdmin`, `statusCode` on error (3a gotcha). This is the read-RLS / write-service-role split used everywhere.
- **Resolved URL** — path from `type`+`slug`: `home`→`/`, `category`/`service`→`/services/{slug}`, `geo`→`/service-area/{slug}`, `supporting`→`/{slug}`. **Site origin** for a live link = `clients.allowed_origins[0]` (real `text[]`; used by `tenant-resolver`/`FinalizeInvite`) ?? `template_vars.company_website_link`.
- **Preview** — **no HTML sanitizer** in the repo (no DOMPurify; `dangerouslySetInnerHTML` only in a chart util) AND **drafts can't render via STORE-2** (anon RPCs are published-only). ⇒ preview must be **in-admin**, isolated: render the row's `body` in an **`<iframe srcdoc>`** (no new dep, sandboxed) with the `h1`/`title`. "Open live" (the real `{origin}{path}`) only for **published** rows.
- **AI-write** — the first concrete content generation (no pipeline module exists yet). **One AI call per page = safe within the Worker 30s limit** (the reason 3b deferred it). Reuse `createLovableAiGatewayProvider` → `generateText` (loose output, `generateText`+parse if structured; 3a/3b gotchas). Client context for quality: `business_name`, resolved `city`, the page's service/category name, `template_vars.about_us`/`differentiators`, `service_area`.
- **Cosmetic carryover (3b)** — service titles carry the AI's lowercase names ("hardscaping"). Fold **title-case normalization** into `saveSeoMap` (so future seeds are correct) + the 3c edit surface (agency can fix any row). *(Recommend both.)*

## Recommended sub-slice split [the 6 features are two concerns]
- **SEO-STORE-3c-1 — the management UI (the "make pages visible" win).** LIST (title/type/slug/resolved URL/status) · edit (title/meta/h1/body/target_keyword/internal_links/og_image/external_link/schema_jsonld) · **publish/unpublish** (`setPageStatus`, sets `published_at`) · **preview** (iframe srcdoc) · **delete**. This is the slice you most want — it makes the invisible URLs manageable. Deterministic, no AI, easy to validate.
- **SEO-STORE-3c-2 — the per-page AI-write action.** `aiWritePage(pageId)` — real single-page content via the AI gateway (the seed of the content pipeline; the fuller 8-pass/rank-map automation is the later content-automation tool). Its own concern + its own validation (quality, local specificity, one-H1 preserved). One AI call, on-demand, safe.
- **Rationale:** 3c-1 is CRUD you can validate in minutes; 3c-2 is content-quality that deserves separate eyes. Splitting keeps each validation tractable — the rhythm that's worked all arc. *(If you'd rather ship 3c whole, I'll fold `aiWritePage` into the one prompt.)*

## Net-new vs reused
- **NET-NEW:** the management UI in `admin.seo.tsx` (list/edit/preview panel or `/admin/seo` sub-view) + server fns `updatePage`, `setPageStatus`, `deletePage` (3c-1) + `aiWritePage` (3c-2).
- **REUSED:** `content_pages` + its RLS (read) ; the service-role write pattern + `assertAgencyAdmin` ; `useActiveClient` ; the toast host (now mounted) ; the AI gateway (3c-2). **No schema, no migration, no new grant.**

## Open questions to settle (before 3c-1)
1. **Split or whole?** 3c-1 (management UI) now, 3c-2 (AI-write) next — vs one prompt. *(Rec: split.)*
2. **Edit `body` as raw HTML textarea** (matches the `template_vars` JSON-textarea precedent; agency edits HTML) vs adding a rich-text editor? *(Rec: raw HTML textarea for v1 — no new dep; rich-text is a later nicety.)*
3. **Delete = hard delete** (row gone; `seedCoreThirty` will re-create it on next Generate since it's missing) vs a soft "archive"? *(Rec: hard delete — simple; re-Generate re-seeds. Confirm the agency understands delete + re-Generate resurrects a Core-30 slug.)*
4. **Title-case normalization** — add to `saveSeoMap` now (fixes future seeds) + rely on 3c edit for existing rows? *(Rec: yes to both.)*

---
**Read-only scope. ZERO schema. LIST via RLS; edit/publish/delete/AI-write via service-role fns. Preview = in-admin iframe srcdoc (drafts can't use STORE-2). Recommend split: 3c-1 management UI → 3c-2 AI-write.**
