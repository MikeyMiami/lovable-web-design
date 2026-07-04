# Stage SEO-STORE-3c-2 — aiWritePage + saveSeoMap title-case — validation

> Point-in-time validation record, 2026-07-03. **App-layer on `golden-master-v1.7`; ZERO schema/migration.** The last SEO content-store slice. Verified against `cloud-spark-setup` `origin/main` @ `d51ba38` (`git diff b40c84e..origin/main -- supabase/migrations` = empty). Build spec: `docs/phase-seo-store-3c2-build-spec.md`.

## What shipped
- **`aiWritePage(pageId)`** (`seo.functions.ts`) — per-page real content via the AI gateway; a per-row **"AI-write"** button + a client-side sequential **"AI-write all"** batch on the Pages list; a persistent **ai-written badge**.
- **Title-case at the source** — a shared `titleCase()` applied in `proposeSeoMap`, `saveSeoMap`, `seedCoreThirty`, and `aiWritePage`.

## Validation (PASS — against real code + operator run)
- **`aiWritePage` = exactly one `generateText` call** (`seo.functions.ts:753`), model `gemini-3-flash-preview`; **body-only update** (`:769`) — `title/h1/slug/type/target_keyword/internal_links/status` untouched. Worker-safe (no fan-out). ✅
- **Content quality** — real locally-specific Columbus content (real neighborhoods/conditions), **starts at `<h2>`**, inline editorial `<a>` links, **no `<h1>`** (one-H1 preserved). ✅
- **Anti-hallucination guard holds** (`:726-733`) — no fabricated business name / founding year / warranty / awards / pricing; sticks to PROVIDED CONTEXT, writes around missing facts. ✅
- **Title-case fixed at source** — names title-cased into the editor by `proposeSeoMap` (`:215/221/226`), and by `saveSeoMap` (`:289-293`), `seedCoreThirty` (`:383/400/419/426/447/451/458/481`), `aiWritePage` prompt (`:710-712/741`) → titles/H1/keyword/meta/headings read "Hardscaping in Columbus"; **slugs stay lowercase**; **acronyms preserved** (HVAC/AC/LLC). ✅
- **Persistent ai-written badge** — `aiWritePage` prepends a stable `<!-- ai-written -->` marker (`:764-765`); the list query renders the badge from the marker → survives refresh/navigation (replaced the fragile `<h2>`-shape heuristic). ✅
- **UX** — Generate loading state, per-row AI-write spinner + toast, and the sequential AI-write-all batch (Worker-safe, per-page error collection) all working. ✅
- **Drift** — `seo.functions.ts` (+`aiWritePage`, +`titleCase` export, seedCoreThirty title-casing, hallucination-hardened prompt, ai-written marker), `admin.seo.tsx` (+AI-write button/batch/badge column/loading states). **No schema/migration** (`git diff` empty). `content_pages` RLS unchanged since STORE-1 → **`audit_tenant_rls()` remains 0**. ✅

## Two learnings (generalizable)
1. **AI factual hallucination → strict "only provided facts" prompt guard.** An LLM writing marketing copy will invent business names, founding years, warranties, awards, pricing — a real liability for real clients. Fix: an explicit PROVIDED-CONTEXT block + a STRICT ACCURACY RULES list ("use ONLY these facts; if a fact isn't provided, write around it — describe the service generally instead of fabricating"). **[Captured in `seo-content`.]**
2. **Durable stored marker > content-shape heuristic for state detection.** Detecting "was this AI-written?" by inspecting HTML shape (does it start with `<h2>`?) is fragile — any edit breaks it. Store a durable marker (`<!-- ai-written -->`, invisible in-browser) at write time and read state from that. Generalizes: **derive UI state from a persisted flag, not by re-parsing content.** **[Captured in `scratch-foundation` §6.]**

## Skills brought to parity (verbatim mirrors handed)
- **`admin-view`** — the SEO tab's Pages surface gains the per-row **AI-write** action + **AI-write-all** batch + the persistent **ai-written badge**.
- **`seo-content`** — AI-generation accuracy (only-provided-facts guard) + proper Title-Case/acronym casing.
- **`scratch-foundation` §6** — gotcha (4): durable stored marker over content-shape heuristics for state.

## SEO content-store arc — COMPLETE
STORE-1 store → STORE-2 render routes → 3a map → 3b seed → 3c-1 manage → 3c-2 write. The ongoing **content-automation tool** (supporting/geo + rank-map loop, `seo-content` §7/§8) is a separate future module. Next requested slice: **SEO images** (scope only).
