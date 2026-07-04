---
name: seo-content
description: Use when producing the WRITTEN content for a client's local site — the content-production standard for every page (initial Core-30 copy AND ongoing monthly articles). Covers the quality bar (helpful/distinct/genuinely-local/indexable), local-specificity rules, per-page-type content patterns, the 8-pass human-passing writing pipeline, research inputs (People-Also-Ask + Reddit + competitor + local), editorial internal + external linking, and — critically — the RANK-MAP decision framework (topical vs geographic) + the monthly production loop. This is what the content-automation tool implements; the per-client build uses a lighter first pass. Content is written as rows into the `content_pages` store (see seo-build §4) that the site renders. NOT the site structure/technical (seo-build) and NOT off-site links / GBP posts / rank-tracking (agency ops / Lead Snap). Full spec: docs/seo-system-analysis-and-skill-plan.md.
---

# SEO Content — local content production standard

How every page's COPY is produced so it builds **relevance** (the thing that makes the GBP rank). `seo-build` is the container (structure + technical); this is what fills it — for the initial Core-30 pages AND the ongoing monthly articles. Content is written as `content_pages` rows (seo-build §4); the site renders them.

## The job [LOCKED — read first]
- Content exists to build **relevance so the GBP ranks** — NOT to chase blog traffic. Two kinds:
  - **Topical relevance** — connects the business entity ↔ the service entity (proves you actually do the service). Built via the Core-30 pages + **supporting content**.
  - **Geographic relevance** — connects the business + service ↔ a specific location entity (proves you operate there). Built via **neighborhood/landmark pages**.
- Which one you build next is **decided by data (the rank map), not by guessing** — see §7. Getting it backwards wastes months.

## 1. The quality bar [LOCKED — or it won't index/rank]
Google doesn't care AI vs human — it cares that content is **helpful, distinct, genuinely local, well-formatted.** Every page must be:
- **Helpful** — answer the searcher's actual intent (someone searching "AC repair near me" wants someone to fix it today, not an explainer of how AC works).
- **Distinct / informationally additive** — say something not already on page one; generic AI content often won't even get **indexed**.
- **Genuinely local** — see §2.
- **Well-formatted** — client photos (best) or AI images, callouts, tables, headers, bullets, **short paragraphs**, internal links. Judged on the latest mobile Chrome. **No walls of "AI slop."**

## 1b. AI-generation accuracy & casing [LOCKED — proven in SEO-STORE-3c-2]
When content is AI-generated (the per-page writer + the content tool), two guards are non-negotiable:
- **Only-provided-facts (anti-hallucination).** An LLM writing marketing copy WILL invent business names, founding years / "since YYYY", warranties + guarantee terms, awards / certifications / licenses / BBB ratings, team size, job counts, testimonials, and pricing — **a real liability for real clients.** The prompt MUST carry an explicit **PROVIDED CONTEXT** block (the only business facts it may state — name, city, service, about-us, differentiators) + a **STRICT ACCURACY RULES** list forbidding each fabrication class, with the fallback: **if a fact isn't provided, write around it — describe the service/process/benefit generally instead of inventing a specific claim.** Never let the model substitute or shorten the business name.
- **Proper casing.** Headings/service/business/city names in **Title Case** ("Hardscaping in Columbus", "What's Included"); **acronyms preserved exactly** (HVAC/AC/LLC — never "Hvac"/"llc"). Title-case is normalized **at the source** (the map names via `titleCase()`), not per-render, so titles/H1/keyword/meta/headings all agree; **slugs stay lowercase-hyphen.**

## 2. Local specificity [LOCKED — the differentiator]
Not "we serve the {area} area" — **actually local**: neighborhoods and their conditions (older homes with cast-iron pipes vs new construction with PEX; coastal weather; historic-downtown building types), driving routes techs/customers take, nearby landmarks and businesses. This is what convinces Google + AI you're genuinely local even without a physical presence there. **Never** city-name-swap ("plumber in {city}" pages that only change the city) or "{landmark}" repeated 50×.

## 3. Per-page-type content patterns [LOCKED]
- **Homepage** — talks directly to the searcher (what you do, how fast, where); each secondary category gets an H2 + 50–100 words + an editorial link to its category page.
- **Category page** — what the category is / why customers need it; each service under it gets an H2 + 50–100 words + editorial link to the service page.
- **Service page** — specific to that one service: why customers need it, what's included, how long, what to expect, cost ranges where useful. Not generic advice.
- **Geo / neighborhood page** — **H1 = service + neighborhood** (e.g. "Emergency Plumber in Downtown Houston"); **para 1** answers "do you serve here?" + response time; **para 2** = the specific local pain point; **para 3** = local landmarks/specifics (conditions, routes, nearby areas); then a **local FAQ** (e.g. "How much does {service} cost in {neighborhood}?", "What's your response time to {area}?").
- **Supporting page** — one specific question answered comprehensively (hundreds of words); linked to from a brief FAQ answer on a Core-30 page.

