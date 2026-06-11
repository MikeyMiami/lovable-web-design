---
name: onboard-from-form
description: Use when capturing a new client's onboarding data into the shared backend — taking the owner-filled onboarding form (§9b) plus agency-set config and writing it to the right places (clients columns, template_vars, send_settings, storage buckets, the AI-knowledge bundle). Run during per-client launch, after the foundation exists. Defines the field→destination mapping. NOT the design/site build (website-structure) and NOT the orchestration (new-client-site).
---

# Onboard From Form — capture client data into the shared backend

Takes the §9b onboarding inputs (owner-filled + agency-set) and writes them into the ONE shared backend as a new `clients` row + related config. This is data capture/mapping, not site generation. Every write is server-side (admin client); the owner never writes directly to the DB.

**Built vs used:** the onboarding **wizard UI is BUILT once in Stage 3** (alongside `/admin-view`); it is **USED per-client at Stage 5** (launch) to capture each new client. The field→destination mapping below is the contract for both.

## Two input layers (§9b)
- **Owner-filled** — the onboarding form the business owner completes (content + brand).
- **Agency-set** — config you set during setup (review link, Twilio, domains, etc.).

## Field → destination mapping

### Owner-filled → where it lands
| Onboarding field | Destination |
|---|---|
| Full Name (req) | derive `template_vars.company_owner_first_name` (first token of full name) |
| Business Phone | `clients.call_forwarding_number` (their real phone / lead-notify target) |
| Official Business Name (req) | `clients.business_name` + `template_vars.company_name` |
| Tax ID / EIN | AGENCY-OPS ONLY — captured on the form, used by the agency for A2P registration (a manual Twilio process); NOT stored in the app DB (no feature reads it; no column). |
| Current website link | `template_vars.company_website_link` + AI-knowledge source |
| About Us (3–5 sentences, req) | site copy + AI-knowledge |
| Top location + service areas (MAX 14) | `clients.service_area` (text[]) + site copy + AI-knowledge |
| All services offered (req) | site copy + **AI chat-widget knowledge** |
| Special things / differentiators | site copy + AI-knowledge |
| Hours of operation (req) | site + `send_settings.business_hours` (lead-form branching, §7) |
| Social links (IG/FB/BBB/TikTok/Yelp, if applicable) | `clients.social_links` jsonb **[ADD column]** ({instagram, facebook, bbb, tiktok, yelp}; missing keys simply absent) → site footer/contact |
| Full shipping address (req, no PO box) | AGENCY-OPS ONLY — used to mail business cards; NOT stored in the app DB (distinct from `clients.address`, which is the display address; no feature reads shipping). |
| Return/referral discounts | `template_vars.discount__on_referral` + `template_vars.discount_amount` |
| Logo (upload or request) + "need a logo?" flag | `public-assets` bucket → `clients.logo_url`; flag noted for agency |
| Timezone (EST/CST/MST/PST/Honolulu) | `send_settings.timezone` (NOT on clients) |
| Site style choice (1 of 4) | `clients.site_style` (corporate\|standard\|family_owned\|owner_operated) — drives `/website-structure` |
| Photos (25–60 + team/owner photo), **categorized: work examples / per-service examples / staff** | `public-assets` (public) / `client-assets` (private) under structured paths `{client_id}/work-examples/…`, `{client_id}/services/{service_slug}/…`, `{client_id}/staff/…` → write an **asset manifest** (`template_vars.site_assets`) so the site knows what exists; **missing categories fall back to pre-approved niche-default images** bundled in the template. Forward spec: `docs/client-onboarding-process.md` + `/template-builder`. |
| Consent (terms + SMS opt-in) | recorded; basis for contact consent |

### Agency-set → where it lands
| Config | Destination |
|---|---|
| Google review link + Place ID | `clients.review_link`, `clients.review_place_id` (agency grabs from GBP; setup task if none yet) |
| Star threshold (default 4) | `clients.star_threshold` |
| Google review toggle | `clients.google_review_toggle` (default `gated`) |
| Terms page (A2P-compliant, hosted) | generated (§9b.C) → `template_vars.website_terms_page_link` |
| Quote form link | `template_vars.quote_form_link` (defaults to the lander) |
| Marketing domain(s) | `clients.allowed_origins` (text[]) — powers CORS allowlist (§6) |
| Twilio number + Messaging Service SID | `clients.twilio_number`, `clients.twilio_messaging_service_sid` (non-secret, under the one parent account) |
| Call-forwarding number | `clients.call_forwarding_number` (may match the owner's Business Phone) |
| Sending subdomain / DKIM | **NOT created in v1** — `sending_subdomain`/`dkim_status` deferred (owner emails use ONE platform-level agency sender, not per-client domains); `ADD COLUMN` later only if per-client email is built |

## template_vars — the single source for merge values [LOCKED]
All per-client merge values live in `clients.template_vars` (jsonb), NOT as dedicated columns. Required keys to populate at onboarding: `company_owner_first_name`, `company_name`, `company_website_link`, `review_request_link`, `discount__on_referral`, `discount_amount`, `quote_form_link`, `website_terms_page_link`. (review_request_link is the client's own direct Google review link, distinct from the per-contact tracked `review_link`.) Validate ALL required keys are present before the client goes live — missing keys render blank silently in messages.

## AI chat-widget knowledge bundle (§7e dependency)
The chat widget answers FAQs from the onboarding data. Assemble a retrieval bundle from: About Us, all services (detailed), service areas, hours, special/differentiators, business identity, + the client's website content. Store it where the §7e widget can load it as model context at chat time. This is the concrete resolution of §7e's "knowledge inputs."

## Build notes
- All writes via the admin (service-role) client in a server function — never owner-direct-to-DB. Zod-validate inputs.
- `call_forwarding_number` precedence: the owner's **Business Phone seeds it as the default**; the **agency value wins if both set** (agency configures the actual forwarding target in admin, editable over time).
- Creating the client today: `createClient` accepts only slug/business_name/phone_display/email; everything else here is set via an extended onboarding capture / `updateClientSettings` (extend it to cover all §9b fields — [BUILD]).
- Assets: logo + public hero images → `public-assets` (public read); private uploads → `client-assets` (client_id-scoped).
- A2P terms page (§9b.C) is generated as part of onboarding and its URL stored in `template_vars.website_terms_page_link`.
- Telephony setup (§9b.D) — provisioning the Twilio number under the parent account, forwarding, GBP/site placement — is an onboarding step (orchestrated by `/new-client-site`); this skill just records the resulting `twilio_number`/`messaging_service_sid`.
- Style + content captured here are the inputs `/website-structure` consumes to generate the site.
