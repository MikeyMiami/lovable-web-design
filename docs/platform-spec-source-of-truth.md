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
- Any exit caused by a detected click → contact status = **`Review Completed`**.
- "pass" or any global opt-out keyword → opt out, stop all sends.
- Notification step counts as the drip's terminal action (NOT a customer text).

### Required custom merge keys
`company_owner_first_name`, `company_name`, `review_request_link` (the client's own direct review link, distinct from the per-contact tracked `review_link`). Add to `template_vars` contract.

---

## 5. FEATURE — One-Year Follow-Up SMS Drip [TBD — build coming from user]
Enrollment via a website form (see §6). Full sequence/copy/exit-rules to be provided. Open question still: does it exit on review/booking, or only on opt-out?

## 6. `/opt-in-forms` — forms → automations map [PARTIAL]
- **Website form → One-Year Follow-Up drip** enrollment. [details TBD with §5]
- **Mobile app "Review Request" tab form** → Review Request SMS Drip + Email Drip (§4). [LOCKED trigger]
- Existing public funnel: `/r/rate`, `/r/feedback`, `/r/enroll`.
- (Each form: fields, validation, which client_id it writes to, which sequence it enrolls into — to be fully enumerated.)

## 7. FEATURE — Customer Review Request Email Drip [TBD — steps coming from user]
Triggered alongside the mobile-app review enrollment. Must go through the **external email sender** (Resend etc.), NOT Lovable native email (transactional-only). Steps/copy/timing TBD.

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
- [TBD] One-Year Follow-Up full build (§5) + its exit rule.
- [TBD] Email drip steps (§7).
- [TBD] Copy-strategy decision (templatize hardcoded marketing copy vs rewrite per vertical) — blocks `/theme-to-brand`.
- [TBD] Onboarding form vs SQL/settings (`createClient` only takes 4 fields today) — blocks `/onboard-from-form`.
- [BUILD] Tracked-redirect link system (§4), enrollment cap (§3), Notifications subsystem (§8), mobile Review Request tab (§8), "pass" keyword added to opt-out (§4).