## 4. The 8-pass writing pipeline [LOCKED — human-passing + ranks]
Each page (per-type prompts differ) runs: (1) **research synthesis → content brief** (compress §5 research into what to answer, local details to weave in, competitor angles to beat); (2) **strategic outline** (every H2, its angle, the flow); (3) **section-by-section drafting** (a separate call per H2 → natural tonal variation); (4) **burstiness** (vary sentence/paragraph length — long, short, fragment); (5) **perplexity injection** (replace predictable AI words — "robust/leverage/streamline" — and remove em-dashes); (6) **human bookends** (first 2 + last 2 sentences extra-conversational — weighted heaviest by Google, read first by users); (7) **conversion pass** (natural CTAs + phone number, per content type); (8) **final QC** (vs the brief/outline, word count, leftover AI patterns → flag/rewrite). **In parallel:** FAQ block, meta title/description/H1, schema (per seo-build §3), images (with prompts), the external-link slot, optional rendered + embedded YouTube video (improves indexing/ranking). Track an **AI-detection score** per page (aim low; human QA on high scorers).

## 5. Research inputs [LOCKED]
Before writing: **People Also Ask** (search the keyword **without** the city; click to expand → 20–30 questions — **reword them, don't copy verbatim**), **Reddit + local forums** (real local questions from real people in the area), **competitor headlines** already ranking, and **local research** (neighborhoods, landmarks, local conditions from §2).

## 6. Linking [LOCKED]
- **Editorial in-content internal links** following the seo-build hierarchy (home→category→service; supporting/geo pages link to their Core-30 parent; a Locations index links to all geo pages). Nav/footer links don't count.
- **FAQ pattern:** put the question on the relevant page → answer briefly (a couple dozen words) → **editorial link** to a deep supporting page that answers it fully.
- **One external "not-AI-slop" link per page** (validates the content is real). The content places the outbound slot; **sourcing the inbound link back to the page is agency/off-site** (out of scope here).

## 7. The decision framework — what to build next [LOCKED — data, not guessing]
- Run a **local rank map** for the target keyword → compute the **top-3%** (the % of the 169-point map that's green = positions 1–3; only top-3 counts). Compare to the **market threshold** = **25–50% of the top competitors' top-3%** (competitive markets: leaders ~25–40%; easy markets: 90–99%).
- **Below threshold → build TOPICAL content** (supporting pages / FAQs — Google doesn't trust your expertise yet).
- **At/above threshold → build GEOGRAPHIC content** (neighborhood/landmark pages — expand coverage). Target rank-map **positions 4–6** (a 4→3 is easy and worth it; a 19→4 gets nothing — only top-3 matters).
- Most agencies get this backwards (location pages before proving topical authority) → wasted months.

## 8. The monthly loop [LOCKED]
Every month: run the rank map → check the top-3% → **below** = topical, **at** = geographic, **dominating everywhere** = **maintain/defend** (keep the GBP active, add new services as the business evolves, watch competitors, consider a second location/GBP). Produce the batch (~10–20 targeted pages; the retainer floor ≈ **12 articles/mo**), each fully built (§4) + published (§6). Re-run every couple weeks for geo, monthly overall. **Repeatable system, not random publishing.**

## When content ISN'T the fix [LOCKED]
If a site has many indexed pages but ranks ~20th *standing in the lobby*, Google likely treats it as **spam** — more content won't help. That needs a **content audit** (full crawl → find thin/duplicate/harmful pages), not production. (Diagnosis; agency/tool, not this pipeline.)

## Output + where it goes
- Every page written per §1–§6 → saved as a **`content_pages` row** (seo-build §4, `status='published'`) → the site renders it. **Publishing = writing/flipping a row; no site rebuild.**
- **Initial Core-30 copy** at per-client build = a lighter first pass of this standard (structure-correct, locally-seeded). **Ongoing articles** = the full 8-pass via the content-automation tool.

## Out of scope [LOCKED]
- **The external links themselves** (chambers, sponsorships, "not-AI-slop" links, "best of" round-ups) → agency / link tool.
- **GBP content** (weekly posts, photos, review responses, description) → agency / Lead Snap; we can *generate* the 52 posts + description as agency assets.
- **Rank-map tracking** → Lead Snap; we **ingest the CSV** to drive §7.

## How this connects [LOCKED]
- Implemented by the **content-automation tool** (the executor — gap analysis + research + 8-pass writing → writes `content_pages` rows). The **per-client build** uses the lighter first pass for the Core-30.
- Pairs with **`/seo-build`** (structure the copy lives in), **`/website-structure`** (the page set), **`/new-client-site`** (build step), **`/launch-check`** (quality gate). Inputs: onboarding/admin data + the admin SEO panel + the rank-map CSV.
