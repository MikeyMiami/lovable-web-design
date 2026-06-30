# BACKLOG SCOPE — Comprehensive SEO build skill(s) for the marketing-site template build

> **Status: BACKLOG — scoped 2026-06-30, NOT built.** A Phase-A (template-build) concern: encode the SEO standards EVERY page / section / header in the Lovable-generated client sites must follow, so each client's site is set up to rank in **local** search. Develop alongside/before Phase A style-building (styles should be SEO-correct from the start). This doc is the scope to develop from later.

## 1. Recommended skill structure
**Recommendation: ONE comprehensive `seo-build` skill (v1), organized by the three pillars + a per-page checklist + a data-mapping table — with `seo-local` ready to split out if the local section grows.**

Why one (not three) for v1:
- The template build wants **one "apply SEO" reference per page**, not three docs to cross-check mid-build. The pillars are applied **together** on every page (local SEO uses on-page titles/schema; performance gates ranking).
- The pillars are **interdependent** (LocalBusiness schema = on-page JSON-LD + local data; per-area pages = on-page + local + performance).
- It mirrors how the other build skills work (one authoritative standard the template build follows).

Internal structure of `seo-build`:
- **§A On-page / technical** · **§B Local (the priority)** · **§C Performance / Core Web Vitals** · **§D Per-page-type checklist** · **§E Data-mapping table (SEO field → captured onboarding data)** · **§F Gaps / future onboarding fields**.

