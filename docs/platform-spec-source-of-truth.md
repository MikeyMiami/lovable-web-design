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
5. `/chat-widget` — the AI chat widget (§7e): opt-in gate, FAQ retrieval, pricing guardrail, request→lead-form handoff.
6. `/mobile-app` — the client app (`app.theirdomain.com`): Conversations, Review Request, Notifications tabs.
7. `/admin-view` — the admin tabs/settings on the client website (what's editable where).
8. `/launch-check` — pre-go-live verification gate.
9. `/new-client-site` — orchestrates the from-scratch build for a new client.
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

### Link tracking + Review Funnel [BUILD — does not exist yet, skill must construct]
- The review link in every SMS is a **per-contact tracked redirect**, NOT the raw Google URL.
- At enrollment, generate a unique token → maps to (contact_id, client_id, sequence).
- SMS contains `https://<client-domain>/r/<token>`.
- On tap: public route looks up token → writes `review_clicked` event → **lands the contact on the Review Funnel rate page (`/r/rate`)**.
- **Landing on `/r/rate` EXITS the contact from the review drip immediately** (they clicked through — this is the click the drip was watching for). Status + one-year handoff are then determined by their star selection (below).

### Review Funnel pages [LOCKED]
The same funnel is the destination for BOTH the review-drip tracked link and the reactivation link.

**`/r/rate`** — text "How would you rate us?" + a 1–5 star multiple-choice. Threshold = per-client `star_threshold` in `/admin-view` (default 4, **inclusive ≥**).
- **Selection ≥ threshold** → status **`Review Completed`** → redirect to the client's Google review page (deep-links the leave-a-review screen on their GBP) → **enroll into the One-Year Follow-Up drip** (normal handoff).
- **Selection < threshold** → status **`Negative Review`** → go to `/r/feedback`. **Does NOT enroll into the One-Year drip.**

**`/r/feedback`** (below-threshold path) — collects **Name, Email, Feedback**; **phone auto-fills** from the mapped contact (they arrived via their token). Stores in `review_feedback`. On submit → fires the owner email + mobile-app notification (below) → shows the customer confirmation screen.

**Customer confirmation screen** (after feedback submit):
> I'm sorry we missed the mark... 😔
>
> Thank you for letting us know. We value your review regardless and appreciate you letting us know where we can improve.

**Owner email — Subject: We Saved You From a Negative Review** (Lovable native transactional):
> Hey {company_owner_first_name},
>
> We just saved you from getting a bad Google review. You can read about this customer's experience here:
>
> Name: {full_name}
> Email: {email}
> Phone: {phone}
> Message: {feedback_message}

**Mobile-app notification (same content, fires with the email):**
> We just saved you from getting a bad Google review. You can read about this customer's experience here:
>
> Name: {full_name}
> Email: {email}
> Phone: {phone}
> Message: {feedback_message}

**Status semantics:** `Review Completed` (≥ threshold, went to Google) vs `Negative Review` (< threshold, left private feedback). Both exit the review drip; only `Review Completed` hands off to One-Year. `/r/enroll` is REMOVED (enrollment happens via the mobile-app Review Request form).
New dynamic key: `{feedback_message}` (the feedback text). `{email}` from the feedback form.

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
- On review-drip **completion, enroll the contact into the 1-Year Follow-Up drip (§5) — UNLESS they opted out OR are marked `Negative Review`.**
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
- **Mobile app "Review Request" tab form** (first_name, last_name, phone, email) → enrolls into Review Request SMS Drip (§4) ONLY. Subject to the daily enrollment cap. This is the entry point for the review/1-year chain (review enrollment happens here, by the client — there is no public self-enroll page). **Re-enrollment guard:** a contact already enrolled in the review automation (by client_id + phone) cannot be re-enrolled — block and show "contact already enrolled" so owners can safely re-attempt without double-texting.
- **One-Year Follow-Up drip has NO form** — automatic handoff from review-drip completion (§4/§5).
- **Public website lead form** (first_name, last_name, phone, email, your_message) → enrolls into the Lead-Form drip (§7). Public route, anon insert constrained to `source IN ('web_form','review_enroll')`.
- Public funnel pages: `/r/rate`, `/r/feedback`. (`/r/enroll` removed.)
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

## 7e. FEATURE — AI Chat Widget Lead Opt-In [LOCKED — own skill `/chat-widget`]

A corner chat widget on the client's website. An AI assistant answers FAQs from the client's business data and routes quote/pricing interest into the same lead pipeline as the website lead form. Net-new; the largest single feature — gets its own `/chat-widget` skill.

### AI model & knowledge source
- **Model:** Lovable's native/built-in AI capability (no third-party API setup — Lovable can build this self-contained). NOT per-client fine-tuning — uses retrieval: the client's business info is provided to the model as context at chat time.
- **Knowledge source [DEPENDENCY]:** the AI answers from (a) the client's website content and (b) the **business onboarding form data** (services, hours, business details — the same data that builds the site copy). The AI's knowledge inputs are now defined by the onboarding form (§9b): About Us, services (detailed), service areas, hours, special/differentiators, social/site content. Answer quality = onboarding data captured.

### Opt-in gate [LOCKED]
- The widget opens with: **"What do you need help with?"** → two options: **Question** and **Request Services / Contact Us**.
- BEFORE the AI converses on either path, the person opts in with: **First Name, Last Name, Email, Phone, and their message/question.** (SMS opt-in + terms consent language required, since phone is collected for texting.)
- Contact created with source **`chat_widget`** (distinct from `web_form`, so leads are attributable to the widget). Phone E.164.

### Behavior [LOCKED]
- **Question (FAQ) path:** the AI answers general questions about the business and its services from the business data (e.g. "do you offer drain cleaning?", "what are your hours?").
- **Pricing/quote guardrail:** the AI must NOT quote prices or give official pricing. Any question asking a price or a quote → the AI directs them to submit a request ("Let me get you an accurate quote — fill in your request and the team will reach out"). General service *info* is answered; *pricing/quotes* are redirected. This is a system-prompt guardrail (strong but soft — instruct firmly).
- **Request path:** works exactly like the main website lead form (§7) — creates the contact, enrolls into the SAME lead-form drip + automations (business-hours branching, the typo/correction texts, day-10 reminder, owner email). After a request is submitted, the AI confirms: it sent the request to the team and they'll hear back shortly.
- **The ONLY difference from the website lead form:** the owner notification (in-app + email) reads **"New Website AI Chat Lead"** instead of "New Website Lead." All downstream automation/enrollment is identical.

### AI hard rules (system prompt guardrails) [LOCKED]
- Never quote prices or give official pricing → always redirect to the request form.
- Only discuss this business and its services; don't answer off-topic/general questions unrelated to the business.
- Don't make promises or commitments on the owner's behalf beyond "the team will reach out."
- If unsure / lacks the info → direct them to submit a request so the team can follow up.

### Owner notification copy (variant of §7 / §7d)
**In-app + email subject: New Website AI Chat Lead** (otherwise identical body to the website-lead notification/email):
> Hey {company_owner_first_name},
>
> You've got a new lead from your website AI chat!
>
> Name: {full_name}
> Phone: {phone}
> Message: {your_message}
>
> We've already replied to them in the chat. Open your app to see the conversation.

(Business-hours / after-hours branching applies the same as §7, since it feeds the same lead-form drip. The notification label is the only copy difference.)

### Build notes [BUILD]
- Real-time AI chat UI (corner widget) on the client site; Lovable native AI for responses.
- Opt-in gate before chat; consent capture; `chat_widget` contact source.
- Retrieval context assembled from onboarding data + site content.
- Request path reuses the §7 lead-form enrollment exactly; only the owner-notification label differs.
- AI knowledge inputs = §9b onboarding fields (About Us, services, areas, hours, differentiators) + site content.

---

## 8. `/mobile-app` — client app at `app.theirdomain.com` [LOCKED scope / BUILD tabs]
Mobile-first PWA, scoped to the logged-in client's `client_id`.
- **Conversations tab** — SMS threads across all contacts in this client's CRM. (Exists at `/app`.)
- **Review Request tab** — the enrollment form (first/last/phone/email) → enrolls into Review SMS Drip, subject to daily enrollment cap. [BUILD]
- **Notifications tab** — internal notifications to the client: automation-finished alerts (e.g. §4 step-5), weekly/monthly stats, messages. Needs a notifications table + automations writing to it + app UI reading it. [BUILD — net-new subsystem]

---

## 9. Other features (status)

### FEATURE — Missed-Call Textback [LOCKED]
**Trigger:** inbound call to the client's Twilio number ends with a Twilio call status of **`busy`, `no-answer`, `canceled`, or `failed`** (matched against Twilio's literal status strings — note `no-answer` hyphenated, `canceled` one L). Voice-status webhook (`/api/public/twilio/voice-status`). Note: a call that rolls to voicemail reports as `completed` and does NOT fire (catching voicemail would require Answering Machine Detection — out of scope).
**Timing:** fires 24/7 — a missed call is a live signal, so it is NOT gated by the SMS Send Window or Business Hours. Transactional; exempt from the bulk marketing throttle.
**Contact handling:** create/match the contact by `phone_e164`, log the missed call (event), send the drip. Replies flow into the normal inbox/conversation.
**Re-eligibility (7-day rule):** the drip fires only if this contact (client_id + phone) has NOT received a missed-call textback in the last 7 days. First missed call → fires + records `last_missed_call_textback_at`. Any missed call within 7 days of the last send → logged but suppressed (no re-send). A missed call ≥7 days after the last send → eligible again, re-enrolls and fires. (Boundary = 7 days from the last actual textback SEND, per client_id + phone.)

