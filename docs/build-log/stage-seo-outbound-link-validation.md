# Stage SEO — Outbound authority link (in-content) — validation

> Point-in-time validation record, 2026-07-04. **Prompt-only weave inside `aiWritePage` (+ read `external_link`) + panel relabel; ZERO schema/migration.** Verified against `cloud-spark-setup` `origin/main` @ `07d1e0a` (`git diff ad33789..origin/main -- supabase/migrations` = empty). Build spec: `docs/phase-seo-outbound-link-build-spec.md`. Method basis: `seo-content` §6 (three link types).

## What shipped
The **outbound** in-content authority link (link type #2 of the three): `aiWritePage` weaves ONE natural in-content link to an operator-provided authority URL, reusing the existing `content_pages.external_link` column.

## Validation (PASS — against real code + operator run)
- **Weave present:** `aiWritePage` selects `external_link` (`seo.functions.ts:712`), computes `externalLink` (`:752`), adds the PROVIDED-CONTEXT line (`:803`) + the STRUCTURE rule emitting `<a href="…" target="_blank" rel="noopener">` (`:828`). ✅
- **Operator run:** a **set** `external_link` → woven as ONE natural in-content link, displays correctly. A **blank** `external_link` → **NO link, no hallucinated URL** (the guard holds — the AI never invents an authority URL). ✅
- **Guards intact:** internal editorial links still weave; anti-hallucination (STRICT ACCURACY) unchanged; one-`<h1>`; body-only `update`; one `generateText` call. ✅
- **Panel:** the existing `external_link` input relabeled "Outbound authority link"; saves via the existing `updatePage` patch (`:568`). ✅
- **AI-write-safe:** the URL lives in the `external_link` column, so it's re-woven from the column on every rewrite — never lost, never fabricated. ✅
- **Drift:** `seo.functions.ts` (`aiWritePage`: `external_link` in select + 2 prompt lines) + `admin.seo.tsx` (relabel). **No schema/migration** (`git diff` empty); `audit_tenant_rls()` unaffected. ✅

## Boundary (three link types — `seo-content` §6)
- **Internal** (to our pages) — AI-woven. Built.
- **Outbound** (to an authority source) — AI-woven, operator-provided URL. **This slice — DONE.**
- **Inbound** (backlinks on other sites) — OFF-SITE agency ops (chamber, paid links, sponsorships); NOT a page feature → the **Agency Link-Building Tracker** (roadmap agency-ops).

## Roadmap
**Outbound authority link → DONE (on-page).** Ledger row flipped in `docs/seo-completion-roadmap.md`. Inbound tracker stays PLANNED (agency-ops).
