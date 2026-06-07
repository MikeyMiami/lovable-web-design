# Platform Spec — Multi-Tenant Reviews / SMS Automation (Source of Truth)

> Canonical record of build decisions. Skills are generated FROM this doc.
> Status legend: **[LOCKED]** decided · **[BUILD]** net-new, skill must construct it · **[TBD]** awaiting input.
> Last updated: this is a living doc — update it as decisions land so it never drifts from the build.

---

## 0. Build philosophy [LOCKED]
- **Build from scratch, in ordered layers** — do NOT clone-and-patch. Every site is constructed identically from nothing, so every site is identical by construction (determinism = reliability).
- Layer order (also the skill order): **foundation → features → automation-config → launch-check**, then per-client **onboard-from-form → theme-to-brand**.
- One skill, one job (per Lovable docs). No monolithic "build everything" skill.
- The spec doc is the source of truth; skills are derived from it; version-controlled in the repo.

## 0a. Stack (unchanged, see workspace knowledge) [LOCKED]
TanStack Start v1 (React 19 + Vite 7), SSR, Cloudflare Workers (pure JS + fetch, no native deps). Lovable Cloud / Supabase. Server logic in TanStack Start (`createServerFn` + `src/routes/api/public/*`). RLS on every table; roles in `user_roles`; SECURITY DEFINER helpers. Three Supabase clients (browser / authed-server-fn / admin).

---

