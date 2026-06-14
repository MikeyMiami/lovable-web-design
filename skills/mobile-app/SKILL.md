---
name: mobile-app
description: Use when building, modifying, or reviewing the client-facing mobile app (the PWA at app.theirdomain.com) — its Conversations, Review Request, Notifications, and Dashboard tabs, the in-app notification records, the day-10 Auto-Enroll button, and the owner email notifications that accompany lead/discount events. NOT for the public website or admin dashboard (use admin-view) and NOT for the drip message copy itself (use automation-config).
---

# Mobile App — client PWA at `app.theirdomain.com`

Mobile-first installable PWA, scoped to the logged-in client's `client_id` via RLS. The business owner / staff (`client_owner`, `client_staff`) log in here; they see only their own client's data. Build four tabs.

**Bottom-nav DISPLAY labels (shorter, for mobile UX) ↔ canonical concept:** Inbox = Conversations (Tab 1) · Review = Review Request (Tab 2) · Alerts = Notifications (Tab 3) · Stats = Dashboard (Tab 4). The display labels are canonical for the UI; this doc uses the concept names below.

Formatting standard (applies to every notification + email here): stack details on separate lines — never cram "Name: X Phone: Y Message: Z" onto one line.

---

## Tab 1 — Conversations
SMS threads across all of this client's contacts (CRM). iMessage-style, mobile-first, newest first, status badges + relative time. Reply box sends an outbound SMS in the thread. (Exists at `/app`; keep/extend.)

## Tab 2 — Review Request
The client's enrollment form for the Review Request SMS drip.
- Fields: First Name, Last Name, Phone, Email.
- On submit → enroll the contact into the Review Request SMS drip (one enrollment; SMS-only).
- Subject to the **daily enrollment cap** (default 50/day; overflow queues to the next day).
- **Re-enrollment guard:** if the contact (client_id + phone) is already enrolled in the review automation, block and show "contact already enrolled."

## Tab 3 — Notifications
A simple feed of notification records for this client. **No read/unread tracking** — each notification is just a message filled with the relevant data. Records are written by automations as they fire (timings follow the drip specs). All are informational EXCEPT two that carry actions: the day-10 lead reminder (Auto-Enroll button) and the missed-call notification (Open-conversation deeplink).

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

**AI chat widget — new lead (§7e; chat-widget Request path, same lead-form drip; only this label differs):**
> New Lead from your Website AI chat!
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
Weekly + monthly stat counters, computed from `events` scoped to this client. Four counters:

> New Website Leads this week: {count}
> New Website Leads this month: {count}
> Review Link Clicks this week: {count}
> Review Link Clicks this month: {count}

- **New Website Leads** = count of contacts created with source `web_form` (lead form + discount form) in the period.
- **Review Link Clicks** = count of `review_clicked` events in the period (each = a contact landing on `/api/public/r/rate` via their tracked link). Renamed from "New Google Reviews" for accuracy, since landing ≠ a confirmed posted review.
- "This week" / "this month" computed in the client's timezone.

---

## Owner Email Notifications (accompany the in-app notifications)
When a lead-form or discount-form submission fires its in-app notification, ALSO send the owner an email pointing them to the app. The in-app notification still fires — the email is additive. **One email per lead** (after-hours is a body variant of the website-lead email, not a second email).

- **Channel:** Lovable NATIVE transactional email (owner account-activity notice = transactional). Sends from the client's verified sending subdomain; not the external marketing sender. Low volume, no warmup concern.
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

**Subject: New Website AI Chat Lead** (§7e chat-widget variant; same business-hours/after-hours branching as the website lead):
> Hey {company_owner_first_name},
>
> You've got a new lead from your website AI chat!
>
> Name: {full_name}
> Phone: {phone}
> Message: {your_message}
>
> We've already replied to them in the chat. Open your app to see the conversation.

---

## Build notes
- [BUILD] Notifications table (client_id, type, body, related contact_id, optional action {type, payload}, created_at) + automations writing to it + this UI reading it. No read/unread state.
- [BUILD] Auto-Enroll action wired to the Review Request enrollment path (with re-enrollment guard).
- [BUILD] Owner email notifications via Lovable native transactional email.
- Dashboard counters read `events`; no extra tracking tables needed.
- Ship as an installable PWA (manifest + service worker), client branding on icon/splash. PWA web-push is backlog, not v1 — owner emails cover the "alert me" need.
