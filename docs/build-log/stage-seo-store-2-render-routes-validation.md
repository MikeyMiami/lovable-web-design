# Stage SEO-STORE-2 — content-store render routes (marketing template) — validation

> Point-in-time validation record, 2026-07-02. **Frontend-only in the STYLE TEMPLATE (marketing Remix); no backend/schema change.** Validated **operator-side** — the template repo has no local clone, so this is live-behavior verification (env-wired to the real backend), not a code drift-check. Reads the SEO-STORE-1 anon RPCs verified on `cloud-spark-setup` `origin/main` @ `646b4d0`. Build spec: `docs/phase-seo-store-2-build-spec.md`.

## What shipped
The marketing template's dynamic render routes reading `content_pages` via the anon RPCs (`get_client_page` / `get_client_pages`) + `get_client_public`, applying `/seo-build` §1/§3/§5:
- **Routes** — `/` (home + GBP signals), `/services` (generated index), `/services/$slug` (category **or** service row), `/service-area/$slug` (geo row), `/$slug` (supporting only, lowest precedence), `/locations` (generated geo index), `/sitemap.xml` (generated), `/robots.txt` (static).
- **Data-driven** — pages live in `content_pages`, not the filesystem; the editor cannot enumerate slugs (expected). Routes resolve rows at request time.
- **Env-wired to the real backend** — `VITE_SUPABASE_URL` + anon key + `VITE_CLIENT_SLUG=test-landscaping`.

## Validation (PASS — operator-side)
Seeded 5 published rows + 1 draft for `test-landscaping` (seed SQL in the build spec), then verified live:
- **`get_client_pages` returned the 5 published rows; the hidden draft was excluded.** ✅
- **All routes render seeded content** — `/`, `/services`, `/services/$slug` (category + service), `/service-area/$slug` (geo), `/$slug` (supporting), `/locations`, `/sitemap.xml`, `/robots.txt`. ✅
- **Draft 404s** — the `draft-test` row does not render on any route. ✅
- **Dynamic routes are data-driven** — editor can't enumerate slugs since pages live in `content_pages` (expected, not a defect). ✅
- Test rows cleaned up after validation.

## Real bug caught + fixed (during validation)
**RPC param-name mismatch → silent 404 → demo-fixture fallback.** The template's RPC calls used **`p_client_slug` / `p_page_slug`**, but the backend functions take **`_slug` / `_page_slug`**. PostgREST resolves RPCs by named args, so the mismatched names **404'd silently**, and the template fell back to its built-in demo fixture (masking the failure — it *looked* like it worked). Lovable corrected:
1. **Param names** → `_slug` / `_page_slug` (match the backend).
2. **Row-shape mapping** → the RPC returns a `content_pages` row whose page identifier column is **`slug`**; the template maps it to its internal **`page_slug`** (`slug` → `page_slug`).
3. **Added error logging** on the RPC calls so a future failure surfaces instead of silently falling back to the fixture.
Re-verified live after the fix (the 5-rows / draft-hidden / all-routes checks above).

## Gaps flagged for follow-up (NOT blockers)
1. **Home = 6/8 GBP-consistency signals.** The **Google Maps embed** + **reviews widget** were not wired — not present in the template's current client contract (the `get_client_public` payload the template consumes). The other 6 (title = category+city, H1 = category+city, NAP char-for-char, secondary-category H2s + editorial links, LocalBusiness JSON-LD, address/phone) render. **Follow-up:** wire Maps embed (from `clients.address`) + reviews widget (from `clients.review_link` / GBP) into the template's home — a template pass, closeable alongside SEO-STORE-3 or a dedicated template touch-up. `/seo-build` §1 still requires all 8; this is a known template deviation to close, not a spec change.
2. **RPC param-name convention should be captured** so future templates get it right the first time — see the skill mirror below.

## Skill brought to parity (verbatim mirror handed)
- `seo-build` §4 — the exact anon-RPC contract: function signatures + param names (`_slug` / `_page_slug`) + the returned-row page identifier is `slug` (map to `page_slug` template-side) + surface RPC errors (don't silently fall back to a fixture).

## Drift note
Operator-side validation only (no template clone to diff). The backend was untouched — no migration, no RLS change; `audit_tenant_rls()` remains 0 from SEO-STORE-1. Baseline stays `golden-master-v1.7` (this was a frontend/template pass).

## Next
**SEO-STORE-3** — the `seedCoreThirty` first-pass Core-30 writer (service-role) + the **admin SEO panel** (categories / services-by-category / geo input that feeds it). Read-only scope: `docs/phase-seo-store-3-scope.md`.
