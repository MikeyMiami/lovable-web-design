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

## 🟡 Reconcile items
- **Status-flip timing (deviation from skill-literal).** §4 reads `<threshold selection → Negative Review → /r/feedback` (flip **on rating click**). Lovable flips **on feedback submit** (so abandoners aren't marked). One-Year handoff is correct either way; only the abandoner's status label differs (flip-on-submit leaves low-rate-then-abandon contacts in limbo + uncounted in negative-review stats). **DECIDE:** flip-on-rating (skill-literal) vs flip-on-submit (update §4 to match if kept). Lean: flip-on-rating.
- **Reactivation sequence_key string.** 2a **seeded `reactivation`**; this report exits "**reactivation_drip**" (spec prose §6/§9 also says `reactivation_drip`). If the exit query uses `reactivation_drip` but enrollments use the seeded `reactivation`, **reactivation contacts never exit on click → over-texting past reviewers** (the Google-flag risk reactivation avoids). **Confirm 2b exit + future 2d enrollment use the exact seeded key `reactivation`**; fix spec prose §6/§9 to drop `_drip` (keep the seeded key, it's in the DB). *(Seed↔spec↔code naming drift — missed at 2a, surfaced here.)*

## Status
- **2b NOT closed** until: (1) public-access HTTP proof of `/r/` (BLOCKER); (2) status-flip decision + skill reconcile; (3) reactivation-key string confirmed = `reactivation`.
- **Clear to start 2c** (notifications wiring — independent of `/r/` reachability).
- 2e drip step-logic that consumes these tokens is deferred (2b scope = funnel-infra standalone).
