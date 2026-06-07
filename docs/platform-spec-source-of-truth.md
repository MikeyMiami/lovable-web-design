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
- Timezone (drives all SMS send windows).
- Send window (default **09:00–19:00**, client timezone) — applies to ALL SMS automation.
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
- Source: the client enrolls a customer via the **mobile app "Review Request" tab** (first name, last name, phone, email). Also enrolls them into the Customer Review Request Email Drip simultaneously (two enrollments). [email drip = TBD §7]
- Subject to the **daily enrollment cap** (default 50/day, overflow queues to next day).

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
> Hey {first_name}, this is {company_owner_first_name}! I hope you had a great experience with {company_name}! We donate a meal to charity for every customer who takes 10 seconds to leave a review. Here's the link: {review_link}

**Wait 4 days → check click status. Clicked → mark `Review Completed`, exit. Not clicked → SMS 2:**
> Hey {first_name}! I wanted to follow-up because I saw you haven't left a review yet. We donate a meal to charity for every customer that leaves a review! If you have 10 seconds to help someone you don't know, you're our kind of people. Click here: {review_link}  P.S. Just say 'pass' if you want me to stop texting you

**Wait 7 days → check. Clicked → exit. Not clicked → SMS 3:**
> Little review reminder incase you got extra busy this week (we give a free meal to someone in need for each new review). Here's the link again: {review_link}

**Wait 7 days → check. Clicked → exit. Not clicked → SMS 4:**
> Hey {first_name}! This is the last time I'll request a review from you I promise... if you have a sec to leave one we'll donate a meal to a person in need. Here's the link and thanks for helping those in need! {review_link}

**Wait 48 hours → check. Clicked → mark `Review Completed`, exit. Not clicked → fire internal notification to client's mobile app Notifications tab:**
> Hey {company_owner_first_name}! We've attempted to get {first_name} to leave you a review 4 times over the course of the last 4 weeks. Try to get in touch with them to leave you a review. They'll have the link in their text messages. Their information: Name: {first_name} Phone: {phone}  Here's your direct review link again if you need it: {review_request_link}

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
> Hey {first_name}! I'm running a season special this week and giving {discount__on_referral}. It's only for the first three people, so if you're interested (or know someone who might be), just tap this link: {company_website_link}/get-your-discount  -{company_owner_first_name} from {company_name}

**On reply at any point → exit + internal notification:**
> Hey {company_owner_first_name}, {first_name} just replied to your return/referral discount offer in the 1-year follow-up sequence! Here's their response: {message.body}  You can reach them at {phone} if needed. (Do NOT reply to this message; it's not the client!)

**Wait 8 weeks (no reply / no opt-out) → SMS 2:**
> Hey {first_name}! I'm running a customer anniversary special for the next 6 days and giving {discount__on_referral}, so if you're interested (or know someone who might be), just tap this link: {company_website_link}/get-your-discount  -{company_owner_first_name} from {company_name}

**After SMS 2 → internal notification to client:**
> {company_owner_first_name}, it's been 3 months since you added {first_name} into your 1 year follow up sequence. We just sent them a little discount offer to ask for referrals! Their number is {phone} if you want to reach out / or they contact you! (Do NOT reply to this message; it's not the client!)

**Wait 3 months → SMS 3:**
> Hey {first_name}! I'm running a loyalty special this week and giving {discount__on_referral}. It's only for the first three people, so if you're interested (or know someone who might be), just tap this link: {company_website_link}/get-your-discount  -{company_owner_first_name} from {company_name}

**Wait 3 months → SMS 4:**
> Hey {first_name}! I'm running a special this week and giving {discount__on_referral}. It's only for the first four people, so if you're interested (or know someone who might be), just tap this link: {company_website_link}/get-your-discount  -{company_owner_first_name} from {company_name}

**Wait 3 months → SMS 5:**
> Hey {first_name}! I'm running an anniversary special giving {discount__on_referral}. It's only for the next 6 days, so if you're interested (or know someone who might be), just tap this link: {company_website_link}/get-your-discount  -{company_owner_first_name} from {company_name}

