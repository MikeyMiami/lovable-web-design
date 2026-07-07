# Stage — double-H1 strip — validation [DONE]

> 2026-07-07. Verified against `cloud-spark-setup` `origin/main`. ZERO schema. Shared writer post-processing (both deep 8-pass + single-pass aiWritePage).

## What shipped
`stripDuplicateH1(body, h1Disp)` in `writer.ts` — (1) removes ALL `<h1>…</h1>` from the body; (2) removes a LEADING heading (h1/h2/h3) whose text duplicates the page H1 (catches a title emitted as `<h2>`). Applied in pass 8 (`content-jobs.server.ts`) and single-pass `aiWritePage`, before the marker. The template owns the page H1 (`ctx.h1Disp`); the body now always starts at the first real `<h2>`.

## Root cause
AI non-compliance: the prompts already said "no `<h1>`", but the model sometimes emitted a title heading anyway. No deterministic guard existed → fixed with the strip (same discipline as the marker/link-guarantor).

## Validation (PASS)
- Cleveland page starts cleanly (template H1 + first content heading, no duplicated title); one H1 rendered. ✅
- Content quality confirmed ranking-grade: on-scope (only x3's real 8 services, no invented snow removal), accurate local grounding (verified landmarks + neighborhoods + climate), human-sounding, correct category structure + links. ✅ Zero schema.

## Roadmap
Deep-writer content pipeline is producing on-scope, real-service-only, locally-grounded, single-H1, ranking-grade content. Next: Batch 2 (#4 location-state accuracy). Held: S4-D5 UI formalization, Slice-5, wave/research batches (#2/#3 done or scoped).
