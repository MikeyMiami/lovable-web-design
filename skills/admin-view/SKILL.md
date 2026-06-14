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
- **Automations** (`/admin/automations`) — edit message templates + sequence steps (the editable surface of the automation-config content). Each drip also shows a **live count of contacts currently enrolled** (active) in it — read from `enrollments WHERE status='active'` grouped by `sequence_key`. Gives at-a-glance visibility into what's running per drip. [BUILD — new]
- **Upload Customers** (`/admin/reactivation`) — CSV/paste uploader that feeds the **Customer Review Reactivation drip** specifically (normalize phones → dedupe → enroll, with the reactivation caps: 50/day + 2/20min). Shows the current reactivation enrollment count + how many remain queued from an upload.
- **Settings** (`/admin/settings`) — client profile + config (below).

## Settings tab — required configurable values (per client)
- **Timezone** — drives all SMS time windows.
- **SMS Send Window** — default **09:00–19:00** in the client's timezone. Applies to MARKETING/FOLLOW-UP SMS only (review drip, one-year drip, reactivation). Purpose: don't annoy past customers.
- **Business Hours** — a SEPARATE per-client window, distinct from the SMS Send Window. Applies to the LEAD-FORM drip only: decides whether a fresh website lead gets the live in-hours response (single SMS#1) or the after-hours single message. Purpose: "is the owner reachable / open right now." Independent value from the marketing window. [BUILD — new field, and the lead-form handler must branch on it]
- **Daily SMS send cap** — customizable per client; max messages dispatched per day. Enforced in the cron runner.
- **Daily enrollment cap** — customizable per client, **default 50**; max NEW contacts entering the review drip per day. Overflow waits to the next day. Enforced at the enrollment path (mobile-app Review Request form/button + uploads). DISTINCT from the send cap — do not conflate.
- **Business identity** — business_name, tagline, phone_display, email, address, hours, license_number, logo_url, brand_color.
- **Review config** — review_place_id, review_link, star_threshold (default 4, inclusive ≥ — the Review Funnel gate), google_review_toggle (enum `review_gate_mode`: gated|direct). Toggle meaning: `gated` = use the funnel (rate page → branch by threshold; default); `direct` = skip the funnel, send everyone straight to the Google review page (no gate). The funnel logic in features applies in `gated` mode; `direct` bypasses `/api/public/r/rate`. (DB enum is 2-mode `{gated, direct}` — no separate "off"; to suppress review prompts, just don't enroll contacts.)
- **template_vars** — free-form per-client placeholder values. Must cover all custom keys referenced by templates. Required set today: `company_owner_first_name`, `company_name`, `review_request_link`, `discount__on_referral`, `company_website_link`, `discount_amount`, `website_terms_page_link`, `quote_form_link` (defaults to `{company_website_link}` lander; overridable here — the page hosting the quote form). Dynamic values (not template_vars, set at runtime): `caller_phone`, `call_time`, `request_time`, `message.body`, `feedback_message`, `email`. Surface missing keys to prompt the agency to fill them.
- **Messaging config** — twilio_number, twilio_messaging_service_sid, call_forwarding_number (the client's real phone the Twilio number rings through to; editable per client over time). These per-client Twilio values are NON-secret (From + Messaging Service SID, under ONE parent account). The Twilio auth token is a single platform runtime secret, never per client. (BYO-Twilio per-client creds = Option 2, future, in a server-only `client_secrets` store — not here.) `sending_subdomain`/`dkim_status` are **NOT created in v1** (deferred; `ADD COLUMN` later only if per-client email is built): owner notifications send from ONE platform-level agency sender (see Email below), not per-client domains.
- **Email sender (platform-level, NOT per-client)** — owner notifications send from ONE verified agency domain (e.g. `notify@myagency.com`) with a display name; there is no per-client sending identity in v1 (all emails go to business owners, not their customers, so per-client DKIM isn't needed). Per-client only sets the **notification recipient email** (below).
  - **Single-source rule [LOCKED]:** the Twilio number is stored ONCE (on the `clients` row) and everything that displays or uses it READS from that single source — the marketing site (header/contact/footer, via a merge value), all SMS automations, and missed-call detection. Changing `twilio_number` in admin updates everywhere on-site + in automations automatically; never hardcode the number into a page. External placements (Google Business Profile, printed business cards) are set manually outside the system and are NOT auto-updated.
- **Notification recipient email** — the email address owner notifications are sent to. Defaults to the onboarding `clients.email`; editable here in case the owner wants alerts at a different address. [BUILD — surfaced field]
- **Marketing domain(s) / allowed origins** — agency-set; the client's site domain(s); powers the public-write CORS allowlist (see opt-in-forms / scratch-foundation).

## Notes
- **All onboarding values are surfaced + editable here [LOCKED]:** every field captured by `/onboard-from-form` (business identity, review config, template_vars, timezone, site_style, social_links, Twilio/forwarding, marketing domains, notification email, hours/business hours, service areas, discounts) must have an editor in Settings so the agency can review/adjust anything that was prefilled from onboarding. No onboarding-captured value should be invisible or uneditable in admin.
- `createClient` currently accepts only slug, business_name, phone_display, email; everything else is set here via `updateClientSettings` (or, for fields without a UI editor yet, via direct SQL until editors are added). Adding editors for those is the natural extension of this skill.
- `brand_color` is stored as hex but is NOT yet wired into the oklch theme tokens — per-client theming requires injecting a converted oklch value into the shell head (handled by the design layer, `/website-structure` §9c, which absorbed the retired `/theme-to-brand`).
- Caps and windows are the ban-protection surface: a cap or window that is only a UI field does nothing — confirm the cron runner (send cap + SMS window) and the enrollment/lead-form paths (enrollment cap + Business Hours) actually enforce these values.
