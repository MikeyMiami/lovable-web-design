# Stage SEO Slice 1 — content-quality wins (per-type §3 prompts + structure) — validation

> Point-in-time validation record, 2026-07-04. **Prompt-only inside `aiWritePage` (+ one read-addition: the client phone); ZERO schema/migration.** Verified against `cloud-spark-setup` `origin/main` @ `e5e7278` (`git diff d51ba38..origin/main -- supabase/migrations` = empty). Build spec: `docs/phase-seo-slice1-content-quality-build-spec.md`. Roadmap: `docs/seo-completion-roadmap.md` (Slice 1).

## What shipped
`aiWritePage` now branches its content prompt by page type to `seo-content` §3's patterns + enforces §1 "well-formatted" structure + a §4 conversion CTA, guards unchanged.

## Validation (PASS — against real code + operator run)
- **Per-type briefs match §3** (`seo.functions.ts:717-745`): **home** = overview hub (`:719-726`), **category** = mid-level router (`:727-733`), **service** = deep single-service (`:734-739`), **default** = deep single-topic (`:740-743`). ✅
- **Operator run on `test-landscaping` — output reads DISTINCTLY per type:** home = searcher-focused intro + `<h2>` per category routing outward (no deep-dive) + CTA; category (Design & Hardscaping) = category explainer + `<h2>` per service with inline editorial `<a>` + bulleted list + CTA; service (Hardscaping) = multi-section deep-dive with detailed "What's Included" bullets + a full PROCESS section (consultation→installation) + local specifics (freeze-thaw/slopes/runoff) + inline `<a>` back to parent category. ✅
- **Structure block** (`:772-782`): HTML-only, start at `<h2>`, ≥3 `<h2>` sections, `<h3>` where useful, short paras, one `<ul>`, closing CTA (phone-gated), Title Case + acronym preservation, ~400-700 words, inline editorial `<a>`. ✅
- **PROVIDED CONTEXT gained the phone** (`:758`); `publicPhone = twilio_number ?? phone_display` (`:696-697`); select adds `phone_display, twilio_number` (`:678`). `test-landscaping` has no phone → CTA correctly used **no fabricated number**. ✅
- **Guards intact:** STRICT ACCURACY block unchanged (`:760-767`); one-H1 (start-at-`<h2>`); one `generateText` call (`:790`); **body-only** `update({ body, updated_at })` (`:806`); `<!-- ai-written -->` marker/badge; anti-hallucination held (no invented name/year/warranty/pricing). ✅
- **Drift:** `seo.functions.ts` (`aiWritePage` only) + phone in its select. **No schema/migration** (`git diff` empty). `audit_tenant_rls()` unaffected. ✅

## Boundary confirmed (roadmap-anchored)
Slice 1 makes the per-page writer follow **§3 (per-type) + §1 (well-formatted) + §1b (accuracy) + §6 (editorial links)** in **one `generateText` call**. Still **deferred to the content-automation tool (Slice 4):** §5 research inputs (PAA/Reddit/competitor/real local), the §4 8-pass refinement (burstiness/perplexity/human-bookends/AI-detection/QC), real pricing, and the §7-8 rank-map + monthly loop. "Structurally on-method now; ranking-grade depth later."

## Skills brought to parity (verbatim mirrors handed)
- **`seo-content`** — the per-page writer now implements §3 per-type patterns + §1 structure (the lighter first pass); 8-pass/research/rank-map stay the tool.
- **`admin-view`** — the AI-write action now produces page-type-differentiated content + a CTA using the client's public phone.

## Roadmap
**Slice 1 → DONE** in `docs/seo-completion-roadmap.md` ledger. Next: **Slice 2 — images v2** (`images jsonb`, 2-3/page, template interleave).
