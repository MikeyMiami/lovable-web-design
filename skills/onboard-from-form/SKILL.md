---
name: onboard-from-form
description: Use when capturing a new client's onboarding data into the shared backend — taking the owner-filled onboarding form (§9b) plus agency-set config and writing it to the right places (clients columns, template_vars, send_settings, storage buckets, the AI-knowledge bundle). Run during per-client launch, after the foundation exists. Defines the field→destination mapping. NOT the design/site build (website-structure) and NOT the orchestration (new-client-site).
---

# Onboard From Form — capture client data into the shared backend

Takes the §9b onboarding inputs (owner-filled + agency-set) and writes them into the ONE shared backend as a new `clients` row + related config. This is data capture/mapping, not site generation. Every write is server-side (admin client); the owner never writes directly to the DB.

**AS-BUILT — the C-3 onboarding wizard [BUILT + validated; `cloud-spark-setup` `origin/main`, 2026-06-28].** The capture surface is now real: an **8-step stepper** at `/onboard` (`src/routes/_authenticated/onboard.tsx`, admin/`agency_owner`-gated) that assembles `{ slug, fields, sendSettings, submission }` and calls `createClientFull`. **[C-3d-1]** The wizard is now **mode-aware** — extracted to `OnboardWizard` (`src/components/onboard/OnboardWizard.tsx`), rendered in **agency mode** by this authed `/onboard` route OR in **client mode** on the **public `/onboard/$token`** route (a one-time tokenized link the agency generates + emails; see `agency-view` + the `onboarding_tokens` model in `scratch-foundation`). Client-mode **uploads are LIVE [C-3d-2]** via a token-gated service-role proxy (`/api/public/onboarding/upload` → `uploadSiteImageViaProxy`; validates the token → writes to `public-assets` under the token's `draft_id`; per-token/IP rate-limit + image/10MB caps). Agency mode keeps the direct `uploadSiteImage`. The **final submit stays gated** pending C-3d-3 (public submit). **[C-3c-2a]** `createClientFull` creates the row as **`status='pending'`** (dormant — no automations / not anon-visible until the agency runs **Finalize & Invite** in `/admin`, which flips it to `active`). **App-layer only — no schema, no migration** (everything lands in existing `clients` columns / `template_vars` / `send_settings` / `public-assets`). The field→destination table below is the implemented contract. Steps as built:
1. **Account Setup** — owner full name; business name; **"Personal Cell / Business Number"** (US mask `(305) 555-0142`, **no country-code input**, stored **E.164 `+1…`** via `toE164US` on assembly → `call_forwarding_number`); display address; **"Website Domain"** (+ "I don't have a domain" → preferred-domain field + "get me the closest" button, recorded to `submission.domain_request`); business notification email. **Slug is HIDDEN** — auto-derived from the business name (`slugify`) and still sent in the payload.
2. **Content** — About Us / Services / Differentiators; **service areas** (CSV, max 14 → `service_area[]`); **per-day business-hours picker** (all 7 days default OPEN 09:00–17:00, toggle a day Closed) → **`clients.hours` (PUBLIC)** with **`send_settings.business_hours` DERIVED EQUAL** at onboarding; **timezone** select (moved here from the old Config step).
3. **Branding** — **logo image upload** → `public-assets` via `src/lib/clients/site-image-upload.ts`, sets `clients.logo_url`; OR "I don't have a logo" → "make one for me? Yes/No" (`submission.logo_request`). **Brand colors via native `<input type="color">` pickers** (primary/secondary/tertiary; `ColorField` = color swatch + hex text input); OR "not sure — we'll choose for you" (`submission.color_request`).
4. **Industry & Style** — niche/segment (→ `template_vars.segment`); **site style = the 6 finalized slugs** (`professional_modern` / `artistic_unique` / `corporate` / `modern_tech` / `family_owned` / `owner_operated`) → `clients.site_style` (free text).
5. **Photos** — **multi-file categorized image uploads** to `public-assets` via `site-image-upload.ts`: `work` / `gallery` / `about` / `services`, plus **staff** (per entry an **individual/group toggle** — individual = photo + name + position; group = photo + label) → assembled into the **`template_vars.site_assets` manifest** (shape in `/website-structure`). "Don't have photos — design this section for me" → `submission.photo_request.designForMe`.
6. **Reviews** — the client's **Google Business Profile link** (so the agency can look them up) → **`template_vars.google_business_profile_link`** (+ immutable copy in `submission`). The wizard **no longer sets `clients.review_link` or `template_vars.review_request_link`** — the correctly-formatted Google review URL is **agency-set in admin Settings** (it must be formatted right to work; `review_request_link` is synced from it on save). Star threshold / review-gate toggle / Place ID **removed from the form** (DB defaults: `star_threshold=4`, `google_review_toggle=gated`).
7. **Texting Registration (A2P)** — **required to advance: EIN, legal business name, vertical/industry, TCPA attestation**; **DBA optional**; **Entity type REMOVED** (always the same for us). Captured into the immutable `submission` JSON (PII) + `template_vars` (anon-safe); `a2p_status` stays `not_started` — the wizard PREPARES, never submits.
8. **Review & Create** — a **readable, grouped proofread summary** (7 sections in wizard order: Account Setup / Content / Branding / Industry & Style / Photos / Reviews / Texting Registration), replacing the old raw-JSON dump (`src/components/onboard/ReviewSummary.tsx`): formatted phone, per-day hours list, friendly timezone/style names, brand hex swatches, plain-language request flags, photo counts per category, staff entries with thumbnails. The **Create** button assembles the **unchanged** payload and calls `createClientFull`. *(D7: this final review step IS the pre-gen console.)*

**Removed from the form** vs the old spec (agency-set later / DB defaults apply): SMS send window, daily send + enrollment caps, marketing domains, quote-form link, terms link, **entity type**, **Place ID**, **star threshold**, **review-gate toggle**, the standalone **Config step**, the **visible slug input**, the **Returning Customer Discount step** (moved to agency-set admin Settings), and the **direct Google review link** (now agency-set; onboarding collects the Google Business Profile link instead).

This is the per-client capture surface (was specced as "Stage 3 built / Stage 5 used"; now BUILT as **Phase C-3** — C-3a stepper + R-1 copy/structure + R-2 uploads/manifest + R-3 review summary, all UI-validated).

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
| Return/referral discount | **AGENCY-SET in admin Settings** (no longer collected at onboarding) → `template_vars.discount__on_referral` + `template_vars.discount_amount` (merge-safe edit) |
| Google Business Profile link (so the agency can find them) | `template_vars.google_business_profile_link` (+ immutable copy in `submission`); the agency uses it to set the correct `clients.review_link` in admin. **Editable in admin Review Config** (merge-safe). |
| Logo (upload or request) + "need a logo?" flag | uploaded to `public-assets` bucket → `clients.logo_url`; flag noted for agency. **[BUILD — admin file-upload + preview/download]** today admin is URL-paste only (`admin.settings.tsx`); add an upload-to-storage flow + an `<img>` preview + download per client so the logo is retrievable from the client's admin view. |
| Brand colors (primary, secondary, optional third; "don't have? we'll create them") | primary → `clients.brand_color` (hex); secondary/tertiary → `template_vars.brand_secondary`/`brand_tertiary`. Data-only; agency-editable in admin. |
| Niche / segment (plumbing, roofing, HVAC, …) | `template_vars.segment` (NOT a `clients` column — avoids a migration). Keys the `/a2p-site-compliance` niche library → drives site content/context + the `customer_care_category`/`marketing_category` consent strings (also stored in `template_vars`, single source). |
| Timezone (EST/CST/MST/PST/Honolulu) | `send_settings.timezone` (NOT on clients) |
| Site style choice (1 of 6) | `clients.site_style` (free-text slug: `professional_modern`\|`artistic_unique`\|`corporate`\|`modern_tech`\|`family_owned`\|`owner_operated`) — drives `/website-structure` |
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
- **A2P field coverage (FLAG):** the per-client Brand/Campaign registration (TextGrid §4) needs EIN ✓ (captured), legal business name ✓, website ✓, business address ✓ (`clients.address`), and the opt-in/T&C URL ✓ (generated terms page). **Missing today: an explicit `vertical`/industry field** for the Brand — derive it from the client's niche/`search_term` or add an onboarding field; confirm before registration, as the Brand vet requires it. **A2P-prep field capture + compliance-copy generation → `/a2p-site-compliance`** (canonical verbatim copy: `docs/a2p-compliance-copy-source-of-truth.md`): legal name/DBA/entity type (default Private Profit)/segment→niche-key/EIN+issuer/DUNS-GIIN-LEI/address/website/contact-email **domain-match-enforced**/E.164 phone/business description/logo ≤400px/TCPA attestation/business-domain-email flag. The site's opt-in/Privacy/ToS/SMS-Program copy is reproduced VERBATIM from that doc (tokens only).
- **Immutable onboarding-submission record [BUILD — data-only, migration-free]:** preserve the RAW as-submitted answers + logo as a read-only record, distinct from the editable pre-generation config. Store the submission JSON in the existing private `client-assets` bucket at `{client_id}/onboarding-submission.json` (NOT in `template_vars` — it carries PII and must stay immutable + anon-private); the authenticated admin reads it into a read-only viewer (`/admin-view`). The editable config (prefilled FROM the submission) writes to the `clients` row / `template_vars` as usual. No new table/column.
- Style + content captured here are the inputs `/website-structure` consumes to generate the site.
