# Stage S4-D2 — real AI passes 1-3 (brief → outline → sections) — validation [DONE]

> Point-in-time validation record, 2026-07-06. Verified against `cloud-spark-setup` `origin/main` @ `e951413`. ZERO schema (writes to `content_jobs.payload`). No `content_pages` write (S4-D4 does that).

## What shipped
- **`writer.ts`: `buildProvidedContextBlock(ctx)`** extracted (PROVIDED CONTEXT + STRICT ACCURACY RULES incl. the geo rule); `buildWritePrompt` recomposed from it — **byte-identical** (aiWritePage unchanged).
- **`content-jobs.server.ts` real passes 1-3** (reusing `loadWriteContext`/`buildTypeBrief`/`buildProvidedContextBlock`/`runGen`, one pass per call, grounded):
  - **Pass 1** research→brief → `payload.brief`.
  - **Pass 2** BRIEF → H2 outline (parsed `[{h2,angle}]`) → `payload.outline` + dynamic `payload.sectionCount`.
  - **Pass 3** section-by-section, one `runGen` per H2 against `payload.sectionCount`, each into `payload.sections[]` (`section_idx` sub-progress). Passes 4-8 still no-op.

## Validation (PASS — live-confirmed)
- Deep-write on **hardscaping-westlake** ran clean end-to-end: brief grounded (20 years, Westlake); outline = **6 H2s** with **real verified landmarks** (Esperanza Elementary, Bay Village, Rocky River); **6/6 sections drafted**; status `done`; no error — all in `payload` (**no page write**, as expected for D2). ✅
- Multi-pass generation produces **grounded, locally-specific** content (verified landmarks appear; no fabricated facts — the grounding block is in every AI pass). ✅
- Resumable (interrupt mid-pass-3 resumes from `section_idx`); `aiWritePage` byte-identical after the recompose. ✅

## Note — view-live link
The view-live `origin` resolution (`admin.seo.tsx:787-802`) is intact in `origin/main`: `allowed_origins[0] → template_vars.company_website_link → TEMPLATE_PREVIEW_BASE` with the `/cloud-spark-setup/` backend-domain guard. No separate regression fix distinct from that logic observed.

## Roadmap
**S4-D2 → DONE.** Next: **S4-D3** — passes 4-7 polish (join `sections[].html` → `payload.draft`, then burstiness → de-AI/perplexity → human bookends → conversion, each on `payload.draft`, grounded, resumable; no page write). Then S4-D4 (pass 8 QC + final `content_pages` write), S4-D5 (UI/resume/workflow wiring).
