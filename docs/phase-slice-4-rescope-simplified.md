# SLICE 4 — RE-SCOPE (simplified per operator decisions) + expert methodology answers

> Supersedes the ambition of `phase-slice-4-content-automation-tool-scope.md`. Three operator decisions collapse the module: (1) research = ONE AI call, no paid APIs; (2) rank-checking = MANUAL (operator feeds a signal); (3) monthly = a toggle + rate scheduler. Expert answers cite `C:/Users/Pierc/Documents/SEO/tactiq-free-transcript-ZKZnDORR0ds.txt` (cited `ZKZnDORR0ds:line`). **Scope only. Commits held.**

## PART B — What the expert actually prescribes (grounded, cited)

### B1 — When to expand from topical → geo (the trigger)
Topical relevance FIRST; the trigger to shift to geo is a **measured threshold**, not a guess.
- "when Google doesn't believe you're an authority, throwing more service pages at it won't help. You need supporting content" (`ZKZnDORR0ds:301-302`).
- "If you're below that threshold, Google doesn't trust you yet… more content proving you know what you're talking about. But if you're at or above your topical relevance threshold, that's a sign that Google trusts you… we're going to shift to building geographical relevance" (`ZKZnDORR0ds:287-292`).
- The anti-pattern: agencies "start building location pages… before they've proven topical authority. And those location pages do nothing because Google just doesn't trust them yet" (`ZKZnDORR0ds:294-295`).
- **Trigger = your top-3% reaches your topical-relevance threshold.** "keep building supporting content and running rank maps every month until you hit 30%. And once you hit that threshold, the strategy completely changes" (`ZKZnDORR0ds:352-354`).

### B2 — How to measure "are the topic pages working" before expanding
- **When:** "30 days after you've launched the core 30, it's time to start running more rank maps for your target keyword" (`ZKZnDORR0ds:263`). Keyword = "your primary category, plumber Houston… or a core service, water heater replacement Houston" (`ZKZnDORR0ds:264-265`).
- **The one metric — top 3%:** "take the total area… that top 3% determines whether we build topical content or geographical content" (`ZKZnDORR0ds:266-271`). It's the % of the 169-point grid where you rank positions 1–3.
- **The threshold is RELATIVE to competitors:** "Run rank maps for the top three or four businesses that are dominating your keyword. Look at what their top 3% is. In highly competitive markets, the top players will be at 30 or 40% at best… less competitive markets, the top players might be a 99%" (`ZKZnDORR0ds:272-275`). Your threshold = **25–50% of the leaders' top-3%**: "if the top players are at 80%, your threshold is 30 to 40. If the top players are at 40%, your threshold is 15 to 20. That is your topical relevance threshold" (`ZKZnDORR0ds:286-287`).
- Re-check **monthly** (`ZKZnDORR0ds:352-353`).

### B3 — Improving the initial service/topic pages (before/while expanding)
The expert's mechanism is **ADDITIVE supporting content + internal linking — NOT rewriting the existing pages.**
- "throwing more service pages at it won't help. You need supporting content… by answering questions" (`ZKZnDORR0ds:301-303`).
- **Not blog posts, not city pages:** "generic blog posts… or… create city pages… Just changing the city name and calling it content. These tactics don't work" (`ZKZnDORR0ds:304-306`). "What you're building here are not blog posts. They're highly targeted supporting content pages built to answer specific questions that the rank map shows you're not ranking for. Every page is connected to your core 30 structure" (`ZKZnDORR0ds:311-313`).
- **The FAQ mechanism (this IS how existing pages get stronger):** find real questions → "add the question to the relevant page on your site" (homepage/category/service) → "answer the question briefly, a couple dozen words" → "add an editorial link right in that content… That link goes to a new supporting content page where you're then going to answer that question in depth. Hundreds of words" (`ZKZnDORR0ds:334-342`). This "adds value to your main pages without bloating them" + "creates internal linking from your core 30 pages to supporting content pages. Google follows these links and sees that you have depth" (`ZKZnDORR0ds:345-347`).
- Every supporting page also needs one authority ("not AI slop") external link (`ZKZnDORR0ds:347-350`).
- **So "improving the core pages" = (i) add reworded FAQ answers on them, (ii) editorial-link out to new deep supporting pages, (iii) keep adding supporting pages until threshold** (`ZKZnDORR0ds:351-352`).

