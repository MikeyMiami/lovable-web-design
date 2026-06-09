# Build Log — Stage 2b Validation (tracked-link + Review Funnel system)

> Validation of Stage 2b (tracked_links table + 3 funnel routes) against `skills/features` (Review Request — tracked link + Review Funnel block) + guardrail-1 audit. Source: Lovable 2b report (round-trip tested via service-role SQL, NOT public HTTP). Validated 2026-06-09 (Claude Code).
> **Verdict: PASS — CLOSED 2026-06-09.** Funnel logic validated; the public-reachability blocker was caught (top-level `/r/*` was auth-gated → dead funnel), fixed by relocating to `/api/public/r/*`, and **proven by direct unauthenticated curl**; reactivation key resolved (`reactivation`); status-flip decided (flip-on-feedback-submit) + skill reconciled. 2c clear. No secret values.

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
- **Reactivation sequence_key — RESOLVED: `reactivation`.** Lovable patched + confirmed the exit query now uses `["review_request","reactivation"]` (all 7 seeded keys verified). Spec §9 + `features` prose fixed `reactivation_drip` → `reactivation`. ✅

## ✅ BLOCKER — public accessibility: CAUGHT, FIXED, PROVEN
Was broken as flagged: top-level `/r/*` returned **302→auth-bridge for logged-out users** (funnel dead). **Fixed by relocating all 3 routes to `/api/public/r/*`** (the auth-exempt public path from 1d). **Proven by direct unauthenticated curl** on the stable preview (no auth header):
- `GET /api/public/r/<token>` → **HTTP 302** → `location: /api/public/r/rate?token=...` (NOT auth-bridge) ✅
- `GET /api/public/r/rate` → **HTTP 200**, real star form (`<title>Rate your experience</title>`, `form action="/api/public/r/rate"`) (NOT a login wall) ✅
- Inter-route redirects + form actions verified end-to-end: `$token.ts`→`/api/public/r/rate`; `rate.ts` form→`/api/public/r/rate`; `rate.ts` below-threshold→`/api/public/r/feedback`; `feedback.ts` form→`/api/public/r/feedback`. All `createFileRoute` paths registered. ✅

All docs/skills route references renamed `/r/*` → `/api/public/r/*` (uniform; `features` §4 carries an anti-regression note: do NOT relocate to top-level).

## Status
- **2b CLOSED — PASS.** Public reachability proven; reactivation key resolved; status-flip decided + reconciled; route relocation applied + propagated + mirrored into master copies.
- **2c clear to start** (notifications wiring).
- 2e drip step-logic that consumes these tokens is unblocked (steps_json contract proven at 2a; funnel infra proven here); generates tracked links at `/api/public/r/<token>`.
