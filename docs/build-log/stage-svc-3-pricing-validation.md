# Stage SVC-3 — per-service pricing into aiWritePage — validation

> Point-in-time validation record, 2026-07-05. **`aiWritePage`-only; ZERO schema.** Verified against `cloud-spark-setup` `origin/main` @ `1180b06` (`git diff 5fc7810..origin/main -- supabase/migrations` = empty). Build spec: `docs/phase-svc-3-pricing-build-spec.md`.

## What shipped
For a **service** page, `aiWritePage` looks up the price range in `template_vars.services_structured` (by slug, `slugify(name)` fallback) and adds it to PROVIDED CONTEXT with permission to state THAT range only:
- `priceLine` compute, service-type-only (`seo.functions.ts:890-908`); a **`normalizePrice`** helper (`:898`) that prefixes a `$` on bare numbers while preserving `$500` / `5k`.
- Conditional PROVIDED CONTEXT insert (`:965`).
- Guard amended (`:979`): *"Do NOT invent pricing … beyond the Price range provided in PROVIDED CONTEXT (if any)."*

## Validation (PASS)
- Service with a price range set (SVC-1 Settings) → AI-writes the range **naturally with dollar signs** ($500 - $5000); **bare numbers get `$`**, `5k`/`$500` preserved (currency-normalize). ✅
- Price-less service → **no pricing** stated. ✅
- **Home/category** pages → no price line (service-only). ✅
- **Anti-hallucination holds** — no invented prices; reject-list validator clean. ✅
- **Drift:** `seo.functions.ts` (`aiWritePage` priceLine + normalizePrice + PROVIDED CONTEXT insert + amended guard). **No schema/migration.** ✅

## Roadmap
**SVC-3 → DONE.** Next: **SVC-2** (onboarding structured capture). SVC-4 (Photo-Board pre-fill), SVC-5 (Assets tab) remain planned. *(Note: full map-service ↔ structured-service slug binding — when the AI-curated map slug diverges from the structured slug — is a later admin.seo enhancement; SVC-3's `slugify(name)` fallback covers the common case, omits pricing cleanly otherwise.)*