### B4 — Ongoing cadence: what KIND of page each month, and how you know
- **It's a RULE keyed on the rank map, run monthly:** "Every month, run your rank map. Check your top three metric. Look at where you're still weak. Are you below threshold? More topical content. At threshold, build geographical content. Dominating everywhere. Maintain and defend" (`ZKZnDORR0ds:401-402`).
- **Below threshold → topical supporting content** answering the specific questions the map shows you're weak on (`ZKZnDORR0ds:311-352`).
- **At/above → geographic:** "look at your rank map. You're ranking in [green], now… expand your coverage area… geographical content targeted at specific landmarks" (`ZKZnDORR0ds:355-357`); target areas showing **4–6** on the grid: "a 4→3 is easy and worth it; a 19→4 gets nothing — only top-3 matters" (paraphrase of `56` / `ZKZnDORR0ds:355-372`). "build 10 [to] 20 of these geographical pages" (`ZKZnDORR0ds:383-384`); re-run "every couple of weeks. Target the new areas. Keep expanding outward" (`ZKZnDORR0ds:387-389`).
- **Dominating everywhere → maintain/defend:** keep the GBP active, add services as the business evolves, watch competitors, consider a 2nd location (`ZKZnDORR0ds:395-406`).
- **Alternate:** "Alternate between topical content when needed and geographical content when you're above threshold until… you're dominating your entire service area" (`ZKZnDORR0ds:393-395`). "This is a system" (`ZKZnDORR0ds:395`), not random publishing.

### B5 — Minimum manual signal (given rank-checking is manual, not built)
The expert's entire decision reduces to **one 3-state value** the operator can read off a manual rank map and feed:
- **BELOW threshold → topical** · **AT/above threshold → geographic** · **DOMINATING → maintain** (`ZKZnDORR0ds:401-402`).
- To act on it the system also needs the **target keyword** (primary category / core service, `ZKZnDORR0ds:264-265`) and, when geographic, **which towns/areas are "close"** (showing 4–6 on the map, `ZKZnDORR0ds:355-372`).
- **Minimum feed per cycle:** `{ topical_status: below|at|dominating, (if geographic) close_towns: [...] }`. Everything else (which supporting questions, which landmarks) the research call + the built geo machinery can produce. This maps 1:1 to a small operator toggle + list — no rank engine required.

### Fidelity note — what the simplified research gives up vs the expert
The expert's supporting-content engine is DRIVEN by **real** questions from **People Also Ask** (`ZKZnDORR0ds:316-328`) and **Reddit** ("actual local questions from real people… specific about your service in your city", `ZKZnDORR0ds:329-333`). Decision (1) drops both paid/scraped sources. Consequence: our topical-question targeting is **approximated** by the AI (its own candidate questions + competitor-page sections), which is lower-fidelity for finding the *exact* high-intent questions. Competitor + local-landmark inputs are preserved. This is the accepted cost of "no paid APIs" — flag it so the operator can optionally paste a few real PAA/Reddit questions to seed a cycle when they want max fidelity.

## PART A — Re-scoped Slice 4 (simplified)

