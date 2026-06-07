---
name: features
description: Use when building, modifying, or debugging any platform FEATURE on a client site — the review-request SMS drip, one-year follow-up SMS drip, missed-call textback, reactivation, inbound-SMS handling, or the tracked review-redirect. Defines how each feature works and how to construct it from scratch. NOT for message copy/timing (use automation-config) and NOT for admin UI tabs (use admin-view).
---

# Features — mechanics & from-scratch build

This skill defines WHAT each feature is, HOW it works, and HOW to build it from nothing. Build-from-scratch is the model: never assume a feature exists; construct it. Exact message copy and timing live in the `automation-config` skill — this skill defines structure and behavior.

Stack invariants (always): TanStack Start v1, Cloudflare Workers (pure JS + fetch, no native deps), Lovable Cloud/Supabase, RLS on every table, server logic via `createServerFn` and `src/routes/api/public/*`. Phones in E.164. Every outbound send writes an `events` row (live AND stub). All SMS obeys the send window + caps (see admin-view / send_settings).

---

## Feature: Review Request SMS Drip

**Purpose:** get a customer to leave a Google review via a 4-message SMS sequence that stops the moment they click the review link.

**Enrollment:** the ONLY human entry point is the mobile-app "Review Request" form (first_name, last_name, phone, email). That single enrollment enrolls the contact into BOTH this drip AND the Customer Review Request Email Drip (two enrollment rows). Subject to the daily enrollment cap (default 50/day per client; overflow queues to the next day).

**Tracked review link [BUILD — construct this; it does not exist yet]:**
- The link in every SMS is a per-contact tracked redirect, NOT the raw Google URL.
- At enrollment, generate a unique token mapped to (contact_id, client_id, sequence). Store it so the drip can embed `https://<client-domain>/r/<token>` in each message.
- Build a public route (e.g. `src/routes/api/public/r.$token` or `/r/<token>`) that: looks up the token → writes a `review_clicked` event for that contact → sets contact `status = 'Review Completed'` → 302-redirects to the client's `review_link` (the Google writereview URL).
- Per-contact token is REQUIRED so you know exactly which contact clicked.

**Sequence behavior (copy & exact timing in automation-config):**
- 4 SMS. After SMS 1, the drip checks click-status at each step before sending the next. If the contact has clicked (status `Review Completed`) at ANY check stage → exit immediately. If not → send the next message.
- After the 4th message, a final wait, then if still not clicked → fire an internal notification to the client's mobile-app Notifications tab (this notification is the terminal action, NOT a customer text).
- Opt-out keyword `pass` (plus standard STOP/etc.) → opt out, stop all sends.

**Handoff to One-Year Follow-Up [LOCKED RULE]:**
- On review-drip completion, enroll the contact into the One-Year Follow-Up drip — UNLESS they opted out.
- Both a click-exit (`Review Completed`) AND running through all 4 messages with no click and no opt-out → enroll into the 1-year drip.
- ONLY an opt-out blocks the handoff.

---

## Feature: One-Year Follow-Up SMS Drip

**Purpose:** long-tail return-customer + referral nurture with a discount offer.

**Enrollment:** NO form. Automatic handoff from review-drip completion (see above), unless opted out.

**Exit rules [LOCKED]:**
- Exit on REPLY: any inbound message from the contact that is NOT an opt-out keyword → remove from drip + fire a "they replied" internal notification to the client (with the reply body). This applies after ANY message in the sequence.
- Exit on OPT-OUT: pass/STOP/etc. → remove from drip, NO interest notification.
- Do NOT exit on link click — the discount links are plain untracked marketing URLs; clicking does not remove them.
- **Precedence:** evaluate inbound as opt-out FIRST. Opt-out keyword → opt out silently. Any other inbound → exit + interest notification.

**Discount links:** plain `{company_website_link}/get-your-discount`, same for everyone, NOT per-contact tracked. (What happens after a claim is governed by a separate discount-claim form — TBD, do not build yet.)

**Internal notifications [BUILD — needs the Notifications subsystem]:** this drip writes several internal notifications to the client's mobile-app Notifications tab (an interest notification on reply, a 3-month status note, and a final removal note). The on-reply handler must capture the triggering inbound `message.body` and merge it into the interest notification (`message.body` is dynamic, not a template_var). Exact copy/timing in automation-config.

---

## Feature: Missed-Call Textback (already built — scope)

Twilio voice-status webhook (`/api/public/twilio/voice-status`): on no-answer/busy/failed, send the `missed_call_textback` template to the caller from the client's Twilio number, deduped per (client, caller, 30-min window) via `events`. This is transactional/webhook-driven and is EXEMPT from the bulk cron throttle (sends immediately). The caller's reply flows into the normal inbound → conversation path.

## Feature: Customer Reactivation (already built — scope)

Admin uploads CSV/pasted list at `/admin/reactivation` → normalize phones to E.164 → upsert contacts deduped by (client_id, phone) then (client_id, email), source `reactivation` → enroll in `reactivation_drip`. Uses the conservative throttle profile. Copy/timing in automation-config.

## Feature: Inbound SMS → CRM (already built — scope)

`/api/public/twilio/inbound`: verify Twilio signature when configured; resolve client by destination number, contact by sender; handle compliance keywords (STOP/STOPALL/UNSUBSCRIBE/CANCEL/END/QUIT + **`pass`** → opt out; HELP/INFO → info reply; START/YES/UNSTOP → opt back in); otherwise upsert conversation, insert inbound message, write `inbound_sms` event. **`pass` must be added to the opt-out keyword set** [BUILD] as a whole-word match. This webhook is also where drip exits-on-reply are detected for the one-year drip.

---

## Build notes that apply across features
- New SMS sequences MUST include an opt-out exit path. STOP/HELP/START + `pass` handling is global at the inbound webhook — never bypass it.
- Sends honor the send window (9am–7pm client tz) + daily send cap + batch pacing via the cron runner; blocked sends reschedule without advancing.
- Outbound senders write `events` rows in live and stub mode, so all click/cap/dedupe logic reads `events`, never a Twilio round-trip.
- The Notifications subsystem (a notifications table + automations writing to it + mobile-app UI reading it) is net-new and required by both drips — build it as part of the mobile-app layer.
