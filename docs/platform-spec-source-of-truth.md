# Platform Spec — Multi-Tenant Reviews / SMS Automation (Source of Truth)

> Canonical record of build decisions. Skills are generated FROM this doc.
> Status legend: **[LOCKED]** decided · **[BUILD]** net-new, skill must construct it · **[TBD]** awaiting input.
> Last updated: this is a living doc — update it as decisions land so it never drifts from the build.

---

## 0. Build philosophy & deployment model [LOCKED]

**The skills build a tested "golden master" backend ONCE; it is ONE shared multi-tenant backend that serves all clients. Per-client launch does NOT clone the backend — it adds a client to the shared backend and Remixes only that client's marketing site (frontend).** This resolves the build-from-scratch-vs-clone tension: the skills get us to a known-perfect shared backend, and after that we never AI-regenerate it per client (regeneration reintroduces AI-sway/drift risk).

**Three phases:**
1. **Author the skills** (where we are) — the skills are the complete canonical spec of how the backend is built, derived from this doc.
2. **Build & prove the reference backend, once** — run the skills, build the entire shared multi-tenant backend, test every feature until flawless. This produces the **golden master** (tested, working code) — built one time, not per client.
3. **Launch each client on the shared backend** — create a client record + config (the §9b onboarding data); Remix ONLY the marketing site (frontend) for the client's domain, pointed at the shared backend via its Supabase env (`VITE_SUPABASE_URL` + anon key + `project_id`). No per-client backend, DB, Cloud, or service-role key.

**The clean split:**
- **Backend = the ONE shared multi-tenant backend** (golden master, built/proven once, frozen, never regenerated per client). The part that must be reliable.
- **Design = per-client Remixed marketing site (frontend-only)** + the AI design layer (`/website-structure`). The part that should be varied/creative.

**The Remixed marketing site is frontend-only:** it reads public client data via anon SELECT (same-origin to supabase.co) and submits leads to the shared backend's public write routes, which enforce CORS + per-client domain allowlist + Zod + bot protection. No service-role key, no DB-hitting server fns on the Remixed project.

**Why shared-backend (Option A), decided & locked:** considered one-shared-backend (A) vs separate-backend-per-client (B). Chose **A**. Decisive reason: B reintroduces the exact **AI-drift** this golden-master model exists to prevent — every future bug-fix/feature would be re-prompted across N projects and silently diverge. A keeps business logic in ONE codebase: one place to fix, ship, and verify, forever; the other clients get a fix the moment it deploys. Per-client *design* stays fully bespoke either way (only the marketing site is remixed), so A costs nothing on customization. Data isolation is held by disciplined RLS + the isolation guardrails (see `/scratch-foundation`: RLS-audit gate, per-client cron fairness, export-client fn, CORS resolver). Escape hatch: A→B (peel one whale client out to a dedicated backend via the export fn) is easy; B→A (merge DBs) is brutal — so A keeps options open. This is settled; do not reopen without a material change.

