# Phase C — Social Links on the onboarding wizard — build spec [BUILT + VALIDATED 2026-06-29]

> App-layer / UI only — **no schema, no fn change** (`clients.social_links` + `ClientFields.socialLinks` + `clientPatch` pre-exist; admin Settings already edits `social_links`). The "Reviews" step is renamed "Social Links" and captures Instagram/Facebook/LinkedIn (+ the existing GBP link), each with an "I don't have one" box, → `clients.social_links`. Validated against `cloud-spark-setup` `origin/main` @ `1e328ea`.

## As-built (= the prompt that shipped)
- `OnboardWizard.tsx`: state `instagramUrl/facebookUrl/linkedinUrl` + `noInstagram/noFacebook/noLinkedin` + `noGbp` (all `""`/`false`). `STEPS` "Reviews" → **"Social Links"**.
- Social Links step: keep the GBP link (private, agency lookup) + add an "I don't have one" box; add **Instagram / Facebook / LinkedIn** URL inputs (public, "Shows on your website" tag), each with an "I don't have one" box that disables/clears the input.
- Assembly: build `socialLinks` (only non-empty, non-"I don't have one" platforms) → `fields.socialLinks` (→ `clientPatch` → `clients.social_links`). GBP omitted when `noGbp`.
- `ReviewSummary.tsx`: "Reviews" section → **"Social Links"** showing GBP + IG/FB/LinkedIn (value / "Doesn't have one" / "Not provided").
- Both modes (shared component); the public submit accepts `fields.socialLinks` via `CreateClientFullInput` → `ClientFields.socialLinks`.

## Validation — PASS
`clients.social_links` holds `{instagram, facebook, linkedin}` (only set ones); "I don't have one" omits a platform; review summary shows them; agency self-fill + client mode both work. Zero schema/fn; `tsc` passes.

## Follow-on (separate)
Friendly per-field social editors in **admin Settings** (merge-safe into `social_links` + dual-writer re-seed of the JSON textarea) — `docs/phase-c-social-links-admin-build-spec.md`.
