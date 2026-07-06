# The category → service hierarchy (what pages are really supposed to look like)

> Full-corpus synthesis (all 6 transcripts re-read). The category-page scope bleed is **structural first, prompt second.** Cited `<ID>:line`.

## The hierarchy — a 1:1 mirror of the Google Business Profile [unanimous across sources]
**Primary category → secondary categories → services.** *"The structure follows a very clear hierarchy, primary category, secondary categories, services. This structure directly matches how Google business profiles are set up"* (`HowToUseContent:88-90`). *"one page for every category and service … Homepage to the secondary categories, and the secondary category down to the service pages under that secondary category. You basically build a website that is an **exact mirror image of your GBP**"* (`FifSqbB0:113-127`). *"3-4 category pages, and 25-30 service pages … It mirrors your GBP structure exactly"* (`ZKZnDORR0ds:173-194`).

- **Home page** = the **primary GBP category** + city (H1). e.g. `Landscaper` → "Landscaping Cleveland".
- **Category pages** = the **secondary GBP categories** (2-4 real, Google-recognized categories), each + city. e.g. `Lawn care service`, `Hardscape contractor`, `Landscape designer`, `Snow removal service`.
- **Service pages** = the **GBP services** (20-30+), each nested under its most-relevant category. e.g. under `Lawn care service` → mowing, fertilization, aeration, weed control.

**Services MUST semantically match their category:** *"services need to be **categorized** by which category they're most relevant to. Under your plumber category, you're going to list water heater replacement, pipe repair, leak detection. **Google is looking at whether your services semantically match your categories. If they don't, you're confusing the algorithm**"* (`ZKZnDORR0ds:99-106`). Categories must be **real GBP categories**, not invented buckets (`HowToUseContent:117-118`; `FifSqbB0:66-91` category audit).

## What each page contains
- **Home:** primary-category overview; an H2 + **50-100 words** per secondary category, each **linking** to its category page (`ZKZnDORR0ds:177-188`).
- **Category page:** an overview of THAT category + an H2 + **50-100 words** per **its own** child service, each **linking** to that service's page (**5-10 links**). It may cover the category's sub-types + local relevance, but the **detailed content lives on the service page, NOT the category page** (`ZKZnDORR0ds:188-200`; the "heating contractor" category-page example — water-heater types + neighborhoods served — `HowToUseContent:130-141`).
- **Service page:** **deep, 800-1500 words**, on THAT ONE service in the city — why-needed / what's-included / process / pricing / local specifics (`ZKZnDORR0ds:196-200`; `HowToUseContent:156-161`). This is where depth lives.
- Cross-page relationships are **internal editorial LINKS** down the hierarchy — never body paragraphs about other categories/services.

## Concrete example (plumber, from the transcripts)
- Primary category: **plumber** (home).
- Secondary categories (category pages): **drainage service**, **gas installation service**, **heating contractor** (`ZKZnDORR0ds:179`; `HowToUseContent:114-116`; `FifSqbB0:84-85`).
- Services (service pages) nested under them: **water heater replacement, pipe repair, leak detection** (under plumber/heating), **toilet repair, sewer line replacement, bathroom sink installation** (`ZKZnDORR0ds:104`; `HowToUseContent:146-149`).

## The landscaping example — what x3's map SHOULD look like
The pasted Tampa GBP list (~80 items) is the **services** layer — they belong on **service pages, grouped under real secondary categories**, e.g.:
- **Home** — primary category `Landscaper` → "Landscaping Cleveland".
- **Category pages** (real GBP secondary categories, 2-4 that fit x3):
  - `Lawn care service` → services: mowing, fertilization, aeration, weed control, seeding
  - `Hardscape contractor` → services: retaining walls, paver patios, walkways, stone masonry
  - `Landscape designer` → services: landscape design, garden design, planting/flower beds
  - `Irrigation system installer` → services: sprinkler install, drip irrigation, system repair
  - `Snow removal service` → services: plowing, salting, sidewalk clearing
- **"Gardening"** is a **service** (under Landscape designer / its own), **"snow removal" is a separate CATEGORY**, **"hardscaping" is a separate CATEGORY** — they are NOT content on each other's pages; they connect only by links.

## The diagnosis — why x3 drifts
**"Landscaping Services in Cleveland" as ONE catch-all category is the structural root.** When the category is "all of landscaping," every landscaping service (snow, fencing, hardscaping, gardening) is legitimately its child, so:
- the category page faithfully writes a blurb about each — but those children shouldn't share one category; and
- with no *narrow* category boundary, "stay in scope" has nothing to hold — everything landscaping fits.
On top of that, a **prompt** gap: the category page wrote **detailed paragraphs + bullet lists** about each service instead of the prescribed **50-100-word blurb + link** (depth belongs on the service page). And the earlier service-page hardening's deterministic H2-sibling check **excluded category pages** — so category pages had no backstop at all.

**So: structural first (the map lumps unrelated services under one broad category), prompt second (category page writes depth instead of blurb+link, and had no guard).**

## Recommendation — two layers
### Layer 1 — STRUCTURAL (the root fix): a proper GBP-mirrored map
- The SEO map must be **primary category → 2-4 real secondary categories → services nested by semantic match** (not one "Landscaping Services" bucket). Fix x3's map into real categories (Lawn Care / Hardscaping / Landscape Design / Irrigation / Snow Removal), each with its own services.
- **Tool implications (future build — flag, don't build now):**
  - `proposeSeoMap` should generate **real GBP-style secondary categories** (2-4) with services semantically nested — not collapse everything under one broad category. Ideally seed from the client's actual GBP primary + secondary categories + services (the "matches their GMB" input the Slice-5 spec already flags).
  - The map editor already supports categories→services; add **operator guidance** on the hierarchy (the info popover / a short helper) so operators structure it right.
  - This is a prerequisite for the Slice-5 batch build — a wrong category structure multiplies drift across 30 pages.

### Layer 2 — PROMPT (category-page hardening in `buildTypeBrief`)
- Category-page brief: *"This is a CATEGORY page for {category} in {city}. Write a short overview of the category, then for EACH of its OWN child services: an H2 + a BRIEF 50-100 word blurb + an inline internal LINK to that service's page. Do NOT write detailed multi-paragraph body content or bulleted lists about individual services — that depth belongs on the service page. Only cover services that belong to THIS category; do not cover other categories' services."*
- **Deterministic check for category pages** (the fitting form the operator asked for — not "no sibling H2s"): after write, for each inter-H2 section, flag if it **exceeds ~120-150 words without an internal service-page link** → `scopeWarnings` + one refine to shorten + add the link. This enforces "brief + linked" (catches "detailed bulleted content about snow removal with no link") without forbidding the category from structuring around its services.

## Bottom line for the operator
The pages are supposed to be a **mirror of your GBP**: home (primary category) → a handful of **real secondary categories** (category pages, brief blurbs + links) → **services** (deep pages) nested under the category they belong to. What you "need in place" first is the **right category/service structure in the SEO map** (real categories, services grouped by semantic fit) — that's the boundary the scope guard needs. Then the category-page prompt keeps those pages to blurb-and-link. Fix the structure and the prompt together; the structure is the root.