**After SMS 5 → final internal notification + remove from sequence (end of drip):**
> Hey {company_owner_first_name}! It's been about a year since we added {first_name} to your 1 year follow up sequence for referrals / return customer discounts. We are removing them from further follow up. If you want to contact them for a referral or to see if they'd like to use your service again please contact them at {phone}! (Do NOT reply to this message; it's not the client!)

Note: the "they replied" interest notification (copy above) fires on a reply after ANY of SMS 1–5, not just SMS 1.

### Required custom merge keys [LOCKED]
New keys (set per-client in `/admin-view` Settings, added to template_vars contract): `discount__on_referral`, `company_website_link`. Plus existing `company_owner_first_name`, `company_name`. Dynamic (not template_vars): `message.body`.

## 6. `/opt-in-forms` — forms → automations map [LOCKED]
- **Mobile app "Review Request" tab form** (first_name, last_name, phone, email) → enrolls into Review Request SMS Drip (§4) AND Customer Review Request Email Drip (§7), subject to the daily enrollment cap. This is the ONLY human entry point for the review/1-year feature chain.
- **One-Year Follow-Up drip has NO form** — automatic handoff from review-drip completion (§4/§5).
- Existing public funnel pages: `/r/rate`, `/r/feedback`, `/r/enroll`.
- Discount-claim form (§7b) — TBD.

## 7. FEATURE — Customer Review Request Email Drip [TBD — steps coming from user]
Triggered alongside the mobile-app review enrollment (§6). Must go through the **external email sender** (Resend etc.), NOT Lovable native email (transactional-only). Steps/copy/timing TBD.

## 7b. FEATURE — Discount-Claim Form & lead handling [TBD — details coming from user]
The `{company_website_link}/get-your-discount` destination. A form a contact fills to claim the referral/return discount, plus how that contact is then treated (status change, handoff to client, any follow-on automation, whether the link needs tracking after all). Full details to be provided.

---

## 8. `/mobile-app` — client app at `app.theirdomain.com` [LOCKED scope / BUILD tabs]
Mobile-first PWA, scoped to the logged-in client's `client_id`.
- **Conversations tab** — SMS threads across all contacts in this client's CRM. (Exists at `/app`.)
- **Review Request tab** — the enrollment form (first/last/phone/email) → enrolls into Review SMS Drip + Email Drip, subject to daily enrollment cap. [BUILD]
- **Notifications tab** — internal notifications to the client: automation-finished alerts (e.g. §4 step-5), weekly/monthly stats, messages. Needs a notifications table + automations writing to it + app UI reading it. [BUILD — net-new subsystem]

---

## 9. Other existing features (to be scoped in `/features`)
- **Missed-call textback** [LOCKED-ish] — voice webhook → no-answer/busy → fires `missed_call_textback` template to caller, deduped per (client, caller, 30-min). Exempt from bulk throttle. Confirm scope.
- **Customer reactivation** — CSV/paste upload → dedupe → enroll in `reactivation_drip` (day 0/3/7, exits on `reviewed`), conservative throttle profile. Confirm scope.
- **Inbound SMS → CRM** — every inbound creates/updates conversation + message; STOP/HELP/START + now **"pass"** handled at webhook.

---

## 10. Open items blocking skill authoring
- [TBD] Email drip steps (§7).
- [TBD] Discount-claim form + lead handling (§7b) — incl. whether discount links need tracking after all.
- [TBD] Copy-strategy decision (templatize hardcoded marketing copy vs rewrite per vertical) — blocks `/theme-to-brand`.
- [TBD] Onboarding form vs SQL/settings (`createClient` only takes 4 fields today) — blocks `/onboard-from-form`.
- [BUILD] Tracked-redirect link system for review drip (§4), daily enrollment cap (§3), Notifications subsystem (§8), mobile Review Request tab (§8), "pass" keyword added to opt-out (§4), on-reply handler capturing `message.body` for 1-year notifications (§5).

## 11. Locked & done (captured above)
- Review Request SMS drip — full copy, tokenized tracking, exit-on-click (§4).
- Review→1-Year handoff rule — enroll unless opted out (§4).
- One-Year Follow-Up SMS drip — full copy, exit-on-reply-or-opt-out, no form (§5).
- opt-in-forms map (§6). Send window + two caps (§3). admin-view tabs (§2).
