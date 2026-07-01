---
name: website-structure
description: Use when building or designing a client's marketing site — the per-client design layer (§9c). Covers the page set (always-present pages + data-driven service/service-area pages up to max), the 4 site-style choices that steer copy voice and visual direction, the AI generation inputs (style + onboarding data + visual assets + agency reference screenshots), brand-color theming, and the two-mode design-template system (generate now, codify winners into reusable templates). Absorbs the retired /theme-to-brand. Runs per client on the Remixed marketing site; consumes onboard-from-form data. NOT the backend (scratch-foundation) and NOT the orchestration (new-client-site).
---

# Website Structure & Design Layer (§9c)

The per-client DESIGN layer, applied on the Remixed marketing site (frontend-only) that points at the shared golden-master backend (§0). Defines the page set, the copy/visual direction, and how design is generated and (eventually) templated. This is the per-client CREATIVE layer — the counterpart to the frozen backend. Absorbs the retired `/theme-to-brand`. Consumes `/onboard-from-form` data.

## SEO structure + content [LOCKED — reconciled to `/seo-build` + `/seo-content`, 2026-06-30]
For local-business clients the **site structure = the Core 30** (`/seo-build`) and the **page copy = `/seo-content`** — those two skills are the AUTHORITY for structure, on-page/technical (titles, meta, one-H1, schema JSON-LD, semantic HTML, canonical, OG, sitemap/robots) and content. This skill's page set + styling reconcile TO them: the site **mirrors the client's Google Business Profile** (categories + services); pages are **DATA** in the `content_pages` store rendered by dynamic routes (`/seo-build` §4); internal linking is **editorial in-content** (not nav/footer); the homepage is the **GBP landing page** with the 8 consistency signals (`/seo-build` §1). **Where anything below conflicts with `/seo-build`/`/seo-content`, THEY win.**

## Page set [LOCKED — the Core 30 + functional/compliance pages]
Built as the **Core 30** (`/seo-build` §2), mirroring the client's GBP:
- **Home** — the GBP landing page (hero + services overview + CTAs + all 8 GBP-consistency signals; `/seo-build` §1).
- **Category pages** — one per GBP **secondary category** (~3–4). Target keyword = category + city.
- **Service pages** — one per GBP **service** (~25–30). Target keyword = service + city. **No max-12 cap — mirror the GBP.**
- **Geo / neighborhood pages** — **genuinely-local** landmark/neighborhood pages (`/seo-content`), built diagnostic-driven (rank-map positions 4–6), mostly post-launch. **NOT** re-targeted city-swap landers.
- **Supporting pages** — FAQ/topical deep pages (`/seo-content`), editorial-linked from the Core 30.

Internal linking mirrors the GBP hierarchy via **editorial in-content links** (home→category→service) — NOT nav/footer (`/seo-build` §2).

**Always present** (every site, in addition to the Core 30): About, Contact Us, Gallery, Thank You, Discount Funnel, Review Us, Terms of Service, Privacy Policy, SMS Program. The functional pages (Discount Funnel, Review Us, Contact, Thank You) wire to the backend features (§4/§7/§7b) — this skill styles them; their behavior/copy lives in those features.

Pages are **DATA** (`content_pages` store, `/seo-build` §4) rendered by dynamic routes: the per-client build writes the first-pass Core-30 rows; ongoing supporting/geo rows come from the content-automation tool. **Build what the client's categories/services support** (mirror the GBP — no fixed page cap).

## Canonical page registry [LOCKED — Approach B: fixed identity + flexible label]

**FINITE GENERATION.** Every page's IDENTITY — its canonical `id` + `route` — is FIXED and system-facing: data, skills, and cross-template congruence always key off it, so it NEVER varies across builds. The visitor-facing **display label** MAY flex to any value in `allowed_display_labels` to match the chosen style/reference. **The rule:** the canonical id/route is fixed and system-facing; the nav/heading label may use any value in `allowed_display_labels` to match the style/reference; **never invent a label outside the allowed set, and never change the id/route.** (e.g. a shell may show "Projects" in the nav, but the page is canonically `gallery` at `/gallery` — content, data, and cross-template congruence stay fixed while the label mimics the reference.) Compliance/legal pages keep a **FIXED label** (do NOT flex) for carrier/legal recognizability.

