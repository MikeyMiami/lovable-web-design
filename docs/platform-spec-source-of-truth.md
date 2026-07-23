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
3. **Launch each client on the shared backend** — create a client record + config (the §9b onboarding data); Remix ONLY the marketing site (frontend) for the client's domain, pointed at the shared backend via its Supabase env (`VITE_SUPABASE_URL` + anon key + `VITE_CLIENT_SLUG`). No per-client backend, DB, Cloud, or service-role key.

**The clean split:**
- **Backend = the ONE shared multi-tenant backend** (golden master, built/proven once, frozen, never regenerated per client). The part that must be reliable.
- **Design = per-client Remixed marketing site (frontend-only)** + the AI design layer (`/website-structure`). The part that should be varied/creative.

**The Remixed marketing site is frontend-only:** it reads public client data via anon SELECT (same-origin to supabase.co) and submits leads to the shared backend's public write routes, which enforce CORS + per-client domain allowlist + Zod + bot protection. No service-role key, no DB-hitting server fns on the Remixed project.

**Why shared-backend (Option A), decided & locked:** considered one-shared-backend (A) vs separate-backend-per-client (B). Chose **A**. Decisive reason: B reintroduces the exact **AI-drift** this golden-master model exists to prevent — every future bug-fix/feature would be re-prompted across N projects and silently diverge. A keeps business logic in ONE codebase: one place to fix, ship, and verify, forever; the other clients get a fix the moment it deploys. Per-client *design* stays fully bespoke either way (only the marketing site is remixed), so A costs nothing on customization. Data isolation is held by disciplined RLS + the isolation guardrails (see `/scratch-foundation`: RLS-audit gate, per-client cron fairness, export-client fn, CORS resolver). Escape hatch: A→B (peel one whale client out to a dedicated backend via the export fn) is easy; B→A (merge DBs) is brutal — so A keeps options open. This is settled; do not reopen without a material change.

