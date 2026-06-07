---
name: features
description: Use when building, modifying, or debugging any platform FEATURE on a client site — the review-request SMS drip, one-year follow-up SMS drip, website lead-form drip, discount-claim form/drip, missed-call textback, reactivation, inbound-SMS handling, or the tracked review-redirect. Defines how each feature works and how to construct it from scratch. NOT for message copy/timing (use automation-config), form field layouts (use opt-in-forms), or admin UI tabs (use admin-view).
---

# Features — mechanics & from-scratch build

Defines WHAT each feature is, HOW it works, and HOW to build it from nothing. Build-from-scratch is the model: never assume a feature exists; construct it. Exact copy/timing live in `automation-config`; form field layouts live in `opt-in-forms`.

Stack invariants: TanStack Start v1, Cloudflare Workers (pure JS + fetch, no native deps), Lovable Cloud/Supabase, RLS on every table, server logic via `createServerFn` and `src/routes/api/public/*`. Phones E.164. Every outbound send writes an `events` row (live AND stub). Marketing SMS obeys the SMS Send Window + caps; lead-form SMS branches on Business Hours (see admin-view).

---

## Feature: Review Request SMS Drip
**Purpose:** get a customer to leave a Google review via a 4-message SMS sequence that stops the moment they click the review link.

**Enrollment:** ONLY via the mobile-app "Review Request" form (first_name, last_name, phone, email). Enrolls into THIS drip only — one enrollment row (email drip was scrapped; SMS-only). Subject to the daily enrollment cap (default 50/day; overflow queues to next day).

**Re-enrollment guard [LOCKED]:** a contact already enrolled in the review automation (by client_id + phone) cannot be re-enrolled — block and show "contact already enrolled." Applies to the form AND the lead-form drip's day-10 Auto-Enroll button.

**Tracked review link [BUILD — construct this]:** the link in every SMS is a per-contact tracked redirect, NOT the raw Google URL. At enrollment generate a unique token mapped to (contact_id, client_id, sequence); embed `https://<client-domain>/r/<token>`. Build a public route that looks up the token → writes a `review_clicked` event → sets contact `status='Review Completed'` → 302-redirects to the client's `review_link`. Per-contact token = know exactly who clicked.

**Sequence behavior:** 4 SMS. After SMS 1, check click-status at each step before the next send; clicked at ANY stage → exit. After SMS 4, a final wait, then if still not clicked → fire an internal notification to the mobile-app Notifications tab (terminal, not a customer text). Opt-out keyword `pass` (+ standard STOP/etc.) stops all sends.

**Handoff to One-Year Follow-Up [LOCKED]:** on review-drip completion, enroll into the One-Year drip UNLESS opted out. Both a click-exit (`Review Completed`) AND running all 4 with no click and no opt-out → enroll. Only opt-out blocks the handoff.

---

## Feature: One-Year Follow-Up SMS Drip
**Purpose:** long-tail return-customer + referral nurture with a discount offer.
**Enrollment:** NO form. Automatic handoff from review-drip completion (above), unless opted out.

**Exit rules [LOCKED]:**
- Exit on REPLY (non-opt-out inbound) → remove + fire "they replied" internal notification (with the reply body). Applies after ANY message.
- Exit on OPT-OUT (pass/STOP/etc.) → remove, NO interest notification.
- Exit on DISCOUNT-FORM SUBMIT → if the contact submits the discount-claim form (§ discount feature), remove them from this drip (real re-engagement).
- Do NOT exit on link click — discount links are plain untracked marketing URLs.
- Precedence on inbound: evaluate opt-out FIRST (opt out silently); any other inbound → exit + interest notification.

**Build notes [BUILD]:** the on-reply handler must capture the triggering inbound `message.body` and merge it into the interest notification (`message.body` is dynamic, not a template_var). This drip writes several internal notifications to the Notifications tab — copy/timing in automation-config.

---

## Feature: Website Lead-Form Drip
**Purpose:** instant response + owner alerting when a lead submits the public website form.
**Enrollment:** public website lead form (first_name, last_name, phone, email, your_message), source `web_form`.

**Two-window branching [LOCKED]:** branches at submission time on **Business Hours** (a SEPARATE per-client setting from the marketing SMS Send Window — see admin-view). Lead-form SMS is transactional: it does NOT defer to the marketing window; it branches on Business Hours.
- **During Business Hours:** wait 30s → internal client notification → SMS #1 to lead (contains an INTENTIONAL TYPO — must not be corrected) → wait 30s → SMS #2 (the correction), SKIP if the lead already replied → day-10 owner reminder.
- **Outside Business Hours:** single after-hours SMS to the lead (no typo, no second text) → after-hours owner notification → day-10 owner reminder. The after-hours message is the end of the customer-facing drip; the normal two-text sequence does NOT fire later.

