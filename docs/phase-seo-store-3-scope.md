# SEO-STORE-3 — `seedCoreThirty` writer + admin SEO panel — READ-ONLY SCOPE

> Scope/plan only — **no code, no build prompts.** The WRITE path for the content store: the admin surface where the agency confirms the Core-30 map, and the service-role writer that turns it into `content_pages` rows. Grounded on `cloud-spark-setup` `origin/main` @ `330d9ad`. Awaiting sign-off. Follows SEO-STORE-1 (store, shipped) + SEO-STORE-2 (render routes, validated).

## 0. The one finding that drives the panel — categories/services-by-category/geos are NOT captured
Read against live code:
- **`template_vars.services`** = a **single free-text, comma-separated string** (OnboardWizard "Services offered" textarea, `OnboardWizard.tsx:283/621`). Not structured. `template_vars.segment` = the industry label for A2P registration (e.g. "Home services"), not an SEO category.
- **`clients.service_area`** = `text[]` (cities/areas) — not neighborhood/landmark geo pages.
- **No primary_category, no categories, no services-by-category map, no per-service metadata, no geo-page list** exists anywhere (`onboarding/submit.ts`, `admin.review.tsx`, the client row all lack it).
- ⇒ This is exactly `seo-build` §6's "**Categories + services-by-category (the Core-30 map) + geo — NOT yet captured — AI-derived at build + agency-confirmed in the admin SEO panel.**" **SEO-STORE-3's panel is where that structure is created.** The writer can't run until the map exists.

