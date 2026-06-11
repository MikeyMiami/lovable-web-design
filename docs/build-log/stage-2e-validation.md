# Build Log — Stage 2e Validation (drip wiring end-to-end, on stub)

> Validation of Stage 2e (all drips wired on stub send + data-driven `window_gated`) against `features` + `automation-config`. Source: Lovable 2e report (5 test walks). Validated 2026-06-09 (Claude Code).
> **Verdict: VALIDATED — NOT closed.** Drip-walking, exits, window-gating, carry-forwards all sound. 4 confirms before close + 1 forward (1f) flag. **Clear to start 2f** (independent). No secret values.

## ✅ Validated
- **Step compositions match the 2a seed**: review_request 5 (4 SMS + final internal), one_year_followup 7 (sms1→sms2→after_sms2_internal→sms3→sms4→sms5→final_internal), missed_call 3 (sms1→internal→sms2), reactivation 4, lead_form 3×2, discount 2. ✓
- **`sequences.window_gated` (new boolean column)** — gated=true: review_request, one_year_followup, reactivation (marketing, §3 9–7 + daily_send_cap); gated=false (24/7): lead_form ×2, missed_call, discount. Runner: internal-notif steps never gated/capped; sms steps defer only if gated & outside-window / gated & cap-hit; non-gated → straight send. Lead-form business-hours branch lives enrollment-side (2d). TEST5 proves the distinction (review deferred, missed-call sent, same off-window tick). ✓
- **Exit semantics** match the skill: review→click (pre-step `tracked_links.clicked_at` + funnel real-time exit = belt-and-suspenders); one_year→reply (`exited_on_reply` + interest notif) / opt-out (silent); NOT on click; missed-call sms2 `skipIfReplied`; reactivation→click; discount→exits one_year on enroll (2d); lead-form→none. ✓
- **action-jsonb:** day-10 → `{auto_enroll:true}`, missed-call internal → `{open_conversation:true}`; step-supplied overrides default. ✓
- **Carry-forwards landed:** `/api/public/r/feedback` raw insert removed → `writeNotification({type:'negative_review_feedback'})` (single 2c path); AI-chat notification deferred to 2f. ✓
- 5 test walks: TEST1 review click→exited (0 SMS); TEST2 review full→4 sms_sent + final notif→completed; TEST3 one-year + simulated inbound→exited_on_reply + interest notif; TEST4 missed-call sms2 + inbound→skipped→completed; TEST5 window-gating.

## 🟡 Confirm before close
1. **`audit_tenant_rls()` not re-run after the `window_gated` migration** (report silent). 2nd additive column on `sequences`; near-certainly still 0, but discipline = run + confirm after every tenant-table migration. **Run + confirm =0.**
2. **Day-10 reminder SUPPRESSION (§7)** — §7 requires suppressing the day-10 reminder if the contact's phone is now enrolled in the review automation. Report doesn't mention it. **Confirm the day-10 step checks active `review_request` enrollment and skips if present** — else owners get reminders for contacts they already added. (Fix if missing.)
3. **Reactivation click NOTIFICATION (§9)** — §9 fires a reactivation click notification on the funnel landing. Report only says reactivation "same click exit as review." **Confirm the funnel route fires `reactivation_click_internal` when the clicking enrollment is reactivation** (review clicks don't; reactivation clicks do).
4. **`writeNotificationByTemplateKey` = thin wrapper that ENDS in `writeNotification`** (single insert path) — not a parallel insert. Report says "reverse-maps templateKey→type + injects actions" but not explicitly "delegates to writeNotification." **Confirm single insert path** + the reverse-map covers every internal-notif step's templateKey.

## 🟧 Forward (1f) — design-confirm now
5. **One-year reply-exit must be REAL-TIME at 1f, not pre-step-only.** One-year inter-step gaps are weeks/months; a pre-step-only reply check delays the "they replied" interest notification up to ~30–60 days (useless for a hot lead). 2e stub uses pre-step (fine for testing). **Confirm the 1f inbound-SMS webhook drives one-year exit + interest notif in real-time** (like the funnel does for clicks). (Missed-call reply-skip is fine pre-step — 2-min gap.)

## 🟢 Minor / confirmed
- **discount `window_gated=false` ✓** (transactional form-ack, matches lead-form pattern; §2/§3 gate only review/one-year/reactivation). **Recommend documenting discount in the spec's transactional list** (currently inferred).
- **one-year opt-out (`opted_out_at >= created_at`) ✓** given 2d enroll guard + §4 handoff opt-out exclusion (≈ `IS NOT NULL` in practice). Confirm the review→one-year handoff uses the guarded enroll path.
- Missed-call enrollment + 7-day re-eligibility is a 1f item (voice webhook creates the enrollment); 2e tests the drip steps only.

## Status
- **2e NOT closed** until confirms 1–4 (audit re-run; day-10 suppression; reactivation click notif; single-path wrapper). #5 is a 1f forward flag.
- **Clear to start 2f** (AI chat widget — last Stage 2 sub-step; reuses the lead-form pipeline; adds the deferred AI-chat notification).
