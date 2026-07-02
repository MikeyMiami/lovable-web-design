# SEO-STORE-2 — content-store render routes (marketing template) — build spec [HELD, ready to send]

> **Build in the STYLE TEMPLATE (marketing Remix), frontend-only, anon reads. NO backend/schema change.** The dynamic routes that render `content_pages` (via the SEO-STORE-1 anon RPCs) + apply the `/seo-build` on-page standard; reconciles the template to the Core 30. **No local clone of the template → validation is operator-side + build-report review.** RPC contract verified on `cloud-spark-setup` `origin/main` @ `646b4d0`. **DEFERRED — build next session (wants fresh focus; it rewrites the one proven template).**

## Read-only-verify findings
- **Location:** the marketing style-template (separate Lovable Remix); frontend-only; reads the shared backend as **anon** via `get_client_public` + the new `get_client_page`/`get_client_pages`. No service-role on the site.
- **`/$slug` precedence:** TanStack Start static routes beat dynamic `$param`; `$slug` is single-segment (not a splat) → `/about`,`/services`,`/gallery`,`/contact`,`/get-your-discount`,`/review`,`/thank-you`,`/terms`,`/privacy`,`/sms-program`,`/locations` (static) win. `/$slug` catches only unmatched root slugs → supporting pages. Safe: `/$slug` renders **only** `type='supporting'` rows (404 otherwise) + the write-time collision guard (SEO-STORE-3) rejects reserved slugs. **`/guides/$slug` = documented fallback** if the template's routing proves greedy in testing.
- **Reserved root slugs** a supporting page must not equal: `about, services, service-area, gallery, contact, get-your-discount, review, thank-you, terms, privacy, sms-program, locations, sitemap.xml, robots.txt`.

---

# PROMPT SEO-STORE-2 — paste into Lovable (the style-template project)

> **Build in the STYLE TEMPLATE (marketing Remix), frontend-only, anon reads. NO backend/schema change.** Add the dynamic routes that render `content_pages` from the anon RPCs and apply the `/seo-build` on-page standard. Reconciles the template to the Core 30 (`/website-structure`). Report the routes + files changed.

## Data access (anon; the site is frontend-only)
The site knows its client via **`VITE_CLIENT_SLUG`**. Read via the anon Supabase client:
- **`get_client_public(VITE_CLIENT_SLUG)`** — client identity/NAP/branding/hours/reviews (existing).
- **`get_client_pages(VITE_CLIENT_SLUG)`** — all published pages (nav / Locations / sitemap).
- **`get_client_page(VITE_CLIENT_SLUG, pageSlug)`** — one published page.
Published pages of an active client only; **drafts never render**. No service-role on the marketing site.

## Routes to build (each renders a `content_pages` row into the template's page-type layout + applies `/seo-build` §1/§3)
| Route | Data | Renders |
|---|---|---|
| `/` | `get_client_page(slug,'home')` + `get_client_public` | GBP landing page. Content (h1/body/schema/meta) from the `home` row; the **8 GBP-consistency signals** from client data (`/seo-build` §1): title/H1 = category+city, Google Maps embed, reviews widget, NAP char-for-char, secondary-category H2s + editorial links, LocalBusiness JSON-LD. |
| `/services` | `get_client_pages` | **Generated** index listing category → service pages. |
| `/services/$slug` | `get_client_page(slug,$slug)` | The `category` OR `service` row (both live here). Title/H1 = the row's; Service schema; editorial internal links from `internal_links`. 404 if no published row. |
| `/service-area/$slug` | `get_client_page(slug,$slug)` | The `geo` row (genuinely-local). LocalBusiness/Service + `areaServed`. 404 if none. |
| `/$slug` | `get_client_page(slug,$slug)` | A `type='supporting'` row ONLY. **Lowest precedence** (static routes win). 404 if not a published supporting page. |
| `/locations` | `get_client_pages` (filter `geo`) | **Generated** index of all geo pages. |
| `/sitemap.xml` | `get_client_pages` | **Generated** XML of every published page's URL. |
| `/robots.txt` | static | Allow crawl + reference `/sitemap.xml`. |

