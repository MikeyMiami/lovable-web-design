---
name: website-structure
description: Use when building or designing a client's marketing site — the per-client design layer (§9c). Covers the page set (always-present pages + data-driven service/service-area pages up to max), the 4 site-style choices that steer copy voice and visual direction, the AI generation inputs (style + onboarding data + visual assets + agency reference screenshots), brand-color theming, and the two-mode design-template system (generate now, codify winners into reusable templates). Absorbs the retired /theme-to-brand. Runs per client on the Remixed marketing site; consumes onboard-from-form data. NOT the backend (scratch-foundation) and NOT the orchestration (new-client-site).
---

# Website Structure & Design Layer (§9c)

The per-client DESIGN layer, applied on the Remixed marketing site (frontend-only) that points at the shared golden-master backend (§0). Defines the page set, the copy/visual direction, and how design is generated and (eventually) templated. This is the per-client CREATIVE layer — the counterpart to the frozen backend. Absorbs the retired `/theme-to-brand`. Consumes `/onboard-from-form` data.

## Page set [LOCKED]
Pages are generated FROM the onboarding data, up to the max. Build ONLY the pages the onboarding supports — e.g. 5 services + 8 areas → 5 service pages + 8 area pages, NOT the max.

**Always present** (every site): Home/Lander, Contact Us, Gallery, Thank You, Review + Referral Follow-up Form, Discount Funnel, Review Us, Terms of Service, Privacy Policy, SMS Program.

**Data-driven** (one each, up to max):
- **Service page** per service listed — **max 12**. The AI determines a good, relevant layout describing that service.
- **Service Area page** per area listed — **max 14**. Essentially the Home/Lander re-focused on serving THAT area (local-SEO play: ranks for "[service] in [city]").

The functional pages (Review+Referral form, Discount Funnel, Review Us, Contact, Thank You) wire to the backend features already specced (§4/§7/§7b) — this skill styles them; their behavior/copy lives in those features.

## Canonical page registry [LOCKED — Approach B: fixed identity + flexible label]

**FINITE GENERATION.** Every page's IDENTITY — its canonical `id` + `route` — is FIXED and system-facing: data, skills, and cross-template congruence always key off it, so it NEVER varies across builds. The visitor-facing **display label** MAY flex to any value in `allowed_display_labels` to match the chosen style/reference. **The rule:** the canonical id/route is fixed and system-facing; the nav/heading label may use any value in `allowed_display_labels` to match the style/reference; **never invent a label outside the allowed set, and never change the id/route.** (e.g. a shell may show "Projects" in the nav, but the page is canonically `gallery` at `/gallery` — content, data, and cross-template congruence stay fixed while the label mimics the reference.) Compliance/legal pages keep a **FIXED label** (do NOT flex) for carrier/legal recognizability.

| Canonical id | Route | Purpose | Allowed display labels |
|---|---|---|---|
| `home` | `/` | Lander — primary conversion page (hero + services overview + CTAs) | Home, Welcome |
| `about` | `/about` | Business story / owner / differentiators | About, About Us, Our Story |
| `services` | `/services` | Services index — links to each Service detail | Services, Our Services, What We Do |
| `service` | `/services/$slug` | Per-service detail; data-driven, one per `template_vars.services` (max 12) | *(label = the service name)* |
| `service-area` | `/service-area/$area` | Lander re-focused on one area; data-driven (max 14) | *(label = the area name)* |
| `gallery` | `/gallery` | Photos of previous work | Gallery, Projects, Our Work |
| `contact` | `/contact` | Lead form + business contact info | Contact, Contact Us, Get in Touch |
| `discount` | `/get-your-discount` | Discount-claim funnel (One-Year drip destination; route per `/opt-in-forms`) | Get Your Discount, Special Offer, Claim Your Discount |
| `review` | `/review` | "Review Us" page — the on-site working review action A2P needs | Reviews, Review Us, Leave a Review |
| `thank-you` | `/thank-you` | Post-submit confirmation | Thank You, Thanks |
| `review-referral` | `/review-referral` | Review + Referral Follow-up form (wires to the review-drip referral feature) | Refer a Friend, Review & Referral |
| `terms` | `/terms` | Terms of Service (verbatim `/a2p-site-compliance` §A) | **Terms of Service** *(FIXED — do not flex)* |
| `privacy` | `/privacy` | Privacy Policy (verbatim `/a2p-site-compliance` §B) | **Privacy Policy** *(FIXED — do not flex)* |
| `sms-program` | `/sms-program` | SMS Program page (verbatim `/a2p-site-compliance` §D) | **SMS Program** *(FIXED — do not flex)* |

