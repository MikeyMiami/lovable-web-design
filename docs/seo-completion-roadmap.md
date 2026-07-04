# SEO Completion Roadmap — source of truth for the SEO build sequence

> **This is the authoritative sequence for fully realizing the scoped SEO method** (`/seo-build` + `/seo-content`, derived from the 5 expert transcripts; full analysis in `docs/seo-system-analysis-and-skill-plan.md`; gap audit in `docs/seo-system-audit-2026-07-03.md`). Every future SEO slice stays anchored to this doc. **Each slice updates its status HERE on validation.**
>
> **Context:** the SEO content-store arc is COMPLETE (STORE-1 store → STORE-2 render routes → 3a map → 3b seed → 3c-1 manage → 3c-2 write) — it delivers single-city topical Core-30 pages that mechanically work. This roadmap closes the gap between "mechanically works" and "follows the full expert method." Sequenced for template synergy + quick universal lift first. All on `golden-master-v1.7`; discipline in `docs/project-overview-and-handoff.md`.

## The 4-slice path

### Slice 1 — Content-quality wins (per-type §3 prompts + structure) — **IN PROGRESS**
- **Gap closed:** `aiWritePage` writes the same generic body for every page type; local pages aren't well-formatted. Closes the `seo-content` §3 (per-page-type patterns) + §1 "well-formatted" gaps in the per-page writer.
- **Change type:** **prompt-only** (inside `aiWritePage`) + one read-addition (the client phone for the CTA). **ZERO schema.**
- **What it does:** branches the content prompt by `type` — **home** (talk-to-searcher + category H2s/links), **category** (explain category + service H2s/links), **service** (deep single-service: why / what's-included bullets / process / local) — mapped 1:1 to §3; adds ≥3 `<h2>` sections, short paragraphs, a bulleted list, and a CTA with the real business phone. Preserves all locked guards (anti-hallucination, one-H1, inline editorial `<a>`, Title Case, `<!-- ai-written -->` marker).
- **Sets up:** the ≥3-section structure enables Slice 2's image interleaving.
- **Spec:** `docs/phase-seo-slice1-content-quality-build-spec.md`.
- **Status:** IN PROGRESS (prompt written, held for review).

### Slice 2 — Images v2 (`images jsonb`, 2-3/page, template interleave) — PLANNED
- **Gap closed:** pages have no images (or one `og_image`); `seo-content` §1 wants client photos, well-placed. Makes published pages look like real local-business pages.
- **Change type:** **schema-additive** — one migration `alter table public.content_pages add column images jsonb;` (nullable). Passes `audit_tenant_rls()` (adds no policy; anon RPCs return `cp.*` so `images` is auto-included; no new grant). Plus panel + template work.
- **What it does:** `images jsonb` = `[{ url, alt, position:'hero'|'inline-1'|'inline-2', width, height }]`, assigned from `site_assets` (auto-suggest + manual picker), **never touched by `aiWritePage`** (AI-write-safe by construction — same principle that made `og_image` safe, generalized to N). Template **interleaves by position** (hero above/below H1; inline-1 after 1st `<h2>`; inline-2 after 3rd) with alt/dims/lazy (`seo-build` §5). `og_image` derived from the hero. Photo-thin → assign what exists; Option B AI-gen is a later gap-filler (separate spike).
- **Supersedes:** the earlier IMAGES-1 (og_image-only, zero-schema) MVP — replaced by this because the model needs 2-3 images + professional layout.
- **Status:** PLANNED.

### Slice 3 — Multi-location (LOC-1 → LOC-2 → LOC-3) — PLANNED [biggest gap]
- **Gap closed:** the business model is multi-location (`service_area[]` = up to 14 towns) but the whole Core-30 is single-city (`service_area[1..n]` unused; **no geo pages exist or can be created**). Closes the entire geographic-relevance half (`seo-content` §7-8, `seo-build` §2). **Also delivers geo/supporting page CREATION** (render routes exist; no writer today).
- **Change type:** mixed. **LOC-1** = prompt/JSON-only (add `locations[]` to `template_vars.seo`, AI-seed from `service_area` + curate). **LOC-2** = **schema-additive** (`content_pages.geo_area text`, additive; passes audit) + `seedGeoPages` (draft `type='geo'` rows per selected location/service) + a **coverage matrix** (services × locations) + **batch-generate** (Worker-safe sequential). **LOC-3** = geo-aware `aiWritePage` (reads `geo_area` for local context; genuinely-local prompt) + **publish-in-waves**.
- **Method reconciliation [LOCKED]:** GENERATION is batched across all locations as **drafts** (satisfies "not one-at-a-time"); PUBLISHING follows §7 (topical Core-30 first; geo published in waves as topical authority builds, rank-map-informed). Never blanket-publish geo at launch (the §2/§7 city-swap / "wasted months" anti-pattern). Geo pages must be **genuinely local**, never city-swap clones.
- **Status:** PLANNED.

### Slice 4 — Ongoing content-automation tool — PLANNED [the big future module]
- **Gap closed:** no ongoing content system — no monthly articles, no rank-map decisioning. Implements the full method the per-page writer intentionally doesn't.
- **Change type:** its own module (likely schema + fns + jobs); scoped later.
- **What it does:** the `seo-content` **§4 8-pass pipeline** (research→brief → outline → section-by-section → burstiness → perplexity/de-AI → human-bookends → conversion → QC + AI-detection scoring), **§5 research inputs** (People-Also-Ask / Reddit / competitor / local research), the **§7 rank-map topical-vs-geographic decision** (ingest the Lead-Snap CSV → top-3% vs threshold → build topical or geographic), and the **§8 monthly production loop** (batch of ~12-20 pages/mo, published per cadence). Writes `content_pages` rows (supporting/geo) — never edits the frontend.
- **Status:** PLANNED.

## The boundary — per-page writer vs content-automation tool [LOCKED]
This line defines where we "follow the full method" vs run "the lighter first pass":
- **The per-page writer (`aiWritePage`, built + Slice 1) DOES:** one `generateText` call; per-type §3 patterns; §1 well-formatted structure; §1b anti-hallucination (only-provided-facts); §6 editorial in-content links; Title Case; deterministic titles/H1/meta from the map. A **structure-correct, factually-safe first pass** — for the Core-30 at build + on-demand per-page rewrite.
- **The content-automation tool (Slice 4, deferred) DOES:** the full §4 8-pass human-passing refinement; §5 real research inputs (PAA/Reddit/competitor/local); §7 rank-map decisioning; §8 monthly cadence + AI-detection QA; ongoing supporting/geo production. The **ranking-grade depth** the first pass intentionally omits.
- **Net:** the built writer gets a page *structurally correct and safe*; the tool makes it *ranking-grade*. Slices 1-3 perfect the first pass + coverage; Slice 4 adds the depth loop.

## Status ledger (update on each validation)
| Slice | Scope | Schema | Status |
|---|---|---|---|
| 1 | content-quality (per-type §3 + structure) | prompt-only (+1 read) | **IN PROGRESS** |
| 2 | images v2 (`images jsonb`, 2-3/page, interleave) | additive (1 column) | PLANNED |
| 3 | multi-location (LOC-1/2/3 + geo/supporting creation) | mixed (LOC-2 additive) | PLANNED |
| 4 | ongoing content-automation tool (8-pass + research + rank-map loop) | its own module | PLANNED |

> **Source of truth.** Build in this order (template synergy + universal lift first). Prior SEO arc: `docs/build-log/stage-seo-store-*`. Audit basis: `docs/seo-system-audit-2026-07-03.md`.
