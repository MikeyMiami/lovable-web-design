# Stage — S4-D5 (finalize deep-write UI) — validation [DONE]

> 2026-07-07. Verified against `cloud-spark-setup` `origin/main`. ZERO schema.

## What shipped
Deep-write finalized from the S4-D1 test harness into a real 497-gated action:
- Real **"deep write"** label + accurate tooltip (full 8-pass ranking-grade); live progress **pass X/8** + **section i/N**; page body updates on done (Batch-1 invalidation).
- **Deep-vs-ai-write = pick-one:** deep write emphasized as the primary write for 497 clients; ai-write the quick single-pass alternative (tooltips clarify use one, not both); non-497 shows only ai-write.
- **Resume:** interrupt (reload) → "resume deep write" continues from the persisted `current_pass` (content_jobs durability).
- **Status surfaced in the row:** failed errors on hover + an amber **"scope?"** badge when the job flagged `scopeWarnings` (return extended to carry them, zero schema — payload already held them).
- **Workflow + timeline wiring:** deep-write participates in the per-row lifecycle emphasis; the Pages "i" panel references the master timeline + deep-vs-ai.

## Validation (PASS)
- Real label/tooltip, live pass/section progress, page updates on done; pick-one clarity; resume-from-pass; failed-error + scope? badge surfaced; "i" panel references the timeline. ✅ 497-gated; single-pass `aiWritePage` untouched. Zero schema.

## Roadmap — DEEP-WRITE ENGINE FULLY FINALIZED
The full stack (structure → research + state-anchored landmarks → closed-set/scope-hardened 8-pass deep-write → single-H1 → geo/supporting → cadence/waves → research cleanup → finalized deep-write UI) is built + validated. **All Slice-5 prerequisites are met.** Next: **Slice 5** — the three one-click flows orchestrating these finalized steps (decomposed: queue infra → Flow 1 Core → Flow 2 Geo → Flow 3 Supporting).
