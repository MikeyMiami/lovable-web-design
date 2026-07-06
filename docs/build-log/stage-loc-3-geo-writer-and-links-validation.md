# Stage LOC-3 — geo-aware aiWritePage + wave-publish + internal-link guarantor — validation [DONE — COMPLETES Slice 3]

> Point-in-time validation record, 2026-07-06. **App-layer; ZERO schema.** Verified against `cloud-spark-setup` `origin/main` @ `c2c6b89` (geo writer) + the follow-up link-guarantor. Specs: `docs/phase-loc-3-*`, `docs/phase-geo-links-guarantor-build-spec.md`. Live-verified on `professional-landscpaing-template.lovable.app`.

## What shipped (LOC-3 + link-guarantor)
- **Geo-aware `aiWritePage` (`case "geo"`)** — page `select` now includes `area_served`; for `type='geo'` the **town (`area_served`) is the city context** (not the primary city), so `cityDisp` + all brief machinery target the town. New `case "geo"` brief writes the subject-in-that-town (why locals need it / what's included / process / get-started) and weaves the parent-service + `/locations` links.
- **Stricter geo guard [LOCKED]** — a geo-only STRICT-ACCURACY rule: do NOT invent local landmarks, neighborhoods, streets, ZIPs, climate/weather, routes, or ANY place-specific detail not in PROVIDED CONTEXT. Honest-but-general until Slice 4 adds real local research. (Geo pages are the highest city-swap-slop risk.)
- **Wave-publish** — `publishGeoWave({clientId, limit})` publishes the oldest-N `type='geo'` drafts (`status='published'`, `published_at=now()`), returns `{published, remaining}`; UI = geo-draft count + batch-size + "publish wave" + a topical-first reminder. Publishing in controlled batches, not all at once.
- **Deterministic internal-link guarantor** — after generation + the reject-validator retry, before the `<!-- ai-written -->` marker: for each `page.internal_links`, if the final body lacks a real `<a href="{href}">`, append a short `Related: <a>…</a> · <a>…</a>` line. Quote-agnostic + regex-escaped href match (no substring false-positives). Only fires for omitted links; compliant pages stay clean. All page types.

## Validation (PASS — live-confirmed)
- Geo AI-write produces real, town-relevant copy referencing the town by name, **no invented local specifics**; non-geo pages unchanged. ✅
- Wave-publish releases geo drafts in batches; they render at `/service-area/{slug}` + list on `/locations`. ✅
- **Link-guarantor:** `gardening-akron` (previously "Service areas" as PLAIN TEXT) now gets a deterministic `Related:` line with real in-content links (`/services/gardening`, `/locations`); `flower-akron` (already compliant) gets **nothing appended** (no-op); `ai-written` marker intact. ✅
- Zero schema across LOC-3 + guarantor. ✅

## BUG 1 — verified NON-ISSUE (recorded for the record)
Report was: geo internal links pointed at `preview--cloud-spark-setup.lovable.app` (the backend) and 404'd. **Root cause = a viewing-context artifact, NOT stored data.** `seedGeoPages` stores **relative** hrefs (`/services/{slug}`, `/locations`); `aiWritePage` feeds the AI those relative hrefs; the template `normalize` + `ContentPageView` + `renderMarkdownLite` all preserve relative — **no origin/base-prepend anywhere**. Live-fetch of `/locations`, `flower-akron`, `gardening-akron` confirmed **every link is relative and resolves to the correct template domain — ZERO `cloud-spark-setup` links**. The backend URLs appear only when the template is viewed through the *backend project's* Lovable preview iframe (a relative `/locations` resolves against `preview--cloud-spark-setup`). Same class as the view-live bug — a domain-context confusion.
**Decision: NO CHANGE. Do NOT switch to absolute** — relative links are correct and **portable to each client's own marketing/custom domain**; a hardcoded absolute marketing URL would break custom domains. Verify by clicking from the real template domain, not the backend preview.

## Roadmap
**Slice 3 (multi-location) → DONE:** LOC-1 → LOC-1b → LOC-1b-final → LOC-2 → LOC-3 + link-guarantor. Geo pages generate (one/town, skip primary), AI-write genuinely-local-but-honest content, publish in waves, render live, and carry guaranteed in-content links. Remaining major SEO items: **Slice 4** (content-automation tool) and the **TextGrid/A2P** launch track. Backlog: dedicated `clients.marketing_url` field (cleaner than reusing `allowed_origins[0]` for view-live).
