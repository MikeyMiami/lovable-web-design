# Stage SVC-2a — onboarding structured services (name + price) — validation

> Point-in-time validation record, 2026-07-05. **App-layer; ZERO schema.** Verified against `cloud-spark-setup` `origin/main` @ `ad3e82a` (`git diff 1180b06..origin/main -- supabase/migrations` = empty). Build spec: `docs/phase-svc-2-onboarding-services-build-spec.md`.

## What shipped
Onboarding now captures services as structured per-service rows (name + optional price range), written into the submitted `template_vars` — identical shape to the Settings SVC-1 editor via a shared normalizer:
- **Shared `normalizeServices`** — `src/lib/seo/services.ts` (`:49`), pure/client+server-safe (slug via `slugify`, dedupe, reserved-guard, omit blank prices, derive `services` string).
- **`updateClientServices`** refactored to use it (`seo.functions.ts:405`) — Settings + onboarding produce identical output.
- **OnboardWizard** — structured service rows (name + price_min – price_max, add/remove) replacing the free-text textarea; submit builds `template_vars.services_structured` + derived `services` via `normalizeServices` (`:7/:280`). Public token flow writes it in the submit (no admin-gated call).

## Validation (PASS)
- Onboarded a new concrete client → `template_vars.services_structured` = **4 rows with proper slugs + per-service prices** (`concrete-foundation` $1000-$5000, `concrete-driveway` $1000-$4000, `concrete-patio` $4000-$6000, `concrete-fill-repair` $200-$500); flat `services` **derived + in sync**. ✅
- **Onboarding + Settings identical** — Settings → Services & Pricing shows the same rows (shared `normalizeServices`). ✅
- **Drift:** `services.ts` (new shared normalizer) + `seo.functions.ts` (`updateClientServices` uses it) + `OnboardWizard.tsx` (structured rows + submit build). **No schema/migration.** ✅

## Roadmap
**SVC-2a → DONE.** Next: **SVC-2b** (per-service photos at onboarding — upload-route relax + per-service dropzones → `site_assets.by_service`). SVC-4 (Photo-Board pre-fill), SVC-5 (Assets tab) remain planned.
