# Build Log — Stage 2a Validation (sequence + template seeding)

> Validation of Stage 2a (7 sequences + 29 templates, all global `client_id = NULL`) against the `automation-config` skill + the 1e cron-runner steps_json contract. Source: Lovable 2a report (summary-level; seeded bodies + runner walker NOT pasted). Validated 2026-06-09 (Claude Code).
> **Verdict: PASS — CLOSED 2026-06-09.** Structural match confirmed; the runner walk-test proved the steps_json↔runner contract (the predicted 0-offset truncation bug was caught + fixed — see below); customer-SMS copy spot-verified consistent with the skill. **2e is UNBLOCKED.** 2b separately in flight. No secret values.

## ✅ Confirmed (report + skills)
- **Sequences (7) + steps:** review_request 5 (4 SMS + final internal §4) · one_year_followup 7 (5 SMS + after-SMS2 internal + final internal; reply-interest template-only §5) · lead_form_business_hours 3 · lead_form_after_hours 3 · discount_claim 2 · missed_call_textback 3 · reactivation 4. All match the skill.
- **Templates (29):** 5 review + 8 one-year + 5 lead-form + 2 discount + 3 missed-call + 1 reactivation-click + 5 owner-email = 29. ✓ *(Later: +1 `negative_review_feedback_internal` added at 2c → seeded global set = 30. See `stage-2c-validation.md`.)*
- **Encoding choices vs skill intent:** (a) lead-form split into 2 branch sequences picked at submit ✓; (c) missed-call 1-min wait enrollment-side (`next_run_at = now+1m`) + SMS#2 `skipIfReplied` ✓; (d) `one_year_reply_interest_internal` template-only / reply-triggered ✓.
- **Reactivation reuses `review_request_sms1..4` verbatim** ✓ (skill §9 — same 4 texts, no "pass" P.S.).
- **template_vars contract complete** — every merge key across §4/§5/§7/§7b/§9/§7d maps to one of: 8 per-client vars (company_owner_first_name, company_name, review_request_link, discount__on_referral, company_website_link, discount_amount, website_terms_page_link, quote_form_link), built-ins (first_name, phone, review_link), or dynamics (message.body, request_time, full_name, your_message, caller_phone, call_time, feedback_message, email). **None missing.** `discount_amount`/`website_terms_page_link` correctly flagged form-render-time (Discount-Claim banner/consent), not SMS. `review_link` (per-contact tracked) ≠ `review_request_link` (per-client direct) correctly distinguished.

## ✅ Bug-risk flag — 0-offset vs terminal — CAUGHT & FIXED (2026-06-09)
The predicted bug was real: the 1e runner's terminal-detection was `step.offsetMinutes ? addMinutes(...) : null` — **falsy on `0`**, which would have truncated One-Year at SMS2 + SMS5 and Missed-Call at SMS1. The walk-test caught it. Fixed in `runner.server.ts` (code-only, no migration) to an explicit presence check:
```ts
const hasOffset = step.offsetMinutes !== undefined && step.offsetMinutes !== null;
const nextRun = hasOffset ? addMinutes(now, step.offsetMinutes as number) : null;
const nextStatus = nextRun ? "active" : "completed";   // nextRun is a Date (truthy) even for offset 0
```
Correct + complete: `0` → `hasOffset=true` → `nextRun=now` (Date, truthy) → `"active"`; absent → `null` → `"completed"`. Recorded as a 1e correction in `stage-1e-validation.md`.

## ✅ Outstanding verifications — both RESOLVED (2026-06-09)
1. **steps_json ↔ runner contract — PROVEN.** Walk-test of 3 enrollments, all 5 assertions PASS:
   - `review_request`: sms1→sms2→sms3→sms4→final_internal → step=5, `completed`.
   - `one_year_followup`: sms1→sms2→after_sms2_internal→sms3→sms4→sms5→final_internal → step=7, `completed` (proceeds past BOTH 0-offset internals — the fix).
   - `missed_call_textback`: sms1→internal_notify→sms2 → step=3, `completed` (past the 0-offset internal).
   - (i) correct templateKey per step ✓ (ii) `next_run_at = send + offsetMinutes` ✓ (iii) current_step monotonic ✓ (iv) 0-offset ≠ terminal ✓ (v) no-offset → completed, next_run_at=null ✓. The 3 tested drips cover the full contract surface (incl. the only edge: 0-offset chained internals); the untested 4 (lead-form ×2, discount, reactivation) use the same generic walker on simpler linear shapes → covered by extension, exercised end-to-end in 2e.
2. **Verbatim copy — spot-verified consistent** (NOT a full byte-diff: the 12 raw bodies were not pasted to Claude Code). Cross-checked the cited structural fingerprints against the skill: review `{review_link}` on own line after blank line (§4) ✓; one-year blank line before `-{company_owner_first_name} from {company_name}` (§5) ✓; missed-call sms1 blank-line stanza + `{quote_form_link}` on own line (§9) ✓. **Residual:** a true byte-diff of all 12 bodies is still offered (paste raw bodies) — low risk (customer SMS stay editable on-site).

## Naming
`lead_form_sms_business_hours` / `lead_form_sms_after_hours` (not `lead_form_sms1_*`) — **kept as-is** (clearer; one customer SMS per branch). No rename. steps_json must reference these exact keys (exercised when 2e wires the lead-form drip).

## Status
- **2a CLOSED — PASS.** Contract proven; 0-offset bug fixed; copy spot-verified.
- **2e UNBLOCKED** (steps_json↔runner contract proven). 2b separately in flight.
- Residual (non-blocking): optional full byte-diff of the 12 customer-SMS bodies.