### S4-A — Research-in-one-call + accuracy gate [FIRST]
- **(a) Competitor read — MECHANISM FLAG.** "AI reads the top-3 ranking pages" has a chicken-and-egg: to read them you must first KNOW their URLs (a SERP query we're not paying for) and the writer's model may have **no web access**. Verify: `aiWritePage` uses the Lovable AI gateway model `google/gemini-3-flash-preview` — whether the gateway exposes Google-Search **grounding** is unconfirmed. **Robust no-paid-API design:** the operator (who is rank-checking manually and already SEES the top-3) **pastes the top-3 competitor URLs**; a server fn **fetches** each (free HTML fetch) and an AI call **extracts the sections/key points**. (If gateway grounding turns out available, it's an optional enhancement.)
- **(b) Local landmarks — the accuracy risk to solve.** AI proposes candidate real landmarks/parks/hospitals/universities/intersections for the town from its own knowledge, then **each is verified against OpenStreetMap Nominatim (FREE, no key, rate-limited)** — unverified ones are dropped — and the **operator reviews/approves** the final list in the research UI. Only verified, approved places enter PROVIDED CONTEXT. This is how we get genuinely-local color **without** reintroducing hallucinated places (no paid Places API).
- **Store** competitor summary + verified landmarks in a research record (additive: a `content_research` table OR a `template_vars.seo`-adjacent jsonb) → fed to the writer as PROVIDED CONTEXT → the **existing reject-validator** still gates. The landmark list being *provided + verified* is exactly what lets the geo writer be specific and accurate.

### S4-B — Manual topical-status signal (replaces the CSV rank engine)
A tiny per-client (or per-keyword) operator-set field = the expert's 3-state: **`topical_status: building | established | dominating`**, plus (when established) a **`close_towns[]`** list. Set by the operator when they manually check rank. No CSV ingest, no tracker. This IS the §7 decision signal, fed manually. Additive (a `template_vars.seo` field or a small column).

### S4-C — The deep writer (8-pass, research-fed) + job runner
`writePageDeep`: passes 1–8 (research→brief → outline → section-by-section → burstiness → perplexity/de-AI → human-bookends → conversion → QC), fed by S4-A research, **reusing** the anti-hallucination validator + link-guarantor + marker + §3 briefs. 8+ chained calls exceed a single Worker request → runs on a **durable `content_jobs` runner** (additive table). Biggest sub-slice; unchanged by the research simplification (only the research INPUT got simpler).

### S4-D — Monthly scheduler (toggle + rate)
Per-client **`auto_content: on/off`** + **`rate` (N pages/week or /month)**. When on, a scheduled runner produces + publishes N pages/cycle. **WHAT it builds is driven by S4-B's signal:** `building` → supporting content pages (AI-generated candidate questions since no PAA, optionally operator-seeded); `established` → geographic pages for `close_towns` (via the built `seedGeoPages` + `writePageDeep` + wave-publish); `dominating` → maintain (pause/minimal). Simplest viable form: the scheduler draws from a **candidate-topic queue** the AI proposes + the operator approves, at the set rate. Additive (settings + a queue table or jsonb).

## Schema / cost
- **Additive only** (audit-safe): `content_research` (or jsonb), `content_jobs` (durable pass runner), a small `topical_status`/`auto_content`/`rate` settings surface, optional candidate-topic queue. `content_pages` additive `ai_detection_score`/`research_id` if wanted.
- **External cost: effectively $0** — free HTML fetch (operator-provided competitor URLs) + free OSM Nominatim (landmark verification) + the existing AI gateway. No DataForSEO/SerpAPI/Places.

## ADDITIONS (folded 2026-07-06)
1. **Competitor URLs in Settings** — `template_vars.seo.competitor_urls: string[]` (≤3), edited in Settings, reused by S4-A each cycle (not re-pasted). Zero schema. → **S4-A**.
2. **30-day SEO-update timer** — additive column `clients.seo_last_reviewed_at timestamptz` (nullable; clock = `coalesce(seo_last_reviewed_at, created_at)+30d`). All-clients agency view (`agency.index.tsx`) surfaces DUE clients; per-client SEO tab has an "SEO Updated" button (`markSeoReviewed` → sets now(), goes green, resets clock). ONE additive column (audit-safe; `clients` is the tenant root). → **S4-B**.
3. **Web browsing — VERIFIED: NO.** Gateway (`ai-gateway.server.ts`) is a plain OpenAI-compatible completions proxy (`createOpenAICompatible`, `google/gemini-3-flash-preview`), no tools/search/grounding; OpenAI-compatible shape can't do Gemini native `google_search`. **Path:** operator-pasted competitor URLs + server `fetch` + AI summarize (baseline, no browsing); OSM Nominatim (free) for landmarks. Optional later deep-research = a cheap search API (Tavily/Brave free tiers, or Perplexity/OpenAI-search ~cents) run monthly — enhancement, not dependency.
4. **Manual topic/subject seeding** — optional `seed` input (operator topics + example details) → flows into the research record + PROVIDED CONTEXT (the escape hatch for the dropped-PAA fidelity gap; operator-provided = allowed by the validator). → **S4-A** (+ reused by the writer).
5. **Monthly rank-check instructions in the UI** — the B1/B2/B5 checklist rendered in the monthly-update section so it's in front of the operator each cycle. → **S4-B**.

## THE IMPROVE-CONTENT DECISION — answered
Reframed correctly: "improve" = the expert's **additive** FAQ-answer + deep supporting page (`ZKZnDORR0ds:334-347`), NOT rewriting.
- **(a) On-method? YES.** Rewriting existing pages is off-method; the expert mechanism is: pick a core page → a relevant question → add a brief FAQ answer + editorial link ON the core page → generate a NEW deep supporting page that answers in depth + links back.
- **(b) Clean spec? Medium, not tiny.** Two ops: (i) targeted FAQ-insert on the core page body, (ii) generate a new `type='supporting'` page. Dependency check: supporting pages **already render** (template root `$slug.tsx` catch-all + `type:"supporting"` in the union) — **no new template route.** The "generate" step reuses `aiWritePage` (minimal) or the 8-pass writer (full).
- **(c) Where it lives: S4-C (its own sub-slice), NOT S4-A.** It generates a supporting page, so it belongs with the writer track, sequenced after S4-A (so it's research-fed).
- **(d) Minimal first form:** select core page → AI proposes ONE relevant question (operator can edit / use the seed) → create a `type='supporting'` row (slug from the question) → write it with the EXISTING `aiWritePage` (research-fed if S4-A shipped) → deterministically insert on the core page an FAQ block `<h3>Q</h3><p>brief answer <a href="/{supporting-slug}">…</a></p>` (link-guarantor-style append). Reuses all built primitives; 8-pass upgrade is later (S4-D).

## Revised sub-slice plan
- **S4-A — Research-in-one-call** [FIRST]: competitor URLs in Settings + fetch+summarize + landmark AI-propose→OSM-verify→operator-review + research store (`template_vars.seo.research[slug]`) + optional seed + wire into `aiWritePage` PROVIDED CONTEXT. **Zero schema.**
- **S4-B — Cadence + manual signal**: 30-day timer (1 additive column) + all-clients DUE view + "SEO Updated" button + the B1/B2/B5 rank-check checklist + `topical_status: building|established|dominating` + `close_towns[]`.
- **S4-C — "Add supporting content" action** (the expert improve mechanism; minimal reuse of `aiWritePage`; supporting route already exists).
- **S4-D — 8-pass deep writer + `content_jobs` runner** (upgrades write quality of supporting/geo pages).
- **S4-E — Monthly scheduler** (toggle + rate) driven by S4-B's signal → produces supporting (building) / geo (established, via built `seedGeoPages`+wave-publish) on cadence.

**First = S4-A** (zero schema; establishes the accuracy-checked research foundation the whole module feeds on).

---
**Recommended: keep the anti-hallucination discipline; get research from ONE AI call grounded by free checks (operator-pasted competitor URLs + server fetch for competitor sections; AI-proposed landmarks VERIFIED via free OSM Nominatim + operator review); replace the rank engine with a 3-state manual `topical_status` (+ `close_towns`) the operator feeds; drive a toggle+rate monthly scheduler off that signal over the already-built geo/topical machinery; the 8-pass deep writer on a durable job runner. Cost ≈ $0, additive schema. First sub-slice S4-A. No build; commits held.**
