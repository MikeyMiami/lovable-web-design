# SEO System — expert-transcript analysis + skill/automation plan

> **Source:** 5 transcripts (`C:\Users\Pierc\Documents\SEO`) from one 7-figure local-SEO agency owner (ranking local businesses + Fortune 500 since 2016). Analyzed 2026-06-30. **This is the knowledge base + proposed plan for the `seo-build` skill and the future SEO content-automation tool.** Supersedes/expands `docs/seo-build-skill-backlog-scope.md`. **BACKLOG — not built; plan pending sign-off.**

---

## PART 1 — The expert's system (every material detail, preserved)

### 1.1 The core mental model
- **Local SEO ≠ regular SEO.** You are NOT ranking website URLs / blog posts — **every page exists to make the Google Business Profile (GBP) rank in the 3-pack map.** 60–70% of clicks go to the top-3 map positions; position 4 = page two = invisible.
- **Three ranking factors: Proximity · Relevance · Authority.** Proximity (searcher distance) can't be controlled. **Relevance (content/structure) and Authority (links) are the two you control** — max them to "overflow the glass" and rank regardless of proximity.
- **Entity-based search (Google's Transformer tech, ~2018).** Google matches ENTITIES, not keywords: business entity ↔ service entities ↔ location entities. Every GBP category/service and each geography is an entity. **The closer your GBP, website, services, and geography entities MATCH, the better you rank.** Same signals now drive ChatGPT / Claude / Perplexity / AI Overviews — fixing for Google fixes for all of them.
- **The "5-year-old" version (3 pillars):** (1) **Helpful** — give searchers exactly what they want (AC repair near me = someone to fix it today, not a blog about how AC works); (2) **Relevant/Match** — the site must literally say what you do + where ("plumber Houston" must appear; one clear neon sign, not 100 scattered flyer blog posts); (3) **Trusted** — votes (backlinks/mentions), especially local-authority ones.

### 1.2 GBP optimization (OFF the website — agency/tool task; the site must MATCH it)
The 3 most common GBP mistakes + fixes:
1. **Categories** — most pick 1; Google allows **up to 10**. Every category = another search you can appear for. **Target 2–4 minimum** (more in competitive markets), all relevant. Tools: GMB Everywhere (Chrome) + an AI prompt (give it the real category list so it doesn't hallucinate).
2. **Services** — most list 1–5; **list ≥20 (30–40+ in competitive markets)**. Services are a **free text box** — be creative. **Services must be categorized under the category they're most relevant to** (semantic match to the category = relevance signal).
3. **Empty boxes** — fill EVERY field (completion signal = active, legit business): **business description (use all 750 chars)**, attributes (check every applicable; check "no" if not — veteran/woman-owned, credit cards, free estimates, ADA, etc.), products, services, **≥20 photos** (exterior/interior/team/work-in-progress — phone photos auto-geotag), posts.
- **Ongoing GBP activity** (ranking factor): weekly posts (a prompt generates **52 posts = 1/week/year**, scheduled at once), weekly geotagged photo uploads, AI review responses, verified citations (**Apple Maps, Bing for Business, Facebook Business** — verification-required ones are what work now; old "fill 200 tiny-box directories" is dead). Tool used: **Lead Snap**.

### 1.3 The 8 GBP↔website consistency signals (the homepage / GBP landing page)
The GBP "website" URL (usually the homepage) MUST prove the site + GBP are the same business, or you won't rank competitively:
1. **Title tag** = primary category + city + brand (e.g. "Houston Plumber — Same-Day Service | BrandName"). *(60%+ of businesses have just "Home" or their name — easy to beat.)*
2. **H1** = primary category + city (matches).
3. **Google Maps embed** of the GBP location on the page.
4. **Secondary categories + core service** mentioned (ideally in subheadings/H2).
5. **Review widget** displaying Google reviews on the homepage.
6. **Address matches GBP character-for-character.**
7. **Phone matches GBP character-for-character.**
8. **LocalBusiness schema** (JSON-LD) on the homepage.

### 1.4 The "Core 30" website structure (THE local-ranking site architecture)
Mirror the GBP exactly: **~30 pages = 1 homepage + 3–4 category pages + 25–30 service pages** (one page per GBP category and per GBP service). Internal linking mirrors the GBP hierarchy:
- **Homepage** (GBP landing page, all 8 signals) → for each secondary category, an **H2 + 50–100 words** → an **EDITORIAL link** (in-content, not nav/footer) to that **category page**. (3–4 editorial links out.)
- **Category page** — target keyword = **category + city** ("Drainage Service Houston") in title + H1; lists its services, each an **H2 + 50–100 words** → **editorial link** to the **service page**. (5–10 editorial links out.)
- **Service page** — target keyword = **service + city** ("Water Heater Replacement Houston") in title + H1; detailed, specific content (why needed, what's included, how long, what to expect) — **not generic advice**.
- **CRITICAL: nav/footer links pass ~no authority** (Google knows they're structure). **Editorial in-content links pass real authority.** The Core 30 = proof of topical relevance ("30 pages all proving you actually do what you say").

### 1.5 Content quality standard (why AI content ranks or dies)
- Google doesn't care AI vs human — it cares **helpful + distinct + genuinely local + well-formatted.** Generic AI "slop" (walls of text, no images/formatting) won't get **indexed** (indexing generic AI content is getting harder).
- Must be **actually local**: not "we serve the Malden area" — talk about *the triple-deckers in Medford, old pipe infrastructure in Somerville, coastal weather off Revere Beach, older homes with cast-iron pipes vs new PEX, the driving routes techs take.* This is what makes Google + AI believe you're local even if you've never set foot there.
- Formatting: client photos (best) or AI images, callouts, tables, headers, bullets, short paragraphs, internal links. Evaluated on **latest mobile Chrome**.
- **The 8-pass AI writing pipeline** (per page type — service/category/location/supporting each get different prompts), how the agent writes human-passing content: (1) research synthesis → content brief (PAA + Reddit + competitor + local); (2) strategic outline (H2 map); (3) section-by-section drafting (separate API call per H2 = tonal variation); (4) **burstiness** (vary sentence/paragraph length); (5) **perplexity injection** (replace predictable AI words — "robust/leverage/streamline" — kill em-dashes); (6) **human bookends** (first 2 + last 2 sentences extra-conversational — weighted heaviest by Google + read first by users); (7) **conversion pass** (natural CTAs, phone numbers); (8) final QC vs brief/outline. In parallel: FAQ section, meta title/description/H1, schema, AI images (with prompts), external authority links, a rendered video → uploaded to YouTube → embedded (videos improve indexing/ranking/authority), publish to WordPress. **AI-detection score** tracked per article (aim low; ~39% avg acceptable, >65% needs another pass).

### 1.6 The diagnostic loop (what content to build next — NOT guessing)
- **Local rank map** (Lead Snap): GBP rank at **169 points** across the city. Green = top-3 (visible); yellow = 4–10 (invisible, close); red = not found.
- **"Top 3%"** metric = % of the map that's green. This single number drives strategy.
- **Topical-relevance threshold** = **25–50% of the top competitors' top-3%** in your market. (Competitive markets: leaders at 25–40%; easy markets: 90–99%.) Below threshold → **build topical content** (Google doesn't trust your expertise yet). At/above threshold → **build geographic content** (expand coverage). Getting this decision backwards wastes months (most agencies build location pages before proving topical authority → they do nothing).

### 1.7 Topical relevance = supporting content (when below threshold)
- **NOT generic blog posts / not "city name swap" pages.** Highly targeted **FAQ/supporting pages** answering specific questions the rank map shows you don't rank for.
- Sources: **Google "People Also Ask"** (search the keyword *without* city; click to expand → 20–30 Qs) + **Reddit** (a prompt crawls Reddit for real local questions). **Reword PAA questions** (don't copy verbatim — Google's wise to it now).
- Usage: add the Q to the relevant existing page → **brief answer (a couple dozen words)** → **editorial link** to a **new deep supporting page** (hundreds of words) that answers it comprehensively. Every supporting page also needs **1 external "not-AI-slop" link.** Keep building supporting pages + re-running the rank map monthly until you hit the top-3% threshold.

### 1.8 Geographic relevance = neighborhood/landmark pages (when at/above threshold)
- Look at the rank map for **positions 4/5/6** (close, not quite). Much easier to turn a 4→3 than a 19→3 (and a 19→4 gets you nothing — only top-3 matters).
- Target **neighborhoods / landmarks that Google recognizes on Google Maps / the Places API** (parks, golf clubs, intersections, shopping centers, schools, neighborhoods) — "if it's on Google Maps, it's relevant; not guesswork." Pick areas with real demographics/search volume (not the middle of a lake).
- Target keyword = **service + landmark + city** ("Plumber Ranchstone Houston") in title + H1. Content must be **genuinely about that area** (local conditions, driving routes, nearby businesses), not "we serve X" ×50. Each geo page needs **1 external link** + **internal link** from a **Locations page** and to the relevant service page.
- Keep re-running the rank map every couple weeks; target newly-appearing 4–6s; watch the green zone expand outward from the address.

### 1.9 Authority / links (off-site — agency/tool task)
- **Two link types per the Core 30:** (a) **"not-AI-slop" links** — ≥1 medium-quality external link per page (validates content is real; ~**$25–35/link**; a link service or manual outreach); for 30 core + 10–20 supporting + 10–20 geo pages that's 1 link each. (b) **Local-authority links** — the real ranking lever: **Chambers of Commerce** (~$200–300/yr each; join **all** within ~70 mi — clients have joined 10), **youth-sports/charity/event sponsorships** (a prompt finds local orgs wanting sponsors — e.g. a $250 TEDx .edu sponsorship moved avg rank 4 spots), **verified directories** (Apple Maps, Bing, Facebook, Yelp/Angi/BBB), **local-business partnerships** (realtors ↔ home services), **"best of [service] in [city]" round-up articles** (weighted heavily by AI now). **A local chamber link outweighs 50 random national links.**

### 1.10 Ranking speed (slowest→fastest) + when NOT just-more-content
- Slowest→fastest: traditional content SEO (6–12 mo, builds topical but not geographic → bad for local) → citations (1–3 mo, table stakes now, only verified ones) → local-authority links → **GBP optimization (2–6 wks — the recommended START)** → **hyper-local service/neighborhood pages (2–4 wks — fastest).**
- **When more content WON'T fix it:** a site with 500 indexed pages ranked 20th *standing in the lobby* = Google thinks the site is **spam**; you can't publish your way out — needs a **content audit** (Screaming Frog crawl → find thin/duplicate/harmful pages). Diagnosis, not production.

### 1.11 The automation reality (what the AI agent replaced)
- 9 production steps/article: (1) SEO expert sets target/keyword/intent/page; (2) content brief; (3) copywriter research+write; (4) manager review; (5) schema + images; (6) video generated; (7) developer publishes; (8) internal links placed+verified; (9) 1 outbound + 1 inbound external link. **The agent does steps 1–5 (setup/brief/research/writing/schema/images/publish/video) in one pass; humans keep QA/review + the external inbound link.** Cost/article fell **$600 → <$100**. ~1 page/dollar in API. Content often beats the old human writers (spends "hours" researching to be *informationally additive* over what's already ranking).

---

## PART 2 — Map to OUR project (what we already have, in/out of scope)

### 2.1 Data we ALREADY capture (onboarding/admin) → SEO inputs
| SEO input | Have it? | Source |
|---|---|---|
| Business name | ✅ | `clients.business_name` / `template_vars.company_name` |
| Public NAP phone | ⚠️ at launch | `clients.twilio_number` (provisioned at A2P/Phase D — not onboarding; the onboarding "personal cell" is private) |
| Address (NAP) | ✅ | `clients.address` |
| Hours (for schema + display) | ✅ | `clients.hours` (structured) |
| Services (text) | ✅ (unstructured) | `template_vars.services` |
| Service areas (cities) | ✅ | `clients.service_area[]` |
| Niche/segment | ✅ | `template_vars.segment` |
| Differentiators / About | ✅ | `template_vars.differentiators` / `about_us` |
| GBP link | ✅ | `template_vars.google_business_profile_link` |
| Social profiles (`sameAs`) | ✅ | `clients.social_links` (IG/FB/LinkedIn) |
| Photos (alt/optimization) | ✅ | `template_vars.site_assets` (work/gallery/about/services/staff) |
| Logo (OG/schema image) | ✅ | `clients.logo_url` |
| Domain / origins | ✅ | `clients.allowed_origins` / `template_vars.company_website_link` |
| Reviews widget/link | ✅ | `clients.review_link` + GBP |

### 2.2 Data we do NOT capture (the real SEO gaps → the "final SEO details" admin panel)
1. **GBP categories (primary + 2–4 secondary)** — DRIVE the Core 30 (each category = a category page). Not captured. → AI-recommend + agency-confirm in an **admin SEO panel**.
2. **Structured services-by-category (the Core-30 map)** — we have `services` as free text; need services grouped under categories. → AI-derive from niche + services + GBP, agency-refine.
3. **Geo coordinates (lat/lng)** — for `LocalBusiness.geo`. → geocode the address at build, or a field.
4. **Target neighborhoods/landmarks** — diagnostic-driven (rank map positions 4–6), post-launch → belongs to the content tool, not the initial build.
5. **Public NAP phone** — = the provisioned `twilio_number` (Phase D sequencing).
*(Everything else is derivable — 750-char GBP description from about_us/differentiators, meta from about_us, etc.)*

### 2.3 IN scope for Lovable (the website build) vs OUT (agency/tool)
**IN — Lovable builds into the templates + per-client pages:**
- The **Core 30 structure** (home + category + service pages mirroring the GBP) + **editorial in-content internal linking** (not nav/footer).
- The **8 GBP-consistency signals** on the homepage (title/H1 with category+city, Maps embed, reviews widget, NAP char-for-char, secondary categories in H2s, LocalBusiness schema).
- **On-page/technical:** per-page title + meta (service/category + city formula), one-H1 hierarchy, **schema.org JSON-LD** (LocalBusiness, Service, Organization, BreadcrumbList, FAQPage), semantic HTML/landmarks, image `alt` + `width/height`, canonical, meta robots, Open Graph/Twitter, **sitemap.xml + robots.txt**.
- **Performance/CWV:** mobile-FIRST, fast LCP, no CLS (dimensioned images), lazy-load below-fold, image format/sizing on `site_assets`.
- **Baseline local content** per page from client data (structure + first-pass copy).

**OUT — agency ops / future tools (NOT Lovable site-build):**
- **GBP optimization itself** (categories/services/description/photos/posts/attributes on Google) — but we can **GENERATE** these (category recs, 20–30 services, 750-char description, 52 posts) for paste/automation.
- **Links** (chambers, sponsorships, verified citations, best-of, not-AI-slop links) — off-site; we can **GENERATE the opportunity list**.
- **Rank-map / top-3% diagnostics** + the topical-vs-geographic decision + **supporting/neighborhood content expansion loop** — ongoing, tool-driven (Lead Snap + the content agent).
- **GBP management automation** (weekly posts/photos/review responses/citations) — Lead Snap territory.
- **Content audit** (Screaming Frog) for distrusted sites — diagnosis service.
- The **deep 8-pass writing pipeline** (Reddit/PAA research, burstiness/perplexity/bookends, AI-detection, video) — beyond Lovable inline; = the **future content-automation tool**.

---

## PART 3 — The ranking-factor HIERARCHY we control (priority order for the WEBSITE)
1. **GBP↔website consistency (the 8 signals)** — #1 job of the homepage; without it, no competitive ranking.
2. **Core 30 structure mirroring the GBP** + editorial internal linking = topical relevance.
3. **On-page/technical correctness** (title/H1/schema/semantic/alt/canonical/OG/sitemap) per the service/category + city keyword formula.
4. **Genuinely-local content** (per service + per area — landmarks/local conditions, not generic) at a quality bar that gets indexed.
5. **Performance/CWV** (mobile-first, fast, no CLS).
6. *(Off-site, not Lovable but part of the service: local-authority links > GBP optimization > citations; then the rank-map-driven topical/geographic content loop.)*

---

## PART 4 — Proposed skill + tool architecture
**A. `seo-build` skill (NEW — the site-build SEO standard; primary deliverable).** What Lovable must do for EVERY client site, niche-agnostic (pulls from client data):
- §A Entity model + GBP-consistency (the 8 signals, the mirror principle).
- §B Core-30 structure + editorial internal-linking rules + per-page-type patterns (home/category/service) + target-keyword formulas.
- §C On-page/technical standard (titles/meta/H1/schema JSON-LD/semantic/alt/canonical/OG/sitemap/robots).
- §D Local-content standard (local specificity requirements, FAQ blocks, formatting bar).
- §E Performance/CWV standard (mobile-first, LCP/CLS/INP, image handling).
- §F Per-page-type checklist + the data-mapping table.
- §G What's out of scope (links/GBP/rank-map) + where they're handled.
- **Referenced by** `website-structure` (page generation), `template-builder` (baked into every style template once), `new-client-site` (build step), `launch-check` (SEO go-live gate). *(Reconciles the existing website-structure page model to the Core 30 — see open decision O1.)*

**B. Admin "SEO / Core-30" panel (future onboard/admin addition).** Agency sets/confirms before finalize: GBP primary + 2–4 secondary categories, the structured **services-by-category** (Core-30 map), geo coordinates (or auto-geocode), optional target neighborhoods. Feeds the site build + the content tool. *(This is the "final SEO details field in admin before we finalize" you mentioned — recommended.)*

**C. Future SEO content-automation tool (the endpoint — Core-30-Agent equivalent).** Reads the admin client data → generates the Core-30 page map (gap analysis) → writes SEO-correct pages per the `seo-build` standard (PAA/Reddit research + the 8-pass writing) → publishes to the client's Lovable site (or hands to the agency). Later: rank-map-driven supporting + neighborhood expansion; GBP-content generation (categories/services/description/52 posts); local-link-opportunity lists. **This is the automation moat.** Scoped here as the roadmap; built after `seo-build` + the admin panel.

---

## PART 5 — What we can AUTOMATE vs need from a client vs is out of scope
- **Fully automatable from data we have (or can derive):** page titles/meta/H1, schema JSON-LD, semantic HTML, image alt, canonical/OG, sitemap/robots, the Core-30 structure + editorial linking, baseline local page content, performance conventions, the 750-char GBP description, meta from about_us.
- **Automatable with a bit more (AI-derived, agency-confirmed):** GBP categories, services-by-category (Core-30 map), local content depth (via the content tool's PAA/Reddit/local research), GBP 52-post batch, local-link-opportunity lists, geo pages (from Places API landmarks).
- **Need from client / agency (minimal — prefer none):** ideally NOTHING extra from the client (we already capture the inputs); the agency confirms categories + services-by-category + geo in the admin SEO panel. Public NAP phone comes from the provisioned number at launch.
- **Out of AI/Lovable scope (agency service or 3rd-party tools):** actual GBP edits on Google, buying/placing links + sponsorships, rank-map tracking (Lead Snap), Screaming Frog content audits, ongoing GBP management.

---

## PART 6 — Open decisions to reconcile (before the master plan is signed off)
- **O1 — Reconcile website-structure with the Core 30.** Our current model (service-area pages = "re-targeted lander", generic) is exactly what the expert warns against. Adopt the **Core 30** (home + category + service pages mirroring the GBP) as the canonical local-business structure + upgrade service-area pages to genuinely-local neighborhood pages? *(Rec: yes.)*
- **O2 — How much content does Lovable generate at build vs the content tool?** (a) Lovable = structure + schema/meta + light placeholder; tool writes all Core-30 content. (b) Lovable generates full first-pass Core-30 content at build; tool only expands (supporting/geo). (c) Hybrid: Lovable builds structure + GBP-consistency homepage + on-page scaffolding + first-pass core content; tool refines/expands to the 8-pass standard. *(Rec: C.)*
- **O3 — Admin SEO panel: now or later?** Categories + services-by-category are needed for the Core-30 structure. Add the admin SEO panel as a near-term addition, or AI-derive at build for v1 and formalize later? *(Rec: AI-derive + a lightweight admin confirm field for v1; full panel with the content tool.)*
- **O4 — Skill split.** One `seo-build` (site-build) + the content-tool roadmap as a separate doc (rec) — vs splitting `seo-onpage`/`seo-local`/`seo-performance`. *(Rec: one `seo-build`; local is woven through, not separate, because the whole point is local.)*
- **O5 — Sequencing vs Phase A.** Build `seo-build` BEFORE styles 2–6 so every style template bakes in the SEO scaffolding once (rec), and slot the content tool after.

---

## PART 7 — Ongoing article content engine (the recurring SEO service)

The transcripts make clear this is **not a one-time build** — it's a **monthly production pipeline** and the actual recurring revenue (the pricing transcript: **$2,400/mo minimum = 12 articles/mo** + GBP management + monthly press release + a monthly local-link-opportunity list). After the Core-30 launches, the ongoing work is: **run rank map → check top-3% → decide topical vs geographic → produce ~10–20 targeted pages/mo (each fully built) → publish → repeat.** We had no skill/mechanism for this. Here's how we build it.

### 7.1 The two ongoing content types (both recurring, decision-driven)
- **Supporting/topical pages** (when BELOW the top-3% threshold): FAQ-derived deep pages answering specific questions the rank map shows you don't rank for (PAA reworded + Reddit-sourced local Qs), each editorially linked from a Core-30 page, each with 1 external link.
- **Geographic/neighborhood pages** (when AT/ABOVE threshold): service + landmark + city pages targeting rank-map positions 4–6, genuinely local (Places-API landmarks, local conditions), each with an external link + internal links (Locations page + relevant service page).
- **The decision between them each cycle is data-driven** (rank map top-3% vs the market's competitive threshold), NOT guessing — this decision layer is core to the engine.

### 7.2 How each ongoing article is built (the production standard)
Per article (from the transcripts' 9-step process + 8-pass writing): target/keyword/intent set → research (PAA + Reddit + local forums + competitor headlines + local landmarks/conditions) → content brief → **8-pass write** (research-synthesis → outline → section-by-section drafting → burstiness → perplexity-injection → human bookends → conversion pass → QC) → in parallel: FAQ block, meta title/description/H1, **schema JSON-LD**, AI images, external authority link, optional rendered+embedded YouTube video → **publish** → internal links placed/verified → 1 inbound external link sourced (the ~$25–35 off-site step, human/agency) → human QA. **Cost <$100/article; humans keep QA + the inbound link.**

### 7.3 THE key architectural question — how ongoing content reaches a Lovable client site
Our client sites are **Lovable Remixes (frontend) pointed at the shared backend** — we can't have a tool keep editing Lovable's frontend code per article. The expert's tool publishes to WordPress; we need our equivalent. **Recommended architecture (fits our shared-backend model exactly):**
- **A backend content store** (additive) — a `content_pages` table on the shared backend: `client_id`, `slug`, `type` (`home`/`category`/`service`/`supporting`/`geo`), `title`, `meta_description`, `h1`, `body` (markdown/html), `schema_jsonld`, `target_keyword`, `internal_links` (jsonb), `external_link`, `status` (`draft`/`published`), `published_at`, `og_image`. **Anon-readable** (the marketing site renders it, same posture as `get_client_public`). RLS/tenant-scoped by `client_id`.
- **Dynamic render routes in the marketing template** (Lovable builds ONCE into every style template): the site renders Core-30 + supporting + geo pages **from the content store** — applying the `seo-build` standard (schema, meta, semantic HTML, internal links, breadcrumbs). e.g. `/services/$slug`, `/$slug` (supporting), `/service-area/$slug` (geo), a Locations index, sitemap generated from the store.
- **The content-automation tool WRITES rows into the store; the site RENDERS them.** The tool never touches Lovable frontend code. This is the clean endpoint: content is DATA, the frontend is a generic renderer. Same "shared backend + frontend reads public data" pattern we already use.
- Result: a client site is effectively **CMS-backed** — the initial Core-30 (from build) and every ongoing article (from the tool) are rows the frontend renders. Publishing a new page = inserting a row.

### 7.4 The rank-map decision input
The topical-vs-geographic decision needs rank-map data (Lead Snap, external). Feed it in via an **admin upload** (rank-map CSV → the tool ingests → computes top-3% → recommends the next content batch) or a future Lead Snap integration. This is the engine's "what to build next" brain. Out of Lovable's site-build scope; part of the content tool + an admin data input.

### 7.5 Skill/architecture refinement (revises O4)
Ongoing content is substantial enough (it's the recurring engine) to warrant **splitting content out of `seo-build`**:
- **`seo-build`** — the SITE/TEMPLATE structure + technical standard (Core-30 architecture, GBP-consistency homepage, on-page scaffolding, schema components, **the dynamic content-render routes**, sitemap/robots, performance). What Lovable/`template-builder` bakes into every style template once.
- **`seo-content`** — the CONTENT PRODUCTION standard (the 8-pass quality bar, local-specificity rules, per-page-type content patterns, PAA/Reddit research, internal/external linking, schema-per-type, **the topical-vs-geographic decision framework + the monthly loop**). Governs BOTH the initial Core-30 copy AND every ongoing article. This is the spec the content-automation tool implements.
So: **two skills by concern** — `seo-build` (the container/renderer) + `seo-content` (what fills it, initially and forever) — plus **the content store** (backend) and **the content-automation tool** (executor). This 2-way split (container vs content) is cleaner than the rejected on-page/local/performance 3-way split.

### 7.6 New decisions (add to reconcile)
- **O6 — Content delivery architecture:** adopt the **backend content store + dynamic render routes** (recommended — content is data, tool writes / site renders, no frontend edits per article) vs any alternative (manual Lovable edits = not scalable; off-platform CMS = breaks the single-backend model)?
- **O7 — Skill split:** `seo-build` (structure/technical incl. the render routes) **+** `seo-content` (production standard, initial + ongoing) — refining O4 from one skill to this 2-way split? *(Rec: yes.)*
- **O8 — Ongoing-content module timing:** build order = `seo-build` + `seo-content` standards (now/Phase A) → the content store + template render routes (with Phase A templates) → the content-automation tool + rank-map input (a later module, like CRM/reactivation were). Confirm this staging.

---

## MASTER PLAN — SIGNED OFF 2026-06-30

**All decisions locked (O1–O8):**
| # | Decision | Locked |
|---|---|---|
| O1 | Site structure | **Adopt the Core 30** (home + 3–4 category pages + 25–30 service pages mirroring the GBP; editorial in-content internal linking) as the canonical local-business structure. **Supersede** the generic "service-area = re-targeted lander" model; area pages become **genuinely-local neighborhood/landmark pages**. Updates `website-structure`. |
| O2 | Build-time content | **Hybrid (C):** Lovable builds structure + the GBP-consistency homepage + on-page scaffolding + **first-pass** Core-30 content; the content tool refines/expands. |
| O3 | SEO inputs | **AI-derive** GBP categories + services-by-category at build + a **lightweight admin confirm field** for v1; the **full admin SEO panel** (categories / services-by-category / geo / target neighborhoods) ships with the content tool. Geo = auto-geocode the address. Public NAP phone = provisioned `twilio_number` (Phase D). |
| O4/O7 | Skills | **Two skills by concern:** **`seo-build`** (site/template structure + technical + the dynamic content-render routes) **+** **`seo-content`** (content-production standard — 8-pass quality, local specificity, per-page-type patterns, PAA/Reddit research, internal/external linking, schema-per-type, the topical-vs-geographic decision + monthly loop). NOT the on-page/local/performance 3-way split. |
| O5 | Sequencing | Author `seo-build` + `seo-content` **BEFORE styles 2–6** so every style template bakes the SEO scaffolding + render routes in **once**; the content tool comes after. |
| O6 | Content delivery | **Backend content store + dynamic render routes.** A `content_pages` table (anon-readable, tenant-scoped) holds every page as data; the marketing template renders it generically; the content tool **writes rows** (never edits Lovable code). Client sites become effectively CMS-backed. |
| O8 | Staging | (1) standards now/Phase A → (2) content store (additive backend table) + template render routes with the Phase A templates → (3) the content-automation tool + rank-map input as a later module (like CRM/reactivation). |

### Deliverables (in build order)
1. **`seo-build` skill** (structure/technical standard; referenced by `template-builder`/`website-structure`/`new-client-site`/`launch-check`) — includes the dynamic content-render-route spec.
2. **`seo-content` skill** (production standard — initial Core-30 copy + all ongoing articles + the topical/geographic decision loop).
3. **`website-structure` reconcile** — replace the generic page model with the Core 30 + genuinely-local neighborhood pages; add the render-route/content-store contract.
4. **Style templates (Phase A)** bake in the SEO scaffolding + consistency homepage + content-render routes once.
5. **Content store** — additive backend `content_pages` table (**schema touch — additive migration**, its own tagged pass) + anon read projection + tenant RLS.
6. **Admin SEO panel** (categories / services-by-category / geo / neighborhoods) — feeds build + tool.
7. **Content-automation tool** (the Core-30-Agent equivalent) — gap analysis + research + 8-pass writing → writes to the content store; + **rank-map input** (admin CSV → top-3% → next-batch recommendation).

### Schema / scope flags (for when we build)
- **Content store = the one real schema add** (`content_pages`, additive; anon-safe public read like `get_client_public`; tenant-scoped by `client_id`; keep it out of / correctly inside the `audit_tenant_rls()` tenant scan — it HAS `client_id` so it needs an is_admin/tenant read policy + anon public-read policy).
- **Admin SEO panel** = app-layer (categories/services-by-category ride `template_vars` or a small additive column set; geo = 2 numeric cols or `template_vars`).
- **Everything in `seo-build`/`seo-content` templates + render routes** = frontend/template (Lovable), no backend schema.
- **Out of Lovable entirely** (agency ops / 3rd-party): GBP edits, links/sponsorships, Lead Snap rank-tracking + GBP management, Screaming-Frog audits.

**Status: PLAN LOCKED — build deferred to Phase A (styles) + a later content-tool module. This doc is the canonical spec.**

