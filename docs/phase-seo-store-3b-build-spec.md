# SEO-STORE-3b — `seedCoreThirty` (Core-30 draft writer) — build spec [HELD, commits held]

> App-layer on `golden-master-v1.7` in `cloud-spark-setup`. **ZERO schema** — writes rows into the existing `content_pages` (SEO-STORE-1). One new server fn in `src/lib/seo/seo.functions.ts` + a "Generate Core-30 (draft)" button on `admin.seo.tsx`. Reads `template_vars.seo` (from 3a) + client data → deterministic Core-30 draft rows. Grounded on `origin/main` @ `330d9ad`. Awaiting the body-generation decision (below) before it's final.

## Read-only-verify findings (against 330d9ad)
- **No `city` column.** `clients.address` = free text ("street, city, state, zip"); `clients.service_area` = `text[]` (≤14). **City is derived** — resolution order for the title/H1 formula: `template_vars.seo.city` (if the agency added one) → `service_area[0]` → first comma-segment heuristic of `address`. *(Recommend: default to `service_area[0]`; optionally add a small `city` field to the 3a panel later.)*
- **`content_pages`** (SEO-STORE-1): `unique(client_id, slug)` (index `uq_content_pages_client_slug`); `type` is free text (no CHECK) — `home`/`category`/`service` fine; `status` default `draft`. Upsert → `.upsert(rows, { onConflict: 'client_id,slug', ignoreDuplicates: true })` = **insert new, never overwrite existing** (preserves agency-edited/published rows).
- **Write path** = service-role (`supabaseAdmin`) in a `createServerFn` gated by `assertAgencyAdmin` — same shape as 3a. Apply the SEO-STORE-3a **server-fn gotchas** (attach `statusCode`; `onError` toast).
- **Map source** = `template_vars.seo = { primary_category, categories:[{name, slug, services:[{name, slug}]}] }` (3a). Slugs already validated unique-across-map + reserved-guarded at 3a save; **re-validate at seed** as the backstop.

## THE ONE OPEN DECISION — body generation (Worker 30s CPU limit)
A Core-30 seed = 1 home + 3–4 category + up to ~30 service pages. The Cloudflare Worker **30s CPU limit** (scratch-foundation §7) makes **~30 synchronous light-AI body calls unsafe** (timeout). Two clean options:
- **Option A [RECOMMENDED] — deterministic structure + templated first-pass body now; AI body per-page on demand.** `seedCoreThirty` writes all rows in ONE fast insert: deterministic slug/type/title/H1/meta/target_keyword/`internal_links` + a **light templated body** (locally-stamped: business_name + city + the §1/§2 H2-per-child structure with the editorial links). Real writing = a later per-page "AI-write" action (3c) or the content-automation tool. **Fast, no timeout, reliable; bodies are drafts anyway.** Slightly walks back "light AI first-pass" — justified by the hard Worker limit.
- **Option B — light AI body at seed for every page.** Truer to the earlier decision, but must be **batched/chunked** (e.g. home+categories AI now; services in bounded batches or a follow-up pass) to respect 30s — more moving parts, slower, partial-failure handling. If chosen, seed structure first (Option A rows), then enrich bodies in bounded batches with the `generateText` + fallback pattern.
- *(Hybrid: Option A rows immediately + AI-enrich **home + category** bodies only in the same call (≤5 calls, safe), leave service bodies templated for the tool. Best of both — anchors are AI, bulk is deferred.)*

**RESOLVED — Option A** (user-confirmed 2026-07-02): deterministic structure + templated bodies with real inline editorial `<a>`; AI body writing is the on-demand per-page action (3c) / content tool. Rationale: a seed that times out mid-Core-30 (partial clients, partial-failure recovery) is a worse failure mode than templated placeholder copy the tool rewrites anyway; the seed's real job is the timeout-proof deterministic structure.

---

# PROMPT SEO-STORE-3b — paste into Lovable (cloud-spark-setup) [Option A]

> **App-layer on `golden-master-v1.7`. ZERO schema change** — writes rows into the existing `content_pages`. Add ONE server fn `seedCoreThirty` to `src/lib/seo/seo.functions.ts` + a "Generate Core-30 (draft)" button on `admin.seo.tsx`. Deterministic writer: reads `template_vars.seo` + client data → draft Core-30 rows. Report rows written/skipped + confirm no migration.

## `seedCoreThirty` — server fn (mirror 3a's `saveSeoMap` shape)
- Input `{ clientId: string (uuid) }`; `requireSupabaseAuth` + `assertAgencyAdmin(supabaseAdmin, context.userId)`. Attach `statusCode` on thrown errors (SEO-STORE-3a gotcha).
- Read via `supabaseAdmin`: `business_name`, `address`, `service_area`, `template_vars` (for `seo`) from `clients`.
- If `template_vars.seo` is missing/empty → throw a clear "Define the SEO map first" error.
- **Resolve `city`** = `seo.city` ?? `service_area?.[0]` ?? first comma-segment of `address` (trim); if none → throw "No city/service area to build titles from."
- **Re-validate** every category/service slug: `^[a-z0-9-]+$`, unique across the map, not in the reserved list (`about, services, service-area, gallery, contact, get-your-discount, review, thank-you, terms, privacy, sms-program, locations, sitemap.xml, robots.txt`).

