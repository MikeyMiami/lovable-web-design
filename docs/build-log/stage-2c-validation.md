# Build Log — Stage 2c Validation (notifications subsystem wiring)

> Validation of Stage 2c (single `writeNotification` dispatcher, `src/lib/notifications/write.server.ts`, mapping 11 drip events → notification types/template keys) against `automation-config` + `features` + the foundation `notifications` table. Source: Lovable 2c report. Validated 2026-06-09 (Claude Code).
> **Verdict: VALIDATED — NOT fully closed.** Dispatcher mechanics + copy sound. 2 items before close (untested 11th type; negative-review email-template reuse). **Clear to start 2d** (independent). No secret values.

## ✅ Validated
- **Copy not drifted** — built off the 2a-seeded DB templates, which 2a validated as canonical (= automation-config). Bodies are the validated copy; the net-new surface is the event→type→key mapping.
- **Dispatcher:** `writeNotification({clientId, type, contactId?, vars?, action?})` — tenant-override→global template load, `clients.template_vars` + contact-field (`first_name`/`full_name`/`phone`/`email`) + per-event var merge, `{token}` render incl. dotted `{message.body}`, `supabaseAdmin` insert, returns `notifications.id`. ✓
- **Service-role-only insert** ✓ — `notifications` has only a SELECT policy; inserts succeed solely via admin-bypass (foundation "no INSERT policy → service-role-only write" working).
- **Stacked-line formatting** proven across 10 types (Name:/Phone:/Email: each on own line, never inlined); `{first_name}` vs `{full_name}` per template; `{message.body}` dotted merge; `action.open_conversation` carried through. ✓
- **tenant→global resolution** ✓ matches the templates global-row pattern (prefer `(client_id,key)` row, fall back to `(key) WHERE client_id IS NULL`). Currently all loads resolve to globals (2a seeded only globals); override path forward-looking.
- **`action` jsonb** ✓ supports `{auto_enroll:true}` / `{open_conversation:true}` structurally.

## Mapping (11 events) — all map to seed categories that exist; 10 proven by live render
review_request_final, lead_form_business_hours, lead_form_after_hours, lead_form_day10_reminder, missed_call, reactivation_click, one_year_reply_interest, one_year_after_sms2, one_year_final, discount_claim, negative_review_feedback → 11 template keys (review_request_final_internal, lead_form_internal_notify, lead_form_after_hours_owner_internal, lead_form_day10_owner_reminder, missed_call_internal_notify, reactivation_click_internal, one_year_reply_interest_internal, one_year_after_sms2_internal, one_year_final_internal, discount_claim_internal_notify, email_saved_from_negative_review).

## 🟡 Before close
- **A) 11th type UNTESTED + unidentified.** Report says "10 of 11" without naming the skip. The 10 live renders prove those keys resolve; the 11th is unverified (typo'd key → blank/silent fail). **Identify + run the skipped type live.**
- **B) `negative_review_feedback` → `email_saved_from_negative_review` reuses an EMAIL template for a NOTIFICATION.** Per §4 the in-app negative-review notification copy = the email block **minus** the `Hey {company_owner_first_name},` greeting. 2a seeded NO separate negative-review notification template — only the email. **Inspect the rendered notification body vs §4's NOTIFICATION copy** — confirm identical, or seed/point to a dedicated notification template. (Strong candidate for the untested 11th — render + eyeball it.)

## 🟢 Recommended (non-blocking)
- **Definitive key-existence check:** `SELECT key FROM public.templates WHERE client_id IS NULL ORDER BY key;` → diff against the 11 referenced keys (byte-verify the exact strings; not confirmable from the report alone).
- **Pin `action`-flag contract for Stage 3:** document `{auto_enroll:true}` (day-10) + `{open_conversation:true}` (missed-call) as the flags the mobile-app Notifications tab reads. Ensure missed-call always sets `related_contact_id` (the `open_conversation` target; mapping hedges "contact | null" — null = dead button).
- **Completeness:** §7e AI-chat-lead notification ("New Website AI Chat Lead") not in the 11 — confirm intentionally deferred to 2f (chat widget). 2b feedback route already inserts a negative-review notification — reconcile to call this dispatcher (single write path) when 2e wires it (avoid double-write).

## Status
- **2c NOT closed** until A (identify+test 11th) + B (negative-review body vs §4) resolved. Recommended key query + action-contract pin alongside.
- **Clear to start 2d** (enrollment paths/caps/guards — independent of the dispatcher; notifications fire at drip-run time = 2e).
