# Stage C-3 — Social Links onboarding capture — validation

> Point-in-time validation record, 2026-06-29. **App-layer / UI only — no schema, no migration, no fn-contract change.** Verified against `cloud-spark-setup` `origin/main` @ `1e328ea`. Build spec: `docs/phase-c-social-links-build-spec.md`.

## What shipped
- The wizard's **"Reviews" step renamed to "Social Links"** (`STEPS`), and the step now collects, alongside the Google Business Profile link: **Instagram / Facebook / LinkedIn** URLs (public, "shows on your website" tag). Each field (incl. GBP) has an **"I don't have one"** box that disables/clears it.
- Assembly: a `socialLinks` object (only the set, non-"I don't have one" platforms) → **`fields.socialLinks`** → `clientPatch` → **`clients.social_links`** (jsonb `{platform: url}`). GBP honors its "I don't have one" (omitted when checked).
- `ReviewSummary` "Reviews" section renamed **"Social Links"**, showing GBP + Instagram + Facebook + LinkedIn (URL / "Doesn't have one" / "Not provided").
- Works in **both** modes (shared `OnboardWizard`); the public submit already accepts `fields.socialLinks` via `CreateClientFullInput` → `ClientFields.socialLinks`.

## Why zero schema/fn
`clients.social_links` (jsonb) + `ClientFields.socialLinks` (`z.record(z.string())`) + `clientPatch` (`p.social_links = f.socialLinks`) all pre-existed; admin Settings already edits `social_links` (Brand & Site "Social links (JSON)" textarea). The wizard fields just feed `fields.socialLinks`.

## Validation (PASS)
- Social-links onboarding capture works (validated): the renamed Social Links step captures the 3 socials + GBP; "I don't have one" omits a platform; `clients.social_links` holds `{instagram, facebook, linkedin}` (only set ones); review summary shows them; both agency self-fill and client mode.
- **Drift:** `OnboardWizard.tsx` (state + STEPS rename + Social Links fields + assembly `socialLinks` + GBP `noGbp`) + `ReviewSummary.tsx` (section rename + rows); no migration/schema/fn; `tsc` passes.

## Known UI gap (next change — scoped separately)
The captured socials are NOT yet surfaced as **friendly per-field editors** in admin Settings — only the raw "Social links (JSON)" textarea. Friendly Instagram/Facebook/LinkedIn inputs in admin (merge-safe into `social_links`, dual-writer re-seed of the JSON textarea) = `docs/phase-c-social-links-admin-build-spec.md`.

## Skill brought to parity (verbatim mirror handed)
- `onboard-from-form` — step 6 renamed "Social Links"; captures GBP + Instagram/Facebook/LinkedIn → `clients.social_links`; "I don't have one" per field; field→destination row.
