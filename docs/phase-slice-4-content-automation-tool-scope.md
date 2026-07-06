# SLICE 4 — Content-automation tool — READ-ONLY SCOPE (no build)

> The big remaining module: turn the current single-pass, honest-but-general `aiWritePage` into **ranking-grade researched content** — the `seo-content` §4 8-pass pipeline + §5 real research + §7 rank-map decisioning + §8 monthly loop. Grounded on `seo-content`/`seo-build` skills + `cloud-spark-setup` @ `1a9a0d4`+ (aiWritePage/content_pages). **Scope only. Commits held.**

## The boundary we're crossing [from the roadmap, LOCKED]
- **Built (Slices 1-3):** `aiWritePage` = **ONE** `generateText` call, per-type §3 briefs, §1 structure, §1b accuracy, anti-hallucination validator + link-guarantor, ~400-700 words. Structurally correct + safe, deliberately **thin** (no research → stays general to avoid slop).
- **Slice 4 adds the depth loop:** real research IN → 8 passes → ranking-grade, genuinely-local content hitting the method word-counts (home 300-400/section, service 800-1500). It does NOT replace the first pass — it's the **upgrade + ongoing-production** executor.

## 1. The §4 8-pass pipeline
Per page, chained (each a separate model call → natural tonal variation):
1. **Research synthesis → content brief** — compress §5 research into: what to answer, local details to weave, competitor angles to beat.
2. **Strategic outline** — every H2, its angle, the flow.
3. **Section-by-section drafting** — a separate call per H2 (reuses the §3 per-type brief as the drafting instruction).
4. **Burstiness** — vary sentence/paragraph length (long, short, fragment).
5. **Perplexity injection** — replace predictable AI words (robust/leverage/streamline), remove em-dashes.
6. **Human bookends** — first 2 + last 2 sentences extra-conversational (Google weights heaviest; users read first).
7. **Conversion pass** — natural CTAs + the client's phone, per content type.
8. **Final QC** — vs brief/outline, word count, leftover AI patterns → flag/rewrite.
**In parallel:** FAQ block, meta title/desc/H1, schema (seo-build §3), images (+prompts), the external-link slot, optional YouTube embed. **AI-detection score** per page (aim low; human QA on high scorers).

