---
name: seo-build
description: Use when structuring or building a client's marketing site for local-search ranking — the SEO STRUCTURE + TECHNICAL standard every page and every style template must follow. Covers the entity/GBP-mirror model, the Core 30 site structure, on-page/technical SEO (titles, meta, one-H1 hierarchy, schema JSON-LD, semantic HTML, image alt, canonical, OG, sitemap/robots), the content-store + dynamic render-route contract (the CMS-backed endpoint for ongoing pages), and Core Web Vitals. Local-business SEO IS Google Business Profile ranking — the site exists to make the GBP rank. Runs at template-build (Phase A) + per-client build. NOT the content writing/quality (seo-content) and NOT off-site links/GBP edits/rank-tracking (agency ops). Pairs with website-structure / template-builder / new-client-site / launch-check. Full spec: docs/seo-system-analysis-and-skill-plan.md.
---

# SEO Build — local-ranking site structure & technical standard

The SEO **container**: how every client site (and every style template) must be STRUCTURED and technically built so the client ranks in local search. Content *writing* quality lives in `/seo-content`; off-site work (links, GBP edits, rank-tracking) is agency ops. This skill is niche-agnostic — it pulls from the client's captured data and applies the same standard to any business type.

## The model [LOCKED — read first]
- **Local SEO = Google Business Profile (GBP) ranking.** When someone searches "plumber near me" / "plumber Houston," Google shows a 3-pack map of GBPs above the organic results; **60–70% of clicks go to the top 3.** Position 4 = invisible. **Every page on the site exists for ONE reason: to make the GBP rank higher in the map.** We are NOT ranking blog posts or chasing out-of-town traffic.
- **Three factors: proximity · relevance · authority.** Proximity (searcher distance) can't be controlled. **Relevance** (site structure + content) and **authority** (links) are controllable. This skill builds the **relevance/structure** half on the site; authority (links) is off-site (agency ops); content quality is `/seo-content`.
- **Entity-based matching [LOCKED].** Google matches ENTITIES, not keywords: the business entity ↔ each service entity ↔ each geography entity. **The tighter the GBP, website, services, and geography MATCH, the higher the rank.** The same signals drive AI answerers (ChatGPT, Claude, Perplexity, Google AI Overviews) — build it right for Google and you're built right for all of them.
- **The site MIRRORS the GBP.** The website is an exact mirror of the GBP's categories + services. If the GBP has more services than the site has pages, Google sees a mismatch and won't rank it competitively.

---

