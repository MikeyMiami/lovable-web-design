# Stage C-3d-2 — token-gated upload proxy (client-mode uploads) — validation

> Point-in-time validation record, 2026-06-29. **App-layer only — no schema, no migration, no fn-contract change, no new secret.** Verified against `cloud-spark-setup` `origin/main`. Build spec: `docs/phase-c-3d2-build-spec.md`.

## What shipped
- NEW public route **`/api/public/onboarding/upload`** — token-gated service-role upload proxy: validates the onboarding token (must be `active`) → derives its `draft_id` → uploads via `supabaseAdmin` to `public-assets/<draft_id>/<category>/…` → returns the public URL. Per-token + per-IP **rate-limit** + image **MIME/10MB caps**.
- NEW client helper **`uploadSiteImageViaProxy`** (`site-image-upload.ts`; `uploadSiteImage` unchanged).
- **`OnboardWizard`** uploads are **mode-aware** — agency mode keeps the direct `uploadSiteImage`; client mode routes through the proxy (threaded into the PhotosStep / logo / staff sites); client-mode uploads **un-gated**. Public `/onboard/$token` passes the `token`.

## Validation (PASS)
- Client-mode uploads work across **all** categories + staff (logged-out, via the proxy); SQL confirms files under the token's `draft_id` in the correct sub-paths (`logo/`, `site/work`, `site/gallery`, `site/about`, `site/services`, `site/staff`). ✅
- **Single-use:** claiming a token kills the whole link ("This link has already been used") at page validation. ✅
- Agency uploads unchanged; the proxy is the only service-role writer. ✅
- **Drift:** NEW `upload.ts` proxy + `uploadSiteImageViaProxy` + `OnboardWizard` mode-aware uploads (threaded into PhotosStep) + `onboard.$token.tsx` passes `token`; no migration/schema/fn/secret; `tsc` passes. ✅

## Schema flag
**NONE.** Existing `onboarding_tokens` + `public-assets` + `supabaseAdmin` + the rate-limit helper.

## Skills brought to parity (verbatim mirror handed)
- `onboard-from-form` — client-mode uploads now LIVE via the token-gated proxy; only the final submit remains gated (C-3d-3).

## Next (finale)
**C-3d-3** — public submit → shared `insertClientFull` (F3 extraction + self-fill regression) → pending-create + token claim + Turnstile on submit + mode-aware success. Read-only scope/plan first (sub-sliced).