Routes use TanStack file-based routing (`$slug`/`$area` = dynamic segments). The **id** is the system key the data contract + skills reference; the **route** is the URL; the **label** is display-only. `/template-builder` points here as the authority for page identity.

## Design generation inputs [LOCKED]
Visual design, fonts, colors, copy, and layout are AI-driven, from combining:
1. **Site style choice** (`clients.site_style`, §9b — 4 options below) → copy VOICE + styling DIRECTION.
2. **Onboarding form data** → content + the AI's copy source (About Us, services, areas, differentiators, hours, identity).
3. **Visual assets from onboarding** → logo (`clients.logo_url`, uploaded or agency-made) + photos of previous work (the `public-assets` / `client-assets` buckets).
4. **Reference style screenshots** — AGENCY-uploaded at build time (NOT an onboarding field). **MIMIC CLOSELY:** treat the references as the design spec to FAITHFULLY REPRODUCE (layout, section structure, spacing, typography, visual style) — not loose inspiration. Label them PAGE-LAYOUT (structure/section flow) vs ART-STYLE (palette/type/visual feel). The only things that change from the references: business content renders from the client data object (never hardcoded), the baked compliance surface (`/a2p-site-compliance`) is added, and the chosen style's copy voice fills the text — everything structural/visual follows the references.

This resolves the copy-strategy decision: copy is **AI-GENERATED, steered by the style choice** — templatized STRUCTURE, generated copy (not hardcoded, not manually rewritten per client).

## Site styles (copy voice + photo treatment)

> **[v2 — Stage-5 layer model]** Style = a selectable PRESET (copy voice + photo selection/treatment) that fills a layout shell. The current preset set is **Family-Owned, Owner-Operated, Corporate/Professional, Modern Professional, Local Professional** (revised from the original 4 below; `clients.site_style` is free text — no migration). Style is **DECOUPLED from niche**: any niche (a data layer, `template_vars.segment` + the `/a2p-site-compliance` library) composes onto any style. `site_style` is the template/style **SELECTION key** (which `Template — {Style}` project to remix), **NOT a render-time branch**. Authoritative layer model: `/template-builder` + `docs/stage5-template-builder-build-spec.md`. The original 4 voices below remain valid descriptions of tone/direction:

### The original 4 site styles (copy voice + visual direction)
- **Corporate** — polished, professional, formal; sleek/minimal visual.
- **Standard Business** — straightforward, service-focused, balanced.
- **Local Family-Owned** — warm, community-rooted, personal.
- **Owner-Operated Local** — the owner IS the brand; first-person, most personal.

The style choice steers BOTH the AI's copy tone and the layout/visual feel. All four use the client's real onboarding content and assets — the style changes the voice and look, not the facts.

## Brand-color theming
`clients.brand_color` (hex, default `#bd703e`) is the per-client brand color. Per-client theming = convert the hex to an oklch value and inject it into the theme tokens / shell head, so the site picks up the client's brand color. (This is the theming job admin-view points here for.)

## Fonts & type [LOCKED — per-style, from the ART-STYLE references]
Fonts are a **per-STYLE decision driven by the ART-STYLE references**, NOT a per-build improvisation. **Do NOT default to Inter / Poppins** (the generic defaults). For each style: pick a **distinctive heading + body pairing that matches that style's references**, then **record the chosen pairing in that style's template** so it is stable across all of that style's remixes. Each style gets its OWN pairing — there is no one universal pairing — but the rule is invariant: **pick deliberately from the references, never the generic default, then LOCK it for the style.**

