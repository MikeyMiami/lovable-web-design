# Stage — scope hardening (closed-set service list + home/category scope) — validation [DONE]

> Point-in-time record, 2026-07-07. Verified against `cloud-spark-setup` `origin/main` @ `735a002`. ZERO schema (services already in `template_vars.seo`). Both writers (deep 8-pass + single-pass `aiWritePage`) via shared `buildProvidedContextBlock`.

## What shipped
- **`offeredServices` closed set:** `loadWriteContext`/`WriteContext` now expose the client's COMPLETE real service list (all `primary_services[].name` + all `categories[].services[].name`). `buildProvidedContextBlock` adds a **"SERVICES THE BUSINESS OFFERS — COMPLETE, CLOSED set"** block for EVERY page type + the rule **"write ONLY about services on this list; never mention a service not listed, even a typical-for-the-industry one (e.g. snow removal)."**
- **Home/category scope (Layer-2):** `buildTypeBrief` home/category reworded to **overview + brief 50-100-word blurb + link per OWN listed child**, no detailed multi-service sections, only-listed services (the home "breadth across its services" open invitation removed).
- **Deterministic scan extended:** the pass-8 sibling-service-H2 scan gate now includes `home` + `category` (was `service|geo` only) — catches drift into *other offered* services. Invented (non-offered) services are handled prompt-side (closed set) + the QC pass (honest limitation: the scan can't enumerate non-offered services).

## Root cause (fixed)
The deep writer previously got **NO service list (a) + no closed-set rule (c)** — so "cover the breadth of a landscaper" → **invented snow removal** (a service x3 doesn't offer). The closed-set list + "only these" rule directly kills it.

## Validation (PASS)
- Re-deep-write x3's Landscaping **home + Cleveland/Westlake geo pages** → **invented snow-removal / plowing / ice content GONE**; all three pages cover only x3's real 8 services (Gardening, Raking, Floral Design, Mulching, Hedge Trimming, Dirt, Stonework, Tree Planting) with accurate local grounding. ✅
- The on-scope **Floral Design service page** (and other on-list pages) preserved exactly — local grounding + depth intact. ✅ ZERO schema.

## Follow-up (separate)
Double-H1 bug surfaced (deep-write body emits a title heading duplicating the page H1 despite the "no <h1>" prompts) — deterministic strip fix scoped next.

## Roadmap
Scope hardening DONE (Layer-1 structural map fix earlier + this Layer-2 prompt hardening + closed-set accuracy). Deep writer produces on-scope, real-service-only, locally-grounded content. Next: double-H1 strip; then S4-D5 (deep-write UI formalization). Held: Slice-5, wave/research batches (#2-#4).
