---
name: admin-view
description: Use when building, modifying, or reviewing the admin dashboard on a client website — the agency/admin tabs and the per-client Settings fields. Defines which tabs exist and which configurable values must live in Settings. Use when adding or adjusting what is editable in the admin view. NOT for the client mobile app (use mobile-app).
---

# Admin View — tabs & settings on the client website

The admin dashboard lives at `/admin` on the client website, gated to `admin` / `agency_owner` roles (RLS-scoped). It is where the agency manages this client. Build/maintain these tabs.

## Tabs
- **Dashboard** (`/admin`) — KPIs (contacts in/out, sends, reviews) for the active client.
- **Contacts** (`/admin/contacts`) — CRM list + detail.
- **Conversations** (`/admin/conversations`) — full SMS inbox + threads.
- **Feedback** (`/admin/feedback`) — low-star private feedback submissions.
- **Automations** (`/admin/automations`) — edit message templates + sequence steps (the editable surface of the automation-config content).
- **Upload Customers** (`/admin/reactivation`) — CSV/paste reactivation uploader.
- **Settings** (`/admin/settings`) — client profile + config (below).

## Settings tab — required configurable values (per client)
- **Timezone** — drives all SMS time windows.
- **SMS Send Window** — default **09:00–19:00** in the client's timezone. Applies to MARKETING/FOLLOW-UP SMS only (review drip, one-year drip, reactivation). Purpose: don't annoy past customers.
- **Business Hours** — a SEPARATE per-client window, distinct from the SMS Send Window. Applies to the LEAD-FORM drip only: decides whether a fresh website lead gets the live in-hours response (typo + correction texts) or the after-hours single message. Purpose: "is the owner reachable / open right now." Independent value from the marketing window. [BUILD — new field, and the lead-form handler must branch on it]
- **Daily SMS send cap** — customizable per client; max messages dispatched per day. Enforced in the cron runner.
- **Daily enrollment cap** — customizable per client, **default 50**; max NEW contacts entering the review drip per day. Overflow waits to the next day. Enforced at the enrollment path (mobile-app Review Request form/button + uploads). DISTINCT from the send cap — do not conflate.
- **Business identity** — business_name, tagline, phone_display, email, address, hours, license_number, logo, brand_color.
- **Review config** — review_place_id, review_link, star_threshold (default 4, inclusive ≥ — the Review Funnel gate), google_review_toggle (gated|all|off). Toggle meaning: `gated` = use the funnel (rate page → branch by threshold; default); `all` = send everyone straight to Google (no gate); `off` = no review redirect. The funnel logic in features assumes `gated`.
- **template_vars** — free-form per-client placeholder values. Must cover all custom keys referenced by templates. Required set today: `company_owner_first_name`, `company_name`, `review_request_link`, `discount__on_referral`, `company_website_link`, `discount_amount`, `website_terms_page_link`, `quote_form_link` (defaults to `{company_website_link}` lander; overridable here — the page hosting the quote form). Dynamic values (not template_vars, set at runtime): `caller_phone`, `call_time`, `request_time`, `message.body`, `feedback_message`, `email`. Surface missing keys to prompt the agency to fill them.
- **Messaging config** — twilio_number, twilio_messaging_service_sid, sending_subdomain, dkim_status.

## Notes
- `createClient` currently accepts only slug, business_name, phone_display, email; everything else is set here via `updateClientSettings` (or, for fields without a UI editor yet, via direct SQL until editors are added). Adding editors for those is the natural extension of this skill.
- `brand_color` is stored as hex but is NOT yet wired into the oklch theme tokens — per-client theming requires injecting a converted oklch value into the shell head (see theme-to-brand, TBD).
- Caps and windows are the ban-protection surface: a cap or window that is only a UI field does nothing — confirm the cron runner (send cap + SMS window) and the enrollment/lead-form paths (enrollment cap + Business Hours) actually enforce these values.
