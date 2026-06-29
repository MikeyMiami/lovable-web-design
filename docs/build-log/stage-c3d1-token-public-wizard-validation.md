# Stage C-3d-1 — token model + generate-link + public mode-aware wizard (+ no-expiry + email-link) — validation

> Point-in-time validation record, 2026-06-28. **One additive table (`onboarding_tokens`); everything else app-layer.** Verified against `cloud-spark-setup` `origin/main` @ `ef5d7b8`. Build specs: `docs/phase-c-3d1-build-spec.md` + `docs/phase-c-3d1-email-link-build-spec.md`.

## What shipped
- **`onboarding_tokens`** table (additive migration `20260628235901`): `token` (PK), `draft_id` (pre-submit upload namespace), `status` (`active`|`claimed`) + `claimed_at` (**single-use**, idempotent claim), `expires_at` (retained but **no longer checked — no time-expiry**, set far-future), **`created_client_id`** (nullable FK, set on submit; **named NOT `client_id`** to stay out of the tenant-table catalog scan), `created_by`, `prefill jsonb`. **Service-role-only** (RLS on, no policies; revoked from anon/authenticated).
- **`generateOnboardingLink`** (admin server fn) + **`validateOnboardingToken`** (public, no-auth, service-role read; returns `valid`/`claimed`/`not_found`).
- **`OnboardWizard`** extracted to `src/components/onboard/OnboardWizard.tsx`, **mode-aware** (`agency` | `client`); authed `/onboard` renders agency mode; public **`/onboard/$token`** renders client mode. Client-mode uploads + submit **gated** pending C-3d-2/3.
- **/agency Onboarding** card: "Generate onboarding link" (copyable URL) + **"Email this link"** composer — editable subject/body (default + `localStorage` + Reset; `{link}` token) → opens the agency's mail client via **`mailto:`** (real-address send; no provider/secret).
- **No-expiry** (change #1): links are single-use only; time-expiry removed from the validate path.

## Validation (PASS)
- Columns correct (`created_client_id`, NO `client_id`); **`audit_tenant_rls()` clean / 0** (table not in the tenant scan). ✅
- Generate link works; **single-use, no time-expiry**. ✅
- Public `/onboard/$token` renders the **client-mode wizard logged-out** (emailed the link, opened it). ✅
- **Email-this-link:** `mailto:` opens pre-filled, `{link}` → real URL, delivered, link worked. ✅
- **Self-fill regression:** authed `/onboard` still creates a pending client (`bot-buddiezs` → `status='pending'`) after the `OnboardWizard` extraction. ✅
- **Drift:** migration + `onboarding.functions.ts` (2 new fns; `createClientFull` untouched) + NEW `OnboardWizard.tsx` + `_authenticated/onboard.tsx` (renders agency mode) + NEW `onboard.$token.tsx` + `agency.onboarding.tsx` (generate-link + email composer); `tsc` passes.

## Schema flag
**`onboarding_tokens`** is the one additive table (migration `20260628235901`). `createClientFull` unchanged — **F3 (shared `insertClientFull`) + the self-fill-after-helper regression are owed in C-3d-3.**

## Skills brought to parity (verbatim mirrors handed)
- `onboard-from-form` — wizard now mode-aware (`OnboardWizard`); client mode via public `/onboard/$token`; uploads/submit gated pending C-3d-2/3.
- `scratch-foundation` — the `onboarding_tokens` model (single-use, no-expiry, `created_client_id`, service-role-only).
- `agency-view` — Onboarding card: generate-link + email-this-link composer (mailto + localStorage template).

## Next
**C-3d-2** — upload proxy: token-gated service-role upload to `public-assets` under `draft_id`; Turnstile + rate-limit; client mode uses it (replaces the "enables shortly" gate). Then **C-3d-3** — public submit → shared `insertClientFull` (`status='pending'`) + token claim + mode-aware success (F3 + regression here).