**Day-10 owner reminder (BOTH branches):** suppress if the lead's phone is now enrolled in the review automation; otherwise send. Includes an **Auto-Enroll button** [BUILD] in the Notifications tab that enrolls the contact into the Review Request drip directly (runs the re-enrollment guard; shows "contact already enrolled" if applicable).

**Build notes [BUILD]:** lead reply-detection (to skip SMS #2) on the inbound webhook; Business Hours setting + branch logic; the intentional typo is flagged in copy and must never be "fixed."

---

## Feature: Discount-Claim Form & Drip
**Purpose:** the `{company_website_link}/get-your-discount` page (destination of one-year drip links) + its short response drip.
**Form:** public lead-capture form (banner with company name/logo + "Get {discount_amount} with us!"; fields First Name, Last Name, Phone, Your Message; consent checkbox linking the client's own terms; "Get My Discount!" button). Inserts a contact, source `web_form`, phone E.164. Field layout detailed in opt-in-forms.
**Drip:** on submit → immediate internal client notification → wait 2 min → one SMS to the lead → end. Copy in automation-config.
**One-year interaction [LOCKED]:** if the submitter is currently in the One-Year drip, the submission EXITS them from it (re-engagement). A form submit is distinct from a raw link click (which does not exit).

---

## Feature: Missed-Call Textback [LOCKED]
**Trigger:** inbound call to the client's Twilio number ends with status busy / cancelled / no-answer / voicemail (all four). Voice-status webhook (`/api/public/twilio/voice-status`).
**Timing:** fires 24/7 — live signal, NOT gated by SMS Send Window or Business Hours. Transactional; exempt from the bulk throttle.
**Re-eligibility (7-day rule) [BUILD]:** fires only if the contact (client_id + phone) has no missed-call textback in the last 7 days. Track a per-contact `last_missed_call_textback_at` timestamp; on a missed call, fire only if `now - last_missed_call_textback_at >= 7 days` (or never sent); update the timestamp on send. Within 7 days → log but suppress. This replaces the old 30-min dedupe.
**Flow:** on missed-call status → wait 1 min → send SMS #1 + fire internal notification (same time) → wait 2 min → if the caller replied in that window, skip SMS #2; else send SMS #2. (Copy in automation-config.)
**Contact handling:** create/match the contact by `phone_e164`, log the missed call (event); replies flow into the normal inbox. A brand-new caller has no name yet — the internal notification keys off `{caller_phone}` + `{call_time}`, with an "Open conversation" button.
**SMS #2 reply-skip** uses the same inbound-webhook reply detection as the lead-form drip.

## Feature: Customer Reactivation (built — scope)
Admin uploads CSV/paste at `/admin/reactivation` → normalize phones → upsert contacts deduped by (client_id, phone) then (client_id, email), source `reactivation` → enroll in `reactivation_drip`. Uses the conservative throttle profile. Copy/timing in automation-config.

## Feature: Inbound SMS → CRM (built — scope)
`/api/public/twilio/inbound`: verify Twilio signature when configured; resolve client by destination number, contact by sender; compliance keywords (STOP/STOPALL/UNSUBSCRIBE/CANCEL/END/QUIT + **`pass`** → opt out [BUILD: add `pass` as whole-word match]; HELP/INFO → info; START/YES/UNSTOP → opt back in); else upsert conversation, insert inbound message, write `inbound_sms` event. This webhook also detects drip exits-on-reply (one-year, lead-form SMS#2 skip).

---

## Cross-feature build notes
- New SMS sequences MUST include an opt-out exit path; STOP/HELP/START + `pass` is global at the inbound webhook.
- Marketing sends honor SMS Send Window + daily send cap + batch pacing in the cron runner; blocked sends reschedule without advancing. Lead-form/missed-call sends are transactional (Business-Hours branch / immediate), not deferred by the marketing window.
- Outbound senders write `events` in live and stub mode, so all click/cap/dedupe logic reads `events`, never a Twilio round-trip.
- Notifications subsystem (table + automations writing to it + mobile-app UI reading it, incl. the interactive Auto-Enroll button) is net-new and required by multiple features — build it as part of the mobile-app layer.
