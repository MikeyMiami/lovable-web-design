# Build Log — Stage 2d Validation (enrollment paths + caps + guards)

> Validation of Stage 2d (5 enrollment paths, caps, guards) against `opt-in-forms` + `features`. Source: Lovable 2d report. Validated 2026-06-09 (Claude Code).
> **Verdict: PASS — CLOSED 2026-06-09.** All paths/caps/guards validated; the systematic first-step `next_run_at` bug was fixed data-driven (new `sequences.start_delay_minutes` column; enrollment reads it instead of `step[0].offsetMinutes`). All 7 first-run times now match the skill; `audit_tenant_rls()=0` after the additive migration. **2d closed, 2e clear.** No secret values.

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

## ✅ Fix — RESOLVED (2026-06-09): `sequences.start_delay_minutes` (data-driven)
Added `sequences.start_delay_minutes int NOT NULL DEFAULT 0` (additive; column comment documents `offsetMinutes` = gap-to-next vs `start_delay` = pre-first-step). `enroll.server.ts` now reads `start_delay_minutes` (tenant-override wins) → `next_run_at = now + start_delay*60s`. `audit_tenant_rls()=0` after the migration (column add, no policy change). Logged to `events.payload.start_delay_min`. All 7 verified vs skill:

| Drip | start_delay_minutes | first-run | skill |
|---|---|---|---|
| review_request | 0 | now | §4 SMS1 = day 0 |
| reactivation | 0 | now | §9 immediate |
| one_year_followup | 43200 | +30d | §5 SMS1 = day 30 post-handoff |
| discount_claim | 0 | now | §7b step0 = immediate internal (SMS at its own +2 offset) |
| lead_form_business_hours | 0 | now | §7 "wait 30s" → sub-cron-minute, rounds to 0 |
| lead_form_after_hours | 0 | now | §7 immediate |
| missed_call_textback | 1 | +1m | §9 "wait 1 min → SMS#1" |

**Preventive:** `scratch-foundation` §7 (sequences table + runner) now documents the two delay concepts explicitly (`start_delay_minutes` = pre-step-0 vs `offsetMinutes` = gap-to-next; `0` ≠ absent for terminal) — both timing bugs (2a 0-offset truncation, 2d first-step) now have a single-source guard so a third build doesn't trip.

## Status
- **2d CLOSED — PASS.** Paths/caps/guards + first-step timing all validated.
- **2e clear** (drip-walking on top of correct `next_run_at` + the proven steps_json contract).
- Carry to 2e: wire the 2b feedback notification through the 2c dispatcher (single path); §7e AI-chat notification is 2f.