**Flow:**
1. On qualifying missed-call status → **wait 1 minute** (so it doesn't feel like a bot).
2. Send **SMS #1** to the caller + fire the **internal notification** to the client (same time).
3. **Wait 2 minutes.** If the caller replied in that window → skip SMS #2. Else → send **SMS #2**.

**SMS #1 (after 1-min wait):**
> Hey, sorry I missed you! I'll get back to you as soon as possible!
>
> If you want to give me a few details about the job, that would be great. You can click this link for a free quote:
>
> {quote_form_link}
> -{company_owner_first_name} from {company_name}

**SMS #2 (after 2-min wait, only if no reply):**
> Look forward to hearing from you!... In the meantime are there any quick questions I can answer here for ya?

**Internal notification (fires with SMS #1):**
> You missed a call from {caller_phone} at {call_time}, so we sent them a text.
>
> View the conversation here: [Open conversation button]

**Merge keys:** `{quote_form_link}` (per-client, defaults to the site lander `{company_website_link}`; overridable in `/admin-view` Settings — the page where the quote form lives), `{company_owner_first_name}`, `{company_name}`. Dynamic (not template_vars): `{caller_phone}`, `{call_time}` (client tz, human-readable). A brand-new caller has no name yet, so the notification keys off phone + time.
**Note:** the SMS link goes to the client's quote-form page; if the caller submits that form, they also enter the Lead-Form drip (§7) — intentional (the form submission gets its own acknowledgment). The two drips run independently.

### Other features
- **Customer reactivation** [scope to confirm] — CSV/paste upload → dedupe → enroll in `reactivation_drip` (day 0/3/7, exits on `reviewed`), conservative throttle profile. Copy not yet reviewed/finalized.
- **Inbound SMS → CRM** [built] — every inbound creates/updates conversation + message; STOP/HELP/START + `pass` handled at webhook.

---

## 9b. Business Onboarding Form & Client Setup [LOCKED]

Two layers: **owner-filled** content/brand fields (a real form the business owner completes), and **agency-set** automation/config (you configure during setup). The onboarding data also feeds the AI Chat Widget's knowledge (§7e) and builds the site copy. Resolves the onboarding-form architecture decision: it's a real owner-facing form for content + agency-side config for plumbing.

### A. Owner-filled fields (the onboarding form)
Verbatim from the live client form (light edits for our system):
- **Full Name** (required) → derive `{company_owner_first_name}`.
- **Business Phone** (where they want lead notifications) → this is their real phone / call-forwarding target.
- **Official Business Name** (required) → `{company_name}`.
- **Tax ID / EIN** → business record (also useful for A2P).
- **Current website link** (if any) → `{company_website_link}` + AI knowledge source.
- **"About Us"** (3–5 sentences, personal-brand angle) (required) → site copy + AI knowledge.
- **Top location + service areas** (be specific; MAX 14) → site copy + AI knowledge.
- **All services offered** (specific) (required) → site copy + **AI chat widget knowledge**.
- **Special things about the business** (differentiators to show off) → site copy + AI knowledge.
- **Hours of operation** (required) → site + feeds the **Business Hours** setting (lead-form branching).
- **Social links** — Instagram, Facebook, BBB, TikTok, Yelp (each if applicable) → site.
- **Full shipping address** (required, no PO boxes) → for business cards (agency ops).
- **Return/referral discounts** (e.g. "$500 off your next roof / 15% off your next driveway wash") → `{discount__on_referral}` and `{discount_amount}`.
- **Logo** (upload; or request one) + "do you need a logo?" flag → branding.
- **Timezone** (NEW field — pick one: EST / CST / MST / PST / Honolulu) → drives all send windows; also editable in admin.
- **Photos** — 25–60 best photos + a team/owner photo (sent to the agency email) → site.
- **Consent** — terms & conditions + SMS opt-in language.

### B. Agency-set config (during onboarding, in `/admin-view` — NOT owner-filled)
- **Google review link + Place ID** — agency grabs from the client's GBP (they may not have one yet → setup task; the whole review engine depends on it).
- **Star threshold** (default 4) — agency-decided in admin settings.
- **Terms page** — agency-hosted; generated A2P-compliant from onboarding data (see C).
- **Quote form link** — defaults to the site lander (not collected).
- **Twilio number** — agency-provisioned (local area code); editable in admin.
- **Call-forwarding number** — the client's real phone the Twilio number rings through to; editable in admin per client over time. [BUILD — new admin field]
- **Sending subdomain / DKIM** — agency setup.
- **Timezone** — editable in admin (default from the owner's pick).

### C. A2P-compliant terms page [BUILD]
The agency hosts each client's terms/privacy page. Needs a documented process to generate an **A2P 10DLC-compliant terms & conditions + privacy page** from the onboarding data (business name, contact, SMS consent language, opt-out instructions, data handling). This page is what `{website_terms_page_link}` points to. Required for compliant SMS consent on all forms.

### D. Per-client telephony setup [LOCKED pattern]
- Provision a **new local Twilio number** per client (area code matching their market).
- **Forward** the Twilio number's calls to the client's real phone (the call-forwarding number) — so they answer calls normally.
- Put the **Twilio number on the website + Google Business Profile** (+ business cards). All SMS automations and missed-call textback operate on the Twilio number. The client keeps their existing number everywhere else.
- Register the new number under the agency's existing **A2P 10DLC** brand/campaign (ISV/reseller) — no re-vetting, fast to live.
- Rationale: SMS automation + missed-call detection require a Twilio-controlled number; forwarding preserves the client's normal call experience.

---

## 10. Open items blocking skill authoring
- [TBD] Copy-strategy decision (templatize hardcoded marketing copy vs rewrite per vertical) — blocks `/theme-to-brand`.
- [RESOLVED] Onboarding form (§9b) — it's a real owner-filled content form + agency-set config. `/onboard-from-form` can now be written. (Remaining build: extend `createClient`/settings to capture all §9b fields.)
- [BUILD] Tracked-redirect link system for review drip (§4); daily enrollment cap (§3); Notifications subsystem (§8); mobile Review Request tab + Auto-Enroll button (§7/§8); "pass" keyword → opt-out (§4); on-reply handler capturing `message.body` (§5) and lead reply-detection (§7); Business Hours setting + lead-form branching (§2/§7); re-enrollment guard (§4/§6); discount-form-submit exits one-year drip (§7b); per-contact `last_missed_call_textback_at` timestamp + 7-day re-eligibility check (§9); constrained RLS (no wide-open anon inserts) baked into `/scratch-foundation`; call-forwarding-number admin field (§9b); A2P-compliant terms-page generation (§9b); onboarding form capturing all §9b owner fields incl. timezone picker.

## 11. Locked & done (captured above)
- Review Request SMS drip — full copy, tokenized tracking, exit-on-click, SMS-only (§4).
- Review→1-Year handoff rule — enroll unless opted out (§4).
- One-Year Follow-Up SMS drip — full copy, exit-on-reply-or-opt-out, no form (§5).
- Website Lead-Form drip — full copy, two-window branching, intentional-typo guard, day-10 reminder + auto-enroll button (§7).
- Discount-Claim Form & drip — form structure, copy, exits one-year drip on submit (§7b).
- Owner Email Notifications — Lovable native transactional, one per lead, formatted with line breaks (§7d).
- Missed-Call Textback — full scope + copy: 24/7, 4 triggers, 1-min/2-min drip, reply-skip, 7-day re-eligibility per contact, internal notification (§9).
- Review Funnel — `/r/rate` (1–5, inclusive threshold), landing exits drip, ≥thr → Google + Review Completed + One-Year handoff, <thr → /r/feedback + Negative Review (no handoff) + owner email/notification; stat renamed "Review Link Clicks"; /r/enroll cut (§4/§6).
- AI Chat Widget — opt-in gate, FAQ answering from business data, pricing→request-form guardrail, Request path = lead-form drip with "New Website AI Chat Lead" label; own /chat-widget skill; depends on onboarding form for AI knowledge (§7e).
- Business Onboarding Form & Client Setup — owner content form + agency config, A2P terms-page generation, per-client Twilio-forwarding telephony pattern; resolves onboarding architecture decision; feeds AI knowledge + site copy (§9b).
- Email drip — SCRAPPED, SMS-only (§7c).
- Re-enrollment guard (§4/§6). opt-in-forms map (§6 — now FINITE). Two-window model + two caps (§2/§3). admin-view tabs (§2).
- Naming convention: `{first_name}` customer-facing, `{full_name}` internal notifications.

## 12. Backlog / Work Queue (ordered)

### DONE
- ~~SMS automation formatting pass~~ ✓ COMPLETE — all customer-facing SMS finalized with intended line breaks (proofread/approved); all internal notifications + emails reformatted to stacked form (§4/§5/§7/§7b + `/automation-config` + `/mobile-app`); owner-email copy added to `/automation-config`. `/features` is mechanics-only (no inline copy). Customer SMS remain editable on-site.

### >>> NEXT UP <<<
- Pick from "FEATURES STILL TO DEFINE" below, or write `/scratch-foundation`, or make an architecture decision.

### FEATURES — all defined ✓
- All platform features are now scoped. (AI Chat Widget §7e scoped; its AI knowledge inputs finalize once the onboarding form is defined — see Architecture Decisions.)
- Reactivation still needs a confirmation/full pass (copy + how its link reaches /r/rate) — §9.

### LATER / PARKED (non-blocking)
- **PWA web-push notifications** — superseded by owner email notifications (§7d); revisit if real-time phone push wanted.
- **Stats label** — DONE: dashboard renamed to "Review Link Clicks" (counts `review_clicked` landings).

### ARCHITECTURE DECISIONS PENDING (block 2 skills)
- Copy-strategy: templatize hardcoded marketing copy vs rewrite per vertical → blocks `/theme-to-brand`.
- ~~Onboarding form vs SQL~~ RESOLVED (§9b): real owner form + agency config. `/onboard-from-form` unblocked.
