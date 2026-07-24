---
name: mobile-app
description: Use when building, modifying, or reviewing the client-facing mobile app (the PWA — served today from the SHARED origin app.pierceworks.co; per-client app.theirdomain.com subdomains are not built yet) — its Conversations, Review Request, Notifications, and Dashboard tabs, the in-app notification records, the day-10 Auto-Enroll button, and the owner email notifications that accompany lead/discount events. NOT for the public website or admin dashboard (use admin-view) and NOT for the drip message copy itself (use automation-config).
---

# Mobile App — client PWA (shared origin `app.pierceworks.co` today; per-client `app.theirdomain.com` not yet built)

Mobile-first installable PWA, scoped to the logged-in client's `client_id` via RLS. The business owner / staff (`client_owner`, `client_staff`) log in here; they see only their own client's data. Surfaces are arranged per the **B-design nav model** (see *Navigation shell + payment gate* below).

**Role model + access gate.** The client logs in as `client_owner` (provisioned via `provisionClientOwner` — see scratch-foundation §5; `client_staff` is owner-invited later).

**How the owner FIRST gets in [BUILT 2026-07-23 — read this before touching auth]:** Finalize & Activate creates their login **silently with no password and sends nothing**. At LAUNCH the agency clicks **Send Client Welcome** (`/admin/review` — see `/admin-view`), which emails three links: their website · **set a password** (`app.pierceworks.co/set-password?token_hash=…&type=recovery&c=…`) · **download the app** (`/download?c=…`). The **`/set-password`** route establishes the recovery session (hash-session OR `token_hash` → `supabase.auth.verifyOtp`), takes a new password via `updateUser({password})`, then forwards to **`/download`**. Only after that do they have a durable password for `/login`. **`/download` gates install behind sign-in**, which is exactly why the email's link order is website → set password → download. There is NO self-serve "Forgot password?" on `/login` yet — a locked-out client is recovered by the agency re-sending the welcome email (each re-send mints a fresh single-use link and kills the previous one). This PWA is the ONLY surface the payment-access gate suspends: a non-paying client's `access_suspended` flag blocks the client PWA shell only — it never touches `status`/`deleted_at`, so automations keep running. The agency surfaces (agency account + per-client admin view) are agency-scoped (`admin`/`agency_owner`) and are NEVER payment-gated.

**Navigation model [BUILT — B-design Slice 2a, 2026-06-20]:** **Stats (Dashboard) = Home** — the app lands on Stats at `/app`; Stats is NOT a bottom-nav tab. **Bottom nav = 3 tabs:** Inbox (Conversations) · Review (Review Request) · Alerts (Notifications). **Top-right hamburger (☰) menu:** Account (read-only) · Request an Edit · Support. **Top-left back arrow** on every non-Home view → returns to Stats Home. (The concept names — Conversations / Review Request / Notifications / Dashboard — are used throughout this doc; the nav labels above are canonical for the UI.)

Formatting standard (applies to every notification + email here): stack details on separate lines — never cram "Name: X Phone: Y Message: Z" onto one line.

---

## Tab 1 — Conversations
SMS threads across all of this client's contacts (CRM). iMessage-style, mobile-first, newest first, status badges + relative time. Reply box sends an outbound SMS in the thread. (`app.inbox.tsx`.) **iPhone-style upgrade 2026-07-14:** the conversation list shows a **last-message text preview** per row (embedded latest message; outbound prefixed "You:"), an **unread dot + bold name** on conversations whose latest message is inbound and newer than last-open, and a **count badge on the Inbox/MessageSquare bottom-nav tab** — all via per-device localStorage `msg_last_read` (map conversationId→ISO; NO DB read/unread column), cleared on opening the thread. Same localStorage/badge pattern as the Alerts unread badge (`use-unread`).

## Tab 2 — Review Request
The client's enrollment form for the Review Request SMS drip.
- Fields: First Name, Last Name, Phone. (Email field REMOVED 2026-07-14 — SMS/phone-only.)
- On submit → enroll the contact into the Review Request SMS drip (one enrollment; SMS-only).
- Subject to the **daily enrollment cap** (default 50/day; overflow queues to the next day).
- **Re-enrollment guard:** if the contact (client_id + phone) is already enrolled in the review automation, block and show "contact already enrolled."

## Tab 3 — Notifications
A simple feed of notification records for this client. **Unread badge added 2026-07-14** (per-device localStorage `alerts_last_seen` marker — the Bell tab shows an unread count pill, Home shows an "N new alerts" banner, and opening the Alerts tab marks seen; no DB read/unread column). Each notification is just a message filled with the relevant data. Records are written by automations as they fire (timings follow the drip specs). All are informational EXCEPT two that carry actions: the day-10 lead reminder (Auto-Enroll button) and the missed-call notification (Open-conversation deeplink).

