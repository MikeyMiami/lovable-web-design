---
name: opt-in-forms
description: Use when building, modifying, or reviewing any FORM on a client site or app and how it feeds the automations — the mobile-app Review Request form, the public website lead form, the public discount-claim form, and the existing review-funnel pages. Defines each form's fields, validation, consent, the source tag it writes, and which sequence it enrolls into. NOT for the message copy of the resulting drips (use automation-config) or feature mechanics (use features).
---

# Opt-In Forms — forms → automations map

Every form, its fields, and exactly what it triggers. Phones normalized to E.164. Public forms insert contacts with a constrained `source` (per the tightened RLS — no wide-open anon inserts). Display field names: First Name, Last Name, Phone, Email, Your Message; `full_name` = derived first+last for internal notifications. **The exact WIRE payload each public route accepts — verified against the frozen backend — is in "Wire payloads" below; POST those keys, NOT the display names.**

## Wire payloads [LOCKED — verified against the frozen backend]
The public-write routes accept these EXACT keys (Zod-validated). **Never send `client_id`** — tenant is resolved server-side from Origin → `allowed_origins` (optional `slug` fallback). **Never send `source`** — it is server-set (`web_form`). **Phone is normalized CLIENT-SIDE to E.164 and sent as `phone_e164`** (regex `^\+[1-9]\d{6,14}$`).

- **Lead form → `POST /api/public/intake`:** `{ first_name, last_name?, phone_e164?, email?, notes?, turnstile_token }` — requires **`phone_e164` OR `email`**; the lead **message field is `notes`** (NOT `your_message`).
- **Discount form → `POST /api/public/discount`:** `{ first_name, last_name?, phone_e164, your_message?, consent, turnstile_token }` — **`phone_e164` is REQUIRED**; **`consent` is REQUIRED and must be `true`** (`discount.ts`: `consent: z.literal(true)`) — this is the **single required consent checkbox**, the ONLY consent field on either route (discount-only); the discount **message field is `your_message`** (stored to `contacts.notes` server-side).
- Both: `turnstile_token` (the Cloudflare token) is REQUIRED.

**[boundary] Field set vs consent copy:** `opt-in-forms` + the real route govern the **form field set + wire payload keys** (above); **`/a2p-site-compliance` §1.1/§C governs the consent COPY + two-checkbox structure**. Don't mix them — the a2p §C "Request Information" block shows consent copy, NOT the authoritative field set.

---

## 1. Mobile-app "Review Request" form (client-facing)
- **Location:** the Review Request tab inside the client mobile app (`app.theirdomain.com`). Only the logged-in client/staff can access it.
- **Fields:** First Name, Last Name, Phone, Email.
- **Enrolls into:** the Review Request SMS Drip ONLY (one enrollment — email drip scrapped).
- **Caps/guards:** subject to the daily enrollment cap (default 50/day, overflow queues to next day). Runs the **re-enrollment guard** — if the contact (client_id + phone) is already enrolled in the review automation, block and show "contact already enrolled."
- **Downstream:** on review-drip completion the contact is auto-handed to the One-Year Follow-Up drip (unless opted out) — no form for that.

## 2. Public website Lead Form (customer-facing)
- **Location:** the main client website (quote/contact request).
- **Fields:** First Name, Last Name, Phone, Email, Your Message. (Wire payload → `/api/public/intake` per **Wire payloads** above: `phone_e164`, message = `notes`.)
- **Consent [see `/a2p-site-compliance` §1.1]:** the **two-checkbox** a2p opt-in surface (customer_care + marketing), both **unchecked + NOT required** (form submits without them) — **display-only** (`intake.ts` has NO consent field).
- **Source:** `web_form`.
- **Enrolls into:** the Website Lead-Form Drip. Branches on **Business Hours** (separate setting from the SMS Send Window): in-hours → single SMS#1 (correctly spelled); after-hours → single after-hours text. Plus the day-10 owner reminder (with Auto-Enroll button) on both branches.

