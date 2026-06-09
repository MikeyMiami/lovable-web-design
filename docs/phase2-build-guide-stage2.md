# Phase 2 Build Guide — Stage 2 (Feature / Automation Layer)

How to build the feature/automation layer on the proven foundation. **Infrastructure-first**: build the shared machinery once, validate it, freeze it — then features just consume it. Same discipline as the foundation: one verifiable sub-step at a time, name the skill explicitly, reload the skill before each sub-step if it changed, validate via artifacts (migration SQL + live DB + code) → here + Claude Code → approve → next.

> Lessons carried from the foundation build, baked into this runbook:
> - **Lovable builds more per turn than asked** → each sub-step says "build ONLY this; stop for validation."
> - **Name the skill explicitly** each sub-step (auto-retrieval isn't 100%); confirm Lovable's "building from skill X" line before it writes code.
> - **Reload the skill** (delete + re-import) right before a sub-step if it changed since last import.
> - **Stub external sends** — real Twilio (1f) is deferred; the stub `sendSms` logs `sms_sent` events, so all drip mechanics are testable WITHOUT Twilio. Keep using the stub through Stage 2.
> - **Validate against high-trust artifacts** (migration files, live DB queries, code) not prose. Migrations are append-only.
> - **The cron engine already works** — features plug INTO it (seed sequences, enqueue enrollments); they don't rebuild runner logic.

---

## Prerequisites (must be true before starting)
- Foundation Stage 1 (1a–1e) complete + validated. ✓
- 1f (Twilio) deferred — fine; stub send is in place. (Twilio account + A2P registration started in background.)
- Skills current in Lovable: `features`, `automation-config`, `opt-in-forms`, `chat-widget` — **re-import each right before its sub-step** to guarantee latest.

---

## STAGE 2 ORDER (infrastructure → features → AI)

### 2a — Sequence + template seeding (`/automation-config`)
The data layer every drip reads. Build first so features have their copy/timing to enroll into.
- Seed all drips' `templates` rows + `sequences` steps_json **verbatim** (exact copy, line breaks preserved) per `/automation-config`: Review Request, One-Year, Lead-Form, Discount-Claim, Missed-Call, Reactivation, + owner-email templates.
- Seed as **global rows** (`client_id IS NULL`) where the copy is platform-default; per-client overrides come later via admin.
- **Verify required `template_vars` contract exists** (the seeding-rules list: company_owner_first_name, company_name, review_request_link, discount__on_referral, company_website_link, discount_amount, website_terms_page_link, quote_form_link). Missing keys render blank silently.
- Validate: query `sequences` + `templates`; confirm steps_json shape matches the cron runner's expectations (step offsets, message refs), copy is verbatim, global rows present.
- **Gate:** the cron runner (built in 1e) can read a seeded sequence and walk its steps (test with a stub enrollment).

### 2b — Tracked-link + Review Funnel system (`/features` review-drip + funnel; shared by review AND reactivation)
The shared redirect/funnel infrastructure. Built once; both review and reactivation drips consume it.
- Token generation: at enrollment, unique token → maps to (contact_id, client_id, sequence). **NET-NEW storage:** the as-built foundation (12 tables) has no token/tracked-link table — 2b adds one via an **additive migration** (a `tracked_links`/token table with client_id + contact_id + sequence_key + token). Since it carries `client_id`, it's a tenant table → it MUST get a `user_client_ids()`/`is_admin()` RLS policy and pass the guardrail-1 audit (see discipline reminder below).
- Public routes on the SHARED BACKEND domain (NOT client marketing domain — they write the DB): `/r/<token>` (logs `review_clicked`, exits drip, lands on rate page), `/r/rate` (1–5 stars, threshold-gated), `/r/feedback` (below-threshold capture → owner email + notification).
- Funnel logic: ≥threshold → `Review Completed` → Google redirect + One-Year enroll; <threshold → `Negative Review` → feedback page (no One-Year).
- Validate: token round-trip (generate → resolve → event written → correct landing); threshold branching; `/r/feedback` writes `review_feedback` + fires notification; all routes server-side (no anon write path).
- **Gate:** a stub enrollment's tracked link resolves, logs the click, exits the drip, and routes correctly by star selection.

### 2c — Notifications subsystem (`/mobile-app` §8 notifications table is built; this wires AUTOMATIONS writing to it)
The `notifications` table exists (foundation). This sub-step wires the automation events that WRITE notifications (the in-app side; owner-email is 2a's templates + the send pipeline).
- **Skill attribution:** the `/mobile-app` reference here is **table/spec only** (it owns the notifications-table shape + the UI that READS it — that UI is Stage 3). The notification-**writing** logic rides with `/features` + `/automation-config` (the drips that fire them) — so this is legitimately Stage 2 even though `/mobile-app` is a Stage-3 surface skill. Do NOT build mobile-app UI here.
- Each drip's internal-notification points (review step-5, lead-form owner alert, missed-call alert, reactivation click, one-year reply/interest, discount-form) write `notifications` rows (service-role).
- Formatting standard: stacked lines (never inline "Name: X Phone: Y").
- Validate: each notification-writing path inserts a correctly-shaped `notifications` row with the right type + body + related_contact_id.
- **Gate:** triggering a drip's notification point writes the expected row.

### 2d — Enrollment paths + caps + guards (`/opt-in-forms` + `/features`)
How contacts ENTER drips, with the caps/guards that protect sends.
- Mobile-app Review Request enroll fn (daily enrollment cap, re-enrollment guard by client_id+phone).
- Public website Lead Form → Lead-Form drip (via the 1d intake skeleton — now wire the real enrollment + business-hours branching).
- Public Discount-Claim form → discount drip (+ exits one-year on submit).
- Reactivation CSV upload (normalize E.164 → dedupe → enroll, caps 50/day + 2/20min, dedup guard vs already-reactivated/Review-Completed).
- Auto-Enroll button (day-10 reminder) → review drip (same re-enrollment guard).
- Validate: each enrollment path enforces its cap + guard; `source` set server-side; enrollments land with correct sequence_key + next_run_at.
- **Gate:** enroll via each path → correct enrollment row, caps/guards enforced, dedup works.

### 2e — Drip wiring end-to-end (`/features` + the seeded `/automation-config`)
Now the drips RUN on the cron engine using 2a's sequences. Each drip's step logic, exit rules, handoffs.
- Review drip: 4-SMS cadence, click-check-before-each-step, exit-on-click → Review Completed → One-Year handoff (unless opted out / negative).
- One-Year drip: 5-SMS, exit-on-reply (interest notification) / exit-on-opt-out (silent), no exit-on-click.
- Lead-Form drip: business-hours branch (A in-hours single SMS / B after-hours SMS + owner notif), day-10 reminder both branches.
- Missed-Call Textback: 24/7, 4 trigger statuses, 1-min/2-min drip, reply-skip, 7-day re-eligibility.
- Reactivation: immediate + 24h×3, same 4 texts as review, click → funnel, One-Year only on Review Completed.
- Discount-Claim: 2-min SMS, exits one-year.
- **1f dependency — reply-exits + missed-call trigger:** Missed-Call Textback's trigger (the Twilio voice-status webhook) and all reply-based exits (One-Year exit-on-reply, Missed-Call reply-skip — driven by the inbound-SMS webhook) depend on Twilio webhooks NOT built until 1f. In Stage 2 these are testable ONLY by **simulating the inbound event/webhook payload** (insert the inbound message/voice-status row directly); real webhook wiring lands at 1f. Build + unit-test the logic now against simulated inbound; don't assume end-to-end on stub.
- Validate (all on STUB send — logs sms_sent events): each drip walks its steps, exits on the right conditions, handoffs fire, caps/windows respected. Use the cron tick to advance test enrollments. (Reply/missed-call paths validated via simulated inbound per the note above.)
- **Gate:** each drip, driven by the cron runner with stub sends (+ simulated inbound for reply/missed-call), produces the correct event trail end-to-end.

### 2f — AI Chat Widget (`/chat-widget`)
The largest single feature; built last (reuses the lead-form pipeline from 2d/2e).
- Streaming chat route `src/routes/api/chat.ts` (Lovable AI Gateway, LOVABLE_API_KEY, gemini-3-flash-preview, useChat client).
- Opt-in gate (First/Last/Email/Phone + consent) BEFORE AI converses; contact `source='chat_widget'`.
- FAQ path (answer from per-request knowledge-bundle system-prompt injection); pricing/quote guardrail (redirect to request).
- Request path = reuses §7 lead-form enrollment exactly; owner notification labeled "New Website AI Chat Lead".
- Validate: opt-in gate fires before chat; knowledge-bundle injection; pricing guardrail redirects; request path creates contact + enrolls in lead-form drip; 429/402 handled.
- **Gate:** chat opt-in → FAQ answers from business data; pricing question redirects; request submits → lead-form drip enrollment with correct label.

---

## Stage 2 exit gate
Run `/launch-check` section C (per feature) across all drips + the chat widget. All green (on stub send) → the feature/automation layer is proven. Then Stage 3 (admin-view + mobile-app surfaces), then 1f (real Twilio) before launch.

## Discipline reminders
- One sub-step per turn; build → validate → next. Never "build all features."
- Stub send stays until 1f — all of Stage 2 is testable without Twilio.
- Seed copy VERBATIM (line breaks matter; customer SMS stay editable on-site later).
- Skill wins over Lovable suggestions; if a skill is wrong, fix the skill (single-source) + re-import, don't patch around it.
- Additive migrations only.
- **Run `SELECT * FROM public.audit_tenant_rls()` = 0 after every Stage 2 migration that adds a tenant table** (e.g. the 2b token/tracked-link table). Guardrail 1 now exists — any new `client_id`-bearing table must carry a `user_client_ids()`/`is_admin()` RLS policy and pass the audit before the sub-step is approved.
- **1f swap note:** when 1f replaces the stub `sendSms` with the real Twilio gateway, apply the 1e idempotency forward-note to 2e's drips (check no `sms_sent` event exists for (enrollment, current_step) before sending, or mark step-sent first) — the lease is at-least-once, so a crash mid-send could otherwise duplicate a real text.
- Carry-forward foundation items (guardrail 3 export-client fn, audit_log, self-lockout guard) are before-go-live, NOT Stage 2 — don't lose them, don't block on them.
