---
name: admin-view
description: Use when building, modifying, or reviewing the admin dashboard on a client website — the agency/admin tabs and the per-client Settings fields. Defines which tabs exist and which configurable values must live in Settings. Use when adding or adjusting what is editable in the admin view. NOT for the client mobile app (use mobile-app).
---

# Admin View — tabs & settings on the client website

The admin dashboard lives at `/admin` on the client website, gated to `admin` / `agency_owner` roles (RLS-scoped). It is where the agency manages this client. Build/maintain these tabs.

## Tabs
- **Dashboard** (`/admin`) — KPIs (contacts in/out, sends, reviews) for the active client.
- **Contacts** (`/admin/contacts`) — CRM list + detail.
- **Conversations** (`/admin/conversations`) — full SMS/email inbox + threads.
- **Feedback** (`/admin/feedback`) — low-star private feedback submissions.
- **Automations** (`/admin/automations`) — edit message templates + sequence steps (the editable surface of the automation-config content).
- **Upload Customers** (`/admin/reactivation`) — CSV/paste reactivation uploader.
- **Settings** (`/admin/settings`) — client profile + config (below).

## Settings tab — required configurable values (per client)
- **Timezone** — drives all SMS send windows.
- **Send window** — default **09:00–19:00** in the client's timezone; applies to ALL SMS automation.
- **Daily SMS send cap** — customizable per client; max messages dispatched per day. Enforced in the cron runner.
- **Daily enrollment cap** — customizable per client, **default 50**; max NEW contacts entering the review drip per day. Overflow waits to the next day. Enforced at the enrollment path (mobile-app enroll fn + uploads). This is DISTINCT from the send cap — do not conflate them.
- **Business identity** — business_name, tagline, phone_display, email, address, hours, license_number, logo, brand_color.
- **Review config** — review_place_id, review_link, google_review_toggle (gated|all|off), star_threshold (default 4).
- **template_vars** — free-form per-client placeholder values. Must cover all custom keys referenced by templates; the required set today: `company_owner_first_name`, `company_name`, `review_request_link`, `discount__on_referral`, `company_website_link`, and `discount`. Surface missing keys to prompt the agency to fill them.
- **Messaging config** — twilio_number, twilio_messaging_service_sid, sending_subdomain, dkim_status.

## Notes
- `createClient` currently accepts only slug, business_name, phone_display, email; everything else is set here via `updateClientSettings` (or, for fields with no UI editor yet — hours, logo_url, brand_color, service_area, license_number, google_review_toggle, twilio_*, sending_subdomain, dkim_status, status — via direct SQL until editors are added). Adding editors for those is the natural extension of this skill.
- `brand_color` is stored as hex but is NOT yet wired into the oklch theme tokens — per-client theming requires injecting a converted oklch value into the shell head (see theme-to-brand, TBD).
- Caps and window are the ban-protection surface: a cap that is only a field does nothing — confirm the cron runner and enrollment path actually enforce these values.
