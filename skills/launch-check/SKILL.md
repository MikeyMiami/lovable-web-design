---
name: launch-check
description: Use as the verification gate before anything goes live — both when proving the golden-master backend (Phase 2) and before each client's marketing site goes public. A checklist skill that confirms the foundation invariants, every feature's wiring, the automation/cron engine, telephony, security (RLS/CORS/secrets), and per-client config are all correct. Run LAST in a build/launch sequence. NOT a build skill — it verifies what the other skills built.
---

# Launch Check — pre-go-live verification gate

The verification gate. Confirms everything the other skills built is correct before it goes live. Run in two contexts:
- **Golden-master proving (Phase 2):** after the shared backend is built, verify every invariant + feature works before declaring it the frozen golden master.
- **Per-client go-live:** before a client's marketing site goes public, verify their config + site are correct (the backend is already proven, so this is the lighter per-client subset).

This skill VERIFIES; it does not build. If a check fails, fix it in the owning skill's domain, then re-run.

## A. Foundation invariants (golden-master proving)
- [ ] RLS on every table; `(SELECT auth.uid())` wrap in all policies; helpers SECURITY DEFINER + STABLE; one permissive policy per action per table; no recursion on `user_roles`.
- [ ] NO anon INSERT/UPDATE/DELETE anywhere; anon SELECT limited to `clients` public columns WHERE status='active'.
- [ ] All public writes go through server fns (admin client + Zod + slug→client_id + server-set source).
- [ ] CORS + per-client domain allowlist + OPTIONS on public lead-intake routes — incl. the AI-chat-widget endpoints `/api/public/chat/optin` + `/api/public/chat/request` (new public lead-writes at 2f), not just `/api/public/intake`; NO CORS on webhook/cron routes. *(This structure is proven at FREEZE. The LIVE Turnstile/hCaptcha + rate-limit enforcement is the **1f launch gate (§E)** — NOT a freeze blocker; it is the deliberate final pre-launch hardening that may touch the frozen backend.)*
- [ ] `enrollments` UNIQUE (client_id, contact_id, sequence_key) present (and existing dupes removed first).
- [ ] Index set present incl. partial `enrollments(next_run_at) WHERE status='active'`; client_id-leading indexes on contacts/messages/events; user_roles(user_id).
- [ ] Enum migrations applied: contact_status += review_completed, negative_review, reactivation; contact_source += chat_widget, mobile_enroll (all lowercase_snake).
- [ ] Net-new columns/tables migrated: clients (allowed_origins, call_forwarding_number, site_style, social_links, deleted_at); contacts (last_missed_call_textback_at, deleted_at); send_settings (business_hours, daily_enrollment_cap, overrides); events.created_by; notifications table; sequences (client_id, key) unique.
- [ ] Two storage buckets: public-assets (public read), client-assets (private, client_id-scoped RLS).
- [ ] Runtime secrets set: CRON_SECRET, parent Twilio auth token (NOT on any row).
- [ ] template_vars is the single source for merge values (review_request_link et al. there, not columns).
- [ ] **Isolation guardrail 1 — RLS audit gate** passes: `SELECT * FROM public.audit_tenant_rls()` returns **0 rows** (scans every public base table with a client_id column for a `user_client_ids()`/`is_admin()` tenant check). Run after every migration — manual until a CI harness asserts `count = 0`.
- [ ] **Isolation guardrail 4 — CORS resolver:** public-write client_id is resolved server-side from Origin/Host→allowed_origins, never from the request body (verify a forged body client_id is ignored).
- [ ] **Isolation guardrail 3 — export-client server fn** exists and returns a full per-client bundle; archive-via-`status='archived'`+`deleted_at` offboard stops automation (cron filters active).

## B. Automation / cron engine
- [ ] pg_cron + pg_net hitting /api/public/cron/sequences every 1–5 min; route checks x-cron-secret against CRON_SECRET.
- [ ] Runner: bounded batch (~500), FOR UPDATE SKIP LOCKED, group by client_id; blocked → reschedule next_run_at WITHOUT advancing step; allowed → render → send → insert message+event → advance.
- [ ] **Outbound materialization (Stage-3 / 3c):** the runner writes each outbound drip send into `messages` + bumps `conversations.last_message_at` (STUB status) via the shared `insertOutboundMessage` helper (admin variant cron + RLS variant reply, reused with `reply.functions.ts`) → the Conversations inbox shows drip sends + the missed-call Open-conversation deeplink opens a real thread; ONE insert helper, no duplication; send primitive stays SEND-ONLY. (1f swaps stub status → real Twilio SID/delivery — §D.)
- [ ] Twilio 5xx → reschedule+jitter; 4xx → fail; send-layer retry up to 2×.
- [ ] **PRE-FREEZE regression (3a send-primitive extraction):** `sendStubSmsWithRetry` was extracted to `lib/sms/send.server.ts` (now shared by the cron runner + the reply path). Re-run the 2e TEST1–TEST5 drip walks → claim-lease (FOR UPDATE SKIP LOCKED), window-gating, caps, reschedule-`next_run_at`-without-advancing, advance-on-success, and 2× retry ALL intact (only the stub-send call was extracted). AND confirm the primitive is SEND-ONLY — no DB writes / no cron-decision event-logging in it, else the interactive reply path inherits cron-style logging. Part of the **PRE-FREEZE CLEANUP batch (Stage 3.5)** with the audit_log table + the export-client fn (§A).
- [ ] Send window (9–7 client tz), daily send cap, per-sequence pacing all read from events.
- [ ] Enrollment caps enforced at the enrollment-creation server fn (not send time); reactivation 50/day + 2/20min verified.
- [ ] Every cron decision logged to events (sent / blocked-window / blocked-cap / blocked-batch / rescheduled).
- [ ] **Isolation guardrail 2 — per-client fairness:** runner round-robins across clients so one large client can't starve others' drips within a tick.