## Per-page `/seo-build` application (every rendered page)
- **`<head>`:** `<title>` = row `title`; `<meta name="description">` = `meta_description`; **canonical** (self); **Open Graph + Twitter** (title/description/`og_image`); **meta robots** (index/follow money pages; compliance pages per `/website-structure`).
- **Body:** exactly **one `<h1>`** = row `h1`; render `body` (markdown/html) into the page-type layout with **semantic landmarks** (`<main>`,`<article>`,`<section>`); **breadcrumbs** (BreadcrumbList schema on inner pages); place the row's **`internal_links`** as **editorial in-content links** (not just nav/footer).
- **Schema:** inject the row's **`schema_jsonld`** (LocalBusiness/Service/FAQPage per type). If a row has no `schema_jsonld`, the template composes a baseline from client data (`/seo-build` §3).
- **Images:** `og_image` + body images get explicit `width`/`height`; lazy-load below-fold (`/seo-build` §5).

## Reconcile to the Core 30 [LOCKED — `/website-structure` + `/seo-build`]
- Page set becomes the Core 30: home + category + service (from rows) + geo + supporting. **Retire** the old generic service-area-lander; area pages are the genuinely-local `geo` rows.
- **Editorial in-content linking** (home→category→service) — nav/footer links don't count.
- `/$slug` renders **only** supporting rows; a colliding slug is prevented at write time (SEO-STORE-3) — the route just 404s on a miss.

## Drift check (report back)
1. Routes added/changed: `/`, `/services`, `/services/$slug`, `/service-area/$slug`, `/$slug`, `/locations`, `/sitemap.xml`, `/robots.txt` — all reading the anon RPCs + `get_client_public`.
2. **Frontend-only** — anon reads, no service-role, no schema/backend change; drafts never render.
3. `/$slug` sits below all static routes; renders only `type='supporting'`.
4. Each page applies `/seo-build` §1/§3 (head/title/meta/canonical/OG/one-H1/schema/breadcrumbs/editorial links) + §5 image handling.

## VALIDATION (operator-side — no template clone to diff)
Seed rows (SQL below), then on the live/preview site:
1. Each route renders its row; the **draft** row does NOT render (404/absent).
2. **Home** shows the 8 signals — title/H1 = category+city, Maps embed, reviews widget, address/phone matching the GBP.
3. Paste a page URL into **Google Rich Results Test** → LocalBusiness (home) / Service (service) detected, no errors.
4. **Unique** `<title>` + meta per page (Detailed SEO Extension); exactly one `<h1>`.
5. **In-content** editorial links present (once `internal_links` are populated), not just nav.
6. `/sitemap.xml` lists the published pages; `/robots.txt` loads + references the sitemap.
7. `/$slug`: a supporting slug renders; a reserved slug (e.g. `about`) still hits the static About page.
8. **PageSpeed Insights** (mobile) reasonable; no CLS.

