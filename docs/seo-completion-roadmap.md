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
- **Spec:** `docs/phase-seo-slice1-content-quality-build-spec.md`. Validation: `docs/build-log/stage-seo-slice1-content-quality-validation.md`.
- **Status:** ✅ **DONE — validated 2026-07-04** (`cloud-spark-setup` @ `e5e7278`; prompt-only, zero schema; home/category/service read distinctly per §3).

### Slice 2 — Images v2 (`images jsonb`, 2-3/page, template interleave) — PLANNED
- **Gap closed:** pages have no images (or one `og_image`); `seo-content` §1 wants client photos, well-placed. Makes published pages look like real local-business pages.
- **Change type:** **schema-additive** — one migration `alter table public.content_pages add column images jsonb;` (nullable). Passes `audit_tenant_rls()` (adds no policy; anon RPCs return `cp.*` so `images` is auto-included; no new grant). Plus panel + template work.
- **What it does:** `images jsonb` = `[{ url, alt, position:'hero'|'inline-1'|'inline-2', width, height }]`, assigned from `site_assets` (auto-suggest + manual picker), **never touched by `aiWritePage`** (AI-write-safe by construction — same principle that made `og_image` safe, generalized to N). Template **interleaves by position** (hero above/below H1; inline-1 after 1st `<h2>`; inline-2 after 3rd) with alt/dims/lazy (`seo-build` §5). `og_image` derived from the hero. Photo-thin → assign what exists; Option B AI-gen is a later gap-filler (separate spike).
- **Supersedes:** the earlier IMAGES-1 (og_image-only, zero-schema) MVP — replaced by this because the model needs 2-3 images + professional layout.
- **Spec:** `docs/phase-seo-slice2-images-v2-build-spec.md`. Validation: `docs/build-log/stage-seo-slice2-images-v2-validation.md`. Assignment reconcile: `docs/phase-seo-image-assignment-reconcile.md`.
- **Status:** ⚠️ **Part A (storage + per-page panel) DONE — validated 2026-07-04** (`cloud-spark-setup` @ `ad33789`; migration `images jsonb`, `audit_tenant_rls()=0`, `updatePage.images`, `deleteAllClientPages`/Reset Core-30, per-page `ImagesManager`). **Part B (template interleave render) PENDING** — images are STORED but do NOT render on published pages until Prompt B ships to the marketing template (hero + inline interleave, `og:image` from hero). Send after snapshotting the template.

### Slice 2.5 — Operator Photo-Board (assignment UX) — PLANNED
- **Gap closed:** clients dump photos into broad buckets and don't tag which photo is which service, so photo→page mapping is a HUMAN (operator) decision. The per-page dropdown `ImagesManager` (Slice 2) works but is slow for bulk curation. The board makes assignment fast + visual, and works for every client (existing dumped-photo + future).
- **Change type:** **UI/UX only — ZERO schema.** Layered on the shipped `images jsonb` storage; reuses `updatePage({images, og_image})`, `allAssetsFlat` (pool), `readImageDims`, `buildAlt`, `PageImage`.
- **What it does:** a **pool** of all `site_assets` merged (dedup'd, category chips/filter) → **drag-and-drop** onto per-page **3-slot drop-zones** (hero/inline-1/inline-2) → reuses the existing **auto-suggest** as a first pass + per-slot clear + an **"empty slots: N"** per-row indicator. **Augments** (does not replace) the per-page dialog manager. Writes the same `images` jsonb via the same fn.
- **Status:** PLANNED (next build).

### Slice 2.6 — AI-fill (gap-filler) — PLANNED [needs an image-gen spike]
- **Gap closed:** pages/slots with no suitable real photo. Per `seo-content` §1 "client photos best, AI images the fallback."
- **Change type:** **new infra** (image-gen model/endpoint + likely a new runtime secret + a `fetch` integration + storage-to-`public-assets`). NOT a schema change to `content_pages` (writes the same `images` jsonb).
- **What it does:** an agency-triggered **"Fill empty slots with AI"** (per-page + global) that touches **only** slots still empty after human placement; **one gen call per empty slot**, sequential Worker-safe batch; generate → **persist bytes to `public-assets`** (`{client_id}/ai/{page-slug}-{position}-{uuid}.png`, never hotlink) → write into `images` jsonb; guarded prompt (**no text/logos/signage/faces/storefronts/awards** — anti-hallucination for imagery); deterministic alt.
- **Gating unknown [SPIKE FIRST]:** the Lovable AI gateway is **text-only** today (`createLovableAiGatewayProvider` → OpenAI-compatible text). Confirm a gateway image model exists, else pick a provider (OpenAI `gpt-image-1` / Google Imagen / Replicate-Flux) + secret + cost ceiling. Spike one image end-to-end into `public-assets` before building.
- **Status:** PLANNED (after Slice 2.5 + the spike).

### Onboarding per-service photo capture (data-quality feeder) — PLANNED [independent, parallel-OK]
- **Gap closed:** photos arrive untagged; the operator sorts everything. Capturing photos **per service at intake** pre-maps them to service pages AND flags AI-gen needs early.
- **Change type:** **additive JSON only** — after the client lists services, onboarding renders **per-service upload categories** (from their listed services) + an **"I don't have photos of this service"** option → stored as `template_vars.site_assets.by_service[serviceName] = [{url,path}]` (additive to the jsonb; **no DB schema change**). Touches `OnboardWizard` + the submit path + a seed/board **name→slug match** step.
- **Interacts with:** the board (pre-places tagged photos into matching service pages' slots) + AI-fill (no-photo services become AI-gen candidates).
- **Caveats:** future clients only; friction if the service list is long (mitigated by "I don't have this"); onboarding free-text services vs AI-derived Core-30 map services need a name match (operator reconciles in the board).
- **Status:** PLANNED (most valuable once Slice 2.5 exists; can run parallel).

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
| 1 | content-quality (per-type §3 + structure) | prompt-only (+1 read) | ✅ **DONE** (2026-07-04) |
| 2 | images v2 (`images jsonb`, storage + per-page panel) | additive (1 column) | ⚠️ **Part A DONE** (2026-07-04) · **Part B (template render) PENDING** |
| 2.5 | operator Photo-Board (pool + drag-drop assignment) | UI-only (reuses storage) | PLANNED (next) |
| 2.6 | AI-fill (gap-filler for empty slots) | new infra (image-gen spike) | PLANNED (post-spike) |
| — | onboarding per-service photo capture (data feeder) | additive JSON (template_vars) | PLANNED (parallel) |
| 3 | multi-location (LOC-1/2/3 + geo/supporting creation) | mixed (LOC-2 additive) | PLANNED |
| 4 | ongoing content-automation tool (8-pass + research + rank-map loop) | its own module | PLANNED |

> **Source of truth.** Build in this order (template synergy + universal lift first). Prior SEO arc: `docs/build-log/stage-seo-store-*`. Audit basis: `docs/seo-system-audit-2026-07-03.md`.
