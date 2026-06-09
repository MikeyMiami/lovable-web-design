# Build Log — Stage 2a Validation (sequence + template seeding)

> Validation of Stage 2a (7 sequences + 29 templates, all global `client_id = NULL`) against the `automation-config` skill + the 1e cron-runner steps_json contract. Source: Lovable 2a report (summary-level; seeded bodies + runner walker NOT pasted). Validated 2026-06-09 (Claude Code).
> **Verdict: STRUCTURAL PASS — NOT fully closed.** Counts/composition/encoding/template_vars all match the skill. **2 verifications outstanding before 2e** (runner walk-test incl. 0-offset; verbatim copy) + 1 bug-risk flag. **Clear to start 2b** (independent infra). No secret values.

## ✅ Confirmed (report + skills)
- **Sequences (7) + steps:** review_request 5 (4 SMS + final internal §4) · one_year_followup 7 (5 SMS + after-SMS2 internal + final internal; reply-interest template-only §5) · lead_form_business_hours 3 · lead_form_after_hours 3 · discount_claim 2 · missed_call_textback 3 · reactivation 4. All match the skill.
- **Templates (29):** 5 review + 8 one-year + 5 lead-form + 2 discount + 3 missed-call + 1 reactivation-click + 5 owner-email = 29. ✓
- **Encoding choices vs skill intent:** (a) lead-form split into 2 branch sequences picked at submit ✓; (c) missed-call 1-min wait enrollment-side (`next_run_at = now+1m`) + SMS#2 `skipIfReplied` ✓; (d) `one_year_reply_interest_internal` template-only / reply-triggered ✓.
- **Reactivation reuses `review_request_sms1..4` verbatim** ✓ (skill §9 — same 4 texts, no "pass" P.S.).
- **template_vars contract complete** — every merge key across §4/§5/§7/§7b/§9/§7d maps to one of: 8 per-client vars (company_owner_first_name, company_name, review_request_link, discount__on_referral, company_website_link, discount_amount, website_terms_page_link, quote_form_link), built-ins (first_name, phone, review_link), or dynamics (message.body, request_time, full_name, your_message, caller_phone, call_time, feedback_message, email). **None missing.** `discount_amount`/`website_terms_page_link` correctly flagged form-render-time (Discount-Claim banner/consent), not SMS. `review_link` (per-contact tracked) ≠ `review_request_link` (per-client direct) correctly distinguished.

## 🚩 Bug-risk flag — 0-offset vs terminal
Encoding (b) models the One-Year after-SMS2 internal + the missed-call internal as **`offsetMinutes: 0`** steps. Safe ONLY if the runner distinguishes `offsetMinutes: 0` (valid → next step due now) from `offsetMinutes` **absent** (terminal → completed). **If the 1e walker uses a falsy check (`if (!step.offsetMinutes)`), `0` reads as terminal → One-Year completes after the internal and never sends SMS3–5; missed-call truncates before SMS#2.** Must confirm the runner uses `'offsetMinutes' in step` / `!= null`, not `!offsetMinutes`.

## ❓ Outstanding verifications (couldn't confirm from the summary report) — required before 2e
1. **steps_json ↔ runner contract (the 2a gate).** The 1e runner's steps_json **walker** was never pasted, and this report summarizes (doesn't paste) the seeded steps_json — so the contract match is **asserted, not verified.** Confirm via a **live walk-test**: seed a throwaway enrollment into `review_request` AND `one_year_followup`, run cron ticks, assert (i) correct `templateKey` rendered, (ii) `next_run_at = send + offsetMinutes`, (iii) `current_step` advances, (iv) **0-offset internal does NOT complete the drip** (One-Year reaches SMS3), (v) terminal step → `status='completed'`. (Or paste the walker code.)
2. **Verbatim copy.** Seeded bodies weren't pasted → "matches skill copy, line breaks preserved" unverified. Paste bodies (or diff vs skill copy) for the customer-facing SMS: review 1–4, one-year 1–5, lead-form SMS#1/after-hours, discount SMS, missed-call SMS#1/2.

## Status
- **Clear to start 2b** (tracked-link/funnel — independent of steps_json + copy).
- **2a not closed / do NOT wire 2e** until #1 (walk-test, incl. 0-offset) + #2 (verbatim copy) are green. Copy/step errors are cheap at seed time, expensive once 2e drips wire to them.
- When #1 + #2 confirmed → flip this record to PASS.