**Project structure [LOCKED]:** two long-lived Lovable projects + N short-lived marketing remixes.
- **Project 1** — the shared backend + agency/admin dashboard + per-client tenant app (`app.theirdomain.com`). All share auth, RLS, server fns, and types; they belong in one project. Project 1 owns the database.
- **Project 2** — a lean marketing-site template (presentational; no admin/backend code).
- **Per-client marketing sites** — Remix Project 2 (NOT Project 1, so admin code never ships in a client's marketing bundle), customize the design, point `.env` (`VITE_SUPABASE_URL` + anon key + `project_id`) at Project 1's shared Supabase. Custom domain attached at the remix level.
- **Subdomain routing [LOCKED]:** tenant app at `app.theirdomain.com`; marketing at root `theirdomain.com`. Lock before building auth-redirect URLs + CORS allowlists (changing later means rewriting `/auth` redirects and every `/api/public/*` CORS header).
- **Code ownership/reproducibility:** Lovable creates its OWN GitHub repo from Project 1 (it cannot attach to a pre-existing repo) — that repo + downloadable codebase = the golden master is owned and reproducible (within Lovable via Remix → migrations re-run; outside via export + own Supabase). The planning repo (spec + skills + build docs) stays SEPARATE as the source-of-truth library. Skills are fed to Lovable as imported Skill snapshots (re-upload to update — no live external-repo read). Remix carries code + migrations, NOT secrets/data/integrations/domain (re-added per project).

**Role of the skills:** they are the blueprint that builds (and, if ever needed, rebuilds) the golden master, AND the canonical documentation of how the system works. They remain the source of truth forever — they are just not the per-client *runtime* path once the master exists.

**Determinism within the build:** when the skills DO build (Phase 2, or a rebuild), they build from scratch in ordered layers — every construction identical by construction. One skill, one job. No monolithic "build everything" skill. The spec doc is the source of truth; skills are derived from it; version-controlled in the repo.

**Layer order (also the skill order):** foundation → features → automation-config → launch-check; per-client launch = `/new-client-site` (provision client on the shared backend + Remix marketing site + invoke the design layer) → `/onboard-from-form` → `/website-structure` (design).

## 0a. Stack [LOCKED]
TanStack Start v1 (React 19 + Vite 7), SSR, Cloudflare Workers (pure JS + fetch, no native deps). Lovable Cloud / Supabase. Server logic in TanStack Start (`createServerFn` + `src/routes/api/public/*`). RLS on every table; roles in `user_roles`; SECURITY DEFINER helpers. Three Supabase clients (browser / authed-server-fn / admin). One shared multi-tenant backend serves all clients; each client's marketing site is a separate Remixed frontend sharing the same Supabase env, frontend-only (no Cloud / no service-role).

---

## 1. The skill set [LOCKED list]
1. `/scratch-foundation` — builds the deterministic core (schema, RLS, helpers, server-fn/route skeleton, auth/roles) from nothing; builds the single shared multi-tenant core (the golden master) once.
2. `/features` — reference + build instructions for each feature's mechanics & scope.
3. `/automation-config` — exact message copy + timing (the "snapshot").
4. `/opt-in-forms` — which forms feed which automations.
5. `/chat-widget` — the AI chat widget (§7e): opt-in gate, FAQ retrieval, pricing guardrail, request→lead-form handoff.
6. `/mobile-app` — the client app (`app.theirdomain.com`): Conversations, Review Request, Notifications tabs.
7. `/admin-view` — the admin tabs/settings on the client website (what's editable where).
8. `/launch-check` — pre-go-live verification gate (for building/proving the golden master).
9. `/new-client-site` — per-client launch orchestrator: **provision a new client on the shared backend (client row + settings + Twilio subaccount/number + onboarding capture) + Remix the marketing site for the client's domain (frontend-only) + invoke the design layer. NOT a backend clone, NOT a regenerate.**
10. `/website-structure` — the per-client DESIGN layer: page set (generated from onboarding, up to max), the 4 style choices, AI-driven copy + visual generation from onboarding data + assets + reference screenshots, and the codified style-template library (plug-and-play via Lovable cross-project referencing). Absorbs the old `/theme-to-brand` (brand colors/logo are part of this).
11. `/onboard-from-form` — captures the §9b onboarding data into the system (config + AI knowledge + design inputs).
(`/website-structure` and `/onboard-from-form` are the per-client design + data-capture skills; both now unblocked. `/theme-to-brand` is absorbed into `/website-structure`.)

---

## 2. `/admin-view` — admin tabs on the client website [LOCKED]
Current tabs: **Dashboard, Contacts, Conversations, Feedback, Automations, Upload Customers, Settings**.
- **Automations** tab shows a **live active-enrollment count per drip** (from `enrollments WHERE status='active'` grouped by `sequence_key`). [BUILD — new]
- **Upload Customers** tab feeds the **Reactivation drip** (normalize → dedupe → enroll, reactivation caps).

**Settings tab must hold these per-client configurable values:**
- Timezone (drives all SMS windows).
- **SMS Send window** (default **09:00–19:00**, client timezone) — applies to MARKETING/FOLLOW-UP SMS only (review drip, one-year drip, reactivation). Purpose: don't annoy past customers.
- **Business Hours** (separate per-client window) — applies to the LEAD-FORM drip only (§7). Purpose: decide whether a fresh web lead gets the live in-hours response or the after-hours message. Independent from the SMS Send window. [BUILD — new field]
- **Daily SMS send cap** (customizable per client) — max messages dispatched/day.
- **Daily enrollment cap** (customizable per client, **default 50**) — max NEW contacts entering the review drip/day; overflow waits to next day. *(Distinct from send cap.)*
- **Twilio config** (twilio_number, messaging_service_sid, call_forwarding_number) — **single-source rule:** the number is stored ONCE and read everywhere on-site + in automations; changing it in admin propagates automatically. External placements (GBP, cards) are manual.
- **Notification recipient email** — where owner notifications go; defaults to onboarding `clients.email`, editable. [BUILD]
- Existing: business identity, review config (place ID, link, gate mode, threshold), template_vars, sending subdomain, marketing domains/allowed_origins.
- **All onboarding-captured values are surfaced + editable here** — nothing prefilled from onboarding should be invisible/uneditable.

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
- SMS contains `https://<shared-backend-domain>/api/public/r/<token>` (e.g. `links.myagency.com/api/public/r/<token>` or `app.myagency.com/api/public/r/<token>`). **NOT the client marketing domain** — these routes WRITE to the DB, and the per-client marketing site is frontend-only (no service-role/DB writes). All tracked-link + funnel routes (`/api/public/r/<token>`, `/api/public/r/rate`, `/api/public/r/feedback`) are served by the SHARED BACKEND.
- On tap: public route looks up token → writes `review_clicked` event → **lands the contact on the Review Funnel rate page (`/api/public/r/rate`)**.
- **Landing on `/api/public/r/rate` EXITS the contact from the review drip immediately** (they clicked through — this is the click the drip was watching for). Status + one-year handoff are then determined by their star selection (below).

### Review Funnel pages [LOCKED]
The same funnel is the destination for BOTH the review-drip tracked link and the reactivation link. **All funnel pages are served by the SHARED BACKEND domain** (they read/write the DB), NOT the per-client frontend-only marketing site.

**`/api/public/r/rate`** — text "How would you rate us?" + a 1–5 star multiple-choice. Threshold = per-client `star_threshold` in `/admin-view` (default 4, **inclusive ≥**). The star value is **re-selectable and commits only on submit** (a star tap is not a committed choice — the customer can change it before submitting). Status is set on submit, from the submitted rating:
- **Submitted rating ≥ threshold** → status **`Review Completed`** (on rate-form submit) → redirect to the client's Google review page (deep-links the leave-a-review screen on their GBP) → **enroll into the One-Year Follow-Up drip** (normal handoff).
- **Submitted rating < threshold** → go to `/api/public/r/feedback`; **status flips to `Negative Review` on FEEDBACK-form submit** (so an abandoned feedback form doesn't permanently mark the contact). **Does NOT enroll into the One-Year drip.**

**`/api/public/r/feedback`** (below-threshold path) — collects **Name, Email, Feedback**; **phone auto-fills** from the mapped contact (they arrived via their token). Stores in `review_feedback`. On submit → fires the owner email + mobile-app notification (below) → shows the customer confirmation screen.

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

**Status semantics:** `Review Completed` (≥ threshold, went to Google) vs `Negative Review` (< threshold, left private feedback). Both exit the review drip; only `Review Completed` hands off to One-Year. `/api/public/r/enroll` is REMOVED (enrollment happens via the mobile-app Review Request form).
New dynamic key: `{feedback_message}` (the feedback text). `{email}` from the feedback form.

### Sequence & exact copy [LOCKED]
Placeholders use the project's merge system. Opt-out keyword is **"pass"** (added to global opt-out set — whole-word match). Same 4 message texts are used by the Reactivation drip (§9).

**SMS 1 — day 0 (on enrollment, respecting send window):**
> Hi {first_name}! This is {company_owner_first_name}. If you loved working with {company_name}, would you mind leaving us a review? We really appreciate it! Here's the link:
>
> {review_link}

**Wait 4 days → check click status. Clicked → mark `Review Completed`, exit. Not clicked → SMS 2:**
> Hi {first_name}! I see you haven't left a review yet. If you loved {company_name}, could you leave one? It's a HUGE help for us!
>
> {review_link}

**Wait 7 days → check. Clicked → exit. Not clicked → SMS 3:**
> Hi {first_name}! I see you haven't left a review for {company_name} yet. It takes 20 seconds, and that review helps us for YEARS to come! This link makes it easy:
>
> {review_link}

**Wait 7 days → check. Clicked → exit. Not clicked → SMS 4:**
> Hi {first_name}! Don't forget to leave us a review for {company_name}. It helps us serve our community better when more people find us! Here's the link:
>
> {review_link}

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
- **Public website lead form** (first_name, last_name, phone, email, your_message) → enrolls into the Lead-Form drip (§7). Submitted to a public server function (`supabaseAdmin` + Zod; `client_id` resolved from the public slug; CORS + per-client domain allowlist + bot protection). NO anon INSERT. `source` set server-side (CHECK-constrained column).
- Public funnel pages: `/api/public/r/rate`, `/api/public/r/feedback`. (`/api/public/r/enroll` removed.)
- Discount-claim form (§7b) — TBD.

## 7. FEATURE — Website Lead-Form Drip [LOCKED copy]

**Purpose:** instant response + owner alerting when a lead submits the public website form requesting a quote/contact.

**Enrollment:** public website lead form (first_name, last_name, phone, email, your_message). source = `web_form`.

**Two-window model [LOCKED — see §2]:** the lead-form drip branches on **Business Hours** (a SEPARATE per-client setting from the marketing SMS Send Window). Business Hours = "is the owner reachable / open" and governs lead-form branching only. SMS Send Window (9am–7pm) governs marketing/follow-up drips only. They are independent values.

**Lead-form SMS is transactional** (the lead just requested contact) — it does NOT defer to the marketing send window; it branches on Business Hours instead.

### Branch A — submitted DURING Business Hours
1. Wait 30s → internal notification to client.
2. SMS #1 to the lead (single text, correctly spelled).
3. Day 10 → owner reminder (see below).

### Branch B — submitted OUTSIDE Business Hours
1. Single after-hours SMS to the lead.
2. After-hours owner notification (so they see it when back).
3. Day 10 → owner reminder (same as Branch A — fires on BOTH paths).
(After-hours customer-facing drip ends after the single SMS.)

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

**SMS #1 to lead — Branch A only (single text, correctly spelled):**
> Hey {first_name}! Just got your form! I'll be in touch shortly!
> -{company_owner_first_name} with {company_name}

**After-hours SMS to lead — Branch B only (replaces Branch A's SMS):**
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
- Branch A is now a single SMS (the "touchr" typo + correction SMS#2 were removed). [No reply-skip logic needed for a second text.]
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

- Public form → POSTs to the server function that inserts the contact (`source='web_form'`, server-set; `supabaseAdmin` + Zod; CORS / per-client domain allowlist / bot-protection). Not an anon RLS insert. Phone normalized to E.164.
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
- **Request path:** works exactly like the main website lead form (§7) — creates the contact, enrolls into the SAME lead-form drip + automations (business-hours branching, single SMS#1, day-10 reminder, owner email). After a request is submitted, the AI confirms: it sent the request to the team and they'll hear back shortly.
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
- AI invocation (confirmed): Lovable AI Gateway (`https://ai.gateway.lovable.dev/v1`) + `LOVABLE_API_KEY` (ambient server runtime, never browser) + model `google/gemini-3-flash-preview`; streaming chat via `src/routes/api/chat.ts` (AI SDK `streamText`/`toUIMessageStreamResponse`, client `useChat`), one-shot via `createServerFn`; knowledge bundle = per-request system-prompt injection; handle 429/402. Full detail in `/chat-widget` + §9d.

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
### FEATURE — Customer Review Reactivation Drip [LOCKED]
**Purpose:** win reviews from PAST customers (bulk-uploaded), drip-fed slowly so reviews arrive organically and don't flag Google.

**Enrollment:** CSV/paste upload in `/admin-view` → normalize phones (E.164) → dedupe → enroll in the `reactivation` sequence (sequence_key = `reactivation`, matching the 2a seed). Source `reactivation`.
- **Dedup guard:** do NOT enroll a contact already run through reactivation OR already marked `Review Completed`. (So re-uploading a list won't re-message past reviewers.)

**Per-drip safety caps (independent from other drips' caps):**
- Max **50 new enrollments per day** into reactivation (controls how many new review asks go out daily — the Google-protection lever; a 5k upload trickles in over ~100 days).
- Max **2 enrollments dripped every 20 minutes** (paces enrollment so it doesn't burst).
- Follow-up sends flow on top within the **send window (9am–7pm client tz)**.

**Cadence:** SMS 1 immediately on enrollment → SMS 2 at +24h → SMS 3 at +24h → SMS 4 at +24h. All a day apart, all respecting the send window. Click-check before each step; clicked → exit.

**Copy:** SAME 4 message texts as the Review Request drip (§4) — no separate copy. (No "pass" P.S. line; opt-out still works via the inbound webhook.)

**On click → land on `/api/public/r/rate`:** marks the contact, exits the drip, fires the reactivation click notification (below), runs the normal funnel (≥threshold → Google + `Review Completed`; <threshold → `/api/public/r/feedback` + `Negative Review`).

**One-Year handoff:** ONLY if they leave a review (`Review Completed`, ≥threshold → Google). If they don't review, hit the negative path (`Negative Review`), or opt out → NOT enrolled in One-Year. (Identical rule to §4.)

**No final owner notification** after no response — the drip just ends silently after SMS 4 if they never click.

**Reactivation click notification (to owner's mobile app, fires on the click/landing) — show whichever of name/phone/email are present:**
> {company_owner_first_name}, you just got a review link click from your Customer Review Reactivation campaign!
>
> Customer Info:
> Name: {full_name}
> Phone: {phone}
> Email: {email}
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
- **Site style choice** (NEW field — pick one of 4): **Corporate** (polished, professional, formal, sleek/minimal), **Standard Business** (straightforward, service-focused, balanced), **Local Family-Owned** (warm, community-rooted, personal), **Owner-Operated Local** (owner is the brand, first-person, most personal). Drives the AI's copy voice AND the site's styling direction (§9c).
- **Photos** — 25–60 best photos + a team/owner photo (sent to the agency email) → site.
- **Consent** — terms & conditions + SMS opt-in language.

### B. Agency-set config (during onboarding, in `/admin-view` — NOT owner-filled)
- **Google review link + Place ID** — agency grabs from the client's GBP (they may not have one yet → setup task; the whole review engine depends on it).
- **Star threshold** (default 4) — agency-decided in admin settings.
- **Terms page** — agency-hosted; generated A2P-compliant from onboarding data (see C).
- **Quote form link** — defaults to the site lander (not collected).
- **Marketing domain(s) / allowed origins** — the client's site domain(s); powers the public-write CORS allowlist (§6). [BUILD — new field]
- **Twilio number + Messaging Service SID** — per-client, NON-secret (a number under the ONE parent Twilio account); editable in admin. (No per-client auth token — see D.)
- **Call-forwarding number** — the client's real phone the Twilio number rings through to; editable in admin per client over time. [BUILD — new admin field]
- **Sending subdomain / DKIM** — agency setup.
- **Timezone** — editable in admin (default from the owner's pick).

### C. A2P-compliant terms page [BUILD]
The agency hosts each client's terms/privacy page. Needs a documented process to generate an **A2P 10DLC-compliant terms & conditions + privacy page** from the onboarding data (business name, contact, SMS consent language, opt-out instructions, data handling). This page is what `{website_terms_page_link}` points to. Required for compliant SMS consent on all forms.

### D. Per-client telephony setup [LOCKED pattern — Twilio Option 1: one parent account]
- **One parent Twilio account** (the agency's, wired via Lovable's connector gateway). Per client, provision a **number under the parent account** (a subaccount/number, local area code matching their market). Store only the per-client **From number (`clients.twilio_number`)** + optional **Messaging Service SID (`clients.twilio_messaging_service_sid`)** — both NON-secret.
- **No per-client Twilio auth token.** The ONLY Twilio secret is the single parent account auth token, held as a platform runtime secret (never on a row).
- **Outbound:** gateway POST with the per-client `From` / `MessagingServiceSid`.
- **Inbound + voice-status webhooks:** configured ONCE at the parent level; route to the correct client by the `To` number → `clients` row; verify with the single parent auth token.
- **Forward** the client's number's calls to the client's real phone (the call-forwarding number) — so they answer calls normally.
- Put the **number on the website + Google Business Profile** (+ business cards). All SMS automations and missed-call textback operate on it. The client keeps their existing number everywhere else.
- **A2P:** numbers/subaccounts under the parent are covered by the agency's ONE A2P 10DLC brand/campaign (ISV/reseller) — no per-client re-vetting, fast to live.
- **Option 2 (BYO-Twilio, future — NOT v1):** for clients who insist on owning their Twilio, store per-client `accountSid`/`authToken` in a server-only secret store (`client_secrets` table), bypassing the gateway. Reserved.
- Rationale: SMS automation + missed-call detection require a Twilio-controlled number; forwarding preserves the client's normal call experience.

---

## 9c. Website Structure & Design Layer [LOCKED — skill `/website-structure`]

The per-client DESIGN layer, applied on top of the shared golden-master backend (§0). Defines the page set, the copy/visual direction, and how design is generated and (eventually) templated. Absorbs the old `/theme-to-brand`.

### Page set [LOCKED]
Pages are generated FROM the onboarding data, up to the max below. Only build pages the onboarding form supports (e.g. 5 services + 8 areas → 5 service pages + 8 area pages, not the max).

**Always present:** Home/Lander, Contact Us, Gallery, Thank You, Review + Referral Follow-up Form, Discount Funnel, Review Us, Terms & Conditions, Privacy Policy.
**Data-driven (one each, up to max):** Service page per service (**max 12**); Service Area page per area (**max 14**).

- **Service Area pages** = essentially the Home/Lander, re-focused on serving that specific area (local-SEO: ranks for "[service] in [city]").
- **Service pages** = AI determines a good, relevant layout describing that service.

### Design generation inputs [LOCKED]
The visual design, fonts, colors, copy, and layout are AI-driven, determined by combining:
1. **Site style choice** (§9b — 4 options: Corporate / Standard Business / Local Family-Owned / Owner-Operated Local) → copy voice + styling direction.
2. **Onboarding form data** → content + the AI's copy source (About Us, services, areas, differentiators).
3. **Visual assets from onboarding** → logo (uploaded or agency-made) + photos of previous work.
4. **Reference style screenshots** (AGENCY-uploaded at build time, not an onboarding field) → Lovable mimics the reference layout/styling, populated with the client's real data + assets.

This resolves the copy-strategy decision: copy is AI-GENERATED, steered by the style choice — templatized structure, generated (not hardcoded, not manually rewritten) copy.

### Two-mode design system [LOCKED]
- **Mode 1 — Generate (now):** AI builds the style from reference screenshots + style choice + onboarding assets/data. Used to discover good styles.
- **Mode 2 — Apply a template (as the library grows):** once a generated style is a winner, capture its CODE as a named, reusable design template; new sites are built by selecting a template and injecting the client's data/assets — no re-derivation. Faster + deterministic + reliably good.
- **Bridge:** codify winning generated styles into the template library. Primary plug-and-play mechanism = **Lovable cross-project referencing** (a proven style lives as a reference project; new builds pull its design patterns via @mention). The codification process gets fully defined once the first winners exist. [BUILD — template library grows over time]

---

## 9d. External Dependencies & Wiring [LOCKED — Phase 2 setup]
Every external service/connection the build needs, with what to set up and when (golden-master = once, per-client = each launch).

- **Email (owner notifications)** — ONE platform-level agency sender. CONFIRMED with Lovable: set up an email domain in Lovable Cloud + verify via NS delegation (Lovable manages SPF/DKIM/DMARC in the delegated subdomain, e.g. `notify.myagency.com`); send as `MyAgency <notify@myagency.com>`. Managed pipeline (pgmq + cron), ~120 emails/min, transactional only (owner lead notifications qualify). NOT per-client (per-client senders = heavier white-label product, not v1). `sending_subdomain`/`dkim_status` columns = deferred-v1. Needs Lovable Cloud + an agency domain. Golden-master, once.
- **Twilio (SMS + voice)** — Option 1: one parent account via the connector gateway; parent auth token = runtime secret; register the two parent-level webhook URLs (`/api/public/twilio/inbound`, `/api/public/twilio/voice-status`) once the backend has a stable domain. Numbers/forwarding/placement = per-client.
- **Bot protection** — Cloudflare Turnstile (free, fits Workers/fetch). One widget, site key (public, in marketing forms) + secret (runtime secret, verified in lead-intake server fns). Add each client domain as a hostname. Verify step = golden-master; client hostname = per-client.
- **AI chat widget** — Lovable native AI. CONFIRMED with Lovable: calls go through the Lovable AI Gateway (`https://ai.gateway.lovable.dev/v1`) authed with `LOVABLE_API_KEY` (already provisioned, ambient on server runtime, never browser-exposed); default model `google/gemini-3-flash-preview`. Streaming chat → server route `src/routes/api/chat.ts` (AI SDK `streamText`/`toUIMessageStreamResponse`, client `useChat`); one-shot → `createServerFn`. Knowledge bundle = per-request system-prompt injection (keep tight). Per-request billing; opt-in gate is the natural rate-limiter; handle 429/402; add own throttle if hard caps needed. AI gateway works without Cloud; the lead-write persistence needs Cloud. Widget/server-fn = golden-master; knowledge bundle = per-client.
- **Google (review links)** — NO integration/OAuth/API. Just two stored strings per client (`review_link`, `review_place_id`); the leave-a-review URL is constructed. Per-client (onboarding).
- **Storage** — native Supabase: `public-assets` (public-read), `client-assets` (private, client_id-scoped RLS). Buckets/policies = golden-master; uploads = per-client.
- **Scheduling** — native pg_cron + pg_net → `/api/public/cron/sequences` with `x-cron-secret`. Needs stable backend URL + `CRON_SECRET`. Golden-master.
- **Domains/DNS** — shared backend needs a stable custom domain (gates Twilio webhooks, cron, tracked links) = golden-master. Per-client: marketing domain (→ deploy + `allowed_origins` + Turnstile hostname), `app.theirdomain.com` for the mobile app.
- **Rate-limiter store** — in-memory won't work across Worker isolates; use Cloudflare Durable Objects / Workers KV / DB-based. Golden-master decision (no new account).

### Architecture note — shared-backend vs frontend-only split [LOCKED]
The per-client **Remixed marketing site is frontend-only** (anon reads + CORS-guarded POSTs; no service-role, no DB writes). The **admin view AND the mobile app are part of the SHARED BACKEND** (authed, DB-touching), served on per-client subdomains (`app.theirdomain.com`), NOT frontend-only Remixes. The **tracked-link + funnel routes (`/api/public/r/<token>`, `/api/public/r/rate`, `/api/public/r/feedback`) are served by the SHARED BACKEND domain** (they write to the DB), not the client marketing domain.

**Project structure (see §0):** Project 1 = shared backend + admin + tenant app (owns the DB); Project 2 = lean marketing template; per-client marketing sites = Remixes of Project 2 with `.env` → Project 1's Supabase. Subdomain routing locked: tenant app `app.theirdomain.com`, marketing root `theirdomain.com`.

**Isolation guardrails (what makes shared-backend safe — built in `/scratch-foundation`):** (1) RLS-audit gate (CI fails if any tenant table lacks a client_id policy); (2) per-client cron fairness (round-robin, no starvation); (3) export-client server fn (offboarding/portability) + archive-via-status; (4) CORS resolver (client_id from server-resolved Origin/Host→allowed_origins, never request body).

---

## 10. Open items blocking skill authoring
- [RESOLVED] Copy-strategy (§9c) — copy is AI-generated, steered by the 4 style choices; templatized structure. `/website-structure` (absorbing `/theme-to-brand`) can now be written.
- [RESOLVED] Onboarding form (§9b) — it's a real owner-filled content form + agency-set config. `/onboard-from-form` can now be written. (Remaining build: extend `createClient`/settings to capture all §9b fields.)
- [BUILD] Tracked-redirect link system for review drip (§4); daily enrollment cap (§3); Notifications subsystem (§8); mobile Review Request tab + Auto-Enroll button (§7/§8); "pass" keyword → opt-out (§4); on-reply handler capturing `message.body` (§5) and lead reply-detection (§7); Business Hours setting + lead-form branching (§2/§7); re-enrollment guard (§4/§6); discount-form-submit exits one-year drip (§7b); per-contact `last_missed_call_textback_at` timestamp + 7-day re-eligibility check (§9); call-forwarding-number + marketing-domain admin fields (§9b); A2P-compliant terms-page generation (§9b); onboarding form capturing all §9b owner fields incl. timezone + style picker.
- [BUILD — foundation, in `/scratch-foundation`] Public writes via server fns (`supabaseAdmin` + Zod, slug→`client_id`); NO anon INSERT; anon SELECT only on `clients` public columns; CORS + per-client domain allowlist + OPTIONS + rate-limit + Turnstile/hCaptcha on public lead-intake. Foundation invariants: `enrollments` UNIQUE (client_id, contact_id, sequence_key) (DB-level re-enrollment/dedup guard); `events.created_by` + cron-decision logging; soft-delete `deleted_at` on contacts/clients; RLS perf (`(SELECT auth.uid())`, STABLE helpers, `client_id` indexes incl. partial `enrollments(next_run_at) WHERE status='active'`); two storage buckets (`public-assets` public-read for logos/hero, `client-assets` private client_id-scoped); `CRON_SECRET`-protected `/api/public/cron/sequences` (`x-cron-secret` header); parent Twilio auth token + `CRON_SECRET` as runtime secrets; no `client_secrets` table in v1 (Option-2/BYO-Twilio only); + the 4 isolation guardrails (RLS-audit gate, cron fairness, export-client fn, CORS resolver).

## 11. Locked & done (captured above)
- Review Request SMS drip — full copy, tokenized tracking, exit-on-click, SMS-only (§4).
- Review→1-Year handoff rule — enroll unless opted out (§4).
- One-Year Follow-Up SMS drip — full copy, exit-on-reply-or-opt-out, no form (§5).
- Website Lead-Form drip — full copy, two-window branching, single in-hours SMS, day-10 reminder + auto-enroll button (§7).
- Discount-Claim Form & drip — form structure, copy, exits one-year drip on submit (§7b).
- Owner Email Notifications — Lovable native transactional, one per lead, formatted with line breaks (§7d). Sender = ONE platform-level agency domain (NS-delegated, `notify@myagency.com`), not per-client (§9d).
- Missed-Call Textback — full scope + copy: 24/7, 4 triggers, 1-min/2-min drip, reply-skip, 7-day re-eligibility per contact, internal notification (§9).
- Review Funnel — `/api/public/r/rate` (1–5, inclusive threshold), landing exits drip, ≥thr → Google + Review Completed + One-Year handoff, <thr → /api/public/r/feedback + Negative Review (no handoff) + owner email/notification; stat renamed "Review Link Clicks"; /api/public/r/enroll cut (§4/§6).
- AI Chat Widget — opt-in gate, FAQ answering from business data, pricing→request-form guardrail, Request path = lead-form drip with "New Website AI Chat Lead" label; own /chat-widget skill; depends on onboarding form for AI knowledge (§7e). AI invocation CONFIRMED: Lovable AI Gateway + LOVABLE_API_KEY + gemini-3-flash-preview (§9d / `/chat-widget`).
- Customer Review Reactivation — CSV upload, same 4 texts as §4, immediate+24h×3, caps (50/day + 2/20min), dedup guard, click notification, One-Year only on Review Completed, no end notification (§9).
- SMS copy de-meal'd — §4 + reactivation now use the meal-free review-request copy; "pass" P.S. line removed (opt-out still functional).
- Business Onboarding Form & Client Setup — owner-filled content form (+ timezone + style picker) + agency-set config + A2P terms-page generation + per-client Twilio/forwarding telephony setup (§9b).
- Website Structure & Design Layer — page set (always-present + data-driven service/area pages, max 12/14), 4 style choices, AI copy+visual generation from style/onboarding/assets/reference screenshots, two-mode design-template system; absorbs /theme-to-brand (§9c).
- Foundation architecture — one shared multi-tenant backend (golden master, built/proven once); per-client launch = client row + config + Remixed frontend-only marketing site sharing the backend's anon env; backend never regenerated per client (§0). Shared-backend (Option A) re-confirmed + locked with AI-drift rationale; 2-project structure + subdomain routing locked; 4 isolation guardrails (§0/§9d/`/scratch-foundation`).
- Public writes via server fns + CORS/allowlist/bot-protection; no anon insert (§6).
- Twilio Option 1 — one parent account, per-client subaccount/number (From/SID on clients, non-secret), inbound/voice routed by To, single parent auth token runtime secret; BYO-Twilio = Option 2, not v1 (§9b.D).
- Email drip — SCRAPPED, SMS-only (§7c).
- Re-enrollment guard (§4/§6). opt-in-forms map (§6 — now FINITE). Two-window model + two caps (§2/§3). admin-view tabs (§2).
- Naming convention: `{first_name}` customer-facing, `{full_name}` internal notifications.
- External dependencies — all confirmed (§9d): email (NS-delegated agency sender), Twilio Option 1, Turnstile, Lovable AI Gateway, Google (stored strings), storage, pg_cron, domains, rate-limiter store. Both prior ❓ items (email + AI) now RESOLVED.

## 12. Backlog / Work Queue (ordered)

### DONE
- ~~SMS automation formatting pass~~ ✓ COMPLETE — all customer-facing SMS finalized with intended line breaks (proofread/approved); all internal notifications + emails reformatted to stacked form (§4/§5/§7/§7b + `/automation-config` + `/mobile-app`); owner-email copy added to `/automation-config`. `/features` is mechanics-only (no inline copy). Customer SMS remain editable on-site.

### >>> NEXT UP — PHASE 2: BUILD & PROVE THE GOLDEN MASTER <<<
Phase 1 (author the skills) is COMPLETE ✓ — spec + all 11 skills, mutually consistent, foundation reconciled against the live DB, zero open decisions.

Phase 2 (the build):
1. Run `/scratch-foundation` — apply the [ADD] migrations + enum `ALTER TYPE`s (review_completed/negative_review/reactivation; chat_widget/mobile_enroll), the enrollments UNIQUE constraint (dedup first), the index set, the two storage buckets, runtime secrets (CRON_SECRET + parent Twilio token).
2. Build the feature + automation layer (features → automation-config → opt-in-forms → mobile-app → admin-view → chat-widget) on the shared backend. *(LAUNCH.md splits this into Stage 2 — feature/automation logic: features → automation-config → opt-in-forms → chat-widget — and Stage 3 — client-facing surfaces: admin-view + mobile-app. Same set, more granular; build logic before UI surfaces.)*
3. Wire telephony (Twilio Option 1) + the pg_cron drip runner.
4. Run `/launch-check` sections A–D until all green → declare the golden master frozen.
5. Then per-client launches use `/new-client-site` (provision + Remix + design + launch-check §E).

### FEATURES — all defined & locked ✓
- All platform features are scoped AND locked, including AI Chat Widget (§7e) and Customer Review Reactivation (§9). No undefined features remain.

### SKILLS — all 11 authored ✓
scratch-foundation, features, automation-config, opt-in-forms, chat-widget, mobile-app, admin-view, onboard-from-form, website-structure, launch-check, new-client-site. Mutually consistent; foundation reconciled against the live DB.

### LATER / PARKED (non-blocking)
- **PWA web-push notifications** — superseded by owner email notifications (§7d); revisit if real-time phone push wanted.
- **Stats label** — DONE: dashboard renamed to "Review Link Clicks" (counts `review_clicked` landings).

### ARCHITECTURE DECISIONS — ALL RESOLVED ✓
- ~~Copy-strategy~~ RESOLVED (§9c): AI-generated copy steered by 4 style choices; templatized structure. `/website-structure` unblocked (absorbs `/theme-to-brand`).
- ~~Onboarding form vs SQL~~ RESOLVED (§9b): real owner form + agency config. `/onboard-from-form` unblocked.
- ~~Build-from-scratch vs clone~~ RESOLVED (§0): golden-master model — skills build/prove ONE shared multi-tenant backend once; per-client launch adds a client to the shared backend + Remixes a frontend-only marketing site (no backend clone, no regenerate); design is the per-client creative layer.
- ~~Shared-backend vs backend-per-client~~ RESOLVED & LOCKED (§0): Option A (shared) — B reintroduces AI-drift; A keeps logic in one codebase; A→B peel-out easy, B→A merge brutal. Do not reopen without material change.
- ~~Email sender + AI invocation~~ RESOLVED (§9d): email = NS-delegated one platform agency sender (~120/min transactional); AI = Lovable AI Gateway + LOVABLE_API_KEY + gemini-3-flash-preview. Both prior ❓ closed.

### SYSTEM NOTES (carry into the build)
- Failed SMS sends retry up to 2× at the send layer before marking failed (the GHL "max retries" equivalent) — [BUILD] in the send/cron logic, not per-drip.
- [DONE 2026-06-09] RLS-audit gate (guardrail 1): `audit_tenant_rls()` built (SECURITY DEFINER, STABLE, service_role-only) — scans every public BASE TABLE with a `client_id` column (excl. `clients`, which is id-scoped) and asserts a `user_client_ids()`/`is_admin()` tenant check on the relevant USING/WITH CHECK per command; **0 rows = PASS (currently PASS)**. Run `SELECT * FROM public.audit_tenant_rls()` after every migration (manual until a CI harness exists). Recorded: `docs/build-log/guardrail-1-rls-audit.md`. (Recommended enhancements, non-blocking: extend to also gate `clients`' own policies; add a functional cross-tenant isolation test before go-live — string-match is a convention tripwire, not a proof.)
- [BUILD — TODO] audit_log table (no client_id; columns: actor_user_id, action, target, payload jsonb, created_at; service-role write, admin read) for ALL role mutations — grants AND revokes, both platform (admin/agency_owner, client_id NULL) and tenant scopes. Currently: only tenant *grants* hit `events`; platform grants + ALL revokes are unaudited (`events.client_id` is NOT NULL; revoke writes no event). Centralize role-mutation audit here. Land before go-live / before real admins are granted. Do NOT make `events.client_id` nullable. Owner: 1d/auth.
- [DONE 2026-06-09] revokeUserRole authorization (1d): verified — same matrix as assignUserRole (client_owner cannot revoke admin/agency_owner/client_owner; scoped to own client_id; platform-admin can revoke any; delete scoped client_id=X / IS NULL). Recorded: `docs/build-log/stage-1d-validation.md`. (Role-mutation audit still pending via the audit_log TODO above.)
- [BUILD — TODO] Export-client server fn (isolation guardrail 3, `scratch-foundation` §11): service-role fn returning a full per-client bundle (`WHERE client_id=$1` across every tenant table) + archive-via-`status='archived'`+`deleted_at` offboard (cron filters active). Offboarding/portability + the A→B escape hatch. NOT yet built; before go-live. Owner: foundation/lifecycle. Verified at `/launch-check` §A.
- [BACKLOG — IDEA] Read-only admin debug/research interface: authenticated (agency-owner/admin role, so RLS + `is_admin()` legitimately spans clients) READ-ONLY endpoint(s) for cross-data debugging/analysis — primarily over `events` (the cron-decision + funnel + status-change audit trail) and enrollment/message state. For programmatic analysis (e.g. an external tool querying "why didn't drip X fire" / send-block patterns / timing distributions). RULES: never expose the service-role key to the caller; SELECT-only; prefer aggregated/metadata views over raw PII (privacy) unless raw is specifically needed + handled. Overlaps with the export-client fn (generalize that pattern to read-across-for-analysis). Repo is public → keys stay runtime secrets, never committed. Owner: post-foundation tooling.
- [GATE] Stage 1f (Turnstile + rate-limit on public lead-intake) MUST ship before ANY client launches — CORS is browser-only; a direct/non-browser POST with a known slug/allowed-origin can spam-insert without it. Mirrored in `/launch-check` §E.
