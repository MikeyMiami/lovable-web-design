---
name: opt-in-forms
description: Use when building, modifying, or reviewing any FORM on a client site or app and how it feeds the automations — the mobile-app Review Request form, the public website lead form, the public discount-claim form, and the existing review-funnel pages. Defines each form's fields, validation, consent, the source tag it writes, and which sequence it enrolls into. NOT for the message copy of the resulting drips (use automation-config) or feature mechanics (use features).
---

# Opt-In Forms — forms → automations map

Every form, its fields, and exactly what it triggers. Phones normalized to E.164. Public forms insert contacts with a constrained `source` (per the tightened RLS — no wide-open anon inserts). Naming: `first_name`, `last_name`, `phone`, `email`, `your_message`, `full_name` (derived first+last for internal notifications).

---

## 1. Mobile-app "Review Request" form (client-facing)
- **Location:** the Review Request tab inside the client mobile app (`app.theirdomain.com`). Only the logged-in client/staff can access it.
- **Fields:** First Name, Last Name, Phone, Email.
- **Enrolls into:** the Review Request SMS Drip ONLY (one enrollment — email drip scrapped).
- **Caps/guards:** subject to the daily enrollment cap (default 50/day, overflow queues to next day). Runs the **re-enrollment guard** — if the contact (client_id + phone) is already enrolled in the review automation, block and show "contact already enrolled."
- **Downstream:** on review-drip completion the contact is auto-handed to the One-Year Follow-Up drip (unless opted out) — no form for that.

## 2. Public website Lead Form (customer-facing)
- **Location:** the main client website (quote/contact request).
- **Fields:** First Name, Last Name, Phone, Email, Your Message.
- **Source:** `web_form`.
- **Enrolls into:** the Website Lead-Form Drip. Branches on **Business Hours** (separate setting from the SMS Send Window): in-hours → typo + correction texts; after-hours → single after-hours text. Plus the day-10 owner reminder (with Auto-Enroll button) on both branches.

## 3. Public Discount-Claim form (customer-facing)
- **Location:** `{company_website_link}/get-your-discount` (destination of One-Year drip links).
- **Banner:** company name + logo; headline **"Get {discount_amount} with us!"**
- **Fields:** First Name, Last Name, Phone, Your Message.
- **Consent checkbox (required):** "I agree to [terms & conditions]({website_terms_page_link}) provided by the company. By providing my phone number, I agree to receive text messages from the business." The terms link points to the CLIENT's own terms page — never an external/leadconnector URL.
- **Button:** "Get My Discount!"
- **Source:** `web_form`.
- **Enrolls into:** the Discount-Claim Drip (immediate internal notification → 2-min wait → one SMS to lead → end).
- **Side effect [LOCKED]:** if the submitter is currently in the One-Year drip, the submission EXITS them from it (re-engagement). A form submit is distinct from a raw link click (which does not exit the one-year drip).

## 4. Existing public review-funnel pages
- `/r/rate` — star rating gate. ≥ star_threshold (or toggle `all`) → redirect to Google review link; below → `/r/feedback`.
- `/r/feedback` — private low-star feedback form → `review_feedback` + internal low-star email to client.
- `/r/enroll` — public self-enroll into the review reminder sequence (consent captured).
- The review drip's per-contact tracked link `/r/<token>` is the redirect that logs the click and sets `Review Completed` (built per the features skill).

---

## Build rules
- Public forms (2, 3, 4) use anon INSERT constrained to `source IN ('web_form','review_enroll')` — do not use wide-open `WITH CHECK (true)`.
- Consent: every form that collects a phone for texting must carry the SMS opt-in + terms language (already in the discount form; ensure the lead form and review-funnel enroll carry equivalent consent).
- Each form writes the contact scoped to the correct `client_id` and enrolls into the named sequence; nothing enrolls into a sequence the form isn't mapped to here.
- The mobile Review Request enrollment and the lead-form day-10 Auto-Enroll button share the same re-enrollment guard.
