---
name: template-builder
description: Use when building a client-site TEMPLATE in a NEW frontend-only Lovable project from design references — the data-driven, mail-merge-style marketing site that gets remixed per client. Supplies the client data contract (clients columns + template_vars + asset manifest), the data-loader/demo-object pattern, platform integration points (/api/public/intake, /api/public/r/), and hard rules (never hardcode business values, frontend-only, anon reads only). Import alongside website-structure (page set + 4 style voices). NOT for the shared backend (that's the platform project), NOT for per-client design generation or the page set (use website-structure), NOT for capturing onboarding data (use onboard-from-form).
---

# Template Builder — Create a Data-Driven Site Template from Design References

> **PURPOSE:** Import this skill into a NEW, FRONTEND-ONLY Lovable project to build a reusable client-site template. The human supplies design references (screenshots/links/style direction) + a niche; THIS SKILL supplies the data contract and platform wiring. The output is a mail-merge-style template: all visual design is yours to craft from the references; ALL business-specific content renders from a `client` data object — never hardcoded. One template, designed once, then remixed per client with zero AI edits.
>
> **The human's role after you build: proofread.** So get the wiring right from this skill, not from guesses.

## Hard rules [LOCKED]

1. **This project is frontend-only.** Do NOT enable Lovable Cloud, do NOT create any database, auth, or backend. The backend already exists (the shared platform project); this template only READS from it.
2. **NEVER hardcode business-specific values in components.** No literal business name, phone, tagline, services, hours, colors, or photos anywhere in component code. Every business-specific spot renders from the `client` object (contract below). Layout, spacing, typography, section structure, animations = hardcoded and universal. Content = variables. (Mail-merge model: design the letter, `{merge_fields}` for content.)
3. **Do not invent the data shape.** Use the exact contract in this skill. If a design calls for content the contract doesn't carry, render it from `client.template_vars.<new_key>` with a sensible fallback and FLAG it to the human (it becomes an onboarding-wizard field) — do not silently hardcode it.
4. **All platform URLs are fixed contracts:** lead form POSTs to `{platform API host}/api/public/intake` (the platform API host = the LOCKED env contract in the data loader §below); any tracked/funnel links use `/api/public/r/...` paths (top-level `/r/*` is auth-gated = dead for logged-out visitors — never use it). The site NEVER writes to the database directly — public writes go only through those `/api/public/*` endpoints.
5. **Anon reads only.** The data loader uses the anon key (RLS-scoped: active clients, public columns). Never request or reference a service-role key in this project.
6. **FINITE GENERATION — no build-time guessing [LOCKED].** Every page identity, route, env-var name, and the service-area / fonts / compliance-render rules are FIXED by the skills (the **canonical page registry** in `/website-structure` + the contracts in this skill). A template build MUST NOT improvise these — if a needed decision isn't covered, **FLAG it for a skill update rather than guessing**, so all templates stay congruent and per-client data populates predictably. (This is what makes generation finite: any template build resolves these the SAME way.)

## Layer model — Layout / Style / Niche [LOCKED — v2]

A client site composes THREE decoupled layers (+ branding + business data):
- **Layout / Template** — the reusable structural site shell (THIS project), built from a design, selectable by niche-fit. **NOT niche-labeled.**
- **Style** — a selectable PRESET (copy voice + photo selection/treatment) that fills the shell and gives it a feel. Set: **Family-Owned, Owner-Operated, Corporate/Professional, Modern Professional, Local Professional.** Reusable, not client-specific. In v1 the style is embodied IN this project (a `Template — {Style}` project); `clients.site_style` is the **template/style SELECTION key** (which project to remix) — **NOT a render-time branch.**
- **Niche** — a SEPARATE, selectable content/context layer (plumbing, roofing, HVAC, dentist…), applied onto ANY style/layout. **Pure DATA** — `template_vars.segment` + the niche-default fallback images + the two compliance category strings (`{customer_care_category}`/`{marketing_category}`), all keyed to the niche via the `/a2p-site-compliance` niche library (skill #14). The shell is niche-AGNOSTIC; never hardcode niche content.

**DECOUPLE niche from style:** any niche composes with any style → build styles once + grow the niche library independently = **N+M to maintain, not N×M.** Adding a niche works instantly across all styles; adding a style works instantly across all niches. Niche lives in `template_vars` (data-only) — do NOT add a `clients.niche` column.

## Baked-in compliance surface [LOCKED — from `/a2p-site-compliance`]

Compliance + Turnstile bake into the STYLE shell (this project), so every style × niche × client combination is compliant by construction. Reproduce VERBATIM from `docs/a2p-compliance-copy-source-of-truth.md` (tokens only — never paraphrase the compliance language):
- **Two-checkbox opt-in** on every lead form (lead, discount, chat-optin): both **unchecked by default + not a condition of service** (form submits without them); phone optional; fixed consent skeleton + `{customer_care_category}`/`{marketing_category}` from `template_vars`.
- **Named Privacy Policy + Terms of Service + SMS Program** pages (rendered from the canonical doc via tokens).
- **Footer** Privacy/Terms/SMS-Program links on EVERY page; all links working, no typos.
- **Working `/review` page** = the always-present "Review Us" page; loads + presents a working review action (CTA to `client.review_link`, optional comment POST to `/api/public/intake`) — no new backend route.
- **Cloudflare Turnstile widget** on all 3 lead forms with the agency PUBLIC site key; submit `turnstile_token` in the POST body. Backend is **fail-closed** → a form WITHOUT the widget = **zero leads.** (Build/test with the Cloudflare test keys; real keys set at launch.)

These render through `useClient()` from `template_vars` like all other content — data-only, **zero frozen-backend change** (`get_client_public` already projects `template_vars`).

## The client data contract (what the template renders from)

### Direct `clients` columns (fetched by slug)
| Field | Type | Used for |
|---|---|---|
| business_name | text | Header, title, footer, everywhere the name appears |
| tagline | text | Hero subheading |
| phone_display | text | Header CTA, contact section, click-to-call |
| email | text | Contact section |
| address | text | Contact/footer, map |
| license_number | text | Footer trust line (render only if present) |
| hours | jsonb | Hours section ({mon:["09:00","17:00"],...}) |
| logo_url | text | Header/footer logo (fallback: text-render business_name) |
| brand_color | text | THE theme color — apply as CSS var `--brand` site-wide (default #bd703e) |
| service_area | text[] | "Serving X, Y, Z" section/strip |
| social_links | jsonb | Footer/contact icons ({instagram, facebook, bbb, tiktok, yelp} — render only the present ones) |
| site_style | text | The **template/style SELECTION key** (which `Template — {Style}` project was remixed: Family-Owned / Owner-Operated / Corporate-Professional / Modern-Professional / Local-Professional). A label, **not a render-time branch** — this project already embodies one style. (Free text, not enum — see website-structure.) |
| (niche) | template_vars.segment | The **niche selection** (plumbing / roofing / …) — pure data; drives niche content/context + the two compliance category strings via the `/a2p-site-compliance` library. NOT a `clients` column. |
| brand colors | brand_color + template_vars | Primary = `clients.brand_color`; secondary/tertiary = `template_vars.brand_secondary`/`brand_tertiary` (optional). Captured at onboarding, agency-editable. |
| review_link | text | "Leave us a review" CTAs (direct Google link) |
| template_vars | jsonb | Everything below |

### `template_vars` keys (merge values shared with the SMS automations)
`company_owner_first_name`, `company_name`, `review_request_link`, `discount__on_referral`, `company_website_link`, `discount_amount`, `website_terms_page_link`, `quote_form_link` — plus site-content keys: `services` (array: [{name, slug, description, …}] — the services section LOOPS over this; never a fixed number of hardcoded cards), and any flagged additions (rule 3).

### Asset manifest (in template_vars or `site_assets` key)
Categorized media the wizard uploaded: `work_examples[]`, `services.{service_slug}[]`, `staff[]` (storage-bucket URLs). **Every image slot must have a fallback:** if a category is empty, render the niche-default images bundled with THIS template (pre-approved by the human, stored in the template's assets) — a client with zero uploads must still look complete and professional.

## The data loader (build this first)

One small module, e.g. `src/lib/client-data.ts`:
- Read `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY` (or publishable key), `VITE_CLIENT_SLUG` from `.env`.
- **Platform API host [LOCKED env contract — one name only]:** the host for all `/api/public/*` POSTs **defaults to the origin derived from `VITE_SUPABASE_URL`**; the ONLY override env var is **`VITE_PLATFORM_API_HOST`** (do NOT invent variants like `VITE_PLATFORM_HOST`). Resolve once: `host = VITE_PLATFORM_API_HOST ?? new URL(VITE_SUPABASE_URL).origin`. In **demo mode** (blank `VITE_CLIENT_SLUG`), public-write forms **no-op gracefully with a toast** ("Demo mode — submission disabled") — they do NOT POST and never error.
- If all present → fetch the client row: `GET {url}/rest/v1/clients?slug=eq.{slug}&select=*` with the anon apikey header. RLS permits anon SELECT on active clients' public columns — this is by design.
- If absent OR fetch fails → return the **demo client object** (below). The template must always render standalone during design.
- Expose one hook/provider (`useClient()`); every component renders from it. Components never know demo vs live.
- `.env` ships in the template with the real platform URL + anon key filled in (they're identical for every client) and `VITE_CLIENT_SLUG=` left as demo/blank. Per-client remix = change the ONE slug line. (.env stays committed — Lovable requires it; VITE_ values are build-time browser-safe publics.)

## The demo client object

Create `src/lib/demo-client.ts`: a fake business of the chosen niche (e.g. "Apex Plumbing"), shaped EXACTLY like the contract above — every column, all 8+ template_vars keys, a services array with 3-5 realistic entries, a manifest with some categories filled and at least one EMPTY (so fallback rendering is exercised during design). Realistic copy so the human evaluates real-looking design.

## Required page/section structure

Follow the **website-structure skill** (import it alongside this one) for the locked page set, the site-style copy voices, brand-color theming, fonts, and the two-mode design system. The design REFERENCES the human uploads govern look/feel/typography/layout aesthetics within that structure.

**Page identity is fixed by the canonical page registry in `/website-structure`** [Approach B]: each page has a stable **canonical id + route** (system-facing — use it for route files, data wiring, and cross-page links) and a set of **`allowed_display_labels`** (visitor-facing). The nav/heading label MAY use any allowed synonym to match the style/reference; the **id/route NEVER varies**, and NEVER invent a label outside the allowed set. Compliance pages (Privacy Policy / Terms of Service / SMS Program) have **FIXED labels** — do not flex them.

## Platform integration points (wire exactly)

1. **Lead form** → POST to `/api/public/intake` on the platform host (fields per the opt-in-forms skill; the backend resolves the tenant from the request Origin — the form does NOT send client_id; consent language + terms link from `template_vars.website_terms_page_link`).
2. **Quote/discount CTAs** → `template_vars.quote_form_link` / discount form per opt-in-forms.
3. **Review CTAs** → `client.review_link`.
4. **Phone CTAs** → `tel:` links from `phone_display`.
5. **NO chat widget wiring here** — the AI chat widget is injected per the chat-widget skill separately; just leave the standard mount point if the structure calls for one.

## Build workflow (the order matters)

1. Confirm frontend-only project; import this skill + website-structure (+ opt-in-forms for form fields).
2. Build the data loader + demo client object FIRST.
3. Design the site from the human's references, rendering everything through `useClient()` from day one (never "design hardcoded, convert later" — that's how hardcoded values survive into production).
4. Human iterates on design ("bolder hero", "different font") — these edits touch ONLY visuals; the variable wiring is untouched.
5. Self-check before handoff (the human will proofread, but verify first):
   - [ ] grep the components for the demo business's name/phone/etc. — ZERO literals outside demo-client.ts
   - [ ] every contract field above is rendered somewhere appropriate (or consciously unused)
   - [ ] services section loops (test: change demo services count → section adapts)
   - [ ] brand_color drives the theme (test: change demo color → site re-themes)
   - [ ] empty asset category renders fallbacks cleanly
   - [ ] lead form posts to /api/public/intake; all funnel paths use /api/public/r/*
   - [ ] missing/blank VITE_CLIENT_SLUG → demo renders; real slug → live data renders
6. Report what was built + any flagged new template_vars keys (rule 3) for the human to validate and add to the onboarding wizard.

## After validation (human-side, for reference)
Template is FROZEN (golden-master discipline — no per-client edits, ever; improvements are deliberate + versioned via CHANGELOG, reaching existing clients only by re-remix). Per-client use: Remix → rename → set VITE_CLIENT_SLUG → connect domain → add domain to allowed_origins in the platform admin (+ add the domain as a Turnstile hostname). See docs/client-onboarding-process.md for the full onboarding flow and docs/stage5-template-builder-build-spec.md for the layer model.

**Pre-generation happens in Project-1 admin, not here:** the onboarding submission assembles in the per-client admin view as a **pre-generation console** (selections + prefilled style + branding + the #14 A2P-prep pack) for the agency to review/edit before remixing, alongside an **immutable read-only record** of the original submission (logo + answers, stored in the `client-assets` bucket). Those are admin-app builds (`/admin-view`, `/onboard-from-form`); this template just renders the resulting client data.
