---
name: website-structure
description: Use when building or designing a client's marketing site — the per-client design layer (§9c). Covers the page set (always-present pages + data-driven service/service-area pages up to max), the 4 site-style choices that steer copy voice and visual direction, the AI generation inputs (style + onboarding data + visual assets + agency reference screenshots), brand-color theming, and the two-mode design-template system (generate now, codify winners into reusable templates). Absorbs the retired /theme-to-brand. Runs per client on the Remixed marketing site; consumes onboard-from-form data. NOT the backend (scratch-foundation) and NOT the orchestration (new-client-site).
---

# Website Structure & Design Layer (§9c)

The per-client DESIGN layer, applied on the Remixed marketing site (frontend-only) that points at the shared golden-master backend (§0). Defines the page set, the copy/visual direction, and how design is generated and (eventually) templated. This is the per-client CREATIVE layer — the counterpart to the frozen backend. Absorbs the retired `/theme-to-brand`. Consumes `/onboard-from-form` data.

## Page set [LOCKED]
Pages are generated FROM the onboarding data, up to the max. Build ONLY the pages the onboarding supports — e.g. 5 services + 8 areas → 5 service pages + 8 area pages, NOT the max.

**Always present** (every site): Home/Lander, Contact Us, Gallery, Thank You, Review + Referral Follow-up Form, Discount Funnel, Review Us, Terms & Conditions, Privacy Policy.

**Data-driven** (one each, up to max):
- **Service page** per service listed — **max 12**. The AI determines a good, relevant layout describing that service.
- **Service Area page** per area listed — **max 14**. Essentially the Home/Lander re-focused on serving THAT area (local-SEO play: ranks for "[service] in [city]").

The functional pages (Review+Referral form, Discount Funnel, Review Us, Contact, Thank You) wire to the backend features already specced (§4/§7/§7b) — this skill styles them; their behavior/copy lives in those features.

## Design generation inputs [LOCKED]
Visual design, fonts, colors, copy, and layout are AI-driven, from combining:
1. **Site style choice** (`clients.site_style`, §9b — 4 options below) → copy VOICE + styling DIRECTION.
2. **Onboarding form data** → content + the AI's copy source (About Us, services, areas, differentiators, hours, identity).
3. **Visual assets from onboarding** → logo (`clients.logo_url`, uploaded or agency-made) + photos of previous work (the `public-assets` / `client-assets` buckets).
4. **Reference style screenshots** — AGENCY-uploaded at build time (NOT an onboarding field). Lovable mimics the reference layout/styling, populated with the client's real data + assets.

This resolves the copy-strategy decision: copy is **AI-GENERATED, steered by the style choice** — templatized STRUCTURE, generated copy (not hardcoded, not manually rewritten per client).

## The 4 site styles (copy voice + visual direction)
- **Corporate** — polished, professional, formal; sleek/minimal visual.
- **Standard Business** — straightforward, service-focused, balanced.
- **Local Family-Owned** — warm, community-rooted, personal.
- **Owner-Operated Local** — the owner IS the brand; first-person, most personal.

The style choice steers BOTH the AI's copy tone and the layout/visual feel. All four use the client's real onboarding content and assets — the style changes the voice and look, not the facts.

## Brand-color theming
`clients.brand_color` (hex, default `#bd703e`) is the per-client brand color. Per-client theming = convert the hex to an oklch value and inject it into the theme tokens / shell head, so the site picks up the client's brand color. (This is the theming job admin-view points here for.)

## Two-mode design system [LOCKED]
- **Mode 1 — Generate (now):** AI builds the style from reference screenshots + style choice + onboarding assets/data. Used to DISCOVER good styles while the template library is small.
- **Mode 2 — Apply a template (as the library grows):** once a generated style is a winner, capture its CODE as a named, reusable design template; new sites are built by selecting a template and injecting the client's data/assets — NO re-derivation. Faster, deterministic, reliably good.
- **Bridge:** codify winning generated styles into the template library. Primary plug-and-play mechanism = **Lovable cross-project referencing** (a proven style lives as a reference project; new builds pull its design patterns via @mention — read-only, the referenced project is unchanged). The codification process is fully defined once the first winners exist. [BUILD — the template library grows over time]

This is the design analog of the backend's golden-master logic: generate while discovering, then freeze winners and apply them — anti-drift, deterministic, but creative where it should be.

## Build notes
- Runs on the per-client Remixed marketing site (frontend-only): reads public client data via anon SELECT; lead/discount/funnel forms POST to the shared backend's CORS-guarded public routes (foundation §6). No service-role key on this project.
- **[LAUNCH PREREQUISITE — 1f step 3 dependency] Every public lead-intake form (website lead form, discount-claim, AND the chat-widget opt-in) MUST render the Cloudflare Turnstile widget with the agency's PUBLIC site key, and submit the resulting token as `turnstile_token` in the POST body.** The backend enforces Turnstile on `intake`/`discount`/`chat/optin` (fail-closed on an invalid token), so a form WITHOUT the widget → no token → **every legit submission is rejected → zero leads.** Add the client's marketing domain as a Turnstile hostname at launch. Site key is public (safe in the frontend); the secret stays a backend runtime secret. (Spec §10 Bot-protection; build-spec `docs/1f-step3-turnstile-ratelimit-build-spec.md`; gated in `/launch-check` §E.)
- Generate exactly the pages the onboarding supports (count services/areas; cap at 12/14).
- Service-area pages are the home page re-focused per area (don't author each from scratch — re-target the lander).
- Assets come from the storage buckets; copy is generated from onboarding data steered by `site_style`.
- As the template library matures, prefer Mode 2 (apply a proven template) over Mode 1 (regenerate) for reliability.