## 1. Net-new vs reused
- **NET-NEW (this stage):**
  1. **The Core-30 map** — a structured `{primary_category, categories[], services-by-category, geos[]}` object per client (where it's stored = §2, a decision to settle — recommend **no migration**).
  2. **Admin SEO panel** — a new `_authenticated/admin.seo.tsx` (per-client): AI-seeded, agency-editable map + a list of existing `content_pages` rows with publish/unpublish/edit.
  3. **`seedCoreThirty(clientId)`** — a service-role server fn: map + client data → first-pass Core-30 `content_pages` rows (home/category/service) with correct slugs/type/title/H1/meta/`internal_links`, `status='draft'`.
  4. **Publish/edit server fns** — service-role update of a `content_pages` row (draft↔published, edit body/meta).
- **REUSED (no change):**
  - **`supabaseAdmin`** service-role client (`integrations/supabase/client.server.ts`, `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY`).
  - **Server-fn + authz pattern** — `createServerFn({method:"POST"}).validator(z…).handler(…)` + `requireSupabaseAuth` for the caller + **`assertAgencyAdmin(supabaseAdmin, callerId)`** (checks `user_roles` for `admin`/`agency_owner`) — exactly the `tickets.functions.ts` / `onboarding.functions.ts` shape.
  - **`content_pages` store + its RPCs** (SEO-STORE-1) — writer INSERTs here; the panel READs rows via the authenticated tenant-read policy (admins see all), no new grants.
  - **`template_vars` read-merge-write** — the discount/GBP/social editors' pattern (spread the full object, overlay keys, never wholesale-replace) — reused if the map lives in `template_vars` (§2).
  - **`_authenticated` admin route pattern** — the panel is a sibling of `admin.review.tsx`.

## 2. Where the Core-30 map is stored [DECISION — recommend no migration]
- **Option 1 [REC — no migration]:** store the confirmed map in **`template_vars.seo`** (additive JSON on the existing jsonb blob), e.g.
  ```jsonc
  template_vars.seo = {
    primary_category: "Plumber",
    categories: [ { name: "Drainage", slug: "drainage",
                    services: [ { name: "Drain Cleaning", slug: "drain-cleaning" } ] } ],
    geos: [ { name: "Downtown Houston", slug: "downtown-houston" } ]
  }
  ```
  Written via the existing `template_vars` read-merge-write. **Zero schema footprint**; the map is small per-client config, which is exactly what `template_vars` is for. `content_pages` stays the rendered output.
- **Option 2:** a dedicated `seo_page_plan` table. More normalized, but another migration + RLS + `audit_tenant_rls()` gate for a small config blob — **overkill** given the additive-no-migration discipline.
- **Note:** the map and the rows are distinct — the **map** is the plan (editable source of truth); **`content_pages`** is the generated output `seedCoreThirty` writes. Keeping the map in `template_vars.seo` lets the agency re-seed/regenerate without losing their category/service structure.

## 3. `seedCoreThirty(clientId)` — the writer [service-role]
- **Reads:** `template_vars.seo` (the confirmed map) + client data (`business_name`, `address`, `service_area`, `hours`, GBP link, `logo_url`, `social_links`, `twilio_number` for NAP — the `seo-build` §6 sources).
- **Generates, per the map:** the Core-30 row set —
  - **1 home** (`type='home'`) — title/H1 = primary category + city (`seo-build` §2 formula), `internal_links` → the category pages.
  - **3–4 category** (`type='category'`) — title/H1 = category + city; `internal_links` → its services.
  - **25–30 service** (`type='service'`) — title/H1 = service + city.
  - *(Geo rows can be seeded here or deferred to the content tool — flag in §7.)*
- **Deterministic vs AI:** slugs, `type`, `title`, `h1`, `meta_description` scaffold, and `internal_links` are **deterministic from the map + the §2/§3 formulas** (no AI needed — reliable). The **first-pass `body`** is the light `/seo-content` pass — either (a) reuse the app's existing server-side AI capability (the chat/knowledge stack, `lib/chat/knowledge.server.ts`) for a short first-pass, or (b) template a minimal body and leave depth to the content-automation tool. **Flag in §7.**
- **Writes:** INSERT rows with **`status='draft'`** (recommend — agency reviews in the panel; a "publish all" is one click). Idempotency: upsert on `(client_id, slug)` (the unique index) so re-seeding updates rather than duplicates — **flag the re-seed policy in §7** (overwrite edited rows? skip published? update draft only?).
- **Closes a STORE-2 gap:** populating `internal_links` here is what makes STORE-2's editorial-in-content links actually render (validated as pending in the STORE-2 build-log).

## 4. Admin SEO panel — `_authenticated/admin.seo.tsx` [agency/admin only]
- **Placement/authz:** new route beside `admin.review.tsx`, gated like the other admin server fns (`assertAgencyAdmin`). Per-client (select a client, or deep-link from the review/detail page).
- **Map editor:** on first open, **AI-seed** a proposed map by parsing `template_vars.services` (the free-text list) into primary category + categories + services-by-category + suggested geos (from `service_area`) → the agency **edits/confirms** → save via a service-role fn writing `template_vars.seo` (read-merge-write). This is the "AI-derived at build + agency-confirmed" step.
- **Generate:** a "Generate Core-30 (draft)" button → calls `seedCoreThirty` → shows the created draft rows.
- **Rows list:** read existing `content_pages` for the client (authenticated tenant read — admins see all; **no new grant needed**), with per-row **publish / unpublish / edit body+meta** → service-role update fn (§5).

## 5. Publish / edit path [service-role, ticket-fn pattern]
- **`setPageStatus(pageId, 'published'|'draft')`** and **`updatePageContent(pageId, {title, meta_description, h1, body, internal_links, …})`** — `createServerFn` + `assertAgencyAdmin` + `supabaseAdmin.from('content_pages').update(...)`. Set `published_at` when flipping to published.
- Read via RLS (the tenant-read policy), write via service-role — the exact **read-RLS / write-service-role** split used across `tickets.functions.ts`.

## 6. MIGRATION FLAG [explicit]
- **Recommended path (Option 1) = NO migration.** SEO-STORE-3 is **pure app-layer on `golden-master-v1.7`**: server fns + admin UI + writing `template_vars.seo` (additive JSON) + INSERT/UPDATE into the existing `content_pages`. No table/column/policy/RPC added. `audit_tenant_rls()` untouched (stays 0 from STORE-1).
- Only Option 2 (a `seo_page_plan` table) would add a migration — **not recommended**.

## 7. Open questions to settle (before building SEO-STORE-3)
1. **Map storage** — `template_vars.seo` (no migration, rec) vs a `seo_page_plan` table? *(Rec: `template_vars.seo`.)*
2. **First-pass body source** — reuse the app's server-side AI (chat/knowledge stack) for a light first-pass body, or template a minimal body and defer real writing to the content-automation tool? *(Rec: light AI first-pass if the server AI is readily callable; else minimal templated body → tool fills depth.)*
3. **Geo rows** — seed them in `seedCoreThirty` from `template_vars.seo.geos`, or leave all geo/neighborhood pages to the content-automation tool (which owns the genuinely-local writing + rank-map)? *(Rec: seed geo *stubs* (slug/type/title/H1/meta + `areaServed`) here; the tool writes the local body — keeps the Core-30 complete while honoring `seo-build` §2's "genuinely local, not city-swap.")*
4. **Publish state at seed** — `draft` (rec, agency publishes) vs `published`?
5. **Re-seed idempotency** — on re-run, upsert on `(client_id, slug)`: overwrite everything, skip `published` rows, or update only `draft`? *(Rec: update `draft` + never clobber a `published`/agency-edited row without an explicit "regenerate" confirm.)*
6. **Slug collision guard** — enforce the reserved-root-slug list (STORE-2) at write time so a supporting/geo slug can't shadow a fixed route. *(Rec: validate in the writer + panel; reject `about/services/service-area/gallery/contact/get-your-discount/review/thank-you/terms/privacy/sms-program/locations/sitemap.xml/robots.txt`.)*

## 8. Slicing + validation
- **SEO-STORE-3a — map capture (panel, part 1).** The `admin.seo.tsx` map editor: AI-seed from `template_vars.services` → agency confirm → save `template_vars.seo`. *Validate:* map persists (read-merge-write, no clobber of other `template_vars`); admin-only.
- **SEO-STORE-3b — `seedCoreThirty` (writer).** Map + client data → draft Core-30 rows with correct slug/type/title/H1/meta/`internal_links`; upsert idempotent; reserved-slug guard. *Validate:* run for `test-landscaping` → home + categories + services exist as `draft`; slugs/formulas correct; re-run doesn't duplicate; STORE-2 routes render them once published; editorial `internal_links` now render.
- **SEO-STORE-3c — publish/edit (panel, part 2).** Rows list + `setPageStatus` / `updatePageContent`. *Validate:* publish a draft → it renders live via the STORE-2 routes + appears in `/sitemap.xml`; unpublish → 404s; edits persist; admin-only.
- **(Parallel, template-side — not STORE-3):** close the STORE-2 home **6/8 → 8/8** gap (wire the Maps embed from `clients.address` + reviews widget from `clients.review_link`/GBP into the template's home). A template touch-up, done in the template repo (snapshot-first per the STORE-2 build-spec safety approach).

---
**Read-only scope. Recommended path adds ZERO schema (Option 1: `template_vars.seo` + app-layer server fns + admin UI writing the existing `content_pages`). Reuses the service-role writer + `assertAgencyAdmin` authz + `template_vars` read-merge-write + the content-store RPCs. Sequence: 3a map capture → 3b seedCoreThirty → 3c publish/edit; then the content-automation tool.**
