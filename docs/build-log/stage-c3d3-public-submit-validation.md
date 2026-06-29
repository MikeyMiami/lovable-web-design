# Stage C-3d-3 — public submit (F3 + client-facing submit) — validation; Turnstile (3c) BACKLOGGED

> Point-in-time validation record, 2026-06-29. **ZERO schema/migration.** Verified against `cloud-spark-setup` `origin/main` @ `7d5f95f`. Build spec: `docs/phase-c-3d3-build-spec.md`.

## What shipped (3a + 3b)
- **C-3d-3a — F3 refactor:** extracted **`insertClientFull(supabaseAdmin, { slug, fields, sendSettings, submission, status })`** (insert `clients` + upsert `send_settings` + write the submission JSON) from `createClientFull`; `createClientFull` now calls it with `status='pending'`. **External signature unchanged.** `CreateClientFullInput` exported (reused by the public route).
- **C-3d-3b — public submit:** NEW public route **`/api/public/onboarding/submit`** — validates the payload (`CreateClientFullInput`) + per-token/IP rate-limit → **claim-first** token (`status active→claimed`, single-use) → **`insertClientFull` forces `status='pending'`** (server-side; ignores any client-sent status/client_id) with **slug-collision auto-resolve** (suffix) → back-links `created_client_id` on the token. `OnboardWizard` client-mode `onCreate` posts to it; submit **un-gated**; **mode-aware success** — client sees **"All Set! / Thanks for submitting! You'll receive login details soon."** (no add-another / no Admin link); agency success unchanged.

## Validation (PASS — per build report; the loop closes)
- Client-facing submit + mode-aware success **live** end-to-end: logged-out `/onboard/$token` → fill + upload (proxy) → Submit → "All Set!" → a `status='pending'` client created + token claimed (`created_client_id` linked) → appears in `/agency` Onboarding → `/admin/review` → Finalize & Invite → active.
- **Single-use** (claim-first) holds; **slug-collision auto-resolve** works; **agency self-fill regression** OK (still creates a pending client via the shared helper).
- **Drift:** `onboarding.functions.ts` (`insertClientFull` + export) + NEW `submit.ts` + `OnboardWizard.tsx` (client submit + un-gate + success); no migration/schema/fn-contract change; `tsc` passes.

## C-3d-3c — Turnstile — BACKLOGGED (decided against for now)
**Not building Turnstile on the public submit.** Rationale: the submit is already gated by the **single-use token + per-token/per-IP rate-limit**, and links are **private one-time links sent to known clients** (not a public signup). Worst case is one junk pending client the agency deletes from the queue — not a real threat. **Revisit only if onboarding becomes publicly accessible** (open signup). The 3c prompt is retained in the build spec, marked BACKLOGGED, for if/when that changes.

## Skills brought to parity (verbatim mirrors handed)
- `onboard-from-form` — client submit LIVE (public submit route + "All Set!"); Turnstile backlog note.
- `scratch-foundation` — submit-time create via the shared `insertClientFull` + token claim.
- `agency-view` — pending clients arrive from BOTH agency self-fill AND client-submitted links.

## Milestone
**C-3d COMPLETE (3a+3b); C-3c+C-3d onboarding arc done.** Full lifecycle: agency generates/ emails a one-time link → client fills the public wizard (uploads via proxy) → submits → pending client → agency Onboarding queue → `/admin/review` → Finalize & Invite → active. App-layer on `golden-master-v1.7` + one additive table (`onboarding_tokens`).
