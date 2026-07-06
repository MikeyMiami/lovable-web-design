# Stage S4-A — research-in-one-call + OSM accuracy gate — validation [DONE]

> Point-in-time validation record, 2026-07-06. **App-layer; ZERO schema; ~$0 external cost.** Verified against `cloud-spark-setup` `origin/main` @ `87e1dc7`. Spec: `docs/phase-slice-4-rescope-simplified.md` (S4-A). First sub-slice of the re-scoped Slice 4.

## What shipped
- **Settings competitor URLs** — `template_vars.seo.competitor_urls[]` (≤3), server-side-merge writer.
- **`gatherPageResearch`** — competitor read (server `fetch` of the operator's saved URLs → extract title/meta/headings/excerpt → ONE `generateText` → "what it takes to compete" summary; per-URL failures recorded, never fatal) + **local landmarks (AI-propose → OSM-verify)**: 8-12 candidates → each queried against **OpenStreetMap Nominatim** (free, no key; `User-Agent` with real contact via `OSM_CONTACT` env, sequential ≥1s/req) → **unverified dropped**, `{ name, osm_display_name }` kept. Optional operator `seed` passes through. Returns for review; does NOT auto-persist.
- **`savePageResearch`** — operator-approved set → `template_vars.seo.research[pageSlug]` (merge-overlay).
- **Review UI** (`admin.seo.tsx` `ResearchDialog`) — competitor summary + verified-landmark list (each shows `osm_display_name`, removable) + editable seed + fetch errors → save.
- **Writer wiring** — `aiWritePage` reads `seo.research[page.slug]` → adds COMPETITOR CONTEXT + VERIFIED LOCAL REFERENCE POINTS + seed to PROVIDED CONTEXT, and **allowlists the verified landmark names in the reject-validator `ctx`** so real provided places aren't flagged. The geo "don't invent landmarks" guard STAYS.

## Validation (PASS — live-confirmed)
- OSM verified REAL Akron landmarks (Stan Hywet Hall, University of Akron, Akron Children's, Lock 3 Park, Canal Park…); competitor research produced real "what it takes to compete" depth; the AI-written akron page **wove real landmarks naturally** (Stan Hywet Hall, University of Akron) with strong local + competitor-informed content. **No hallucinated places in output.** ✅
- Zero schema (all `template_vars.seo` JSON); ~$0 cost (server fetch + free OSM + existing gateway). ✅

## Landmark-match nuance [hardening follow-up]
OSM confirms "a place ~by this name exists here" but can return a **narrower/other entity** than the proposed name implies: validation saw **"Summit Mall"** return a wrong result and **"Quaker Square"** return the **Quaker Square Dorms** specifically. Output stayed clean (the writer used only the safest famous ones), but the gate is being tightened:
1. **Surface `osm_display_name`** next to each landmark — ALREADY in the UI (`admin.seo.tsx:1609-1611`).
2. **Light name-match "verify" flag** — when the OSM matched-entity name (first comma-segment of `display_name`) doesn't equal the proposed name, show a non-blocking amber "verify" chip so the operator catches the Quaker-Square→dorms class. **Do NOT auto-drop — surface for operator judgment.** (Small hardening prompt issued; keeps the operator-approve step meaningful.)

## Storage scale-watch [documented trigger]
Research lives in `template_vars.seo.research[pageSlug]` (JSON, zero schema) — fine at current volume. **Migrate to a `content_research` table if the JSON grows large across many pages per client** — S4-D's `content_jobs` infra introduces that table anyway.

## Roadmap
**S4-A → DONE.** Next: **S4-B** (30-day SEO timer + all-clients DUE view + "SEO Updated" reset + the B1/B2/B5 rank-check checklist + the manual `topical_status` signal + `close_towns`).
