# Stage — Batch 3 (research cleanup on delete #3) — validation [DONE]

> 2026-07-07. Verified against `cloud-spark-setup` `origin/main`. ZERO schema (merge-writes to `template_vars.seo.research`).

## What shipped
- `removeResearchKeys(admin, clientId, slugs[])` shared helper (re-read seo → delete keys → write back, no-clobber).
- **`deletePage`** fetches slug+client_id → removes `seo.research[slug]`; **`deleteGeoPages`** removes the deleted geo slugs' research; **`deleteAllClientPages`** clears `seo.research` wholesale.
- **`clearOrphanedResearch({clientId})`** + a UI action — removes any `research[slug]` with no matching `content_pages` row (sweeps pre-fix orphans), reports count.

## Validation (PASS)
- Page deletes (single / geo / all) auto-clean the corresponding research; other research + `template_vars` keys intact (merge, no clobber). ✅
- "clear orphaned research" sweeps pre-fix orphans; valid research untouched; deep-write/gatherPageResearch still read existing entries. ✅ Zero schema.

## Roadmap
Research lifecycle now consistent with page lifecycle. **Last prerequisite before Slice 5: S4-D5** — formalize the deep-write UI (497-gated action + progress/resume + deep-vs-ai-write clarity + job status/scopeWarnings in the row + workflow/timeline wiring). Then **Slice 5** (the three one-click flows).