## 3. Public Discount-Claim form (customer-facing)
- **Location:** `{company_website_link}/get-your-discount` (destination of One-Year drip links).
- **Banner:** company name + logo; headline **"Get {discount_amount} with us!"**
- **Fields:** First Name, Last Name, Phone, Your Message. (Wire payload → `/api/public/discount` per **Wire payloads** above: `phone_e164` REQUIRED, message = `your_message`.)
- **Consent [LOCKED — SINGLE required checkbox; discount-only]:** the discount form uses a **single, REQUIRED** consent checkbox that **gates submission** (the form does NOT submit without it) and produces **`consent: true`** in the payload (`discount.ts` requires `consent: z.literal(true)`). The checkbox carries the SMS-consent + terms language and links to the CLIENT's on-site `/terms` + `/privacy` (never an external/leadconnector URL). This is a **transactional value-exchange opt-in** (claim the discount in return for texts) — **distinct from the lead form's two-checkbox optional surface (§2)**, and NOT the a2p §1.1 two-checkbox model (which is the lead/contact form).
- **Button:** "Get My Discount!"
- **Source:** `web_form`.
- **Enrolls into:** the Discount-Claim Drip (immediate internal notification → 2-min wait → one SMS to lead → end).
- **Side effect [LOCKED]:** if the submitter is currently in the One-Year drip, the submission EXITS them from it (re-engagement). A form submit is distinct from a raw link click (which does not exit the one-year drip).

## 3b. AI Chat Widget opt-in (customer-facing) [LOCKED — see /chat-widget skill]
- **Location:** corner AI chat widget on the client's main website.
- **Opt-in gate:** before chatting, collects First Name, Last Name, Email, Phone, message/question — with SMS opt-in + terms consent (phone collected for texting).
- **Source:** `chat_widget` (distinct from `web_form`, so chat leads are attributable).
- **Request path → same as the website lead form:** enrolls into the Lead-Form drip (§7) with identical automations; the ONLY difference is the owner notification reads "New Website AI Chat Lead."
- **FAQ path:** AI answers business/service questions from onboarding + site data; pricing/quote questions are redirected to submit a request. (AI behavior detailed in the /chat-widget skill; knowledge inputs depend on the onboarding form.)

## 4. Public review-funnel pages [LOCKED]
Destination of BOTH the review-drip tracked link and the reactivation link. Landing on `/api/public/r/rate` (via `/api/public/r/<token>`) writes a `review_clicked` event and EXITS the contact from the review drip; status + one-year handoff are set by the star selection. **These routes (`/api/public/r/<token>`, `/api/public/r/rate`, `/api/public/r/feedback`) are served by the SHARED BACKEND domain** (they write to the DB) — NOT the frontend-only client marketing site.
- `/api/public/r/rate` — "How would you rate us?" + 1–5 star choice. Threshold = `star_threshold` (default 4, inclusive ≥).
  - ≥ threshold → status `Review Completed` → redirect to the client's Google review page → enroll into One-Year drip.
  - < threshold → status `Negative Review` → `/api/public/r/feedback`. Does NOT enroll into One-Year.
- `/api/public/r/feedback` — below-threshold private feedback. Collects **Name, Email, Feedback**; **phone auto-fills** from the mapped contact. Stores in `review_feedback` → fires owner email ("We Saved You From a Negative Review") + mobile notification → shows the "sorry we missed the mark" confirmation screen. No SMS consent needed (not a texting opt-in).
- `/api/public/r/enroll` — REMOVED. Review enrollment happens via the mobile-app Review Request form (#1), not public self-enroll.

---

## Build rules
- Public forms (2, 3, 4) POST to server functions (`supabaseAdmin` + Zod; `client_id` from the public slug; `source` set server-side). Routes return CORS headers (per-client domain allowlist + OPTIONS) and apply rate-limiting + Turnstile/hCaptcha. NO anon INSERT policies; anon is SELECT-only on `clients` public columns. (CORS/allowlist/bot-protection mechanism lives in `/scratch-foundation`.)
- Consent [ASYMMETRIC — matches the frozen routes]: **Lead form (§2 → `intake`)** = the **two-checkbox** a2p opt-in surface (customer_care + marketing), both **optional / display-only** — `intake.ts` has **NO consent field**; copy + structure authoritative in `/a2p-site-compliance` §1.1. **Discount form (§3 → `discount`)** = a **single REQUIRED** consent checkbox that gates submission + sends **`consent: true`** (`discount.ts` requires it) — a transactional opt-in, NOT the two-checkbox surface. `/api/public/r/feedback` needs no SMS consent (feedback only, not a texting opt-in). `/api/public/r/enroll` is removed.
- Each form writes the contact scoped to the correct `client_id` and enrolls into the named sequence; nothing enrolls into a sequence the form isn't mapped to here.
- The mobile Review Request enrollment and the lead-form day-10 Auto-Enroll button share the same re-enrollment guard.
