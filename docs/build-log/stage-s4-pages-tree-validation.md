# Stage S4 tooling — Pages-list tree reorg + parent_slug + polish — validation [DONE]

> Point-in-time validation record, 2026-07-06. **`admin.seo.tsx` UI + ONE additive column.** Verified against `cloud-spark-setup` `origin/main` @ `e9bae4d` + the tint fix. Not a numbered sub-slice — SEO-panel tooling that makes the growing page set (30 core + geo + supporting → hundreds) navigable.

## What shipped
- **`parent_slug` structural pointer** — additive `content_pages.parent_slug text` (nullable). Set at creation: `addSupportingPage` → `corePageSlug`; `seedGeoPages` → `'home'` for primary else `subjectSlug`. **Store-the-relationship, don't re-parse** (geo→parent can't be derived from the slug cleanly, and primary geos have no subject in the slug — the fragile pattern we've refused throughout). `rebuildPageTree({clientId})` one-click backfill (supporting via the `<!-- s4c-faq:{slug} -->` marker scan; geo via slug/`home`; main → null). Additive, `audit_tenant_rls()=0`.
- **Tree/hierarchy view** — roots (home/category/service) collapsed by default; chevron expand; geo nests under its service/category (primary geos under home), supporting nests under its parent (core or geo); child-count badge on the chevron; every row at every depth keeps its full action set + workflow state-chip.
- **Group-filter chips** (home/category/service/geo/supporting) — flatten to selected type(s).
- **Compact/collapsible categories** (SEO-map editor) — Settings-density, collapsed once a map exists.
- **Polish pass** — removed the slug column; widened the panel (no horizontal scroll to reach actions); compacted row height; moved the chevron + count out of the title cell into a clean leading cell (alignment holds across depths); **de-emphasized "rebuild tree"** behind a ⋯/subtle spot (tooltip: rarely needed, new pages auto-nest).
- **Full-row type tint (edge-to-edge)** — each row lightly tinted in its type color across ALL columns (applied per-`<td>` + `border-collapse` so it spans, not just the left accent): home violet / category sky / service indigo / geo rose / supporting emerald; the saturated type pill + left accent stay the stronger cues.

## Validation (PASS)
- Migration additive; `audit_tenant_rls()` → **0**. `rebuildPageTree` populated existing rows correctly (supporting via FAQ marker, geo via slug/home). ✅
- Tree nests correctly; new pages auto-nest (`addSupportingPage`/`seedGeoPages` set `parent_slug`); child counts + chevrons + per-row actions/state-chips all intact; filters flatten by type; categories view compact. ✅
- Full-row tints span edge-to-edge in five distinct type colors; whisper-subtle + readable; "rebuild tree" de-emphasized. ✅

## Roadmap
Pages-tree tooling **DONE**. Slice 4 progress: S4-A (research) + S4-B (tier/cadence) + S4-C (supporting engine, +FAQ-preserve/workflow follow-up) + pages-tree tooling — all done. **Next: S4-D — the 8-pass deep writer + durable `content_jobs` job runner** (the ranking-grade upgrade; being decomposed into job-infra-first sub-steps). Then S4-E (monthly scheduler).
