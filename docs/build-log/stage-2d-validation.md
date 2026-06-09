# Build Log — Stage 2d Validation (enrollment paths + caps + guards)

> Validation of Stage 2d (5 enrollment paths, caps, guards) against `opt-in-forms` + `features`. Source: Lovable 2d report. Validated 2026-06-09 (Claude Code).
> **Verdict: VALIDATED EXCEPT FIRST-STEP TIMING — NOT CLOSED.** Everything validates except a **systematic `next_run_at` first-step bug** (every drip's first action delayed by its step0→step1 gap). Fix is enrollment-layer only (2a seed is correct). No secret values.

## ✅ Validated
- **5 paths + sequence_keys match the 2a seed** (`SELECT key FROM sequences WHERE client_id IS NULL`): mobile Review Request → `review_request` (mobile_enroll); day-10 Auto-Enroll → `review_request`; website Lead Form → `lead_form_business_hours`/`lead_form_after_hours` (branched at submit on `send_settings.business_hours`, client tz) (web_form); Discount form → `discount_claim` (+ exits one_year) (web_form); Reactivation CSV → `reactivation` (import).
- **`source` server-set on all paths** (web_form/mobile_enroll/import hardcoded in handlers; never from body). `client_id` from `resolveTenant()` (Origin/Host→allowed_origins, slug fallback) on public routes / RLS-scoped caller lookup on authed fns. ✓
- **Caps:** daily_enrollment_cap (review, default 50, from send_settings) + reactivation 50/day both counted from `events`/enrollments since `startOfLocalDayUtc` (client-tz midnight — reuses the runner helper). ✓ Reactivation **2/20min** confirmed (3rd in window → `reactivation_20min_cap`). ✓ Blocked → `enrollment_blocked` event.
- **Guards:** re-enrollment guard (active enrollment on client_id+contact_id+sequence_key) + UNIQUE backstop (confirmed `already_enrolled`); reactivation dedup (prior reactivation OR `review_completed`) confirmed both cases; opt-out (`opted_out_at` → `contact_opted_out`); discount→one-year exit (`exitOneYearOnDiscountClaim` sets active `one_year_followup`→`exited` + `drip_exit` event, confirmed exited=1). ✓
- No new tables → `audit_tenant_rls()` not re-run (correct; no schema change… unless fix option (a) adds a column — then re-run).

## 🟥 BLOCKER — systematic first-step `next_run_at` bug
Lovable's report states it: *"next_run_at for first step: Computed from step 0 offsetMinutes."* But `offsetMinutes` = gap from THIS step → NEXT (1e walk-test confirmed), so `step[0].offsetMinutes` is the step0→step1 gap, **not** the initial delay before step 0. Result: every drip's first action is delayed by the wrong amount.

**Correct rule:** `next_run_at = now + INITIAL_DELAY[sequence_key]` (enrollment-side, per-drip — same pattern 2a set for missed-call's 1-min). NOT `step[0].offsetMinutes`.

| Drip | Lovable | Correct INITIAL_DELAY | Source |
|---|---|---|---|
| review_request | +5760 (4d) ❌ | 0 (now) | §4 SMS1 = day 0 |
| reactivation | +1440 (24h) ❌ | 0 (now) | §9 immediate + 24h×3 |
| one_year_followup | +80640 (56d) ❌ | +43200 (30d) | §5 SMS1 = day 30 |
| discount_claim | +2min ⚠️ | 0 (if step0=internal) | §7b immediate internal; confirm step0 = internal vs SMS |
| lead_form_business_hours | not shown ⚠️ | +0.5 (30s) | §7 wait 30s → internal; verify value |
| lead_form_after_hours | +0 ✅ | 0 | correct (coincidental — step0 offset is 0) |
| missed_call | +1min ✅ | +1min | already enrollment-side (2a) |

**Fix (enrollment-layer; 2a seed unchanged):** options —
- (a) data-driven: add `sequences.start_delay_minutes` (default 0), seed per drip, enrollment reads it (additive migration + 1-column re-seed; re-run `audit_tenant_rls()`). Cleaner / single-source.
- (b) constant map: documented `INITIAL_DELAY` keyed by sequence_key in the enrollment layer (no migration; second source of truth).
Lean (a). Also confirm discount step0 (internal vs SMS) + the lead_form_business_hours value.

## Status
- **2d NOT closed** until the first-step `next_run_at` is fixed + re-verified for ALL drips (esp. one_year=30d, discount, lead_form_business_hours). Cheap now; 2e walks drips on top of it.
- 2e remains blocked on this (its first send fires off `next_run_at`).
