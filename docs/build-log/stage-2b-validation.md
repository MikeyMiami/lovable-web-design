# Build Log — Stage 2b Validation (tracked-link + Review Funnel system)

> Validation of Stage 2b (tracked_links table + 3 funnel routes) against `skills/features` (Review Request — tracked link + Review Funnel block) + guardrail-1 audit. Source: Lovable 2b report (round-trip tested via service-role SQL, NOT public HTTP). Validated 2026-06-09 (Claude Code).
> **Verdict: LOGIC VALIDATED — NOT CLOSED.** 1 blocker (public accessibility of `/r/` unproven + at-risk), 2 reconcile items (status-flip interpretation; reactivation key string). **Clear to start 2c** (notifications wiring — independent). No secret values.

## ✅ Validated (logic + security)
- **tracked_links** (additive migration): token PK + client_id, contact_id, sequence_key, created_at, clicked_at. Service-role writes; authenticated tenant-scoped SELECT (`is_admin()` OR `user_client_ids()`); no anon policy (public route uses supabaseAdmin). **`audit_tenant_rls()` = 0** → new tenant table passes guardrail 1. ✓
- **3 routes:** `GET /r/$token` (resolve → idempotent `clicked_at` → `review_clicked` event → exit active review/reactivation enrollment → 302 /r/rate); `GET/POST /r/rate` (1–5 stars, threshold default 4); `GET/POST /r/feedback`.
- **Funnel logic:** ≥threshold → `review_completed` + event → idempotent One-Year upsert → 302 to `clients.review_link`; <threshold → /r/feedback → (on submit) `negative_review` + `review_feedback` row + owner_email_stub event + notification row, NO One-Year. ✓ matches §4 branching.
- **One-Year upsert keys** `onConflict (client_id, contact_id, sequence_key)` + `ignoreDuplicates` — **exact match** to the `enrollments` UNIQUE constraint. ✓
- **Drip-exit = exit (terminal), not pause** ✓ correct (cron `status='active'` claim then excludes it). Both review + reactivation exit on click ✓ (§4/§9 share the funnel).
- Idempotent `clicked_at`; `review_clicked` event (powers "Review Link Clicks" stat); owner email as `owner_email_stub` event (stub discipline, real send at 1f/email layer). ✓

## 🟥 BLOCKER — public accessibility of `/r/` UNPROVEN + at-risk
The round-trip was tested **via service-role SQL** because "the preview URL is auth-gated for non-`/api/public` routes." That proves logic, not that a **logged-out customer** can reach `GET /r/<token>` (the funnel's whole purpose — SMS-link clickers aren't authed). `/r/` is **top-level, not under `/api/public/`** (the established public-bypass path) → it may inherit the app auth gate.
- **Must prove before close:** an actual **unauthenticated HTTP request** (incognito / curl, no session) → `GET /r/<token>` returns **302→/r/rate**, `GET /r/rate` returns **200** — NOT a login redirect.
- **If it redirects to login → broken; fix before close:** exempt `/r/*` from the root auth gate (allowlist), or relocate under the public path. (`/r/rate` + `/r/feedback` render HTML forms → if `/api/public/*` is API-handlers-only, prefer an auth-gate exemption over relocation.)
- Spec basis: §4 + §9d — funnel pages are served by the shared backend and must be publicly reachable.

## 🟡 Reconcile items — DECIDED 2026-06-09
- **Status-flip timing — DECIDED: flip-on-SUBMIT (keep Lovable's impl).** Rating is re-selectable and commits only on submit; `≥threshold` → `review_completed` on rate-form submit; `<threshold` → /r/feedback, `negative_review` flips on **feedback-form submit** (abandoned feedback ≠ marked). Skill reconciled: spec §4 + `features` §4 updated to flip-on-submit wording (+ re-selection note). *(Note: user's sketch said flip on rate-submit; actual impl flips negative on feedback-submit — skill now matches the impl.)*
- **Reactivation sequence_key — DECIDED: `reactivation`** (the 2a seed is canonical). Spec §9 (line 535) + `features` line 78 prose fixed `reactivation_drip` → `reactivation`. **STILL TO CONFIRM IN CODE:** the 2b report's prose says it exits "reactivation_drip" — UNVERIFIED whether the actual exit-on-click query (and future 2d enroll) uses `reactivation` or `reactivation_drip`. Folded into the Lovable prompt: confirm/fix to use sequence_key `reactivation` exactly. If it uses `reactivation_drip`, reactivation contacts never exit on click (over-texts past reviewers).

## Status
- **2b NOT closed** until: (1) public-access HTTP proof of `/r/` (BLOCKER); (2) status-flip decision + skill reconcile; (3) reactivation-key string confirmed = `reactivation`.
- **Clear to start 2c** (notifications wiring — independent of `/r/` reachability).
- 2e drip step-logic that consumes these tokens is deferred (2b scope = funnel-infra standalone).