**Label precedence [LOCKED]:** the reference may guide WHICH `allowed_display_labels` value you choose, but the label MUST come from that set. If the reference shows wording NOT in `allowed_display_labels` (i.e. a menu/heading word not in that page's set), you MUST use an allowed value — **the reference NEVER overrides the allowed set or the canonical id/route.** Picking a label outside the allowed set is a finite-generation violation. **The allowed sets are intentionally universal / niche-agnostic** — don't widen them to match a single style's or reference's wording (the shell serves every niche, so a label that fits one vertical may be wrong for another).

| Canonical id | Route | Purpose | Allowed display labels |
|---|---|---|---|
| `home` | `/` | GBP landing page — primary conversion (hero + services overview + CTAs) + the **8 GBP-consistency signals** (`/seo-build` §1) | Home, Welcome |
| `about` | `/about` | Business story / owner / differentiators | About, About Us, Our Story |
| `services` | `/services` | Services index — links to the **category** pages → **service** pages | Services, Our Services, What We Do |
| `category` | `/services/$slug` | **Per GBP secondary category** (~3–4); Core 30; target kw = category + city; editorial-links to its service pages (`/seo-build` §2) | *(label = the category name)* |
| `service` | `/services/$slug` | Per-service detail; **one per GBP service (~25–30 — mirror the GBP, no cap)**; target kw = service + city | *(label = the service name)* |
| `service-area` | `/service-area/$slug` | **Geo/neighborhood page — GENUINELY LOCAL** (landmark/neighborhood + service + city per `/seo-content`); diagnostic-driven; **NOT a re-targeted lander** | *(label = the neighborhood/landmark name)* |
| `supporting` | `/$slug` | FAQ/topical deep page (`/seo-content`); editorial-linked from a Core-30 page | *(label = the topic)* |
| `gallery` | `/gallery` | Photos of previous work | Gallery, Projects, Our Work |
| `contact` | `/contact` | Lead form + business contact info | Contact, Contact Us, Get in Touch |
| `discount` | `/get-your-discount` | Discount-claim funnel (One-Year drip destination; route per `/opt-in-forms`) | Get Your Discount, Special Offer, Claim Your Discount |
| `review` | `/review` | "Review Us" page — the on-site working review action A2P needs | Reviews, Review Us, Leave a Review |
| `thank-you` | `/thank-you` | Post-submit confirmation | Thank You, Thanks |
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

## Site styles (copy voice + photo treatment) [LOCKED — the 6 definitive styles]

Style = a selectable PRESET (copy voice + photo/visual treatment) that fills a layout shell — **DECOUPLED from niche** (any niche, a data layer `template_vars.segment` + the `/a2p-site-compliance` library, composes onto any style). `clients.site_style` holds the **slug key** below: the template/style **SELECTION key** (which `Template — {Style}` project to remix) — **free text, no migration, NOT a render-time branch**. Each style = a display name + slug key + copy voice + visual/photo direction. Authoritative layer model: `/template-builder` + `docs/stage5-template-builder-build-spec.md`.

| Display name | Slug key (`site_style`) | Copy voice | Visual / photo direction |
|---|---|---|---|
| **Professional Modern** | `professional_modern` | Professional, high-quality, polished; typography-forward and credible; elevated but not cold. | High-quality imagery, refined type hierarchy, clean modern layout. |
| **Artistic Unique** | `artistic_unique` | Artist/brand-led, retro-artistic, highly minimalistic; **lowest copy density of the set** — image + branding carry the site, minimal copy, visual-first. | The brand identity + imagery create the aesthetic; sparse text, generous visual space. |
| **Corporate** | `corporate` | Franchise / big-business feel; polished, presentable, uniform, formal. | Structured, consistent, credentials/scale-forward. |
| **Modern Tech** | `modern_tech` | SaaS look; minimalistic, clean, contemporary. | Lots of whitespace, product/design-forward. |
| **Family Owned / Local Business** | `family_owned` | Classic family-owned business — not fancy; a standard-classic look "that just works," friendly local identity; warm, approachable, trust-through-familiarity. | Standard-classic local look; warm, approachable. |
| **Owner Operated / Local Business** | `owner_operated` | Same local/approachable feel as Family Owned but centered on a single person/entity; simple, straight-to-the-point on services; the owner is the brand. | Local/approachable; person-centered. |

The style steers BOTH the copy tone and the layout/visual feel. All six use the client's real onboarding content + assets — the style changes the voice and look, not the facts. Fonts are chosen per-style from the ART-STYLE references (see **Fonts & type**) — distinct per style, never the generic default.

## Brand-color theming
`clients.brand_color` (primary) + `template_vars.brand_secondary`/`brand_tertiary` are the per-client brand colors. Per-client theming = convert each hex to an oklch value and inject it into the theme tokens / shell head, so the site picks up the client's brand colors. (This is the theming job admin-view points here for.)

**When brand colors are NOT provided [LOCKED]:** DERIVE the palette from the uploaded design / ART-STYLE references — take the **dominant + accent colors** from the reference imagery so the theme MATCHES the intended look. **`#bd703e` (terracotta) is only a last-resort fallback** when there is nothing to derive from (no references AND no client colors). **Never apply the arbitrary default over a palette the references clearly imply.**

**Demo vs live split:**
- **Style-template build (demo client):** the demo client's colors should **match the ART-STYLE references** (derive dominant + accent) so the demo is coherent with the style.
- **Real client launch:** colors come from the **client's provided brand**, or are **derived from their references / brand imagery** if not given.

So **brand color is NOT a build-prompt parameter** — it comes from the references (demo) or client data (live), **never hand-entered into the prompt**.

## Onboarding data contracts — hours + site_assets [LOCKED]
The onboarding wizard CAPTURES these into the shared backend; the per-client Remix READS them at build time to render hours + place images. **Fixed shapes (finite-generation).**

**Business hours** — `clients.hours` (public display) AND `send_settings.business_hours` (lead-reply timing) both use: `{ "mon": ["09:00","17:00"], "tue": [...], ... }` — keys = 3-letter lowercase day (`sun mon tue wed thu fri sat`); value = `[open, close]` zero-padded 24h `"HH:mm"`; **a missing day = CLOSED**. The marketing site renders `clients.hours` (render absent days as "Closed"); the lead-form branch reads `send_settings.business_hours` (derived equal at onboarding; the agency may diverge it later in admin).

**Site images** — manifest at `template_vars.site_assets` (anon-public) + the logo at `clients.logo_url`. Images live in the **`public-assets`** bucket (public URLs via `getPublicUrl`). Manifest shape:
```json
{
  "work":     [{ "url": "…", "path": "<id>/site/work/…" }],
  "gallery":  [{ "url": "…", "path": "…" }],
  "about":    [{ "url": "…", "path": "…" }],
  "services": [{ "url": "…", "path": "…" }],
  "staff":    [
    { "url": "…", "path": "…", "type": "individual", "name": "Jane Doe", "position": "Lead Designer" },
    { "url": "…", "path": "…", "type": "group", "label": "Our Team" }
  ]
}
```
**Staff entries carry a `type` [SQL-CONFIRMED 2026-06-28 — test client carried both an individual `{name,position,type:"individual"}` and a group `{label,type:"group"}` entry in `template_vars.site_assets.staff`].** Each staff entry is one of: **individual** = `{ url, path, type:"individual", name, position }` (a person — render as a headshot with name + position); **group** = `{ url, path, type:"group", label }` (a single team/group photo — render with the label, no per-person name/position). The wizard sets `type` via a per-entry individual/group toggle.
**Placement at build [LOCKED]:** the template reads each category and drops it into its section — `work`/`gallery` → Gallery; `about` → About; `services` → the Service pages; `staff` → About/Team — for staff, place **individual** entries as team headshots (name + position) and **group** entries as a single team/group photo (label). The **logo comes from `clients.logo_url`** (projected), NOT `site_assets`. A category with no images → the template uses the niche-default fallback (or, if the owner chose "design this section for me" — `submission.photo_request.designForMe` — the agency designs it). **The wizard only CAPTURES + ORGANISES; the template PLACES.**

## Fonts & type [LOCKED — per-style, from the ART-STYLE references]
Fonts are a per-STYLE decision driven by the ART-STYLE references — there is no preset font per style, so the build must **match the typography shown in the attached reference images as closely as possible** (resemble the reference's actual fonts — serif vs sans, weight, proportions, overall character — using the closest available web fonts). Do NOT default to Inter / Poppins (the generic defaults) and do NOT pick a pairing merely "in the spirit of" the style — **replicate what the references actually show**. Then record the chosen pairing in that style's template so it's stable across all of that style's remixes. Each style gets its OWN pairing (no universal pairing); the invariant rule: **resemble the reference imagery's typography as closely as possible, never the generic default, then LOCK it for that style**. If the references don't clearly show typography, pick a distinctive pairing that fits the style's voice/visual direction (per the Site styles table) — never the generic default.

## Two-mode design system [LOCKED]
- **Mode 1 — Generate (now):** AI builds the style from reference screenshots + style choice + onboarding assets/data. Used to DISCOVER good styles while the template library is small.
- **Mode 2 — Apply a template (as the library grows):** once a generated style is a winner, capture its CODE as a named, reusable design template; new sites are built by selecting a template and injecting the client's data/assets — NO re-derivation. Faster, deterministic, reliably good.
- **Bridge:** codify winning generated styles into the template library. Primary plug-and-play mechanism = **Lovable cross-project referencing** (a proven style lives as a reference project; new builds pull its design patterns via @mention — read-only, the referenced project is unchanged). The codification process is fully defined once the first winners exist. [BUILD — the template library grows over time]

This is the design analog of the backend's golden-master logic: generate while discovering, then freeze winners and apply them — anti-drift, deterministic, but creative where it should be.

## Build notes
- Runs on the per-client Remixed marketing site (frontend-only): reads public client data via anon SELECT; lead/discount/funnel forms POST to the shared backend's CORS-guarded public routes (foundation §6). No service-role key on this project.
- **[LAUNCH PREREQUISITE — 1f step 3 dependency] Every public lead-intake form (website lead form, discount-claim, AND the chat-widget opt-in) MUST render the Cloudflare Turnstile widget with the agency's PUBLIC site key, and submit the resulting token as `turnstile_token` in the POST body.** The backend enforces Turnstile on `intake`/`discount`/`chat/optin` (fail-closed on an invalid token), so a form WITHOUT the widget → no token → **every legit submission is rejected → zero leads.** Add the client's marketing domain as a Turnstile hostname at launch. Site key is public (safe in the frontend); the secret stays a backend runtime secret. (Spec §10 Bot-protection; build-spec `docs/1f-step3-turnstile-ratelimit-build-spec.md`; gated in `/launch-check` §E.)
- **[A2P-PREP — compliance pages] Every site carries the carrier-compliance surface from `/a2p-site-compliance`:** the two-checkbox opt-in (unchecked/optional; fixed consent skeleton + per-niche category strings keyed by `{segment}`), the named (not generic) Privacy Policy + Terms of Service, the SMS Program page, footer Privacy/Terms/SMS-Program links on every page, and the working `{site_url}/review` page. **Copy is reproduced VERBATIM from the `/a2p-site-compliance` skill's "Appendix — Canonical Verbatim Copy" — tokens only, never paraphrased** (the same copy is also kept at `docs/a2p-compliance-copy-source-of-truth.md` for human reference + parity). (Carrier 10DLC review reads the live site.) These pages + the Turnstile widget are **baked into the STYLE template** (`/template-builder`) once, so every per-client remix inherits them — not authored per client.
- Generate the pages the client's **GBP categories/services** support (the Core 30 — `/seo-build` §2); **no fixed cap** (mirror the GBP). Geo/supporting pages are added over time by the content-automation tool (`/seo-content`).
- **Service-area / geo pages [LOCKED — SUPERSEDED by `/seo-content`]:** the old v1 rule ("re-targeted lander, NO bespoke per-area copy, city-swap") is **RETIRED** — it's exactly the city-swap anti-pattern `/seo-content` forbids. Geo/neighborhood pages MUST be **genuinely local** (real neighborhoods + their conditions, driving routes, landmarks from Google Maps/Places API), targeting rank-map positions 4–6, built diagnostic-driven. Structure/route = `/seo-build`; copy standard = `/seo-content`.
- Assets come from the storage buckets; copy is generated from onboarding data steered by `site_style`.
- As the template library matures, prefer Mode 2 (apply a proven template) over Mode 1 (regenerate) for reliability.
- **FINITE GENERATION [LOCKED — mirror]:** page identities/routes (the canonical page registry above), env-var names, and the service-area / fonts / compliance-render rules are FIXED by the skills — a template build MUST NOT improvise them; if a needed decision isn't covered, **FLAG it for a skill update rather than guessing** (authoritative rule: `/template-builder` → FINITE GENERATION).