**Relation to `aiWritePage` [DECISION: extend, don't replace].** Build a NEW multi-pass executor (`writePageDeep`) that:
- Is fed the **real research context** (§5, from the research store) as PROVIDED CONTEXT.
- Runs passes 1-8 as chained calls; **reuses the existing primitives** — the §3 per-type briefs (pass 3), the anti-hallucination reject-validator, the link-guarantor, the `<!-- ai-written -->` marker.
- Writes the `content_pages` row body (same store).
- The single-pass `aiWritePage` **stays** for Core-30 first drafts + quick rewrites. The tool is "make it ranking-grade" + monthly production.
- **Worker-safety:** 8+ sequential calls exceed a single request budget → the executor must run as a **durable job** (a `content_jobs` runner processing passes), not one server-fn request. This is the main new architecture.

## 2. §5 research inputs — sources, dependencies, COSTS [the hidden-cost zone]
| Input | What | Real source (accurate, not invented) | Dependency / cost |
|---|---|---|---|
| **People Also Ask** | 20-30 real questions for the keyword (searched WITHOUT the city), reworded | **SERP API** (DataForSEO or SerpAPI) returns PAA | Paid, ~$0.001-0.01/query. API key. |
| **Reddit + local forums** | real local questions from real people | **Reddit API** (OAuth app) or a search API | Free tier + rate limits. OAuth app. |
| **Competitor headlines** | H1/H2s of the pages already ranking | SERP API organic results → fetch each URL → extract headings | SERP API (same as PAA) + HTML fetch/parse. |
| **Local research** | real neighborhoods, landmarks, local conditions | **Places/geo API** (Google Places paid, or OSM Nominatim free) + onboarding local knowledge | Google Places = paid/req; OSM = free, rate-limited. **This is the box that unlocks genuinely-local geo pages.** |
| **AI-detection score** | how human the draft reads | Originality.ai / GPTZero API, OR a self-heuristic | Paid per check, OR free heuristic. |
| **Rank-map data** | the 169-point local grid | **Lead Snap / Local Falcon CSV export** (agency already runs it) | Ingest, NOT build. Manual export or API. |
| **YouTube (optional)** | a relevant embeddable video | YouTube Data API | Free tier. |

**Every source is FETCHED from a real provider, stored verbatim/structured, and fed to the writer as PROVIDED CONTEXT — the writer never invents it.** (See "How research stays accurate" below.)

## 3. §7 rank-map topical-vs-geographic loop
- Ingest the rank-grid CSV → compute **top-3%** (% of the 169-point map that's positions 1-3) for the target keyword.
- Compare to **market threshold** = 25-50% of the top competitors' top-3% (competitive ~25-40%; easy 90-99%).
- **Below threshold → TOPICAL** (more service/supporting pages — build authority first). **At/above → GEOGRAPHIC** (neighborhood/landmark pages; target rank-map positions **4-6**). Backwards = wasted months.
- **Connection to what's built:** GEOGRAPHIC recommendation → feeds **LOC-2 `seedGeoPages` + LOC-3 wave-publish** (which towns/subjects to generate + publish next). TOPICAL → feeds new supporting-page creation into the Core-30 store. So Slice 4 is the **decision brain** over the geo + topical machinery already built.

## 4. §8 monthly cadence — ongoing vs one-time
- **One-time / per-client:** provider setup, initial research per Core-30 keyword, the first deep-write upgrade of Core-30 pages.
- **Ongoing (monthly):** re-run rank map → topical/geographic/maintain decision → produce the batch (~12-20 pages, retainer floor ≈12/mo), each fully 8-pass built + published. Re-run geo every ~2 weeks, overall monthly. **Repeatable system, not random publishing.**

## 5. Schema / external / realistic scope
- **NOT zero-schema** (first multi-table addition since the store). All **additive** (new tables, RLS by `client_id` → `audit_tenant_rls()=0` preserved):
  - `content_research` — per keyword/location: PAA, Reddit, competitor headings, local facts (jsonb + provenance).
  - `rank_map_snapshots` — CSV imports over time; computed top-3% per keyword.
  - `content_jobs` — the durable 8-pass runner queue (page, status, pass-progress, AI-detection score, warnings).
  - `content_pages` additive columns: `ai_detection_score`, `research_id` (link to the research used).
- **External services/keys (server env):** SERP API (DataForSEO/SerpAPI), Reddit OAuth, Places (Google/OSM), optional AI-detector, optional YouTube. **Cost model + keys are the gating lead-time** — settle in the first sub-slice.
- **Realistic scope: multi-slice, the largest module.** ~5-6 sub-slices.

## How research stays ACCURATE (the crux) [anti-hallucination discipline, LOCKED]
The accuracy model is the SAME discipline as today, with a richer real input:
1. Each source is **fetched from a real API** (PAA from SERP API, Reddit from Reddit API, competitor headings from the actual ranking pages, neighborhoods/landmarks from a Places API) — nothing invented at the fetch step.
2. The fetched data is **stored verbatim/structured** in `content_research` (auditable — the operator can SEE the real questions/headings/places before writing).
3. The 8-pass writer is fed **ONLY that real research** as PROVIDED CONTEXT; the **existing anti-hallucination reject-validator** (already built) constrains it to provided facts.
4. **Result:** the writer can now be SPECIFIC and LOCAL without fabricating — because the specifics are real and provided. This is exactly what lets geo pages become "genuinely local" (the box LOC-3 deferred): "the Highland Square area of Akron" is grounded in Places data, not hallucinated. Thin context today → general copy; rich REAL context tomorrow → specific + accurate copy.

## Which expert-doc BOXES Slice 4 ensures
- **§1 quality bar** (helpful/distinct/genuinely-local/indexable) — the 8-pass depth.
- **§2 local specificity** — S4 local research (real places) — **the box the current geo guard defers.**
- **§3 per-type patterns** — reused as the pass-3 drafting base (already built; now depth-filled).
- **§4 all 8 passes** — the deep writer.
- **§5 research** (PAA/Reddit/competitor/local) — the research layer.
- **§6 published + linked** — reuses publish + link-guarantor.
- **§7 rank-map topical-vs-geographic** — the decision brain.
- **§8 monthly loop + 12/mo floor + AI-detection** — the cadence + QA.
- **Word-count targets** (home 300-400/section, service 800-1500) — hit by the 8-pass depth (the box Slices 1-3 deliberately under-shot to avoid slop).

## Proposed SUB-SLICE plan (dependency order)
- **S4-0 — Provider spike + research schema [FIRST].** Decide providers (SERP/PAA, Reddit, Places, AI-detector, rank-grid CSV format), obtain keys, build a cost model, thin fetch-adapters, and the `content_research` table. De-risks the whole module (this is where cost/lead-time lives). Low build, high leverage.
- **S4-1 — Research layer.** The §5 fetchers → structured real research stored per keyword/location; operator "gather research for {keyword}" action + a review UI. The accuracy foundation.
- **S4-2 — Rank-map ingest + decision.** CSV import → `rank_map_snapshots` → top-3% vs threshold → the §7 topical/geographic recommendation dashboard; wire GEOGRAPHIC → `seedGeoPages`/wave-publish, TOPICAL → supporting-page creation.
- **S4-3 — The 8-pass deep writer + job runner.** `writePageDeep` (passes 1-8, fed S4-1 research, reusing the safety primitives) on the `content_jobs` durable runner. The biggest sub-slice.
- **S4-4 — Monthly production loop.** §8 cadence: rank-map decision → pick next 12-20 → batch 8-pass → publish per §6. Scheduled/triggered batch runner.
- **S4-5 — AI-detection QA + parallel outputs.** Per-page AI-detection scoring + human-QA flag; FAQ/meta/schema/images-with-prompts/YouTube parallel artifacts (some overlaps S4-3).

**First sub-slice = S4-0 (provider spike + `content_research` schema)** — the module's feasibility, cost, and lead-time all hinge on the external data providers; scope them + the accuracy-critical research store before any writer work.

---
**Recommended: extend (don't replace) the writer — a research-fed 8-pass `writePageDeep` on a durable `content_jobs` runner, reusing the anti-hallucination + link-guarantor primitives; a `content_research` store fed by REAL provider APIs (SERP/PAA, Reddit, Places, rank-grid CSV) so accuracy = real-data-in + constrained-writer; a rank-map decision brain driving the already-built geo (LOC-2/3) + topical (Core-30) machinery; a monthly batch loop. Additive multi-table (audit-safe). Start with S4-0 (provider spike + research schema) to settle cost/lead-time. Multi-slice; no build; commits held.**
