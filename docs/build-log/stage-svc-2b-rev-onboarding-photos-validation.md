# Stage SVC-2b-rev — onboarding per-service photos (Photos-step rework) — validation + LIVE-BUG FIX (capture side)

> Point-in-time validation record, 2026-07-05. **App-layer; ZERO schema.** Verified against `cloud-spark-setup` `origin/main` @ `fb43f60` (`git diff ad3e82a..origin/main -- supabase/migrations` = empty). Build spec: `docs/phase-svc-2b-rev-onboarding-photos-build-spec.md`. Scope + ripple: `docs/phase-svc-2b-photos-rework-scope.md`.

## ⚠️ Documented LIVE BUG this fixes (capture side)
Onboarding wrote **`site_assets.work`** (`Asset[]`) + a broad **`site_assets.services`** array, but the **template reads `site_assets.work_examples`** (`string[]`) and expects a **slug-keyed `services` map** (`services?.[slug]`). The keys/shapes never matched → **real clients' uploaded photos NEVER reached the live template** (every real client silently fell back to `NICHE_DEFAULTS` stock images). This was a live bug, not just a missing feature. **SVC-2b-rev fixes the CAPTURE side** — onboarding now writes **`site_assets.by_service[slug]`** (the slug-keyed shape the template expects). The **RENDER side** (point the template at `gallery` + `by_service[slug]`) is **SVC-2b-template** (next). Together they close the bug.

## What shipped (capture side)
- **Photos step reworked:** per-service uploaders auto-pulled from the client's `servicesRows` (photos stored on the rows; UI in the Photos step — add/remove/rename graceful); **"Previous Work" (`work`) removed**; broad "Services" dropzone → **per-service**; **Gallery → "Gallery / More Photos"** (label only; `site_assets.gallery` key unchanged). Submit builds `site_assets.by_service` + `gallery`/`about`/`staff` — **no `work`, no broad `services`.** Upload route accepts `site/services/<slug>` (`upload.ts` `SERVICE_CAT_RE`). `ReviewSummary` updated.

## Validation (PASS)
- `x3-landscaping` onboarded → `template_vars.site_assets.by_service` captured **only the photographed services** (`flower`, `hardscaping`, `landscaping-services` = 1 image each); `gardening` has a service row but **no `by_service` entry** (graceful omit — no photos). ✅
- `by_service` slugs **match `services_structured`** slugs. ✅
- **No `work`, no broad `services`** written. ✅
- **Drift:** `OnboardWizard.tsx` (servicesRows photos + Photos-step per-service section + PHOTO_CATS remove work/services + relabel gallery + submit by_service), `upload.ts` (`SERVICE_CAT_RE`), `ReviewSummary.tsx`. **No schema/migration.** ✅

## Roadmap
**SVC-2b-rev → DONE.** Next: **SVC-2b-template** (render-side fix — priority; real clients' photos finally render), then **SVC-2b-board** (Photo-Board reads `by_service`). See the roadmap live-bug flag.