**Project structure [LOCKED]:** Project 1 (the platform) + N template projects (a growing template library, one per niche×style — see `/template-builder` + `/website-structure`) + N short-lived per-client marketing remixes.
- **Project 1** — the shared backend + agency/admin dashboard + per-client tenant app (`app.theirdomain.com`). All share auth, RLS, server fns, and types; they belong in one project. Project 1 owns the database.
- **Template projects** — frontend-only marketing-site templates (presentational; no admin/backend code), **one per niche×style**, built via `/template-builder` + `/website-structure` then FROZEN. The FIRST is built after the backend freeze (Stage 4); the library grows on demand (don't pre-build it).
- **Per-client marketing sites** — Remix the matching template project (NOT Project 1, so admin code never ships in a client's marketing bundle); **no AI/design edits at remix time** — point `.env` at Project 1's shared Supabase by setting the ONE per-client line `VITE_CLIENT_SLUG` (the `VITE_SUPABASE_URL` + anon key are identical for every client). Custom domain attached at the remix level.
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
9. `/new-client-site` — per-client launch orchestrator: **provision a new client on the shared backend (client row + settings + messaging-provider (TextGrid) subaccount/number + onboarding capture) + Remix the marketing site for the client's domain (frontend-only) + invoke the design layer. NOT a backend clone, NOT a regenerate.**
10. `/website-structure` — the per-client DESIGN layer: page set (generated from onboarding, up to max), the 4 style choices, AI-driven copy + visual generation from onboarding data + assets + reference screenshots, and the codified style-template library (plug-and-play via Lovable cross-project referencing). Absorbs the old `/theme-to-brand` (brand colors/logo are part of this).
11. `/onboard-from-form` — captures the §9b onboarding data into the system (config + AI knowledge + design inputs).
12. `/template-builder` — imported into a NEW frontend-only Lovable project to build a client-site template from design references: the client data contract (clients columns + template_vars + asset manifest), the data-loader/demo-object pattern, platform wiring (`/api/public/intake`, `/api/public/r/`), hard rules (never hardcode business values, frontend-only, anon reads). Used WITH `/website-structure` (page set + 4 style voices). One template, designed once, then remixed per client with zero AI edits.
(`/website-structure` and `/onboard-from-form` are the per-client design + data-capture skills; both now unblocked. **The `/onboard-from-form` wizard is BUILT once in Stage 3 (with `/admin-view`) and USED per-client at Stage 5.** `/template-builder` builds the (frozen) marketing-site templates the per-client remixes copy. `/theme-to-brand` is absorbed into `/website-structure`.)

---

## 2. `/admin-view` — admin tabs on the client website [LOCKED]
Current tabs: **Dashboard, Contacts, Conversations, Feedback, Automations, Upload Customers, Settings**.
- **Automations** tab shows a **live active-enrollment count per drip** (from `enrollments WHERE status='active'` grouped by `sequence_key`). [BUILD — new]
- **Upload Customers** tab feeds the **Reactivation drip** (normalize → dedupe → enroll, reactivation caps).

**Settings tab must hold these per-client configurable values:**
- Timezone (drives all SMS windows).
- **SMS Send window** (default **09:00–19:00**, client timezone) — applies to MARKETING/FOLLOW-UP SMS only: **window-gated drips = review, one-year, reactivation** (`sequences.window_gated=true`). **Transactional drips fire 24/7 (`window_gated=false`): lead-form (both branches), missed-call textback, and discount-claim** (the discount SMS is a form-submission acknowledgment, like the lead-form — the customer just submitted, expecting a reply). Purpose: don't annoy past customers with off-hours marketing, while transactional replies stay prompt.
- **Business Hours** (separate per-client window) — applies to the LEAD-FORM drip only (§7). Purpose: decide whether a fresh web lead gets the live in-hours response or the after-hours message. Independent from the SMS Send window. [BUILD — new field]
- **Daily SMS send cap** (customizable per client) — max messages dispatched/day.
- **Daily enrollment cap** (customizable per client, **default 50**) — max NEW contacts entering the review drip/day; overflow waits to next day. *(Distinct from send cap.)*
- **Messaging config** (twilio_number, messaging_service_sid, call_forwarding_number — column names retained; hold the messaging-provider (TextGrid) values) — **single-source rule:** the number is stored ONCE and read everywhere on-site + in automations; changing it in admin propagates automatically. External placements (GBP, cards) are manual.
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

## 7e. FEATURE — Website Chat Widget Lead Opt-In [LOCKED — own skill `/chat-widget`]

> ⚠️ **SUPERSEDED 2026-07-16 — CAPTURE-FIRST, NO AI.** The `/chat-widget` skill is now authoritative; the AI-Q&A description below is historical. The widget is a **lead form in a chat skin**: bubble → customizable greeting → First/Last/Phone (+ message) + consent + Turnstile → `/api/public/chat/optin` → contact `source='chat_widget'` + `channel='chat'` message → the SAME lead-form drip → owner notification "New Website Chat Lead". The AI streaming/FAQ path (stream.ts, knowledge.server.ts, gemini gateway) is built-but-PARKED for a possible v2 toggle. Read `/chat-widget`, not the paragraph below.

A corner chat widget on the client's website. An AI assistant answers FAQs from the client's business data and routes quote/pricing interest into the same lead pipeline as the website lead form. Net-new; the largest single feature — gets its own `/chat-widget` skill.

### AI model & knowledge source
- **Model:** Lovable's native/built-in AI capability (no third-party API setup — Lovable can build this self-contained). NOT per-client fine-tuning — uses retrieval: the client's business info is provided to the model as context at chat time.
- **Knowledge source [DEPENDENCY]:** the AI answers from (a) the client's website content and (b) the **business onboarding form data** (services, hours, business details — the same data that builds the site copy). The AI's knowledge inputs are now defined by the onboarding form (§9b): About Us, services (detailed), service areas, hours, special/differentiators, social/site content. **Storage [PINNED — F-complete Option A]:** these live as anon-safe `template_vars` keys (`about_us`, `services`, `differentiators`, + `service_area`/hours); the chat reads them via `knowledge.server.ts` iterating the full `template_vars` into the system prompt (no per-key wiring). Owner PII (notification email) is NEVER in `template_vars` — it's a dedicated `clients` column. Answer quality = onboarding data captured.

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
- AI invocation (confirmed): Lovable AI Gateway (`https://ai.gateway.lovable.dev/v1`) + `LOVABLE_API_KEY` (ambient server runtime, never browser) + model `google/gemini-3-flash-preview`; streaming chat via `src/routes/api/public/chat/stream.ts` (+ opt-in `…/chat/optin.ts`, request `…/chat/request.ts`; AI SDK `streamText`/`toUIMessageStreamResponse`, client `useChat`), one-shot via `createServerFn`; knowledge bundle = per-request system-prompt injection; handle 429/402. **Routes MUST be under `/api/public/*`** — logged-out visitors hit them; a top-level `api/chat.ts` would be auth-gated (2b `/r/*` lesson). Full detail in `/chat-widget` + §9d.

---

## 8. `/mobile-app` — client app at `app.theirdomain.com` [LOCKED scope / BUILD tabs]
Mobile-first PWA, scoped to the logged-in client's `client_id`.
- **Conversations tab** — SMS threads across all contacts in this client's CRM. (Exists at `/app`.)
- **Review Request tab** — the enrollment form (first/last/phone/email) → enrolls into Review SMS Drip, subject to daily enrollment cap. [BUILD]
- **Notifications tab** — internal notifications to the client: automation-finished alerts (e.g. §4 step-5), weekly/monthly stats, messages. Needs a notifications table + automations writing to it + app UI reading it. [BUILD — net-new subsystem]

---

## 9. Other features (status)

### FEATURE — Missed-Call Textback [LOCKED]
**Trigger:** inbound call to the client's provider number ends with a call status of **`busy`, `no-answer`, `canceled`, or `failed`** (the Twilio-API-compatible literal status strings TextGrid returns — note `no-answer` hyphenated, `canceled` one L). Voice-status webhook = the Supabase EDGE FUNCTION (`telnyx-voice-status` for Telnyx clients; the TextGrid voice-status edge handler for TextGrid — the old `/api/public/twilio/voice-status` app route is DEAD). **Provider-split on voicemail:** for **TextGrid [FROZEN]** a call that rolls to voicemail reports as `completed` and does NOT fire (catching voicemail would require Answering Machine Detection — out of scope for TextGrid). For **Telnyx [go-forward]** AMD voicemail detection is **LIVE (2026-07-20)** — native ringback + Answering Machine Detection, so voicemail is caught.
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
- **Inbound SMS → CRM** — the inbound webhook (LIVE on the Supabase EDGE FUNCTIONS) creates/updates conversation + message + drives reply-exits / missed-call textback; STOP/HELP/START native at the provider + `pass` handled at the webhook. Signature verification is provider-split: **TextGrid [FROZEN]:** `X-TextGrid-Signature` HMAC-SHA1 (the TextGrid inbound edge handler; per-client `provider_webhook_secret`). **Telnyx [go-forward]:** Ed25519 — `telnyx-signature-ed25519` + `telnyx-timestamp` over `{timestamp}|{rawBody}` against the REAL `TELNYX_PUBLIC_KEY` (`telnyx-sms-inbound` / `telnyx-sms-status` edge fns). *(History: verified 2026-06-16 against the frozen repo, NO inbound route/signature check existed — this layer was 1f net-new; it now lives on the edge functions and the earlier `/api/public/*` app-route copies are DEAD.)*

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
- **Site style — NO LONGER owner-filled (REMOVED from onboarding 2026-07-22).** The agency picks one of the **6 style presets** (Professional Modern, Artistic Unique, Corporate, Modern Tech, Family Owned / Local Business, Owner Operated / Local Business) outside the app; all app `site_style` plumbing was removed and `clients.site_style` is dormant. Voices / slugs / visual directions live in `/website-structure` Site styles (the authoritative list). Drives the AI's copy voice AND the site's styling direction (§9c).
- **Photos** — 25–60 best photos + a team/owner photo (sent to the agency email) → site.
- **Consent** — terms & conditions + SMS opt-in language.

### B. Agency-set config (during onboarding, in `/admin-view` — NOT owner-filled)
- **Google review link + Place ID** — agency grabs from the client's GBP (they may not have one yet → setup task; the whole review engine depends on it).
- **Star threshold** (default 4) — agency-decided in admin settings.
- **Terms page** — agency-hosted; generated A2P-compliant from onboarding data (see C).
- **Quote form link** — defaults to the site lander (not collected).
- **Marketing domain(s) / allowed origins** — the client's site domain(s); powers the public-write CORS allowlist (§6). [BUILD — new field]
- **Messaging number + Messaging Service SID** — per-client, NON-secret (a number under the ONE parent messaging-provider (TextGrid) account, via a per-client subaccount); editable in admin. Stored in `clients.twilio_number` / `twilio_messaging_service_sid` (column NAMES retained — they hold the provider's values). (No per-client auth token on a row — see D.)
- **Call-forwarding number** — the client's real phone the provider (TextGrid) number rings through to; editable in admin per client over time. [BUILD — new admin field]
- **Sending subdomain / DKIM** — agency setup.
- **Timezone** — editable in admin (default from the owner's pick).

### C. A2P-compliant terms page [BUILD]
The agency hosts each client's terms/privacy page. Needs a documented process to generate an **A2P 10DLC-compliant terms & conditions + privacy page** from the onboarding data (business name, contact, SMS consent language, opt-out instructions, data handling). This page is what `{website_terms_page_link}` points to. Required for compliant SMS consent on all forms. **The full compliance surface (Privacy Policy + ToS + SMS Program page + single-checkbox opt-in + the copy-paste Brand/Campaign pack) is owned by `/a2p-site-compliance`; verbatim carrier copy lives in `docs/a2p-compliance-copy-source-of-truth.md` (tokens-only substitution + a per-niche category library).**

### D. Per-client telephony setup [LOCKED pattern — the TextGrid per-client subaccount model, now FROZEN LEGACY; Telnyx is the go-forward default — see addendum]
> **Dual-provider addendum (2026-07-20; Telnyx-default 2026-07):** messaging is now multi-provider via `clients.provider` (`'telnyx'` default | `'textgrid'` legacy — the column default flipped `'textgrid'`→`'telnyx'` via a new migration; the admin Messaging Provider select was RETIRED 2026-07-22 — card deleted, provider is effectively fixed). The TextGrid subaccount model below is **FROZEN LEGACY — it still routes any client already on `'textgrid'` but is not the default and cannot be chosen for new clients**; **Telnyx** is the go-forward DEFAULT on a **SINGLE Telnyx account** (no subaccounts — per-client isolation is app-logic from-number resolution + `telnyx_number` lookup; Ed25519-signed webhooks on the `telnyx-*` edge functions). See `skills/telnyx-provider`.
- **One parent messaging-provider (TextGrid) account** (the agency's master; billing rolls up; TextGrid = Twilio-API clone — see `skills/textgrid-provider`). Per client, a **subaccount** (vets independently, ~2–4 day A2P cadence) → Brand (client EIN) → Campaign → **number** (local area code matching their market). Store the per-client **From number (`clients.twilio_number`)** + optional **Messaging Service SID (`clients.twilio_messaging_service_sid`)** — both NON-secret; column names retained, hold the provider's values. **Net-new per-client provider fields added at 1f:** `a2p_brand_id`, `a2p_campaign_id`, `a2p_status` (clients columns) + the subaccount SID / webhook secret / auth token — **which moved 2026-07-22 to the server-only `client_provider_secrets` table** (clients columns dropped; RLS scan found tenant browsers could read them).
- **Secrets:** the agency **master account** auth token is the single platform runtime secret (never on a row). Per-client subaccount creds live in the server-only **`client_provider_secrets`** table (2026-07-22 — moved off clients; RLS on, zero policies, service-role only; admin writes via the write-only ProviderSecretsPanel) — the webhook secret backs the `X-TextGrid-Signature` verification below.
- **Outbound:** fetch POST to the provider (TextGrid) API with the per-client `From` / `MessagingServiceSid` (caller-resolved; the send primitive stays SEND-ONLY).
- **Inbound + voice-status webhooks [1f — NET-NEW, not a swap]:** per-client subaccount webhooks → `/api/public/*`; route to the correct client by the `To` number → `clients` row; **`X-TextGrid-Signature` (HMAC-SHA1) verified** (per-client `client_provider_secrets.webhook_secret`) BEFORE any DB write. *(No inbound route or signature check exists in the frozen master — built fresh at 1f.)*
- **Forward** the client's number's calls to the client's real phone (the call-forwarding number) — so they answer calls normally.
- Put the **number on the website + Google Business Profile** (+ business cards). All SMS automations and missed-call textback operate on it. The client keeps their existing number everywhere else.
- **A2P [per-client]:** each client gets its OWN subaccount → Brand (client EIN) → Campaign under the agency master account (TextGrid ISV/reseller flow); **each vets INDEPENDENTLY per-client** (~2–4 days — register at signing so it vets during the site build). NOT one shared agency-wide campaign. *(Corrected 2026-06-16: the prior "ONE agency brand/campaign covers all numbers, no per-client re-vetting" was the old Twilio-Option-1 assumption — TextGrid registers per-client.)*
- **Option 2 (BYO-provider / BYO-Twilio, future — NOT v1):** for clients who insist on owning their own provider/Twilio account, store per-client `accountSid`/`authToken` in a server-only secret store (`client_secrets` table). Reserved.
- Rationale: SMS automation + missed-call detection require a provider-controlled (TextGrid) number; forwarding preserves the client's normal call experience.

---

## 9c. Website Structure & Design Layer [LOCKED — skill `/website-structure`]

The per-client DESIGN layer, applied on top of the shared golden-master backend (§0). Defines the page set, the copy/visual direction, and how design is generated and (eventually) templated. Absorbs the old `/theme-to-brand`.

### Page set [LOCKED]
Pages are generated FROM the onboarding data, up to the max below. Only build pages the onboarding form supports (e.g. 5 services + 8 areas → 5 service pages + 8 area pages, not the max).

**Always present:** Home/Lander, Contact Us, Gallery, Thank You, Discount Funnel, Review Us, Terms of Service, Privacy Policy. (+ an SMS Program page; the Terms/Privacy/SMS-Program/opt-in copy is the VERBATIM `/a2p-site-compliance` set — `docs/a2p-compliance-copy-source-of-truth.md`, tokens only.)
**Data-driven (one each, up to max):** Service page per service (**max 12**); Service Area page per area (**max 14**).

- **Service Area pages** = essentially the Home/Lander, re-focused on serving that specific area (local-SEO: ranks for "[service] in [city]").
- **Service pages** = AI determines a good, relevant layout describing that service.

### Design generation inputs [LOCKED]
The visual design, fonts, colors, copy, and layout are AI-driven, determined by combining:
1. **Site style** (AGENCY-CHOSEN — one of the 6 style presets; removed from client onboarding 2026-07-22; see `/website-structure` Site styles for the authoritative list) → copy voice + styling direction.
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
- **Messaging provider (TextGrid) — SMS + voice** — agency master account → per-client subaccount → Brand → Campaign → number; master auth token = runtime secret; per-client subaccount webhook secret (`provider_webhook_secret`) backs `X-TextGrid-Signature`. The inbound/voice webhook routes (`/api/public/twilio/inbound`, `/api/public/twilio/voice-status` — literal paths) are **NET-NEW at 1f** (per-client subaccount webhooks; they don't exist in the frozen master). Numbers/forwarding/placement = per-client. **⚠️ Dual-provider (2026-07-20):** `clients.provider` now selects **TextGrid [FROZEN]** vs **Telnyx [go-forward]** (single account, Ed25519, per-client `telnyx_*` columns); the inbound/voice webhooks are **LIVE on the Supabase EDGE FUNCTIONS** (`telnyx-*` / TextGrid handlers) — the `/api/public/twilio/*` routes above are **DEAD**. See `skills/telnyx-provider`.
- **Bot protection** — Cloudflare Turnstile (free, fits Workers/fetch). One widget, site key (public, in marketing forms) + secret (runtime secret, verified in lead-intake server fns). Add each client domain as a hostname. Verify step = golden-master; client hostname = per-client.
- **AI chat widget** — Lovable native AI. CONFIRMED with Lovable: calls go through the Lovable AI Gateway (`https://ai.gateway.lovable.dev/v1`) authed with `LOVABLE_API_KEY` (already provisioned, ambient on server runtime, never browser-exposed); default model `google/gemini-3-flash-preview`. Streaming chat → server route `src/routes/api/chat.ts` (AI SDK `streamText`/`toUIMessageStreamResponse`, client `useChat`); one-shot → `createServerFn`. Knowledge bundle = per-request system-prompt injection (keep tight). Per-request billing; opt-in gate is the natural rate-limiter; handle 429/402; add own throttle if hard caps needed. AI gateway works without Cloud; the lead-write persistence needs Cloud. Widget/server-fn = golden-master; knowledge bundle = per-client.
- **Google (review links)** — NO integration/OAuth/API. Just two stored strings per client (`review_link`, `review_place_id`); the leave-a-review URL is constructed. Per-client (onboarding).
- **Storage** — native Supabase: `public-assets` (public-read), `client-assets` (private, client_id-scoped RLS). Buckets/policies = golden-master; uploads = per-client.
- **Scheduling** — native pg_cron + pg_net → `/api/public/cron/sequences` with `x-cron-secret`. Needs stable backend URL + `CRON_SECRET`. Golden-master.
- **Domains/DNS** — shared backend needs a stable custom domain (gates provider (TextGrid) webhooks, cron, tracked links) = golden-master. Per-client: marketing domain (→ deploy + `allowed_origins`; Turnstile-hostname step retired 2026-07-22 — native bot-shield), `app.theirdomain.com` for the mobile app.
- **Rate-limiter store** — in-memory won't work across Worker isolates; use Cloudflare Durable Objects / Workers KV / DB-based. Golden-master decision (no new account).

### Architecture note — shared-backend vs frontend-only split [LOCKED]
The per-client **Remixed marketing site is frontend-only** (anon reads + CORS-guarded POSTs; no service-role, no DB writes). The **admin view AND the mobile app are part of the SHARED BACKEND** (authed, DB-touching), served on per-client subdomains (`app.theirdomain.com`), NOT frontend-only Remixes. The **tracked-link + funnel routes (`/api/public/r/<token>`, `/api/public/r/rate`, `/api/public/r/feedback`) are served by the SHARED BACKEND domain** (they write to the DB), not the client marketing domain.

**Project structure (see §0):** Project 1 = shared backend + admin + tenant app (owns the DB); N template projects (a growing library, one per niche×style — `/template-builder` + `/website-structure`); per-client marketing sites = Remixes of the matching template with `.env` `VITE_CLIENT_SLUG` → Project 1's Supabase. Subdomain routing locked: tenant app `app.theirdomain.com`, marketing root `theirdomain.com`.

**Isolation guardrails (what makes shared-backend safe — built in `/scratch-foundation`):** (1) RLS-audit gate (CI fails if any tenant table lacks a client_id policy); (2) per-client cron fairness (round-robin, no starvation); (3) export-client server fn (offboarding/portability) + archive-via-status; (4) CORS resolver (client_id from server-resolved Origin/Host→allowed_origins, never request body).

---

## 10. Open items blocking skill authoring
- [RESOLVED] Copy-strategy (§9c) — copy is AI-generated, steered by the 4 style choices; templatized structure. `/website-structure` (absorbing `/theme-to-brand`) can now be written.
- [RESOLVED] Onboarding form (§9b) — it's a real owner-filled content form + agency-set config. `/onboard-from-form` can now be written. (Remaining build: extend `createClient`/settings to capture all §9b fields.)
- [BUILD] Tracked-redirect link system for review drip (§4); daily enrollment cap (§3); Notifications subsystem (§8); mobile Review Request tab + Auto-Enroll button (§7/§8); "pass" keyword → opt-out (§4); on-reply handler capturing `message.body` (§5) and lead reply-detection (§7); Business Hours setting + lead-form branching (§2/§7); re-enrollment guard (§4/§6); discount-form-submit exits one-year drip (§7b); per-contact `last_missed_call_textback_at` timestamp + 7-day re-eligibility check (§9); call-forwarding-number + marketing-domain admin fields (§9b); A2P-compliant terms-page generation (§9b); onboarding form capturing all §9b owner fields incl. timezone + style picker.
- [BUILD — foundation, in `/scratch-foundation`] Public writes via server fns (`supabaseAdmin` + Zod, slug→`client_id`); NO anon INSERT; anon SELECT only on `clients` public columns; CORS + per-client domain allowlist + OPTIONS + rate-limit + Turnstile/hCaptcha on public lead-intake. Foundation invariants: `enrollments` UNIQUE (client_id, contact_id, sequence_key) (DB-level re-enrollment/dedup guard); `events.created_by` + cron-decision logging; soft-delete `deleted_at` on contacts/clients; RLS perf (`(SELECT auth.uid())`, STABLE helpers, `client_id` indexes incl. partial `enrollments(next_run_at) WHERE status='active'`); two storage buckets (`public-assets` public-read for logos/hero, `client-assets` private client_id-scoped); `CRON_SECRET`-protected `/api/public/cron/sequences` (`x-cron-secret` header); parent messaging-provider (TextGrid) auth token + `CRON_SECRET` as runtime secrets; no `client_secrets` table in v1 (Option-2/BYO-provider/BYO-Twilio only); + the 4 isolation guardrails (RLS-audit gate, cron fairness, export-client fn, CORS resolver).

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
- Business Onboarding Form & Client Setup — owner-filled content form (+ timezone + style picker) + agency-set config + A2P terms-page generation + per-client messaging-provider (TextGrid)/forwarding telephony setup (§9b).
- Website Structure & Design Layer — page set (always-present + data-driven service/area pages, max 12/14), 4 style choices, AI copy+visual generation from style/onboarding/assets/reference screenshots, two-mode design-template system; absorbs /theme-to-brand (§9c).
- Foundation architecture — one shared multi-tenant backend (golden master, built/proven once); per-client launch = client row + config + Remixed frontend-only marketing site sharing the backend's anon env; backend never regenerated per client (§0). Shared-backend (Option A) re-confirmed + locked with AI-drift rationale; 2-project structure + subdomain routing locked; 4 isolation guardrails (§0/§9d/`/scratch-foundation`).
- Public writes via server fns + CORS/allowlist/bot-protection; no anon insert (§6).
- Messaging provider (TextGrid) — agency master account → per-client subaccount → Brand → Campaign → number (From/SID on clients, non-secret); master auth token = runtime secret; per-client subaccount webhook secret backs `X-TextGrid-Signature` (inbound/voice routes are NET-NEW at 1f, routed by To); BYO-Twilio = Option 2, not v1 (§9b.D).
- Email drip — SCRAPPED, SMS-only (§7c).
- Re-enrollment guard (§4/§6). opt-in-forms map (§6 — now FINITE). Two-window model + two caps (§2/§3). admin-view tabs (§2).
- Naming convention: `{first_name}` customer-facing, `{full_name}` internal notifications.
- External dependencies — all confirmed (§9d): email (NS-delegated agency sender), messaging provider (TextGrid, per-client subaccount model), Turnstile, Lovable AI Gateway, Google (stored strings), storage, pg_cron, domains, rate-limiter store. Both prior ❓ items (email + AI) now RESOLVED.

## 12. Backlog / Work Queue (ordered)

### DONE
- ~~v1.7 additive backend~~ ✓ DONE 2026-06-18 (`golden-master-v1.7`) — ticketing (`tickets`/`ticket_messages`/`ticket_attachments`; read-only RLS + service-role write fns, trust fields set authoritatively), `consent_records` append-only ledger (`discount.ts` writes both branches), `clients.access_suspended` payment-gate (admin/service-role-only guard trigger; never stops automations), A2P core columns (`a2p_brand_id`/`a2p_campaign_id`/`a2p_status` enum). Migration `20260618225557` + a REVOKE write-grant hardening. Validated live: `audit_tenant_rls()=0`, tenant read-isolation, **write-denial empirically confirmed** (RLS default-deny: "new row violates row-level security policy"), consent immutability, suspend tamper-guard. **Carved out → Phase-B-design/D:** the 5 ticket write fns, the `client-assets` 25 MB/MIME bucket caps, and the extended A2P field set.
- ~~SMS automation formatting pass~~ ✓ COMPLETE — all customer-facing SMS finalized with intended line breaks (proofread/approved); all internal notifications + emails reformatted to stacked form (§4/§5/§7/§7b + `/automation-config` + `/mobile-app`); owner-email copy added to `/automation-config`. `/features` is mechanics-only (no inline copy). Customer SMS remain editable on-site.

### >>> NEXT UP — PHASE 2: BUILD & PROVE THE GOLDEN MASTER <<<
Phase 1 (author the skills) is COMPLETE ✓ — spec + all 11 skills, mutually consistent, foundation reconciled against the live DB, zero open decisions.

Phase 2 (the build):
1. Run `/scratch-foundation` — apply the [ADD] migrations + enum `ALTER TYPE`s (review_completed/negative_review/reactivation; chat_widget/mobile_enroll), the enrollments UNIQUE constraint (dedup first), the index set, the two storage buckets, runtime secrets (CRON_SECRET + parent messaging-provider (TextGrid) token).
2. Build the feature + automation layer (features → automation-config → opt-in-forms → mobile-app → admin-view → chat-widget) on the shared backend. *(LAUNCH.md splits this into Stage 2 — feature/automation logic: features → automation-config → opt-in-forms → chat-widget — and Stage 3 — client-facing surfaces: admin-view + mobile-app. Same set, more granular; build logic before UI surfaces.)*
3. Wire telephony (messaging-provider stub; real provider = TextGrid at 1f) + the pg_cron drip runner.
4. Run the **pre-freeze cleanup** (Stage 3.5 — §A security + audit_log + export-client/guardrail-3 + the 3a send-primitive regression re-test), then `/launch-check` sections A–D green **for the frozen-LOGIC rows** → declare the golden master frozen. **Freeze = the automation LOGIC + schema + surfaces (the drift-prone stuff) are locked.** **The carve-out is the FULL 1f scope (deferred to 1f, post-freeze — NOT freeze blockers), not just the §A Turnstile row:** §A Turnstile/rate-limit + parent messaging-provider (TextGrid) auth token; §B real-provider (TextGrid) 5xx/4xx branch; §C one-year real-time reply-exit + missed-call voice-webhook + owner-email actual send (drip logic frozen); §D nearly all (real provider (TextGrid) account/From/SID, status-swap, render-completeness guard, the net-new inbound+voice webhook layer, real-time reply-driven exits, per-client number/forwarding/GBP) — §D is the 1f stage, not a freeze gate.
5. **1f = the deliberate FINAL pre-launch hardening, AFTER freeze:** real messaging-provider (TextGrid) swap + the net-new inbound webhook layer + message testing + Turnstile/rate-limit live. The ONLY changes permitted to touch the frozen backend; gated by `/launch-check` §E. Then per-client launches use `/new-client-site` (provision + Remix + design + launch-check §E).

### FEATURES — all defined & locked ✓
- All platform features are scoped AND locked, including AI Chat Widget (§7e) and Customer Review Reactivation (§9). No undefined features remain.

### SKILLS — all 12 authored ✓
scratch-foundation, features, automation-config, opt-in-forms, chat-widget, mobile-app, admin-view, onboard-from-form, website-structure, launch-check, new-client-site, template-builder. Mutually consistent; foundation reconciled against the live DB.

### LATER / PARKED (non-blocking)
- **PWA web-push notifications** — superseded by owner email notifications (§7d); revisit if real-time phone push wanted.
- **Stats label** — DONE: dashboard renamed to "Review Link Clicks" (counts `review_clicked` landings). **Dashboard lead counters SPLIT per channel (3d decision 2026-06-14):** Website Leads (`web_form`) + Chat Leads (`chat_widget`) + Review Link Clicks (`review_clicked`), each week/month, client-tz — replaces the single "New Website Leads". Discount-form folds into `web_form` (Website Leads) unless a distinct `discount_form` source is added. Authoritative def in `/mobile-app` Tab 4.

### ARCHITECTURE DECISIONS — ALL RESOLVED ✓
- ~~Copy-strategy~~ RESOLVED (§9c): AI-generated copy steered by 4 style choices; templatized structure. `/website-structure` unblocked (absorbs `/theme-to-brand`).
- ~~Onboarding form vs SQL~~ RESOLVED (§9b): real owner form + agency config. `/onboard-from-form` unblocked.
- ~~Build-from-scratch vs clone~~ RESOLVED (§0): golden-master model — skills build/prove ONE shared multi-tenant backend once; per-client launch adds a client to the shared backend + Remixes a frontend-only marketing site (no backend clone, no regenerate); design is the per-client creative layer.
- ~~Shared-backend vs backend-per-client~~ RESOLVED & LOCKED (§0): Option A (shared) — B reintroduces AI-drift; A keeps logic in one codebase; A→B peel-out easy, B→A merge brutal. Do not reopen without material change.
- ~~Email sender + AI invocation~~ RESOLVED (§9d): email = NS-delegated one platform agency sender (~120/min transactional); AI = Lovable AI Gateway + LOVABLE_API_KEY + gemini-3-flash-preview. Both prior ❓ closed.

### SYSTEM NOTES (carry into the build)
- Failed SMS sends retry up to 2× at the send layer before marking failed (the GHL "max retries" equivalent) — [BUILD] in the send/cron logic, not per-drip.
- [DONE 2026-06-09] RLS-audit gate (guardrail 1): `audit_tenant_rls()` built (SECURITY DEFINER, STABLE, service_role-only) — scans every public BASE TABLE with a `client_id` column (excl. `clients`, which is id-scoped) and asserts a `user_client_ids()`/`is_admin()` tenant check on the relevant USING/WITH CHECK per command; **0 rows = PASS (currently PASS)**. Run `SELECT * FROM public.audit_tenant_rls()` after every migration (manual until a CI harness exists). Recorded: `docs/build-log/guardrail-1-rls-audit.md`. (Enhancements: **extend to also gate `clients`' own policies — DONE in the Stage-3.5 §A security step (RPC-only model, introspection-backed 2026-06-15):** assert **anon has NO direct `clients` base access** (zero column/table grants + NO anon RLS policy → direct anon SELECT = 42501) and that the public read is via the **`get_client_public` RPC** whose projection excludes sensitive cols + strips `notification_email`. *(The earlier "anon column-grants ⊆ presentational set" framing is VOID — there are no anon column-grants under the RPC-only model.)* add a functional cross-tenant isolation test before go-live — string-match is a convention tripwire, not a proof.)
- [DONE 2026-06-15 — built to this design in migrations `20260615210212` + `20260615211022`; live in golden-master-v1.6] audit_log table (no client_id; columns: actor_user_id, action, target, payload jsonb, created_at; service-role write, admin read) for ALL role mutations — grants AND revokes, both platform (admin/agency_owner, client_id NULL) and tenant scopes. Currently: only tenant *grants* hit `events`; platform grants + ALL revokes are unaudited (`events.client_id` is NOT NULL; revoke writes no event). Centralize role-mutation audit here. Land before go-live / **before any real admin OR agency_owner is granted** (agency_owner = full cross-tenant by design — see the PRIVILEGE_ESCALATION decision below — so auditing WHO receives admin/agency_owner is MORE critical, not less). Do NOT make `events.client_id` nullable. Owner: 1d/auth. **DESIGN [Option 3, 2026-06-15]:** a `user_roles` AFTER INSERT/UPDATE/DELETE trigger (`SECURITY DEFINER`, `SET search_path`) is the **SOLE writer** — the completeness floor that catches **direct-SQL** grants too (e.g. how the test admin was minted; a fn-only audit would miss them) — and **NEVER fails the underlying mutation**. Actor = `current_setting('audit.actor', true)::uuid` (set by the fns) → else `auth.uid()` → else **NULL** for direct SQL (`actor_user_id` is uuid → NULL, not `'system'`; `payload.actor_source` notes it). `assignUserRole`/`revokeUserRole` enrich via **`set_config('audit.actor'/'audit.reason', …, is_local := true)` (SET LOCAL — txn-scoped; never plain SET → pooled-connection leak)** and do NOT write `audit_log` themselves (no double-log). `action` ∈ {grant, revoke, change}; **`target_user_id` a discrete queryable column** + role/scope in payload. **Append-only** (no UPDATE/DELETE — immutable). RLS read = `is_admin()` (admin + agency_owner; platform-scope, not client_owner). **Backfill a `{backfilled:true}` row for the pre-audit test-admin grant (4efaaa92…)** so no real admin is unaudited; revoking that test grant later is then auto-audited. **GATE SATISFIED — table + append-only triggers (`audit_log_immutable`) + the `user_roles_audit()` sole-writer trigger + the `assign_user_role_audited`/`revoke_user_role_audited` RPCs + the `assignUserRole`/`revokeUserRole` server fns + the backfill row are all LIVE in golden-master-v1.6.** Verified against the as-built design 2026-06-18 (Phase B-0 scoping).
- [DECISION — INTENTIONAL 2026-06-14] **`user_client_ids` returns ALL clients to any `agency_owner` — scanner flagged PRIVILEGE_ESCALATION; marked INTENTIONAL.** Under the LOCKED single-agency model, `agency_owner` = the platform operator = full cross-tenant by design (same posture as `admin`; it is the basis for `/admin-view`'s cross-client span via `is_admin()`). (a) **The real control is the GRANT PATH:** granting `agency_owner` = granting all-tenant access, so it MUST stay **admin-only-grantable** (the 1d `assignUserRole` matrix) **+ audited** (the audit_log TODO above — which is exactly why that lands before any real admin/agency_owner grant). (b) **Tripwire — becomes a GENUINE bug** if the model ever shifts to **multiple agencies / scoped agency_owners**: then `user_client_ids` must map each agency_owner to only its own clients (Option 2: per-agency mapping) and the cross-tenant span must be re-scoped. Until that model change, this is by-design, not a leak. (Scanner: mark accepted/intentional with this rationale.)
- [DONE 2026-06-09] revokeUserRole authorization (1d): verified — same matrix as assignUserRole (client_owner cannot revoke admin/agency_owner/client_owner; scoped to own client_id; platform-admin can revoke any; delete scoped client_id=X / IS NULL). Recorded: `docs/build-log/stage-1d-validation.md`. (Role-mutation audit still pending via the audit_log TODO above.)
- [DONE 2026-06-15 — isolation guardrail 3] Export-client + archive offboard (`scratch-foundation` §11): **`export_client_bundle(_client_id, _actor)`** — service-role RPC, **catalog-derived table list** (`information_schema`: every public BASE TABLE with a `client_id` column, minus `user_roles`) → 11 tenant tables, each `WHERE client_id=$1` (`%I`-quoted + bound param; live bleed-check = 0), full `clients` row + per-table `to_jsonb` ordered by id, versioned re-importable JSON. **In-RPC authz on line 1** (`is_admin(_actor)` → 42501; `REVOKE FROM PUBLIC`, service_role-only EXECUTE) + server fn `assertIsAdmin` — defense-in-depth (applied the item-1 audit-RPC lesson proactively). **`archive_client()`** = SOFT offboard: `status='archived'` + `deleted_at`. **Archive STOPS drips:** the `claim_due_enrollments` SECURITY DEFINER claim fn filters `c.status='active' AND c.deleted_at IS NULL` (runner gets it for free; live 11→0). **Lifecycle [LOCKED]:** archive = SOFT (status+deleted_at) → runner-stops + data **PERSISTS**; the export bundle is the SEPARATE portability / A→B artifact; **NO automatic hard-delete** (a purge of archived data = deliberate separate op, not built; retention policy = future decision). `audit_tenant_rls()`=0. *(Excludes `user_roles` — FK to auth.users, not portable; client role-assignments re-granted on re-import via the audited RPCs.)* Owner: foundation/lifecycle. `/launch-check` §A + §B.
- [DEPRECATED 2026-06-16 — superseded by the agency reactivation number pool] The per-client reactivation drip (`enrollReactivation`, `sequence_key='reactivation'`, sends from `clients.twilio_number`, admin "Upload Customers" tab) is LOGICALLY deprecated: all real reactivation traffic now runs from agency-owned pool numbers (see `reactivation-number-pool-spec`). **Purely enrollment-driven — NO auto-trigger** (verified 2026-06-16 against the frozen repo: only the admin Upload-Customers CSV → `reactivationUpload` → `enrollReactivation` calls it; no cron/webhook/drip-handoff auto-enrolls), so deprecation = simply never enrolling → dormant. Frozen code left PHYSICALLY INTACT (no modification, no re-validate/re-tag); physical removal = a separate deliberate cleanup. Optional enforcement: hide/repoint the admin "Upload Customers" tab (admin-UI only). **↻ UPDATE 2026-07-21 — REVERSED: the agency number pool was REMOVED, and reactivation now runs FROM THE CLIENT'S OWN Telnyx number** (`clients.telnyx_number`, `provider='telnyx'`) via the per-client `reactivation` drip delivered by the NORMAL send runner (normal throttles + the 50/day · 2/20min enrollment caps + dedup + a REQUIRED consent attestation). DELETED: the `reactivation_numbers`/`reactivation_campaigns`/`reactivation_enrollments` tables, the `create_reactivation_campaign`/`claim_due_reactivation` RPCs, the finite-campaign runner + `/api/public/cron/reactivation` route, and the "Number Pool" admin surface. The per-client drip is therefore no longer "deprecated" — it IS the live mechanism (now the "Upload Customers" enroll path, no auto-trigger); the global `reactivation` SEQUENCE remains. Optional future re-isolation via a dedicated `telnyx_reactivation_number` is a documented NOT-built seam. See `docs/reactivation-number-pool-spec.md` (SUPERSEDED banner).
- [BACKLOG — IDEA] Read-only admin debug/research interface: authenticated (agency-owner/admin role, so RLS + `is_admin()` legitimately spans clients) READ-ONLY endpoint(s) for cross-data debugging/analysis — primarily over `events` (the cron-decision + funnel + status-change audit trail) and enrollment/message state. For programmatic analysis (e.g. an external tool querying "why didn't drip X fire" / send-block patterns / timing distributions). RULES: never expose the service-role key to the caller; SELECT-only; prefer aggregated/metadata views over raw PII (privacy) unless raw is specifically needed + handled. Overlaps with the export-client fn (generalize that pattern to read-across-for-analysis). Repo is public → keys stay runtime secrets, never committed. Owner: post-foundation tooling.
- [PRE-FREEZE / 1f — INFRA] **Runner/worker deploy promotion is laggy/unverified** — at BOTH 3c and 3f the published worker kept serving pre-change runner code after a publish (bodies still `[stub]` / materialization absent until a re-publish promoted). RISK: 1f deploys the real-provider (TextGrid) runner to this SAME worker, so flaky runner promotion is a launch risk. Before relying on any runner deploy (and before 1f): (1) **add a build-version stamp the runner emits** (e.g. `runner_version` in `events`/`cron_decision`) so each tick deterministically shows which bundle ran — turns "squint at `[stub]`" into "check the version" (formalizes the 3c SID-match trick); (2) confirm the **cron worker = the same deploy target as the published site** (one worker, not a separate/stale target); (3) confirm **pg_cron→pg_net hits the PRODUCTION worker URL** (not a preview/alias pinned to an old deploy); (4) rule out a cached/staged worker script. Diagnose NOW, not at launch. Owner: infra/deploy. **Status 2026-06-16 — CLOSED:** (1) `runner_version` stamp IMPLEMENTED + proven at the 3f walk (`v20260615-1`) — the instrument works. (2) ✅ RESOLVED — there is **no separate worker**: the cron entrypoint is an in-app route (`src/routes/api/public/cron/sequences.ts`) compiled into the SAME Nitro bundle as the published site (it imports `runDripTick` from `runner.server`); no `supabase/functions/`, no second deploy target → publishing the site necessarily promotes the runner. (3) ✅ RULED OUT — live `SELECT … FROM cron.job` returned **0 rows**: there is NO scheduled caller at all (the cron job was never migrated — only `CREATE EXTENSION` is; every tick to date has been MANUAL), so there is no URL to mistarget. (4) **inherent Lovable edge-propagation lag** (publish → `.lovable.app` alias flip is eventually-consistent) — not code-fixable; handled procedurally by the confirm-promoted gate below. **Confirm-promoted gate (run after EVERY backend-touching deploy):** bump `RUNNER_VERSION` in the same commit → publish → **POST** `https://cloud-spark-setup.lovable.app/api/public/cron/sequences?ping=1` (early-returns the version before auth/tick — no secret, no send; POST-only, there is no GET handler) until it echoes the new version; once scheduled, cross-check fresh `events.payload->>'runner_version'`. `?ping=1` shipped at `cloud-spark-setup@5e41f41` (RUNNER_VERSION `v20260616-1`), additive early-return, re-validated + re-tagged **`golden-master-v1.1`**.
- [BUILD — 1f · DO LAST] **Schedule the drip runner via pg_cron** — it is currently UNSCHEDULED (`cron.job` empty; the runner has only ever been ticked MANUALLY). As the FINAL 1f step — AFTER the TextGrid swap + the net-new inbound layer are validated on MANUAL ticks — install the schedule pointed at the canonical PRODUCTION host: `SELECT cron.schedule('drip-runner','* * * * *', $$ SELECT net.http_post(url := 'https://cloud-spark-setup.lovable.app/api/public/cron/sequences', headers := '{"x-cron-secret":"<CRON_SECRET>","Content-Type":"application/json"}'::jsonb) $$);`. Use the stable prod URL, NEVER a preview/`*-preview--*` alias. Scheduling LAST is deliberate: an empty `cron.job` means nothing auto-fires real SMS during the build (manual `?ping=1` + secret-authed manual ticks only). Before scheduling, run the `?ping=1` gate to confirm the live bundle is the validated one. Owner: infra/deploy. Mirrored in `/launch-check` §E.
- [GATE] Stage 1f (Turnstile + rate-limit on public lead-intake) MUST ship before ANY client launches — CORS is browser-only; a direct/non-browser POST with a known slug/allowed-origin can spam-insert without it. **1f is the deliberate FINAL pre-launch hardening AFTER the Stage-4 freeze (real messaging-provider (TextGrid) swap + message testing + Turnstile/rate-limit + the net-new inbound webhook layer) — a launch gate, NOT a freeze blocker; the provider-swap + net-new inbound + Turnstile are the ONLY changes allowed to touch the frozen backend.** Mirrored in `/launch-check` §E.
- [BUILD — 1f] Reply-driven drip exits must be REAL-TIME via the inbound-SMS webhook (one-year exit-on-reply + interest notification; missed-call reply-skip; opt-out) — exit + notify ON the reply, not at the next pre-step check. One-year inter-step gaps are weeks/months, so pre-step-only checking delays the "they replied" interest notification by ~a month (a hot lead goes cold). Pre-step checking is the stub-mode fallback; the 1f inbound webhook is the production path. Mirrored in `/launch-check` §D.
- [STAGE 3 — 3c] Runner → `messages`/`conversations` materialization (3b finding; RECLASSIFIED from 1f to a Stage-3 sub-step): today the cron-runner stub logs `sms_sent` to `events` only and does NOT write `messages`/`conversations`; only the reply path inserts — so drip sends are ABSENT from the Conversations inbox and a missed-call Open-conversation deeplink lands on an empty thread. **Build now (3c) with STUB status:** the runner writes each outbound text into `messages` + bumps `conversations.last_message_at`, AND a shared `insertOutboundMessage({clientId,contactId,body,sid?,status})` helper — **admin variant for cron (service-role) + RLS variant for reply (authed)** — is reused by the runner + `reply.functions.ts`; keep the send primitive SEND-ONLY (materialization in the callers). **Both callers write the same `stub` status** in stub mode (neither hits the provider). **At 1f, only swap `stub` status → real messaging-provider (TextGrid) SID/delivery + failure status — for BOTH the runner and reply outbound writes** (no new insert logic). This completes the runner to its already-spec'd behavior (`/launch-check` §B's runner line = "insert message+event"; the stub only did `event`). Mirrored in `/launch-check` §B (Stage-3 build) + §D (1f status-swap).
- [PRE-FREEZE MUST-FIX — Stage 3.5 (3f finding)] The SMS runner never read `templates` — `runner.server.ts` rendered `body = step.body ?? "[stub] "+templateKey` (`step.body` never set in steps_json), so ALL drip SMS bodies were `[stub] <key>` literals, never the template copy (global OR override); only `internal_notification` (the 2c dispatcher) honored templates. Latent since 2e, exposed by 3f's first override row. FIX: a shared `resolveTemplate(clientId,key)` (extracted from `write.server.ts` `loadTemplate`) used by BOTH the dispatcher AND the runner SMS branch (client-override→global precedence); runner renders `templateKey` → resolved template → `dripMergeVars` (incl. the per-contact tracked `review_link`); control-logic untouched. **Also confirm/seed the SMS body templates as global rows for every step `templateKey`** (may never have been seeded, since the runner never read them). Regression: re-run 2e TEST1–TEST5 + confirm A=override / B=global bodies, neither `[stub]`. At 1f this is what prevents transmitting `[stub] …` to real customers. **Plus a 1f render-completeness guard:** before any REAL transmission, assert the rendered body has NO residual `{…}` token (else fail/alert) — production must never ship a literal `{review_link}`/`{first_name}` (in stub mode a literal `{key}` is allowed as a visible diagnostic). Mirrored in `/launch-check` §B + §D + `automation-config` (runtime resolution).
- [PRE-FREEZE CLEANUP — Stage 3.5] Send-primitive extraction regression (from 3a): `sendStubSmsWithRetry` was extracted to `lib/sms/send.server.ts` and is now shared by the cron runner + the reply path. **In the pre-freeze cleanup:** re-run the 2e TEST1–TEST5 drip walks to confirm the runner's claim-lease / window-gating / caps / reschedule-without-advancing / advance-on-success / 2× retry are intact after the stub→shared-primitive extraction, AND confirm the primitive is SEND-ONLY (no DB writes / no cron-decision event-logging leaked in — else the reply path inherits it). Tracked as a checkbox in `/launch-check` §B.
- [STAGE 3.5 §A — SECURITY — RESOLVED/CLOSED; MECHANISM RECONCILED 2026-06-15 (introspection-backed)] `clients_anon_select_sensitive_fields` (= foundation open-item #2): anon had table-wide SELECT on `clients` → all 27 columns exposed. **AS-BUILT (RPC-only):** the SOLE anon public-read path is the **`public.get_client_public(slug)` RPC** — `SECURITY DEFINER`, `STABLE`, `SET search_path=public`, `EXECUTE` to anon (per `pg_proc.proacl`) — returning a **13-column projection** (`slug, business_name, tagline, phone_display, address, hours, license_number, logo_url, brand_color, service_area, social_links, template_vars, review_link`) with **`template_vars - 'notification_email'` stripped inline** and the **`status='active' AND deleted_at IS NULL` filter applied IN-BODY**. Base `public.clients` has **ZERO anon grants** (no column, no table) and **NO anon RLS policy** (all 4 policies authenticated-scoped via `is_admin()`/`user_client_ids()`) → **direct anon SELECT = 42501**. **There is NO `clients_public` view.** Sensitive cols never projected: `twilio_*`, `call_forwarding_number`, `email`, `notification_email`, `allowed_origins`. **F-pii (3g):** `notification_email` is a dedicated `clients` column, never in `template_vars`; the RPC defensively strips it from `template_vars`. Adversarial re-check passed (planted `notification_email` → anon read STRIPPED; direct read 42501). `resolveOwnerEmail()` = `notification_email ?? email`. *(The prior "security_invoker view + 13 anon column-grants + retained anon row policy" record was stale/wrong — RPC-only is cleaner + lint-fine: the linter flags SECURITY DEFINER VIEWS, not functions.)* `/launch-check` §A; see `stage-3.5a-security-validation.md`.
- [STAGE 3.5 §A — SECURITY, PULLED FORWARD to NOW, before 3d] `storage_objects_no_policies`: `storage.objects` has no RLS policies. FIX (per `scratch-foundation` §9): **public-assets** = public read; **client-assets** = client_id-scoped (`FOR ALL TO authenticated USING bucket_id='client-assets' AND (storage.foldername(name))[1]::uuid IN user_client_ids(...) OR is_admin(...)`; paths `{client_id}/…`; service-role for system uploads). Re-scan clears both findings; `audit_tenant_rls()`=0 after; also extend the RLS-audit to gate `clients`' own policies (RPC-only model: assert anon has NO direct `clients` base access — zero grants + no anon policy → 42501 — and the public read is via the `get_client_public` RPC's curated projection). `/launch-check` §A.
- [PRE-FREEZE CLEANUP — Stage 3.5] A dedicated cleanup stage runs AFTER the Stage-3 tabs and BEFORE the Stage-4 freeze, batching the deferred items so the frozen master is complete: **(0) the §A SECURITY fixes above — the `get_client_public` RPC (no view) + the two storage policies — PULLED FORWARD to NOW (before 3d), since they gate publish + the 3c cron walk + all downstream Stage-3 published testing**; (1) **audit_log** table (role-mutation audit — see the [BUILD — TODO] above); (2) **export-client** server fn / isolation guardrail 3 (see the [BUILD — TODO] above; `/launch-check` §A); (3) the **3a send-primitive regression re-test** (the bullet directly above; `/launch-check` §B). None are provider-dependent (so NOT 1f) — they're the pre-freeze finishing batch, all gated within `/launch-check` A–D. Genuinely provider-dependent work (real messaging-provider (TextGrid) swap, Turnstile/rate-limit, real-time reply-driven exits, the materialization status-swap) stays at 1f.