## Two-mode design system [LOCKED]
- **Mode 1 — Generate (now):** AI builds the style from reference screenshots + style choice + onboarding assets/data. Used to DISCOVER good styles while the template library is small.
- **Mode 2 — Apply a template (as the library grows):** once a generated style is a winner, capture its CODE as a named, reusable design template; new sites are built by selecting a template and injecting the client's data/assets — NO re-derivation. Faster, deterministic, reliably good.
- **Bridge:** codify winning generated styles into the template library. Primary plug-and-play mechanism = **Lovable cross-project referencing** (a proven style lives as a reference project; new builds pull its design patterns via @mention — read-only, the referenced project is unchanged). The codification process is fully defined once the first winners exist. [BUILD — the template library grows over time]

This is the design analog of the backend's golden-master logic: generate while discovering, then freeze winners and apply them — anti-drift, deterministic, but creative where it should be.

## Build notes
- Runs on the per-client Remixed marketing site (frontend-only): reads public client data via anon SELECT; lead/discount/funnel forms POST to the shared backend's CORS-guarded public routes (foundation §6). No service-role key on this project.
- **[LAUNCH PREREQUISITE — 1f step 3 dependency] Every public lead-intake form (website lead form, discount-claim, AND the chat-widget opt-in) MUST render the Cloudflare Turnstile widget with the agency's PUBLIC site key, and submit the resulting token as `turnstile_token` in the POST body.** The backend enforces Turnstile on `intake`/`discount`/`chat/optin` (fail-closed on an invalid token), so a form WITHOUT the widget → no token → **every legit submission is rejected → zero leads.** Add the client's marketing domain as a Turnstile hostname at launch. Site key is public (safe in the frontend); the secret stays a backend runtime secret. (Spec §10 Bot-protection; build-spec `docs/1f-step3-turnstile-ratelimit-build-spec.md`; gated in `/launch-check` §E.)
- **[A2P-PREP — compliance pages] Every site carries the carrier-compliance surface from `/a2p-site-compliance`:** the two-checkbox opt-in (unchecked/optional; fixed consent skeleton + per-niche category strings keyed by `{segment}`), the named (not generic) Privacy Policy + Terms of Service, the SMS Program page, footer Privacy/Terms/SMS-Program links on every page, and the working `{site_url}/review` page. **Copy is reproduced VERBATIM from the `/a2p-site-compliance` skill's "Appendix — Canonical Verbatim Copy" — tokens only, never paraphrased** (the same copy is also kept at `docs/a2p-compliance-copy-source-of-truth.md` for human reference + parity). (Carrier 10DLC review reads the live site.) These pages + the Turnstile widget are **baked into the STYLE template** (`/template-builder`) once, so every per-client remix inherits them — not authored per client.
- Generate exactly the pages the onboarding supports (count services/areas; cap at 12/14).
- **Service-area page depth [v1 LOCKED]:** a service-area page = the lander re-focused per area — substitute `{area}` into the **headline, page title, meta description, and intro** (and any "serving {area}" strips); **NO bespoke per-area body copy in v1** (don't author each from scratch — re-target the lander). **[BACKLOG]** richer per-area body copy (local landmarks, per-area testimonials).
- Assets come from the storage buckets; copy is generated from onboarding data steered by `site_style`.
- As the template library matures, prefer Mode 2 (apply a proven template) over Mode 1 (regenerate) for reliability.
- **FINITE GENERATION [LOCKED — mirror]:** page identities/routes (the canonical page registry above), env-var names, and the service-area / fonts / compliance-render rules are FIXED by the skills — a template build MUST NOT improvise them; if a needed decision isn't covered, **FLAG it for a skill update rather than guessing** (authoritative rule: `/template-builder` → FINITE GENERATION).