## Seed SQL (run in the Supabase SQL editor — gives you test rows immediately)
```sql
-- SEED — PUBLISHED content_pages for the demo client + 1 DRAFT (to prove drafts hide).
insert into public.content_pages (client_id, slug, type, title, meta_description, h1, body, target_keyword, status)
select c.id, x.slug, x.type, x.title, x.meta, x.h1, x.body, x.kw, x.status
from public.clients c
cross join (values
  ('home',        'home',       'Landscaping in Plano | Demo Landscaping',       'Full-service landscaping in Plano. Free estimates.',   'Landscaping in Plano',               '<p>Demo Landscaping provides full-service landscaping across Plano.</p>',   'landscaping plano',         'published'),
  ('lawn-care',   'category',   'Lawn Care in Plano | Demo Landscaping',         'Lawn care services in Plano.',                          'Lawn Care in Plano',                 '<p>Our lawn care keeps Plano yards healthy year-round.</p>',                'lawn care plano',           'published'),
  ('lawn-mowing', 'service',    'Lawn Mowing in Plano | Demo Landscaping',       'Reliable weekly lawn mowing in Plano.',                 'Lawn Mowing in Plano',               '<p>Weekly and biweekly mowing for Plano homes.</p>',                        'lawn mowing plano',         'published'),
  ('downtown',    'geo',        'Landscaping Downtown Plano | Demo Landscaping', 'Landscaping near downtown Plano.',                      'Landscaping in Downtown Plano',      '<p>Serving the older homes and tree-lined streets of downtown Plano.</p>',  'landscaping downtown plano','published'),
  ('mulch-cost',  'supporting', 'How Much Does Mulch Cost in Plano?',            'Mulch pricing in Plano.',                               'How Much Does Mulch Cost in Plano?', '<p>Mulch in Plano typically runs $35-$50 per cubic yard installed.</p>',    'mulch cost plano',          'published'),
  ('draft-test',  'service',    'Draft Test',                                    'should not render',                                     'Draft Test',                         '<p>This is a draft and must not appear on the site.</p>',                   'draft test',                'draft')
) as x(slug, type, title, meta, h1, body, kw, status)
where c.slug = 'test-landscaping'      -- <-- your demo/style-template client slug (must be ACTIVE)
  and c.status = 'active' and c.deleted_at is null;
```
Cleanup after testing:
```sql
delete from public.content_pages
where client_id = (select id from public.clients where slug = 'test-landscaping')
  and slug in ('home','lawn-care','lawn-mowing','downtown','mulch-cost','draft-test');
```
*(`schema_jsonld` + `internal_links` left NULL → exercises the template's "compose baseline schema from client data" path; the real `internal_links` + editorial-link rendering are validated once SEO-STORE-3's seeder produces them.)*

---

## Safety approach — reworking the ONE proven template (repo I can't drift-check) [RECOMMENDED]
This reconciles the existing Professional Modern template — the one working style. Because it's the master AND I can't drift-check its code, protect it:
1. **Anchor the rollback.** Confirm the current Professional Modern is pushed to its GitHub repo at a clean commit and **tag it `pro-modern-pre-seo`** (Lovable GitHub-connect = the backup/rollback per `docs/pathway-to-completion.md`). That tag is the known-good to restore to.
2. **Rework a COPY, then promote (recommended — mirrors the golden-master discipline).** **Remix/duplicate** the current template into a new Lovable project ("Pro Modern — SEO"), do the SEO-STORE-2 reconcile THERE, operator-validate (the checklist above), and only then **promote** it to be the new master. The proven template stays frozen until the reworked one is green — exactly how the backend golden-master is treated.
3. **Slice the reconcile (no drift-check → catch regressions small).** Don't do it as one big rewrite. Two operator-validated steps: **(2a)** add the content-store render routes + head/schema/sitemap reading the RPCs (new plumbing, existing design) → verify each route renders + schema/head/sitemap; **(2b)** reconcile the page set to the Core 30 (add category pages, retire the area-lander, editorial linking) → re-verify. Validate between.
4. **Reassurance — it's a data/route REWIRE, not a visual redesign.** The visual style is preserved; SEO-STORE-2 changes the content SOURCE (→ `content_pages`), adds category/supporting/geo routes, and adds head/schema. Risk is to routing/data-binding, not the look. Still snapshot first (steps 1–2).

**Rec:** option 2 (rework a copy → promote) + the `pro-modern-pre-seo` tag + slice per step 3. If you'd rather rework in place, the tag + Lovable version history is the revert path — but keep the slicing.

## Status
**HELD — ready to send next session.** Reconciles the existing Professional Modern template to the content-store + Core-30 model (sizable). Snapshot first (safety above).