**Split trigger:** if **§B Local** outgrows the doc (it's the priority + the deepest — per-area pages, NAP, LocalBusiness schema, GBP alignment, local keyword matrices), promote it to a standalone **`seo-local`** skill that `seo-build` references. Keep on-page + performance in `seo-build`. (Three fully-separate skills = over-split for v1; revisit if each pillar becomes large.)

## 2. Where it plugs into the existing template-build flow
**New standalone `seo-build` skill, REFERENCED by (not duplicated into) the design/template layer:**
- **`website-structure`** — the per-client design layer that generates the page set. Add a short "SEO standard" pointer: every generated page applies `seo-build`. The page registry (home/about/services/service/service-area/gallery/contact/compliance) + the data-driven per-area pages are exactly where the per-page-type checklist lands. (The service-area pages already exist there — `seo-build` makes them locally-optimized, not just re-targeted landers.)
- **`template-builder`** — bakes the SEO scaffolding (schema components, meta/OG head tags, semantic landmarks, sitemap/robots, image-optimization conventions) into each STYLE template ONCE, so every client remix inherits it. This is the "SEO-correct from the start" hook.
- **`new-client-site`** — the orchestrator's design step (step 4) + the launch-check gate (step 5) reference `seo-build` (generate SEO-correct pages; verify before go-live).
- **`launch-check`** — add an SEO subsection to the per-client go-live gate (titles/meta present, one H1/page, LocalBusiness JSON-LD valid, sitemap/robots, NAP consistent, area pages present, CWV within target).

Net: **woven in by reference** — `seo-build` is the single source; `website-structure`/`template-builder`/`new-client-site`/`launch-check` point to it.

## 3. Data mapping — SEO requirement → data we ALREADY capture
| SEO requirement | Pulls from (already captured) |
|---|---|
| Page titles + meta descriptions | `clients.business_name` / `template_vars.company_name`; `template_vars.services` (+ per-service); `clients.service_area[]`; `template_vars.segment` (niche); `template_vars.about_us`/`differentiators` (description) |
| Header hierarchy (1×H1, H2–H6) | the `website-structure` page registry (fixed page identities) + per-page content |
| LocalBusiness JSON-LD | `business_name`, `clients.address`, **phone = `clients.twilio_number`** (the public number; single-source), `clients.hours` (structured), `clients.service_area[]`, GBP = `template_vars.google_business_profile_link`, `clients.logo_url` (image), `sameAs` = `clients.social_links` (IG/FB/LinkedIn) + GBP |
| Service JSON-LD | `template_vars.services` → per-service pages (+ AI-generated per-service descriptions) |
| Image alt text | `template_vars.site_assets` categories (work/gallery/about/services/staff) + `business_name` + `segment` + area context |
| Canonical / robots / OG / Twitter | site domain (`clients.allowed_origins` / `template_vars.company_website_link`); `clients.logo_url` or a hero from `site_assets`; `business_name`; `about_us` |
| Sitemap.xml + robots.txt | the generated page set (page registry + per-service/per-area counts) |
| Per-service-area local pages | **`clients.service_area[]`** (already drives the data-driven area pages — max 14) |
| NAP consistency | single-source `business_name` + `clients.address` + public phone (`clients.twilio_number`) — one data object, rendered identically everywhere (the single-source rule already enforces the number) |
| Local keyword targeting | `template_vars.segment` + `template_vars.services` × `clients.service_area[]` (the "[service] in [area]" matrix) |
| Image optimization / CWV | `template_vars.site_assets` (the uploaded photos) — sizing/format/`width`/`height`/lazy-load |
| GBP alignment | `template_vars.google_business_profile_link` (captured on the Social Links step) |

**Takeaway:** the vast majority of SEO inputs already exist from onboarding — titles/meta/schema/NAP/area-pages/alt/keywords all pull from real client data, not placeholders.

## 4. Per-page-type SEO checklist (what each page needs)
- **Home (`/`):** H1 = business + primary service + main area; title `[Business] — [Service] in [Area]`; meta from `about_us`/`differentiators`; **full LocalBusiness JSON-LD** (NAP + hours + areaServed + geo + sameAs + logo); OG/Twitter; optimized hero (dimensions set); services overview with internal links; canonical.
- **Service page (`/services/$slug`):** H1 = the service; title `[Service] in [Area/Region] | [Business]`; **Service JSON-LD** (+ provider = the LocalBusiness); service-specific copy + alt'd images; internal links to related areas; canonical.
- **Per-area local page (`/service-area/$area`):** H1 = `[Service] in [Area]`; title/meta targeting `[service] in [area]`; **LocalBusiness or Service + `areaServed`** schema; locally-worded content (not just `{area}` swap — local intent); NAP; links to services; canonical (avoid duplicate-content with home).
- **About (`/about`):** H1 about the business; **Organization/LocalBusiness** schema; `about_us`/`differentiators` content; team from `site_assets.staff` (alt = name+position); canonical.
- **Contact (`/contact`):** H1 contact; **LocalBusiness** schema (NAP + hours + map); NAP rendered prominently + machine-readable; canonical.
- **Gallery (`/gallery`):** alt'd, optimized `site_assets` images; canonical.
- **Compliance (terms/privacy/sms-program):** canonical + sensible `meta robots` (decide index vs noindex); fixed labels (already locked).

## 5. Gaps — data onboarding does NOT yet capture (future-field flags)
- **Geo coordinates (lat/lng)** for `LocalBusiness.geo` — not captured. Options: geocode `clients.address` at build time, or add an onboarding/admin field. **Flag.**
- **Public NAP phone timing** — the public phone for NAP = `clients.twilio_number`, which is **provisioned at A2P (Phase D)**, not at onboarding. So full NAP/LocalBusiness schema can't finalize until the number exists. (The onboarding "Personal Cell" is explicitly private/forwarding, NOT the public number.) **Flag — sequencing dependency, not a missing field.**
- **Per-service structured descriptions** — `template_vars.services` is one text field; per-service Service-schema descriptions are AI-generated from it. Acceptable, but note (a future "services as structured list" onboarding field would improve Service schema).
- **aggregateRating / review schema** — we capture the GBP/review link but not live rating numbers; review-rich-snippets need a ratings source (out of scope; future).
- **Tagline / explicit meta-description field** — `clients.tagline` exists but isn't an onboarding field; meta falls back to `about_us`. Minor (fine to derive).
- **Open Graph image** — use `logo_url` or a hero from `site_assets`; a dedicated OG image isn't captured (derive; fine).

*Most gaps are derivable or sequencing (geo, NAP-phone-at-launch); only geo is a candidate future onboarding/admin field.*

## 6. Develop-later checklist
When ready (alongside/before Phase A): author `seo-build` (§A–§F above), add the SEO pointer to `website-structure` + `template-builder` + `new-client-site`, add the SEO gate to `launch-check`, and decide the geo-coordinate source. Split `seo-local` out if §B grows.
