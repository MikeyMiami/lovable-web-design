---
name: onboard-from-form
description: Use when capturing a new client's onboarding data into the shared backend — taking the owner-filled onboarding form (§9b) plus agency-set config and writing it to the right places (clients columns, template_vars, send_settings, storage buckets, the AI-knowledge bundle). Run during per-client launch, after the foundation exists. Defines the field→destination mapping. NOT the design/site build (website-structure) and NOT the orchestration (new-client-site).
---

# Onboard From Form — capture client data into the shared backend

Takes the §9b onboarding inputs (owner-filled + agency-set) and writes them into the ONE shared backend as a new `clients` row + related config. This is data capture/mapping, not site generation. Every write is server-side (admin client); the owner never writes directly to the DB.

**Built vs used:** the onboarding **wizard UI is BUILT once in Stage 3** (alongside `/admin-view`); it is **USED per-client at Stage 5** (launch) to capture each new client. The field→destination mapping below is the contract for both.

## Two input layers (§9b)
- **Owner-filled** — the onboarding form the business owner completes (content + brand).
- **Agency-set** — config you set during setup (review link, messaging-provider (TextGrid) number/A2P, domains, etc.).

## Field → destination mapping

### Owner-filled → where it lands
| Onboarding field | Destination |
|---|---|
| Full Name (req) | derive `template_vars.company_owner_first_name` (first token of full name) |
| Business Phone | `clients.call_forwarding_number` (their real phone / lead-notify target) |
| Official Business Name (req) | `clients.business_name` + `template_vars.company_name` |
| Tax ID / EIN | Used for the per-client A2P **Brand** registration (TextGrid §4; EIN must be ≥15 days old). Captured on the form; NOT a standing app-DB column (consumed at registration time). |
| Current website link | `template_vars.company_website_link` + AI-knowledge source |
| About Us (3–5 sentences, req) | `template_vars.about_us` → site copy + AI-knowledge bundle |
| Top location + service areas (MAX 14) | `clients.service_area` (text[]) + site copy + AI-knowledge |
| All services offered (req) | `template_vars.services` → site copy + **AI chat-widget knowledge** |
| Special things / differentiators | `template_vars.differentiators` → site copy + AI-knowledge bundle |
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
| Messaging number + Messaging Service SID | `clients.twilio_number`, `clients.twilio_messaging_service_sid` (non-secret; column names retained; hold the per-client messaging-provider (TextGrid) subaccount's number/SID) |
| Call-forwarding number | `clients.call_forwarding_number` (may match the owner's Business Phone) |
| Sending subdomain / DKIM | **NOT created in v1** — `sending_subdomain`/`dkim_status` deferred (owner emails use ONE platform-level agency sender, not per-client domains); `ADD COLUMN` later only if per-client email is built |

## template_vars — the single source for merge values [LOCKED]
All per-client merge values live in `clients.template_vars` (jsonb), NOT as dedicated columns. Required keys to populate at onboarding: `company_owner_first_name`, `company_name`, `company_website_link`, `review_request_link`, `discount__on_referral`, `discount_amount`, `quote_form_link`, `website_terms_page_link`, `about_us`, `services`, `differentiators` (the last three are the AI-knowledge content fields — F-complete Option A, anon-safe public content). (review_request_link is the client's own direct Google review link, distinct from the per-contact tracked `review_link`.) Validate ALL required keys are present before the client goes live — missing keys render blank silently in messages.

**SECURITY [LOCKED]:** `template_vars` is **ANON-READABLE** — it is projected by the §A **`get_client_public` RPC** (the marketing site reads merge values via the RPC; there is NO `clients_public` view). So it holds **anon-safe merge values ONLY** — NEVER owner PII (notification email), secrets, or internal config. Owner-PII config (notification recipient email, etc.) belongs in a **dedicated `clients` column NOT projected by `get_client_public`** (anon-denied, 42501, same posture as `clients.email` / `call_forwarding_number`). *(3g initially put `notification_email` in `template_vars` — moved out; the RPC also defensively strips it from the projection. See `stage-3g-validation.md` F-pii.)*

## AI chat-widget knowledge bundle (§7e dependency)
The chat widget answers FAQs from the onboarding data. **Storage [PINNED — F-complete Option A, 2026-06-15]:** the knowledge content lives as `template_vars` keys — `about_us`, `services`, `differentiators` (+ `service_area` column, hours) — all anon-safe public content. `src/lib/chat/knowledge.server.ts` iterates the full `template_vars` JSONB into the system prompt, so these are picked up automatically (no per-key consumer wiring). The retrieval bundle = those keys + business identity + site content. This is the concrete resolution of §7e's "knowledge inputs."

## Build notes
- All writes via the admin (service-role) client in a server function — never owner-direct-to-DB. Zod-validate inputs.
- `call_forwarding_number` precedence: the owner's **Business Phone seeds it as the default**; the **agency value wins if both set** (agency configures the actual forwarding target in admin, editable over time).
- Creating the client today: `createClient` accepts only slug/business_name/phone_display/email; everything else here is set via an extended onboarding capture / `updateClientSettings` (extend it to cover all §9b fields — [BUILD]).
- Assets: logo + public hero images → `public-assets` (public read); private uploads → `client-assets` (client_id-scoped).
- A2P terms page (§9b.C) is generated as part of onboarding and its URL stored in `template_vars.website_terms_page_link`.
- Telephony setup (§9b.D) — the per-client messaging-provider (TextGrid) flow (subaccount → Brand → Campaign → number, forwarding, GBP/site placement) — is an onboarding step (orchestrated by `/new-client-site`, detail in `skills/textgrid-provider`); this skill just records the resulting `twilio_number`/`messaging_service_sid`.
- **A2P field coverage (FLAG):** the per-client Brand/Campaign registration (TextGrid §4) needs EIN ✓ (captured), legal business name ✓, website ✓, business address ✓ (`clients.address`), and the opt-in/T&C URL ✓ (generated terms page). **Missing today: an explicit `vertical`/industry field** for the Brand — derive it from the client's niche/`search_term` or add an onboarding field; confirm before registration, as the Brand vet requires it.
- Style + content captured here are the inputs `/website-structure` consumes to generate the site.
