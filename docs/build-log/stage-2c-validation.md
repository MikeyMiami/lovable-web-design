# Build Log — Stage 2c Validation (notifications subsystem wiring)

> Validation of Stage 2c (single `writeNotification` dispatcher, `src/lib/notifications/write.server.ts`, mapping 11 drip events → notification types/template keys) against `automation-config` + `features` + the foundation `notifications` table. Source: Lovable 2c report. Validated 2026-06-09 (Claude Code).
> **Verdict: PASS — CLOSED 2026-06-09.** Dispatcher mechanics + copy validated; the untested 11th type (negative_review_feedback) was the email-template-reuse bug — fixed by seeding a dedicated `negative_review_feedback_internal` notification template (email body minus subject + greeting) + rewiring the dispatcher; all 11 keys confirmed present; action contract + missed-call related_contact_id confirmed. **Clear for 2d.** No secret values.

## ✅ Validated
- **Copy not drifted** — built off the 2a-seeded DB templates, which 2a validated as canonical (= automation-config). Bodies are the validated copy; the net-new surface is the event→type→key mapping.
- **Dispatcher:** `writeNotification({clientId, type, contactId?, vars?, action?})` — tenant-override→global template load, `clients.template_vars` + contact-field (`first_name`/`full_name`/`phone`/`email`) + per-event var merge, `{token}` render incl. dotted `{message.body}`, `supabaseAdmin` insert, returns `notifications.id`. ✓
- **Service-role-only insert** ✓ — `notifications` has only a SELECT policy; inserts succeed solely via admin-bypass (foundation "no INSERT policy → service-role-only write" working).
- **Stacked-line formatting** proven across 10 types (Name:/Phone:/Email: each on own line, never inlined); `{first_name}` vs `{full_name}` per template; `{message.body}` dotted merge; `action.open_conversation` carried through. ✓
- **tenant→global resolution** ✓ matches the templates global-row pattern (prefer `(client_id,key)` row, fall back to `(key) WHERE client_id IS NULL`). Currently all loads resolve to globals (2a seeded only globals); override path forward-looking.
- **`action` jsonb** ✓ supports `{auto_enroll:true}` / `{open_conversation:true}` structurally.

## Mapping (11 events) — all map to seed categories that exist; 10 proven by live render
review_request_final, lead_form_business_hours, lead_form_after_hours, lead_form_day10_reminder, missed_call, reactivation_click, one_year_reply_interest, one_year_after_sms2, one_year_final, discount_claim, negative_review_feedback → 11 template keys (review_request_final_internal, lead_form_internal_notify, lead_form_after_hours_owner_internal, lead_form_day10_owner_reminder, missed_call_internal_notify, reactivation_click_internal, one_year_reply_interest_internal, one_year_after_sms2_internal, one_year_final_internal, discount_claim_internal_notify, email_saved_from_negative_review).

## ✅ Before-close items — RESOLVED (2026-06-09)
- **A) 11th type = `negative_review_feedback` — RESOLVED.** It was the skip *because* it pointed at the owner-EMAIL template (Subject line + `Hey {owner},` greeting = wrong shape for an in-app feed). Fixed: seeded a dedicated **`negative_review_feedback_internal`** notification template (email body minus subject + greeting), rewired the dispatcher, live-rendered clean (stacked Name/Email/Phone/Message, no greeting/subject).
- **B) Body vs §4 — CONFIRMED (against spec + Lovable's description; not a seed byte-diff).** §4's "Mobile-app notification" copy (spec lines 124–130) IS the email block minus the greeting — the new template matches that intent. *(Residual: the raw seeded body wasn't pasted to Claude Code; offered a final byte-diff. Low risk — internal owner-facing, editable.)*
- **New template:** `negative_review_feedback_internal`, seeded as a **global row** (`client_id IS NULL`) consistent with the other notification templates. **Seeded global-template set: 29 → 30** (added at 2c, not in the original 2a seed of 29).
- **Check 1 — all 11 keys present** in `templates WHERE client_id IS NULL` (the recommended `SELECT key` query was run; all 11 listed incl. the new one). ✅
- **Check 2 — action contract + missed-call contact:** `lead_form_day10_reminder → {auto_enroll:true}`; `missed_call → {open_conversation:true}` with `related_contact_id` populated (missed-call upserts the contact by `phone_e164` before writing → no dead Open-conversation button; `contactId:null` accepted only for the pre-upsert schema case). ✅

## 🟢 Recommended (non-blocking)
- **Definitive key-existence check:** `SELECT key FROM public.templates WHERE client_id IS NULL ORDER BY key;` → diff against the 11 referenced keys (byte-verify the exact strings; not confirmable from the report alone).
- **Pin `action`-flag contract for Stage 3:** document `{auto_enroll:true}` (day-10) + `{open_conversation:true}` (missed-call) as the flags the mobile-app Notifications tab reads. Ensure missed-call always sets `related_contact_id` (the `open_conversation` target; mapping hedges "contact | null" — null = dead button).
- **Completeness:** §7e AI-chat-lead notification ("New Website AI Chat Lead") not in the 11 — confirm intentionally deferred to 2f (chat widget). 2b feedback route already inserts a negative-review notification — reconcile to call this dispatcher (single write path) when 2e wires it (avoid double-write).

## Status
- **2c CLOSED — PASS.** All 4 close items resolved; new `negative_review_feedback_internal` global template seeded (set now 30); 11 keys verified; action contract pinned.
- **Clear to start 2d** (enrollment paths/caps/guards).
- Carry to 2e/2f: 2b feedback route should call this dispatcher (single write path, no double-write); §7e AI-chat-lead notification is a 2f item.