- **Click-to-call:** render every phone number as a `tel:` link so the owner can tap to call directly.
- **Day-10 lead reminder — actionable:** includes an **Auto-Enroll button** that enrolls the contact into the Review Request drip directly (no manual form entry). It runs the same re-enrollment guard — if already enrolled, it shows "contact already enrolled" instead of enrolling. Suppress the whole reminder if the lead's phone is already in the review automation.

Notification copy (sources: review drip §4, one-year §5, lead-form §7, discount §7b — reproduced here line-broken; copy is canonical in automation-config / spec):

**Review drip — final (day-48h, not clicked):**
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

**One-year — interest (on any reply, then remove from drip):**
> Hey {company_owner_first_name},
>
> {first_name} just replied to your return/referral discount offer in the 1-year follow-up sequence!
>
> Their response: {message.body}
>
> You can reach them at {phone} if needed.
>
> (Do NOT reply to this message; it's not the client!)

**One-year — 3-month status (after SMS 2):**
> {company_owner_first_name}, it's been 3 months since you added {first_name} into your 1-year follow-up sequence.
>
> We just sent them a discount offer to ask for referrals!
>
> Their number is {phone} if you want to reach out / or they contact you.
>
> (Do NOT reply to this message; it's not the client!)

**One-year — final removal (after SMS 5):**
> Hey {company_owner_first_name}!
>
> It's been about a year since we added {first_name} to your 1-year follow-up sequence for referrals / return-customer discounts. We're removing them from further follow-up.
>
> If you'd like to contact them for a referral or to see if they'd use your service again, reach them at {phone}.
>
> (Do NOT reply to this message; it's not the client!)

**Lead-form — new lead (both branches):**
> New Lead from Website lead-form!
>
> Name: {full_name}
> Phone: {phone}
> Message: {your_message}
>
> We've let them know you'll be in touch soon.
>
> (Do NOT reply to this message; it's not the client!)

**Lead-form — after-hours owner notice (Branch B):**
> Hey {company_owner_first_name}!
>
> {full_name} submitted a request on your website at {request_time} — outside your business hours, so we sent them an after-hours reply.
>
> Phone: {phone}
>
> Reach out when you're back.
>
> (Do NOT reply to this message; it's not the client!)

**Website Chat widget — new lead (§7e; CAPTURE-FIRST chat widget → same lead-form drip; only this label differs. Renamed from "AI chat" 2026-07-16 — the widget is a lead form in a chat skin, no AI):**
> New Website Chat Lead
>
> Name: {full_name}
> Phone: {phone}
> Message: {your_message}
>
> We've already replied to them in the chat.
>
> (Do NOT reply to this message; it's not the client!)

**Lead-form — day-10 reminder (BOTH branches; suppress if already in review automation; has Auto-Enroll button):**
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

**Discount form — new discount lead:**
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

**Missed-call textback — fires with SMS #1 (actionable: Open-conversation deeplink):**
> You missed a call from {caller_phone} at {call_time}, so we sent them a text.
>
> View the conversation here: [Open conversation button]

The Open-conversation button deep-links to that contact's thread in the Conversations tab. {caller_phone}/{call_time} are dynamic (client tz); a brand-new caller has no name yet.

**Negative review feedback — fires when a contact submits `/api/public/r/feedback` (below threshold):**
> We just saved you from getting a bad Google review. You can read about this customer's experience here:
>
> Name: {full_name}
> Email: {email}
> Phone: {phone}
> Message: {feedback_message}

(This contact is marked `Negative Review` and is NOT enrolled in the One-Year drip. Same content also sent as an owner email, subject "We Saved You From a Negative Review.")

**Review reactivation click — fires when a reactivation contact clicks the review link (show only fields present):**
> {company_owner_first_name}, you just got a review link click from your Customer Review Reactivation campaign!
>
> Customer Info:
> Name: {full_name}
> Phone: {phone}
> Email: {email}

## Tab 4 — Dashboard
Client-scoped (RLS) stat displays, computed in the client's timezone. **REDESIGNED 2026-07-14 — month-focused + display-styled (no longer a 6-counter week/month grid):** three metrics — (a) **New Reviews this month** as a large bold-black hero number, (b) **Missed Calls Texted Back** as a distinct bold-number card, (c) **Website Leads this month** as a card with a relevant icon (colored-circle swapped out). The prior "this week" variants, the graph, and the small circle mini-cards were REMOVED. Data SOURCES unchanged (chat-widget source + `review_clicked` event still exist; only the display changed):

> New Reviews this month: {count}            — large bold-black hero number
> Missed Calls Texted Back this month: {count}  — distinct bold-number card
> Website Leads this month: {count}           — card with a relevant icon (not a colored circle)

- **Website Leads** = count of contacts with source `web_form` in the period (the public website lead form + the discount-claim form — both use `web_form`).
- **Missed Calls Texted Back** = count of `missed_call` events in the period (each `missed_call` event = a missed call that fired the textback flow). *(Added 2026-07-14, replacing Chat Leads.)*
- **New Reviews** = count of `review_completed` events in the period — a positive review-gate submission (rating ≥ `star_threshold`, or the direct-toggle path) that was **redirected to Google**. This is the proxy for a posted review (no Google API), and is more meaningful than counting `review_clicked` landings. *(Changed 2026-07-14 from "Review Link Clicks"/`review_clicked`.)*
- Website Leads reads `contacts` (source=`web_form`); Missed Calls Texted Back + New Reviews read `events` (`missed_call` / `review_completed`). "This week" / "this month" boundaries are computed in the client's timezone.
- *(Not counted as lead channels: `mobile_enroll` (owner-entered review requests) + `reactivation` (bulk uploads) — not inbound website/chat leads. Discount-form submissions currently fold into Website Leads via `web_form`; splitting them out would need a distinct `discount_form` source — decided 2026-06-14: fold into Website Leads; revisit only on client demand.)*

---

## Navigation shell + payment gate [BUILT — B-design Slice 2a, 2026-06-20]
- **Shell** (`src/routes/_authenticated/app.tsx`): Stats=Home, 3-tab bottom nav, ☰ menu (Sheet) with Account/Edit/Support, back-arrow on non-Home views. Dashboard relocated to `app.index.tsx` (Home); Conversations relocated to `app.inbox.tsx`; the Notifications `open_conversation` deep-link repointed → `/app/inbox`.
- **Payment-gate intercept** (in the shell): reads `access_suspended` from the RLS-scoped `clients` row; when `true`, renders ONLY a full-screen message ("There was an issue with your payment method. Please correct to regain access to your mobile app.") — bottom nav + ☰ hidden — instead of the app. Verified **TOTAL** (toggling `clients.access_suspended` flips access; agency/admin surfaces never gated). Fixed string for v1.

## Account · Request an Edit · Support [BUILT — B-design Slice 2b, 2026-06-20]
- **Account (☰) — SIMPLIFIED 2026-07-14:** `app.account.tsx` now shows ONLY (1) the **business name** with a **subscription-tier pill** in the top-right (Starter/Growth/Pro, mapped from `clients.tier` `"297"`/`"397"`/`"749"` cheapest→priciest via `TIER_LABEL` in `src/lib/entitlements.ts`; null/empty = no pill), (2) an editable **"Notifications"** section (alert email input + on/off Switch, saved via `updateOwnerNotificationSettings` → `clients.notification_email` + `email_notifications_enabled`), and (3) the **"Request a change"** deep-link to Request-an-Edit. ALL other identity/branding/links fields were REMOVED from this page (still viewable in admin-view). `notification_email` + `email_notifications_enabled` are the only client-self-editable fields. *(Cosmetic: empty `hours` renders as `{}` — fix to em-dash; logged, non-blocking.)*
- **Request an Edit (Feature A) + Support (Feature B):** a shared **`TicketSurface`** component (exported from `app.support.tsx`, consumed by `app.edit.tsx` with `kind='edit_request'`): ticket list (status badge, 15s poll) + composer + bubble thread (10s poll, `sender_side` alignment) + resolution banner + a `resolved`/`closed` history filter. Reads via the RLS-scoped browser `supabase`; **writes via the Slice-1 service-role fns** (`openTicket` / `postClientMessage` / `recordTicketAttachment`). Attachments: client uploads to `client-assets` at `<client_id>/tickets/<ticket_id>/<uuid>-<file>` via **`src/lib/tickets/ticket-upload.ts`** (NOT `*.client.*` — Lovable's SSR build strips `*.client.*` files from the server bundle), then registers via `recordTicketAttachment`; downloads via **signed URL** (the bucket is private). **Storage caps [set 2026-06-20]:** bucket `file_size_limit = 25 MB`; **MIME enforced at the app layer** (the helper + `recordTicketAttachment`), NOT a bucket-wide MIME list (which would break existing logo uploads).
- **`open_ticket` notification action:** the Notifications/Alerts feed renders an "Open" deep-link for `action.open_ticket` (→ the Edit/Support thread by `kind`), alongside the existing `auto_enroll` / `open_conversation` actions. Written by `notify.server.ts` on agency reply / status change (in-app notification + owner-email stub).
- **Agency side** (admin reply / approve / deny via `postAgencyReply` / `setTicketStatus`) = the per-client **admin-view** surfaces (see `admin-view`; B-design Prompt 3). The client surfaces here consume what the agency writes.

## Owner Email Notifications (accompany the in-app notifications)
**IMPLEMENTED via Resend 2026-07-14:** EVERY in-app notification ALSO emails the owner the same content (`sendOwnerEmail` called from `writeNotification`; from `alerts@notif.pierceworks.co`; fail-open — never breaks the in-app write). Recipient = `clients.notification_email`; GATED by `clients.email_notifications_enabled` (owner toggles both in Account → Notifications; operator in Admin · Settings). Logs an `owner_email_sent` event on success. (Originally spec'd as lead/discount-only via Lovable native email — superseded: now every type, via Resend.) See [[reference-owner-notifications]].

- **Channel:** **Resend** (owner account-activity notice = transactional), from the SINGLE agency sender **`alerts@notif.pierceworks.co`** — NOT Lovable-native email and NOT a per-client verified sending subdomain (that framing was superseded 2026-07-14; matches the §188 / §250 build notes). Low volume, no warmup concern.
- Phone displays as text in email (click-to-call only exists in-app).

**Subject: New Website Lead** (business hours):
> Hey {company_owner_first_name},
>
> You've got a new lead from your website form!
>
> Name: {full_name}
> Phone: {phone}
> Message: {your_message}
>
> We've already texted them to say you'll be in touch. Open your app to see the conversation.

**Subject: New Website Lead** (after hours):
> Hey {company_owner_first_name},
>
> You've got a new lead from your website form — submitted at {request_time}, outside your business hours, so we sent them an after-hours reply.
>
> Name: {full_name}
> Phone: {phone}
> Message: {your_message}
>
> Open your app and reach out when you're back.

**Subject: New Referral/Discount Lead:**
> Hey {company_owner_first_name},
>
> {first_name} just filled out your discount form!
>
> Name: {full_name}
> Phone: {phone}
> Message: {your_message}
>
> We've told them you'll be reaching out soon. Open your app to see the details.

**Subject: New Website Chat Lead** (§7e capture-first chat-widget variant; same business-hours/after-hours branching as the website lead; renamed from "AI Chat" 2026-07-16):
> Hey {company_owner_first_name},
>
> You've got a new lead from your website chat!
>
> Name: {full_name}
> Phone: {phone}
> Message: {your_message}
>
> We've already replied to them in the chat. Open your app to see the conversation.

---

## Per-client branding [BACKLOG]
Each client's mobile app is **branded to their business** — their logo shown in-app, and the app's colors match their brand — so the white-label identity is consistent across the marketing site AND the app. **ONE branding source, two consumers** (set once in `/admin-view` branding → flows to both). **Origin caveat [current]:** the PWA is served from the SHARED origin **`app.pierceworks.co`** today (per-client `app.theirdomain.com` subdomains are not built), so iOS **"Add to Home Screen" shows the shared origin name** — not the client's business name — until per-client subdomains ship; in-app theming/logo is unaffected.

- **Source = the same as the marketing site:** the app reads the client's branding from the existing **`get_client_public` projection** — `brand_color` (primary) + `template_vars.brand_secondary` / `template_vars.brand_tertiary` + `logo_url` — the SAME projection the marketing template already consumes. **NO new branding model, NO new backend/schema change** — branding already lives in `clients` + `template_vars` and is already projected.
- **In-app theming:** reuse the **hex→oklch token injection already proven in the marketing template** — port it, don't reinvent. Primary = `brand_color`; secondary/tertiary = the `template_vars` keys.
- **Logo:** render in-app with the SAME text-render `business_name` fallback when `logo_url` is empty.
- **[FLAG — open scope decision, resolve at build time] App icon + store listing:** in-app theming (screen colors, logo on screens) is **dynamic from data and easy**. BUT the **app icon** (home-screen) + the **App Store / Play Store listing** are **baked at submission/build time, NOT dynamic**. So per-client app icons force a choice: **(a)** per-client app builds/submissions (heavy — one app per client in each store) vs **(b)** a single agency-branded app, client-branded INSIDE (light — one store listing, dynamic in-app branding, generic icon). Decide (a) vs (b) when the mobile app is built; **in-app theming is unaffected either way.** (Relates to the Build-notes "client branding on icon/splash" line.)

## Build notes
- [BUILD] Notifications table (client_id, type, body, related contact_id, optional action {type, payload}, created_at) + automations writing to it + this UI reading it. No read/unread state.
- [BUILD] Auto-Enroll action wired to the Review Request enrollment path (with re-enrollment guard).
- [DONE 2026-07-14] Owner email notifications via **Resend** (not Lovable native) — every notification emails the owner (`sendOwnerEmail`), gated by `clients.email_notifications_enabled`, from `alerts@notif.pierceworks.co`.
- Dashboard counters read `events`; no extra tracking tables needed.
- Ship as an installable PWA (manifest + service worker), client branding on icon/splash. PWA web-push is backlog, not v1 — owner emails cover the "alert me" need.
