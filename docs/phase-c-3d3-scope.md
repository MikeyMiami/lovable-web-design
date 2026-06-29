# Phase C — C-3d-3 (finale): public submit → pending-create + token claim + Turnstile + mode-aware success — READ-ONLY SCOPE

> Scope/plan only — **no code, no build prompt.** Grounded on `cloud-spark-setup` `origin/main` @ `eb40f65`. Three distinct risky pieces (F3 refactor of validated code · net-new Turnstile frontend · public submit) → **sub-sliced 3a/3b/3c**.

## The loop this closes
Client opens `/onboard/$token` → fills the wizard (uploads live via the C-3d-2 proxy) → **submits** → a `status='pending'` client is created (service-role) + the token is claimed → it appears in the agency **Onboarding queue** (C-3c-2c) → `/admin/review` (C-3c-2b) → **Finalize & Invite** (C-3c-1/2a) → active. Everything downstream of submit is already built.

## Verified facts
- `buildPayload()` (`OnboardWizard.tsx:321`) returns `{ slug, fields, sendSettings, submission }` — **mode-agnostic** (slug auto-derived; `site_assets` URLs already in `fields.templateVars` from the proxy uploads). `onCreate()` (`:324`) calls `createClientFull` (agency path). Client submit is gated.
- `createClientFull` (`onboarding.functions.ts:84`) handler does: insert `clients` (`status:"pending"`) → upsert `send_settings` → write the submission JSON. **F3 extracts exactly this** into a shared `insertClientFull`.
- **No Turnstile frontend widget** exists in this repo (backend `verifyTurnstile` only) → adding it is net-new (script + `VITE_TURNSTILE_SITE_KEY` + a widget component).
- The success screen (`:352`) + the authz gate (`:340`) are agency-only; both already keyed on `isAgency`.
- `onboarding_tokens` has `status`/`claimed_at`/`created_client_id` (set on submit). Public-route + service-role + rate-limit pattern = `intake.ts`.

## Schema / fn flags
| # | Item | Schema? | Notes |
|---|---|---|---|
| F3 | extract `insertClientFull` shared helper | **No schema; app-layer refactor of validated code.** `createClientFull` external signature UNCHANGED. | **Regression owed:** agency self-fill `/onboard` must still create a **pending** client after the insert logic moves into the helper. |
| — | public submit route `/api/public/onboarding/submit` | **No schema; new public route.** | Service-role create via `insertClientFull` (forces `status='pending'` server-side — never trusts a client-sent status/client_id) + token **claim** (`status active→claimed`, set `created_client_id`) + rate-limit (+ Turnstile in 3c). |
| — | token claim + `created_client_id` write | **No schema** — existing columns. | Single-use: `update … set status='claimed', claimed_at=now(), created_client_id=$id where token=$ and status='active'`. |
| ENV | Turnstile | **No schema.** New **public env `VITE_TURNSTILE_SITE_KEY`** (site key, not a secret) + **`TURNSTILE_SECRET_KEY`** (backend; already referenced by `verifyTurnstile`). | **Fails-OPEN until both keys are set** (existing LIVE gate #6) — the token + rate-limit still gate meanwhile. |

**Net: ZERO schema/migration.** The touches are: F3 internal refactor (signature unchanged), a new public route, and the Turnstile env/widget. `createClientFull` contract is preserved.

## Slicing recommendation (sub-slice — your call was right)
- **C-3d-3a — F3 refactor (isolate first).** Extract `insertClientFull(supabaseAdmin, { slug, fields, sendSettings, submission, status })` from `createClientFull`; `createClientFull` calls it with `status='pending'`. **No new behavior.** Validate: agency self-fill still creates a pending client (the regression check), `tsc` passes. Lowest-risk, pure refactor of validated code — proven independently before anything builds on it.
- **C-3d-3b — public submit + wire client submit + mode-aware success.** New `/api/public/onboarding/submit` (token claim-first → `insertClientFull` status='pending' → write `created_client_id`; rate-limit; **slug-collision auto-resolve**). Client-mode `onCreate` posts to it (with the token) instead of `createClientFull`; un-gate the client submit. Mode-aware **success screen** (client: "All Set! — you'll get login details by email soon", no Admin/another-client buttons; agency: existing). Validate end-to-end: logged-out submit → pending client in the Onboarding queue; token now single-use-dead; agency Finalize & Invite works.
- **C-3d-3c — Turnstile on submit.** Add the Turnstile **frontend widget** (script + `VITE_TURNSTILE_SITE_KEY`) to the client-mode submit step; the public submit verifies `turnstile_token` via `verifyTurnstile` (fails-open if unset). One challenge on the one create action. Validate: with keys set, a failed challenge blocks submit; without keys, fails-open (token + rate-limit still gate).

*(3a → 3b → 3c. 3b closes the functional loop; 3c hardens it. The link isn't sent to real clients until all three land, so building 3b before 3c is safe.)*

## Open questions to settle (before 3b)
1. **Slug collision in client mode** — the client can't edit the (hidden, auto-derived) slug, so a collision can't be fixed by them. → *Rec: the public submit **auto-resolves** collisions (append a short suffix); the agency can rename in Settings later. (Agency self-fill keeps today's "already taken → edit" behavior.)*
2. **Claim ordering** — *Rec: **claim-first** (atomic `where status='active'`) for single-use integrity; with slug auto-resolve, the create won't fail on the common path. (If create still fails, surface an error; agency regenerates a link.)*
3. **Turnstile keys** — will you set `VITE_TURNSTILE_SITE_KEY` + `TURNSTILE_SECRET_KEY`? If not yet, 3c ships fails-open (token + rate-limit still protect). Confirm.
4. **Client success copy** — confirm: header "All Set!", body "Thanks for submitting! You'll receive an email with login details soon." (no "add another client" / no Admin link).
5. **Submit trust boundary** — confirm the public submit **forces `status='pending'`** and ignores any client-sent status/client_id; trusts only the payload fields + the server-derived token/draft_id. (Rec: yes.)

## Files / skills touched (enumeration)
**Code:** `onboarding.functions.ts` (extract `insertClientFull`; `createClientFull` calls it — 3a). NEW `src/routes/api/public/onboarding/submit.ts` (3b). `OnboardWizard.tsx` (client `onCreate` → public submit; un-gate submit; mode-aware success — 3b; Turnstile widget — 3c). NEW Turnstile widget component + `VITE_TURNSTILE_SITE_KEY` (3c).
**Skills:** `onboard-from-form` (client submit live → pending-create + token claim; success copy), `scratch-foundation` (the `insertClientFull` shared helper + the claim-on-submit), `agency-view` (note client submissions now arrive in the Onboarding queue), `platform-spec-source-of-truth` (client-facing onboarding complete). Mirrors handed per-slice after validation.

---
**Read-only scope. ZERO schema/migration. F3 = internal refactor (signature unchanged, regression-checked). Sub-slice 3a (F3) → 3b (public submit + success) → 3c (Turnstile). Settle Q1–Q5, then I write the C-3d-3a build prompt.**
