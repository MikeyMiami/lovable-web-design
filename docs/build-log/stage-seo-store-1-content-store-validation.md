# Stage SEO-STORE-1 — content_pages content store — validation

> Point-in-time validation record, 2026-07-02. **ONE additive migration on `golden-master-v1.7`; no existing table/column/fn touched.** Verified against `cloud-spark-setup` `origin/main` @ `646b4d0`. Build spec: `docs/phase-seo-store-1-build-spec.md` (+ scope `docs/phase-seo-content-store-scope.md`).

## What shipped
The CMS-backed **`content_pages`** store (migration `20260702203549`) — the endpoint behind `/seo-build` §4:
- **Table** — `id`, `client_id` (FK→`clients` ON DELETE CASCADE), `slug`, `type` (home|category|service|supporting|geo), `title`, `meta_description`, `h1`, `body`, `schema_jsonld` (jsonb), `target_keyword`, `internal_links` (jsonb), `external_link`, `og_image`, `status` (draft|published, default **draft**), `published_at`, `created_at`, `updated_at`. **`unique(client_id, slug)`** + indexes `(client_id,status)` / `(client_id,type)`.
- **RLS** — enabled; ONE **authenticated tenant-read policy** `content_pages_tenant_read` (`is_admin OR client_id IN user_client_ids`). Grants: `service_role` all; `authenticated` select; **anon revoked** (no table access).
- **Anon read** — 2 SECURITY DEFINER RPCs: `get_client_page(_slug, _page_slug)` + `get_client_pages(_slug)` — full rows (no PII), filtered `status='published'` + active/non-deleted client; granted to anon. **No anon table policy** (would fail the tenant audit — same posture as `get_client_public`).
- **Writes = service-role only** (no write policy).

## Validation (PASS)
- **`audit_tenant_rls()` → 0 rows** — the load-bearing check; `content_pages` passes the tenant audit. ✅
- **RPCs** on `test-landscaping`: `get_client_pages` returned published-only; `get_client_page` → published = 1 row, draft = 0 rows (draft correctly hidden from anon). ✅
- **Drift:** exactly one additive migration (table + 3 indexes + 1 tenant-read policy + 2 anon RPCs); **no existing table/column/fn modified**; writes service-role only; anon reads only via the RPCs. Test rows cleaned (a 2nd migration `20260702203923` = the `delete … where slug in ('test-published','test-draft')` cleanup, harmless). Linter warnings pre-existing/project-wide, not from this migration.

## Schema flag
**Additive-no-retag** (like `onboarding_tokens`) — a genuine schema add (a real tenant table) but app-layer-on-v1.7 additive; baseline stays `golden-master-v1.7`. This is the **second and last** schema add of the SEO arc.

## Skill brought to parity (verbatim mirror handed)
- `scratch-foundation` §11 — the `content_pages` store (BUILT) + the `get_client_page`/`get_client_pages` RPCs + the tenant-RLS/anon-RPC posture.

## Next
**SEO-STORE-2** — the marketing-template dynamic render routes (`/`, `/services`, `/services/$slug`, `/service-area/$slug`, `/$slug`, Locations index, sitemap) reading these RPCs + applying `/seo-build` §1/§3. Then **SEO-STORE-3** (the `seedCoreThirty` first-pass writer + the admin SEO panel).