## C. Features wired (each end-to-end)
- [ ] Review Request drip (§4): mobile-app enrollment → 4 SMS (day 0/+4/+7/+7) → click-checks → final owner notification at +48h; re-enrollment guard.
- [ ] Review Funnel (§4): tracked link → /api/public/r/rate → ≥threshold → review_completed + Google + One-Year handoff; <threshold → /api/public/r/feedback → negative_review + owner email/notif, NO handoff.
- [ ] One-Year drip (§5): 5 SMS, exit on reply/opt-out/discount-submit, never on click.
- [ ] Lead-Form drip (§7): business-hours branching, single SMS#1 (correctly spelled), day-10 reminder + Auto-Enroll.
- [ ] Discount form & drip (§7b): submit exits One-Year drip.
- [ ] Missed-Call Textback (§9): 24/7, Twilio busy/no-answer/canceled/failed, 1-min/2-min, 7-day re-eligibility.
- [ ] Owner Email Notifications (§7d): all subjects incl. New Website AI Chat Lead.
- [ ] Reactivation drip (§9): CSV upload → dedupe → caps → same 4 texts → click notification → One-Year only on review_completed.
- [ ] AI Chat Widget (§7e): opt-in gate (source chat_widget), FAQ from knowledge bundle, pricing guardrail, Request path = lead-form drip with "New Website AI Chat Lead" label.

## D. Telephony (Twilio Option 1)
- [ ] One parent account via the connector gateway (fetch, no SDK); per-client From/MessagingServiceSid on the clients row.
- [ ] **Outbound message status-swap (1f):** the `messages`/`conversations` materialization + the shared `insertOutboundMessage` helper are built + proven PRE-freeze (Stage-3 / 3c — see §B), with STUB status. **1f changes only the status: stub → real Twilio SID + delivery status** (no new insert logic). (This is why drip sends + the missed-call Open-conversation deeplink already work in the frozen master.)
- [ ] Inbound + voice-status webhooks at the parent level; route by To → clients row; X-Twilio-Signature verified BEFORE any DB write.
- [ ] STOP/HELP/START + "pass" opt-out handling wired.
- [ ] **Inbound webhook drives REAL-TIME drip exits** (not deferred to the next pre-step check): one-year reply → exit + interest notification immediately (gaps are weeks/months — pre-step-only would delay the notification ~a month); missed-call reply-skip; opt-out. (Pre-step checking is the stub-mode fallback only.)
- [ ] Per-client number provisioned, forwarded to call_forwarding_number, placed on site + GBP.

## E. Per-client go-live subset (lighter — backend already proven)
- [ ] **GATE — Stage 1f shipped (the deliberate FINAL pre-launch hardening, AFTER the Stage-4 freeze):** real Twilio swap + message testing + LIVE Turnstile + rate-limiting on all public lead-intake routes before this client goes public — incl. the 2f chat endpoints `/api/public/chat/optin` + `/api/public/chat/request` (carried forward from 2f-F2). These (Twilio-swap + Turnstile/rate-limit) are the ONLY changes permitted to touch the frozen backend. CORS is browser-only — without 1f, a direct/non-browser POST with this client's slug or allowed-origin can spam-insert. NO client launches pre-1f.
- [ ] Client row + all §9b config present; template_vars required keys all populated (no blanks).
- [ ] timezone (send_settings), business_hours, send window, caps set.
- [ ] Google review link + Place ID + star_threshold set; review engine functional.
- [ ] Twilio number provisioned + forwarded + on site/GBP; A2P campaign covers it.
- [ ] allowed_origins includes the client's marketing domain(s) (CORS will pass).
- [ ] Marketing site Remixed, pointed at the shared backend env (shared `VITE_SUPABASE_URL` + anon key + the one per-client `VITE_CLIENT_SLUG`), frontend-only (no service-role).
- [ ] Site pages generated to match onboarding (services/areas counts, ≤12/≤14); brand color themed; assets loaded.
- [ ] A2P-compliant terms/privacy page generated + linked (website_terms_page_link).
- [ ] Consent/SMS opt-in language present on all public forms.
- [ ] End-to-end smoke test: submit a lead form from the live domain → contact created → drip enrolls → SMS sends → owner notified.

## Output
A pass/fail report per section. Any fail blocks go-live and routes back to the owning skill. All green → golden master is provable / client is cleared to launch.