## 1. The skill set [LOCKED list]
1. `/scratch-foundation` — builds the deterministic core (schema, RLS, helpers, server-fn/route skeleton, auth/roles) from nothing.
2. `/features` — reference + build instructions for each feature's mechanics & scope.
3. `/automation-config` — exact message copy + timing (the "snapshot").
4. `/opt-in-forms` — which forms feed which automations.
5. `/mobile-app` — the client app (`app.theirdomain.com`): Conversations, Review Request, Notifications tabs.
6. `/admin-view` — the admin tabs/settings on the client website (what's editable where).
7. `/launch-check` — pre-go-live verification gate.
8. `/new-client-site` — orchestrates the from-scratch build for a new client.
(`/onboard-from-form`, `/theme-to-brand` follow once their decisions land.)

---

## 2. `/admin-view` — admin tabs on the client website [LOCKED]
Current tabs: **Dashboard, Contacts, Conversations, Feedback, Automations, Upload Customers, Settings**.

**Settings tab must hold these per-client configurable values:**
- Timezone (drives all SMS windows).
- **SMS Send window** (default **09:00–19:00**, client timezone) — applies to MARKETING/FOLLOW-UP SMS only (review drip, one-year drip, reactivation). Purpose: don't annoy past customers.
- **Business Hours** (separate per-client window) — applies to the LEAD-FORM drip only (§7). Purpose: decide whether a fresh web lead gets the live in-hours response or the after-hours message. Independent from the SMS Send window. [BUILD — new field]
- **Daily SMS send cap** (customizable per client) — max messages dispatched/day.
- **Daily enrollment cap** (customizable per client, **default 50**) — max NEW contacts entering the review drip/day; overflow waits to next day. *(Distinct from send cap.)*
- Existing: business identity, review config (place ID, link, gate mode, threshold), template_vars, Twilio config, sending subdomain.

---

## 3. Send-window & throttle behavior [LOCKED — throttle now built]
- All SMS fires only **9am–7pm in the client's timezone**.
- Enrolled outside the window → the day-0 SMS goes out at **9am next day** in their tz, preserving enrollment order.
- Throttle (window + daily send cap + rolling batch pacing) is enforced in the cron runner; blocked sends reschedule `next_run_at` without advancing the step (never dropped, never skipped).
- **Daily enrollment cap** is enforced at the *enrollment path* (mobile-app enroll fn + uploads), separate from the send cap. [BUILD — enrollment cap not yet wired]

---

## 4. FEATURE — Review Request SMS Drip [LOCKED copy / BUILD click-tracking]

### Enrollment
- Source: the client enrolls a customer via the **mobile app "Review Request" tab** (first name, last name, phone, email). Enrolls into the Review Request SMS Drip ONLY (email drip scrapped — see §7c). One enrollment.
- Subject to the **daily enrollment cap** (default 50/day, overflow queues to next day).
- **Re-enrollment guard [LOCKED]:** a contact already enrolled in the review automation (by client_id + phone) cannot be re-enrolled — block with "contact already enrolled." Applies to both the form and the §7 auto-enroll button.

### Link tracking [BUILD — does not exist yet, skill must construct]
- The review link in every SMS is a **per-contact tracked redirect**, NOT the raw Google URL.
- At enrollment, generate a unique token → maps to (contact_id, client_id, sequence).
- SMS contains `https://<client-domain>/r/<token>`.
- On tap: public route looks up token → writes `review_clicked` event for that contact → sets contact status to **`Review Completed`** → 302-redirects to the client's `review_link` (Google).
- The drip's click-checks read this status; exit the moment it's set.
- Per-contact token = know exactly WHO clicked (required to remove the right contact).

### Sequence & exact copy [LOCKED]
Placeholders use the project's merge system. Charity-meal angle throughout. Opt-out keyword is **"pass"** (added to global opt-out set — whole-word match).

**SMS 1 — day 0 (on enrollment, respecting send window):**
> Hey {first_name}, this is {company_owner_first_name}! I hope you had a great experience with {company_name}!
>
> We donate a meal to charity for every customer who takes 10 seconds to leave a review. Here's the link: {review_link}

**Wait 4 days → check click status. Clicked → mark `Review Completed`, exit. Not clicked → SMS 2:**
> Hey {first_name}! I wanted to follow-up because I saw you haven't left a review yet. We donate a meal to charity for every customer that leaves a review!
>
> If you have 10 seconds to help someone you don't know, you're our kind of people. Click here: {review_link}
>
> P.S. Just say 'pass' if you want me to stop texting you

**Wait 7 days → check. Clicked → exit. Not clicked → SMS 3:**
> Little review reminder incase you got extra busy this week (we give a free meal to someone in need for each new review).
>
> Here's the link again: {review_link}

**Wait 7 days → check. Clicked → exit. Not clicked → SMS 4:**
> Hey {first_name}! This is the last time I'll request a review from you I promise...
>
> if you have a sec to leave one we'll donate a meal to a person in need. Here's the link and thanks for helping those in need! {review_link}

**Wait 48 hours → check. Clicked → mark `Review Completed`, exit. Not clicked → fire internal notification to client's mobile app Notifications tab:**
> Hey {company_owner_first_name}!
>
> We've attempted to get {first_name} to leave you a review 4 times over the last 4 weeks. Try to get in touch with them — they'll have the link in their text messages.
>
> Name: {first_name}
> Phone: {phone}
>
> Here's your direct review link if you need it: {review_request_link}
>
> (Do NOT reply to this message; it's not the client!)

### Status semantics [LOCKED]
- Any exit caused by a detected click (at ANY check stage: day 4 / +7 / +7 / +48h) → contact status = **`Review Completed`**.
- "pass" or any global opt-out keyword → opt out, stop all sends.
- Notification step counts as the drip's terminal action (NOT a customer text).

### Handoff to 1-Year Follow-Up [LOCKED]
- On review-drip **completion, enroll the contact into the 1-Year Follow-Up drip (§5) — UNLESS they opted out.**
- Both outcomes chain forward: (a) clicked → `Review Completed` → enroll; (b) ran through all 4 messages with no click and no opt-out → still enroll.
- ONLY an opt-out (pass/STOP/etc.) blocks the handoff. Opted-out contacts are never enrolled in the 1-Year drip.

### Required custom merge keys
`company_owner_first_name`, `company_name`, `review_request_link` (the client's own direct review link, distinct from the per-contact tracked `review_link`). Add to `template_vars` contract.

---

## 5. FEATURE — One-Year Follow-Up SMS Drip [LOCKED copy]

### Enrollment [LOCKED]
- **No form.** Enrollment is an automatic handoff from the Review Request drip (§4): a contact is enrolled on review-drip completion UNLESS they opted out (see §4 Handoff). Click OR silence both enroll; only opt-out blocks.
- Therefore the human entry point for BOTH drips is the single mobile-app "Review Request" form (§8) — it enrolls into the review drip, and the 1-year drip is downstream of that.

### Exit rules [LOCKED]
- **Exit on REPLY** (any inbound message from the contact that is NOT an opt-out keyword) → remove from drip + fire "they replied" internal notification (with the reply body).
- **Exit on OPT-OUT** (pass/STOP/etc.) → remove from drip, NO "they replied" notification (it's a stop, not interest).
- **Do NOT exit on link click** — the discount links are untracked; clicking does not remove them. Only reply or opt-out exits.
- Precedence: evaluate inbound as opt-out FIRST; if opt-out keyword → opt out silently (no interest notification). Any other inbound → exit + interest notification.

### Dynamic / build notes [BUILD]
- The "they replied" notification injects `{message.body}` — the on-reply handler must capture the triggering inbound message body and merge it into the notification. (`message.body` is dynamic, not a template_var.)
- Discount links are plain marketing URLs (`{company_website_link}/get-your-discount`), same for everyone, NOT per-contact tracked. (A separate discount-claim form governs what happens after a click — see §7b, details TBD.)

### Sequence & exact copy [LOCKED]
All sends obey the global send window (9am–7pm client tz) and daily send cap. Day offsets are from enrollment into THIS drip.

**SMS 1 — day 30:**
> Hey {first_name}! I'm running a season special this week and giving {discount__on_referral}.
>
> It's only for the first three people, so if you're interested (or know someone who might be), just tap this link: {company_website_link}/get-your-discount
>
> -{company_owner_first_name} from {company_name}

**On reply at any point → exit + internal notification:**
> Hey {company_owner_first_name},
>
> {first_name} just replied to your return/referral discount offer in the 1-year follow-up sequence!
>
> Their response: {message.body}
>
> You can reach them at {phone} if needed.
>
> (Do NOT reply to this message; it's not the client!)

**Wait 8 weeks (no reply / no opt-out) → SMS 2:**
> Hey {first_name}! I'm running a customer anniversary special for the next 6 days and giving {discount__on_referral}, so if you're interested (or know someone who might be), just tap this link: {company_website_link}/get-your-discount
>
> -{company_owner_first_name} from {company_name}

**After SMS 2 → internal notification to client:**
> {company_owner_first_name}, it's been 3 months since you added {first_name} into your 1-year follow-up sequence.
>
> We just sent them a discount offer to ask for referrals!
>
> Their number is {phone} if you want to reach out / or they contact you.
>
> (Do NOT reply to this message; it's not the client!)

**Wait 3 months → SMS 3:**
> Hey {first_name}! I'm running a loyalty special this week and giving {discount__on_referral}.
>
> It's only for the first three people, so if you're interested (or know someone who might be), just tap this link: {company_website_link}/get-your-discount
>
> -{company_owner_first_name} from {company_name}

**Wait 3 months → SMS 4:**
> Hey {first_name}! I'm running a special this week and giving {discount__on_referral}.
>
> It's only for the first four people, so if you're interested (or know someone who might be), just tap this link: {company_website_link}/get-your-discount
>
> -{company_owner_first_name} from {company_name}

**Wait 3 months → SMS 5:**
> Hey {first_name}! I'm running an anniversary special giving {discount__on_referral}.
>
> It's only for the next 6 days, so if you're interested (or know someone who might be), just tap this link: {company_website_link}/get-your-discount
>
> -{company_owner_first_name} from {company_name}

**After SMS 5 → final internal notification + remove from sequence (end of drip):**
> Hey {company_owner_first_name}!
>
> It's been about a year since we added {first_name} to your 1-year follow-up sequence for referrals / return-customer discounts. We're removing them from further follow-up.
>
> If you'd like to contact them for a referral or to see if they'd use your service again, reach them at {phone}.
>
> (Do NOT reply to this message; it's not the client!)

Note: the "they replied" interest notification (copy above) fires on a reply after ANY of SMS 1–5, not just SMS 1.

### Required custom merge keys [LOCKED]
New keys (set per-client in `/admin-view` Settings, added to template_vars contract): `discount__on_referral`, `company_website_link`. Plus existing `company_owner_first_name`, `company_name`. Dynamic (not template_vars): `message.body`.

## 6. `/opt-in-forms` — forms → automations map [LOCKED]
- **Mobile app "Review Request" tab form** (first_name, last_name, phone, email) → enrolls into Review Request SMS Drip (§4) ONLY. Subject to the daily enrollment cap. This is the ONLY human entry point for the review/1-year feature chain. **Re-enrollment guard:** a contact already enrolled in the review automation (by client_id + phone) cannot be re-enrolled — block and show "contact already enrolled" so owners can safely re-attempt without double-texting.
- **One-Year Follow-Up drip has NO form** — automatic handoff from review-drip completion (§4/§5).
- **Public website lead form** (first_name, last_name, phone, email, your_message) → enrolls into the Lead-Form drip (§7). Public route, anon insert constrained to `source IN ('web_form','review_enroll')`.
- Existing public funnel pages: `/r/rate`, `/r/feedback`, `/r/enroll`.
- Discount-claim form (§7b) — TBD.

## 7. FEATURE — Website Lead-Form Drip [LOCKED copy]

**Purpose:** instant response + owner alerting when a lead submits the public website form requesting a quote/contact.

**Enrollment:** public website lead form (first_name, last_name, phone, email, your_message). source = `web_form`.

**Two-window model [LOCKED — see §2]:** the lead-form drip branches on **Business Hours** (a SEPARATE per-client setting from the marketing SMS Send Window). Business Hours = "is the owner reachable / open" and governs lead-form branching only. SMS Send Window (9am–7pm) governs marketing/follow-up drips only. They are independent values.

**Lead-form SMS is transactional** (the lead just requested contact) — it does NOT defer to the marketing send window; it branches on Business Hours instead.

### Branch A — submitted DURING Business Hours
1. Wait 30s → internal notification to client.
2. SMS #1 to the lead — **[INTENTIONAL TYPO — DO NOT CORRECT: "touchr"]**.
3. Wait 30s → SMS #2 to the lead (the correction) — **skip if the lead already replied**.
4. Day 10 → owner reminder (see below).

### Branch B — submitted OUTSIDE Business Hours
1. Single after-hours SMS to the lead (no typo, no second text).
2. After-hours owner notification (so they see it when back).
3. Day 10 → owner reminder (same as Branch A — fires on BOTH paths).
(After-hours customer-facing drip ends after the single SMS; the normal two-text sequence does NOT fire later.)

### Exact copy [LOCKED]
Naming convention (consistent across all skills): `{first_name}` in customer-facing texts; `{full_name}` in internal notifications. `{request_time}` = submission time rendered in the CLIENT's timezone, human-readable; dynamic, not a template_var.

**Internal notification to client (both branches, ~30s / on submit):**
> New Lead from Website lead-form!
>
> Name: {full_name}
> Phone: {phone}
> Message: {your_message}
>
> We've let them know you'll be in touch soon.
>
> (Do NOT reply to this message; it's not the client!)

**SMS #1 to lead — Branch A only — [INTENTIONAL TYPO, DO NOT CORRECT]:**
> Hey {first_name}! Just got your form! I'll be in touchr shortly!
> -{company_owner_first_name} with {company_name}

**SMS #2 to lead — Branch A only, the correction (skip if lead already replied):**
> I'll be in *touch* shortly! Sorry I haven't had enough coffee today haha!
> Talk soon!

**After-hours SMS to lead — Branch B only (replaces #1 and #2):**
> Hey {first_name}, just got your form. We'll be in touch as soon as possible!
> -{company_owner_first_name} with {company_name}

**After-hours owner notification — Branch B only (fires after the after-hours SMS):**
> Hey {company_owner_first_name}!
>
> {full_name} submitted a request on your website at {request_time} — outside your business hours, so we sent them an after-hours reply.
>
> Phone: {phone}
>
> Reach out when you're back.
>
> (Do NOT reply to this message; it's not the client!)

**Day-10 owner reminder — BOTH branches. Suppress if the lead's phone is now enrolled in the review automation. Includes an auto-enroll button:**
> Hey {company_owner_first_name},
>
> It's been about 10 days since {full_name} filled out a request on your website. If you've worked with them, please remember to add their info to your marketing form. This is important!
>
> Name: {full_name}
> Phone: {phone}
>
> If you haven't added them yet, add their info into the Review Request form — or auto-enroll them below.
>
> [Auto-Enroll button]
>
> (Do NOT reply to this message; it's not the client!)

**Auto-Enroll button [BUILD]:** in the mobile-app Notifications tab, the button enrolls this contact into the Review Request drip directly (no manual form entry). It runs the same re-enrollment guard — if already enrolled, it displays "contact already enrolled" instead of enrolling.

### Exit / build notes
- If the lead replies before SMS #2 (Branch A) → skip SMS #2. [BUILD: reply detection on the inbound webhook tied to this drip]
- Branch selection happens at submission time based on Business Hours in the client's timezone.
- [BUILD] Business Hours is a NEW per-client Settings field, separate from the SMS Send Window (§2).

## 7c. Customer Review Request Email Drip — REMOVED
Scrapped. Review request is SMS-only. The mobile-app Review Request form enrolls into the SMS drip only (one enrollment, not two).

## 7d. FEATURE — Owner Email Notifications [LOCKED]

When a lead-form or discount-form submission fires its in-app notification, the owner ALSO gets an email pointing them to the app. The in-app notification still fires — the email is additive. **One email per lead** (the after-hours case is a variant of the website-lead email, not a second email).

**Channel:** Lovable NATIVE transactional email (this is a system event-notification to the account owner = legitimately transactional, unlike customer marketing email). Sends from the client's verified sending subdomain; SPF/DKIM/DMARC auto-handled; low volume, no warmup concern. Does NOT use the external marketing sender.

**Formatting standard [applies to ALL notification + email copy]:** stack details on separate lines for scannability — never run "Name: X Phone: Y Message: Z" inline. Apply this to the in-app notifications too.

### Email — Subject: `New Website Lead` (business-hours version)
> Hey {company_owner_first_name},
>
> You've got a new lead from your website form!
>
> Name: {full_name}
> Phone: {phone}
> Message: {your_message}
>
> We've already texted them to say you'll be in touch. Open your app to see the conversation.

### Email — Subject: `New Website Lead` (after-hours version)
> Hey {company_owner_first_name},
>
> You've got a new lead from your website form — submitted at {request_time}, outside your business hours, so we sent them an after-hours reply.
>
> Name: {full_name}
> Phone: {phone}
> Message: {your_message}
>
> Open your app and reach out when you're back.

### Email — Subject: `New Referral/Discount Lead`
> Hey {company_owner_first_name},
>
> {first_name} just filled out your discount form!
>
> Name: {full_name}
> Phone: {phone}
> Message: {your_message}
>
> We've told them you'll be reaching out soon. Open your app to see the details.

Note: in email, the phone displays as text (no click-to-call); the click-to-call `tel:` link lives in the in-app notification.

## 7b. FEATURE — Discount-Claim Form & Drip [LOCKED]

The page at `{company_website_link}/get-your-discount` (destination of the one-year drip links). A public lead-capture form on the client's site.

### Form structure [LOCKED]
**Banner:** company name + logo; headline **"Get {discount_amount} with us!"**
**Fields:** First Name, Last Name, Phone, Your Message
**Consent checkbox:** "I agree to [terms & conditions]({website_terms_page_link}) provided by the company. By providing my phone number, I agree to receive text messages from the business."
**Button:** "Get My Discount!"

- Public form → inserts a contact with source constrained to `web_form` (per tightened RLS). Phone normalized to E.164.
- Terms link points to the CLIENT's own terms page (`{website_terms_page_link}` template_var, or the site `/terms` route) — NOT any external/leadconnector URL.

### One-year drip interaction [LOCKED]
- If the submitting contact is currently in the One-Year Follow-Up drip, the submission **EXITS them from that drip** (a form submission with contact info + consent is real re-engagement — distinct from a raw link click, which does NOT exit). Fire the one-year "they engaged" handling (owner sees the discount-form notification below, which serves that purpose).

### Drip & exact copy [LOCKED]
Naming: `{full_name}` internal, `{first_name}` customer-facing.

**On submit → internal notification to client (immediate):**
> Hey {company_owner_first_name},
>
> {first_name} just filled out your discount form on the website!
>
> Name: {full_name}
> Phone: {phone}
> Message: {your_message}
>
> We've told them you'll be reaching out soon.
>
> (Do NOT reply to this message; it's not the client!)

**Wait 2 minutes → SMS to the lead:**
> Hey {first_name}, just got your discounted request! I'll be in touch shortly and get you that discount!
> -{company_owner_first_name} with {company_name}

Then the drip ends.

### Merge keys
New: `{discount_amount}` (banner display amount — SEPARATE from `{discount__on_referral}` used in the one-year SMS), `{website_terms_page_link}`. Existing: `company_owner_first_name`, `company_name`.

---

## 8. `/mobile-app` — client app at `app.theirdomain.com` [LOCKED scope / BUILD tabs]
Mobile-first PWA, scoped to the logged-in client's `client_id`.
- **Conversations tab** — SMS threads across all contacts in this client's CRM. (Exists at `/app`.)
- **Review Request tab** — the enrollment form (first/last/phone/email) → enrolls into Review SMS Drip + Email Drip, subject to daily enrollment cap. [BUILD]
- **Notifications tab** — internal notifications to the client: automation-finished alerts (e.g. §4 step-5), weekly/monthly stats, messages. Needs a notifications table + automations writing to it + app UI reading it. [BUILD — net-new subsystem]

---

## 9. Other features (status)

### FEATURE — Missed-Call Textback [LOCKED]
**Trigger:** inbound call to the client's Twilio number ends with status **busy, cancelled, no-answer, or voicemail**. (All four included; "cancelled" intentionally kept to catch more leads.)
**Timing:** fires 24/7 — a missed call is a live signal, so it is NOT gated by the SMS Send Window or Business Hours. Transactional; exempt from the bulk marketing throttle.
**Contact handling:** create/match the contact by `phone_e164`, log the missed call (event), send the drip. Replies flow into the normal inbox/conversation.
**Re-eligibility (7-day rule):** the drip fires only if this contact (client_id + phone) has NOT received a missed-call textback in the last 7 days. First missed call → fires + records `last_missed_call_textback_at`. Any missed call within 7 days of the last send → logged but suppressed (no re-send). A missed call ≥7 days after the last send → eligible again, re-enrolls and fires. (Boundary = 7 days from the last actual textback SEND, per client_id + phone.)

**Flow:**
1. On missed-call status → **wait 1 minute** (so it doesn't feel like a bot).
2. Send **SMS #1** to the caller + fire the **internal notification** to the client (same time).
3. **Wait 2 minutes.** If the caller replied in that window → skip SMS #2. Else → send **SMS #2**.

**SMS #1 (after 1-min wait):**
> Hey, sorry I missed you! I'll get back to you as soon as possible!
>
> If you want to give me a few details about the job, that would be great. You can click this link for a free quote:
>
> {company_website_link}/contact
> -{company_owner_first_name} from {company_name}

**SMS #2 (after 2-min wait, only if no reply):**
> Look forward to hearing from you!... In the meantime are there any quick questions I can answer here for ya?

**Internal notification (fires with SMS #1):**
> You missed a call from {caller_phone} at {call_time}, so we sent them a text.
>
> View the conversation here: [Open conversation button]

**Merge keys:** `{company_website_link}`, `{company_owner_first_name}`, `{company_name}` (existing template_vars). Dynamic (not template_vars): `{caller_phone}`, `{call_time}` (client tz, human-readable). Note: a brand-new caller has no name yet, so the notification keys off phone + time, not name.

### Other features
- **Customer reactivation** [scope to confirm] — CSV/paste upload → dedupe → enroll in `reactivation_drip` (day 0/3/7, exits on `reviewed`), conservative throttle profile. Copy not yet reviewed/finalized.
- **Inbound SMS → CRM** [built] — every inbound creates/updates conversation + message; STOP/HELP/START + `pass` handled at webhook.

---

## 10. Open items blocking skill authoring
- [TBD] Copy-strategy decision (templatize hardcoded marketing copy vs rewrite per vertical) — blocks `/theme-to-brand`.
- [TBD] Onboarding form vs SQL/settings (`createClient` only takes 4 fields today) — blocks `/onboard-from-form`.
- [BUILD] Tracked-redirect link system for review drip (§4); daily enrollment cap (§3); Notifications subsystem (§8); mobile Review Request tab + Auto-Enroll button (§7/§8); "pass" keyword → opt-out (§4); on-reply handler capturing `message.body` (§5) and lead reply-detection (§7); Business Hours setting + lead-form branching (§2/§7); re-enrollment guard (§4/§6); discount-form-submit exits one-year drip (§7b); per-contact `last_missed_call_textback_at` timestamp + 7-day re-eligibility check (§9); constrained RLS (no wide-open anon inserts) baked into `/scratch-foundation`.

## 11. Locked & done (captured above)
- Review Request SMS drip — full copy, tokenized tracking, exit-on-click, SMS-only (§4).
- Review→1-Year handoff rule — enroll unless opted out (§4).
- One-Year Follow-Up SMS drip — full copy, exit-on-reply-or-opt-out, no form (§5).
- Website Lead-Form drip — full copy, two-window branching, intentional-typo guard, day-10 reminder + auto-enroll button (§7).
- Discount-Claim Form & drip — form structure, copy, exits one-year drip on submit (§7b).
- Owner Email Notifications — Lovable native transactional, one per lead, formatted with line breaks (§7d).
- Missed-Call Textback — full scope + copy: 24/7, 4 triggers, 1-min/2-min drip, reply-skip, 7-day re-eligibility per contact, internal notification (§9).
- Email drip — SCRAPPED, SMS-only (§7c).
- Re-enrollment guard (§4/§6). opt-in-forms map (§6 — now FINITE). Two-window model + two caps (§2/§3). admin-view tabs (§2).
- Naming convention: `{first_name}` customer-facing, `{full_name}` internal notifications.

## 12. Backlog / Work Queue (ordered)

### DONE
- ~~SMS automation formatting pass~~ ✓ COMPLETE — all customer-facing SMS finalized with intended line breaks (proofread/approved); all internal notifications + emails reformatted to stacked form (§4/§5/§7/§7b + `/automation-config` + `/mobile-app`); owner-email copy added to `/automation-config`. `/features` is mechanics-only (no inline copy). Customer SMS remain editable on-site.

### >>> NEXT UP <<<
- Pick from "FEATURES STILL TO DEFINE" below, or write `/scratch-foundation`, or make an architecture decision.

### FEATURES STILL TO DEFINE (not yet scoped — full definition needed)
- **Review Automation Funnel form/page — NEEDS FULL SETUP.** The funnel direction (`/r/rate`, gating, `/r/enroll`) has NOT been detailed. Detailed setup: page look/flow, contact movement, gating config, ties to review drip + tracked link.
- **Chat-Widget Lead Opt-In — NEEDS FULL BUILD DIRECTION.** Separate chat-widget feature for leads who opt in via an on-site widget. Needs whole layout/build direction: widget look, lead capture, what it collects, which drip it feeds, how it differs from the website lead form.

### LATER / PARKED (non-blocking)
- **PWA web-push notifications** — superseded by owner email notifications (§7d); revisit if real-time phone push wanted.
- **Stats label** — decided: dashboard uses "New Google Reviews" (counts review-link clicks).

### ARCHITECTURE DECISIONS PENDING (block 2 skills)
- Copy-strategy: templatize hardcoded marketing copy vs rewrite per vertical → blocks `/theme-to-brand`.
- Onboarding form vs SQL/settings (`createClient` takes 4 fields today) → blocks `/onboard-from-form`.
