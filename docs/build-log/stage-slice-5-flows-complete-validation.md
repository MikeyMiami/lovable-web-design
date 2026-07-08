# Stage — Slice 5 (one-click client build: Core / Geo / Supporting) — validation [DONE]

> 2026-07-08. Verified against `cloud-spark-setup` `origin/main` (not Lovable prose). ZERO schema beyond S5-0's `content_flows` table; `audit_tenant_rls()=0`. Closes the three-flow one-click SEO automation. Follows S5-0 (`stage-s5-0-flow-orchestrator-validation.md`).

## What shipped — the shared orchestrator
Phased **N=3 fan-out** in `advanceContentFlow` (one call per poll, all under a ~22s budget < 30s Worker cap):
- **Phase A** — warm ONE cold town's OSM landmarks (sequential, once per distinct town), cached in `template_vars.seo.landmarks_by_town`.
- **Phase B** — research fan-out (≤3 concurrent), cached landmarks, `runPageResearch(persist:false)`, then **ONE merged** `template_vars.seo.research` write.
- **Phase C** — deep-write fan-out (≤3 concurrent), budgeted `advanceJobOnce` loop; writes only `content_pages`/`content_jobs` by id.
- **Single-writer-per-call** invariant (one `template_vars` write in A or B; one `content_flows` payload write at end) ⇒ race-free. Verified 10 pages / 10 research keys, no clobber. Same hardened 8-pass deep-writer (closed-set/scope/single-H1/leak) for all types.

## The three flows (each a thin config)
- **S5-1 Core** — `seedCoreThirty` → fan-out → gate **photos → publish-all** (all Core-30 published together, Day-0 topical foundation).
- **S5-2 Geo** — coverage-matrix cells → `seedGeoPages` (returns pageIds) → fan-out → ONE optional **awaiting-review** gate → publish the curated wave (curated cells = the wave; Day-30+ established branch).
- **S5-3 Supporting** — up-front **question-approval gate** (operator edits ONE AI-proposed on-topic question per under-ranking core page) → `seedSupportingPages` creates pages **SEQUENTIALLY** (the S4-C FAQ-append to a shared core parent must not race) → fan-out → optional review → publish (Day-30+ below-threshold branch). Parents restricted to core (server guard); bidirectional links (core→supporting FAQ editorial link-down + supporting→core back-link); additive idempotent `<!-- s4c-faq:slug -->` marker never rewrites core body.

## Validation (PASS)
- **Core:** full clean run — cancel/restart, fast parallel build (~25-35min → ~5-8min), photos gate → publish, all Core-30 published with correct content. ✅
- **Geo:** builds/writes/publishes the curated wave; town-cache spans the wave's towns. ✅
- **Supporting:** correct core parents, non-destructive additive FAQ, bidirectional links, published. ✅

## Fixes shipped along the way
- **`runGen` backoff** — fail-fast on 403 quota (the "Forbidden" was a hit monthly AI cap), retry 429/503/timeout. The DB auth was never the issue (flow always used service-role `supabaseAdmin`, identical to manual).
- **`setFlowStatus`** — was wiping `checkpoint` on resume→running (broke gate advance); now clears only on cancel.
- **`cancelledRef`** — stale latch broke every build after a cancel; reset at `pollLoop` top.
- **Terminal-state UI** — clear done/failed/cancelled messages (no frozen "N/N done · gating").
- **Completed-state on buttons** — the three build buttons turn green + show published counts (no standalone pills); `run test flow` (S5-0 dev scaffolding) removed; row reads core → geo → prepare+build-supporting.

## Expert-scope correction (important, cited)
The expert's **"authority link per page" = OFF-PAGE inbound backlinks** acquired externally (`ZKZnDORR0ds:228-243, 347-350, 383-384`) — NOT the tool's on-page outbound `external_link` (a separate minor practice, `FifSqbB0:~535`). So the misleading core "authority links" gate was **removed**, the per-page field **relabeled** "optional outbound reference link," and the real authority links captured as a **future per-page backlink-tracker slice** (`docs/phase-slice-backlink-tracker-scope.md`, `178a72b`). Also: page CTAs now offer **both** paths — a varied-anchor link to `/contact` (the real LeadForm → `/api/public/intake`) **and** the phone — previously phone-only.

## Roadmap
Slice 5 COMPLETE — the three-flow one-click SEO automation (Core Day-0 / Geo Day-30+ waves / Supporting Day-30+ below-threshold) built, validated end-to-end, polished. **Next SEO work:** the per-page **backlink tracker** (held scope) for the expert's real off-page authority links; optional on-page `external_link` ordering fix (capture before deep-write) if kept.