## 1. GBP ↔ website consistency — the homepage (the "GBP landing page") [LOCKED — 8 signals]
The URL in the GBP "website" field (for a single-location business, the homepage) must PROVE the site and GBP are the same business. Every homepage MUST have all eight:
1. **Title tag** = **primary category + city + brand** — e.g. `Houston Plumber — Same-Day Service | {business_name}`. (Not "Home" or just the business name.)
2. **H1** = **primary category + city** (matches the title's intent).
3. **Google Maps embed** of the GBP location on the page.
4. **Secondary categories + core service** mentioned on the page, ideally in **H2 subheadings**.
5. **Review widget** displaying the client's Google reviews.
6. **Address matches the GBP character-for-character** (`clients.address`).
7. **Phone matches the GBP character-for-character** (the public number = `clients.twilio_number`; see §6 note).
8. **LocalBusiness schema (JSON-LD)** on the page (see §3).
> The template renders these from client data; the agency confirms the GBP uses the same primary category + NAP so they match exactly.

---

## 2. The Core 30 structure [LOCKED — supersedes the old page model]
Mirror the GBP: **≈30 pages = 1 homepage + 3–4 category pages + 25–30 service pages** — one page per GBP **category** and per GBP **service**. This is the topical-relevance foundation ("30 pages all proving you do what you say"). It **replaces** the previous generic model (home + a services index + re-targeted service-area landers).

**Internal linking mirrors the GBP hierarchy via EDITORIAL in-content links [LOCKED]:**
- **Homepage** → for each secondary category, an **H2 + 50–100 words** (what it is, why customers need it, why you're good) → an **editorial link in that paragraph** to the **category page**. (3–4 out.)
- **Category page** → lists its services, each an **H2 + 50–100 words** → **editorial link** to the **service page**. (5–10 out.)
- **Service page** → detailed, specific content for that one service (why needed, what's included, timeline, what to expect) — **not generic advice**.
- **CRITICAL:** nav/footer links pass ~**no** authority (Google knows they're site chrome). **Only editorial in-content links pass real authority.** The template must place these contextual links inside body copy, not just in menus.

**Per-page-type target-keyword formula [LOCKED]** (goes in title tag + H1):
| Page type | Target keyword | Example |
|---|---|---|
| Home | primary category + city | Houston Plumber |
| Category | category + city | Drainage Service Houston |
| Service | service + city | Water Heater Replacement Houston |
| Geo/neighborhood | service + landmark/neighborhood + city | Emergency Plumber Downtown Houston |

**Geographic/neighborhood pages [LOCKED — genuinely local, not city-swap].** These target rank-map positions 4–6 and use **landmarks/neighborhoods that exist on Google Maps / the Places API** (parks, golf clubs, intersections, shopping centers, schools, neighborhoods). They must be **actually local** (local conditions, older homes vs new construction, driving routes, nearby businesses) — NEVER "we serve {area}" repeated. *(Which geos to build, and the writing, is `/seo-content` + the content tool + rank-map data; this skill defines their route + structure + schema.)*

---

## 3. On-page / technical standard [LOCKED — every page]
- **Title tag** — the target-keyword formula (§2) + brand; unique per page; ~50–60 chars.
- **Meta description** — unique, benefit + city + CTA; derived from `about_us`/`differentiators` + the page's service/area.
- **One H1 per page** = the target keyword; logical **H2–H6** hierarchy (no skipped levels; no multiple H1s).
- **Semantic HTML / landmarks** — `<header><nav><main><article><section><footer>`; one `<main>`; headings convey structure.
- **Schema.org JSON-LD** [LOCKED — per page type]:
  - `LocalBusiness` (the specific subtype, e.g. `Plumber`, when it maps to the niche) on **home + contact** — `name, image (logo), url, telephone (public number), address (PostalAddress), geo (lat/lng), openingHoursSpecification (from clients.hours), areaServed, sameAs (social_links + GBP), priceRange` if known.
  - `Service` on **service + category** pages — `name, serviceType, provider (→ the LocalBusiness), areaServed`.
  - `Organization` site-wide; `BreadcrumbList` on inner pages; `FAQPage` wherever an FAQ block renders.
- **Image alt text** — templated from photo category + business + service/area context (e.g. "{business_name} water heater replacement in {city}"); never empty, never keyword-stuffed.
- **Image dimensions** — every `<img>` has explicit `width`/`height` (prevents CLS).
- **Canonical URL** on every page (self-canonical; avoid duplicate-content between home and area pages).
- **Meta robots** — index/follow for money pages; the compliance pages (terms/privacy/sms-program) may be `noindex` per `/website-structure`.
- **Open Graph + Twitter Card** — title/description/image (logo or a page hero) per page.
- **sitemap.xml** (generated from the content store — every published page) + **robots.txt** (allow crawl; reference the sitemap).

---

## 4. Content store + dynamic render routes [LOCKED — the CMS-backed endpoint]
Pages are **DATA**, not hand-built frontend code. This is what makes ongoing article publishing possible without editing the Lovable site per page.
- **`content_pages` store** (on the shared backend; **additive migration** — its own tagged pass): `client_id`, `slug`, `type` (`home`|`category`|`service`|`supporting`|`geo`), `title`, `meta_description`, `h1`, `body` (markdown/html), `schema_jsonld`, `target_keyword`, `internal_links` (jsonb), `external_link`, `og_image`, `status` (`draft`|`published`), `published_at`. **Anon-readable** (the marketing site renders it — same posture as `get_client_public`); **tenant-scoped by `client_id`** (is_admin/tenant read + anon public-read policy; keep the `audit_tenant_rls()` gate satisfied since it has `client_id`).
- **Dynamic render routes** the marketing template builds ONCE: `/` (home), `/services` (index), `/services/$slug` (service + category), `/service-area/$slug` (geo/neighborhood), `/$slug` (supporting), a **Locations index** (links to all geo pages), and a **sitemap** generated from the store. Each route renders a `content_pages` row and applies **§1/§2/§3** (schema, meta, semantic HTML, editorial internal links, breadcrumbs).
- **Write vs render [LOCKED]:** the per-client BUILD writes the first-pass Core-30 rows (hybrid O2); the future **content-automation tool** writes ongoing supporting/geo rows. **Both only WRITE rows — neither edits the frontend.** The template is a generic renderer. Publishing a page = inserting/flipping a row to `published`.

---

## 5. Performance / Core Web Vitals [LOCKED]
Ranking factors + they gate whether searchers stay (bounce = a negative signal).
- **Mobile-FIRST** — build for the phone, then verify desktop (most local searches are mobile). Phone number tappable at the top; fast tap targets.
- **LCP** fast (optimized hero, no render-blocking); **CLS ~0** (dimensioned images/media, reserved space — see §3); **INP** responsive.
- **Images** — right-sized, modern format (WebP/AVIF), **lazy-load below-the-fold**, eager-load the LCP hero.
- HTTPS padlock; no layout jank; no 8-second loads.

---

## 6. Data sources — pulls from captured client data [niche-agnostic]
| SEO field | Source |
|---|---|
| Titles / meta / H1 / local keywords | `business_name`/`company_name`, `template_vars.services` (+ per-service), `service_area[]`, `template_vars.segment`, `about_us`/`differentiators` |
| LocalBusiness/Service schema | `business_name`, `clients.address`, **public phone = `clients.twilio_number`**, `clients.hours`, `service_area[]`, GBP = `template_vars.google_business_profile_link`, `clients.logo_url`, `sameAs` = `clients.social_links` (IG/FB/LinkedIn) + GBP |
| Image alt / OG image | `template_vars.site_assets` (+ context), `clients.logo_url` |
| Canonical / sitemap / domain | `clients.allowed_origins` / `template_vars.company_website_link`; the content store |
| Reviews widget | `clients.review_link` + GBP |
| Categories + services-by-category (the Core-30 map) + geo coords | **NOT yet captured** — AI-derived at build + agency-confirmed in the admin SEO panel; geo = auto-geocode `clients.address` |
> **Public NAP phone note:** the site's public phone = the provisioned `clients.twilio_number` (assigned at A2P/Phase D). Until provisioned, the NAP/schema phone is pending — finalize at launch so it matches the GBP character-for-character.

---

## 7. Per-page-type checklist
- **Home** — 8 consistency signals (§1); LocalBusiness JSON-LD (full NAP + hours + geo + areaServed + sameAs + logo); title/H1 = primary category + city; secondary-category H2s + editorial links to category pages; reviews widget; Maps embed; optimized hero.
- **Category page** — title/H1 = category + city; Service schema; service H2s + editorial links to service pages; canonical.
- **Service page** — title/H1 = service + city; Service schema (provider → LocalBusiness); specific local content; FAQ block (FAQPage schema) where relevant; canonical.
- **Geo/neighborhood page** — title/H1 = service + landmark + city; genuinely-local content; LocalBusiness/Service + `areaServed`; internal links from Locations index + to the relevant service page; canonical (no dup with home).
- **About** — Organization/LocalBusiness schema; `about_us`/`differentiators`; team from `site_assets.staff` (alt = name + position).
- **Contact** — LocalBusiness schema (NAP + hours + map); NAP prominent + machine-readable.
- **Gallery** — alt'd, optimized `site_assets` images.
- **Compliance (terms/privacy/sms-program)** — canonical + `meta robots` per `/website-structure` (fixed labels).

---

## Out of scope — handoffs [LOCKED]
- **Content WRITING quality** (local specificity, the 8-pass pipeline, FAQ research, the topical-vs-geographic decision + monthly loop) → **`/seo-content`**.
- **Off-site authority** (chamber/sponsorship/directory links, "not-AI-slop" links, "best of" round-ups) → agency ops / a future link tool. **Not a site build.**
- **GBP itself** (choosing categories/services, the 750-char description, 20+ photos, attributes, weekly posts, review responses, citations) → agency/Lead-Snap. We can *generate* these as agency assets (future tool); the SITE must MATCH them (§1).
- **Rank-map / top-3% diagnostics** (Lead Snap) → the content tool's "what to build next" brain; an admin CSV input later.

## How this connects [LOCKED]
- **`/template-builder`** bakes §1–§5 into every STYLE template **once** — the consistency homepage, the dynamic content-render routes (§4), schema components, sitemap/robots, performance conventions — so every client remix inherits SEO-correctness. (Author the styles SEO-correct from the start.)
- **`/website-structure`** generates the per-client page set as the **Core 30** (§2), reconciled to this skill (the old service-area-lander model is superseded; area pages are genuinely-local geo pages).
- **`/new-client-site`** applies this at the design/build step; **`/launch-check`** gates on an SEO subsection (titles/meta present, one H1/page, valid LocalBusiness JSON-LD, sitemap/robots, NAP consistent char-for-char, Core-30 present, CWV within target).
- Inputs: onboarding/admin data (§6) + the future **admin SEO panel** (categories / services-by-category / geo).

## FINITE GENERATION [LOCKED — mirror /website-structure]
Page identities/routes, schema types, the target-keyword formulas, and the content-store contract are FIXED by this skill. A template build MUST NOT improvise them; if a needed decision isn't covered, **FLAG it for a skill update rather than guessing.**