### Rows to build (deterministic; `status='draft'`)
Per `/seo-build` §2/§3 formulas (city = resolved above; brand = `business_name`):

| Row | slug | type | title | h1 | target_keyword | internal_links |
|---|---|---|---|---|---|---|
| Home | `home` | `home` | `{primary_category} {city} \| {business_name}` | `{primary_category} in {city}` | `{primary_category} {city}` | one per category → `{href:"/services/{cat.slug}", anchor:"{cat.name}"}` |
| Category (each) | `{cat.slug}` | `category` | `{cat.name} {city} \| {business_name}` | `{cat.name} in {city}` | `{cat.name} {city}` | one per its service → `{href:"/services/{svc.slug}", anchor:"{svc.name}"}` |
| Service (each) | `{svc.slug}` | `service` | `{svc.name} {city} \| {business_name}` | `{svc.name} in {city}` | `{svc.name} {city}` | back-link → `{href:"/services/{parentCat.slug}", anchor:"{parentCat.name}"}` |

- **`meta_description`** (deterministic, ~150 chars): e.g. `` `${business_name} provides ${keyword} — ${cta}.` `` where `cta` = "Free estimates. Call today." (templated; the agency/tool refines).
- **`body`** (templated first-pass HTML) — **[LOCKED] the editorial links MUST be real `<a href>` tags emitted INSIDE the paragraph prose**, not only in the `internal_links` jsonb and not a separate "related links" chrome block. This is what makes a published seeded page close STORE-2's editorial-link gap (validation #4) regardless of how the template consumes `internal_links`.
  - **Home:** an intro `<p>` (`{business_name}` provides `{primary_category}` across `{city}`) + for each category an `<h2>{cat.name}</h2>` followed by a `<p>` whose 1–2 sentence blurb **contains an inline `<a href="/services/{cat.slug}">{cat.name}</a>`**. Rendered example: `<h2>Lawn Care</h2><p>Our <a href="/services/lawn-care">lawn care</a> keeps Plano yards healthy year-round.</p>`.
  - **Category:** intro `<p>` + per service `<h2>{svc.name}</h2>` + a `<p>` blurb **containing an inline `<a href="/services/{svc.slug}">{svc.name}</a>`**.
  - **Service:** intro `<p>` + templated `<h2>`s ("What's included", "Why it matters in {city}", CTA) + a closing `<p>` **containing an inline `<a href="/services/{parentCat.slug}">{parentCat.name}</a>`** back to the parent category — generic but locally stamped; **draft** for the tool/agency to enrich.
  - The `<a>` `href`s and anchors MUST match the row's `internal_links` entries 1:1 (same hrefs/anchors, just also emitted inline in body).
- `schema_jsonld` = leave NULL (the STORE-2 template composes baseline schema from client data); `external_link`, `og_image` = NULL.

### Write (idempotent, no overwrite)
- Build the full row array, then **one** `supabaseAdmin.from('content_pages').upsert(rows, { onConflict: 'client_id,slug', ignoreDuplicates: true })`.
- `ignoreDuplicates: true` → **new services get pages; existing rows (agency-edited / published) are NOT touched.**
- Return `{ written: <inserted count>, skipped: <already-existing count>, city }`.

## `admin.seo.tsx` — add "Generate Core-30 (draft)"
- A button (below the map editor) → `seedCoreThirty({ data: { clientId: activeClientId } })` → toast `Wrote N pages (skipped M existing)`; spinner; `onError` toast (3a gotcha).
- Disable if the map is empty/unsaved. **No content_pages list/edit here** — that's 3c.

## Guardrails
- **ZERO schema/migration.** Only: `seedCoreThirty` added to `seo.functions.ts` + a button in `admin.seo.tsx`.
- Writes **draft** rows only; **never overwrites** an existing `(client_id, slug)`.
- **No geo rows** (deferred — topical Core-30 only).
- Deterministic — no AI in this fn (Option A).

## Drift check (report back)
1. Files: `src/lib/seo/seo.functions.ts` (+`seedCoreThirty`), `src/routes/_authenticated/admin.seo.tsx` (+button). No migration.
2. Rows are `draft`; upsert `ignoreDuplicates` preserves existing rows.
3. `internal_links` populated (home→categories, category→services, service→parent) + inline editorial `<a>` in body.
4. City resolution + slug re-validation + reserved-guard present.

## VALIDATION
1. Save a map for `test-landscaping`, click **Generate Core-30 (draft)** → toast reports N written.
2. Query `content_pages` for the client: 1 `home` + 3 `category` + all `service` rows, all `status='draft'`; titles/H1 = the §2 formulas with the resolved city; `internal_links` populated.
3. **Re-run** Generate → all skipped (0 written); no duplicates; edit a row then re-run → the edit survives (no overwrite).
4. Publish one row (temporarily, via SQL or 3c later) → the **STORE-2** routes render it AND the **editorial internal links now appear in-content** (the STORE-2 gap closes). Confirm on the template that `internal_links` / inline `<a>` render in body, not nav.
5. Reserved/duplicate slug in the map → seed rejects with a clear error.
6. `audit_tenant_rls()` unaffected; no migration in the diff.

## Status
**FINAL — Option A, ready to send.** Next: 3c publish/edit panel (rows list + `setPageStatus`/`updatePageContent`) + the per-page "AI-write" on-demand action.
