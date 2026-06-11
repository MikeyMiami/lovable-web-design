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
4. **All platform URLs are fixed contracts:** lead form POSTs to `{VITE_SUPABASE_URL's host}/api/public/intake`; any tracked/funnel links use `/api/public/r/...` paths (top-level `/r/*` is auth-gated = dead for logged-out visitors — never use it). The site NEVER writes to the database directly — public writes go only through those `/api/public/*` endpoints.
5. **Anon reads only.** The data loader uses the anon key (RLS-scoped: active clients, public columns). Never request or reference a service-role key in this project.

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
| site_style | text | Which of the 4 copy voices this client uses (corporate / standard / family_owned / owner_operated — see website-structure skill) |
| review_link | text | "Leave us a review" CTAs (direct Google link) |
| template_vars | jsonb | Everything below |

### `template_vars` keys (merge values shared with the SMS automations)
`company_owner_first_name`, `company_name`, `review_request_link`, `discount__on_referral`, `company_website_link`, `discount_amount`, `website_terms_page_link`, `quote_form_link` — plus site-content keys: `services` (array: [{name, slug, description, …}] — the services section LOOPS over this; never a fixed number of hardcoded cards), and any flagged additions (rule 3).

### Asset manifest (in template_vars or `site_assets` key)
Categorized media the wizard uploaded: `work_examples[]`, `services.{service_slug}[]`, `staff[]` (storage-bucket URLs). **Every image slot must have a fallback:** if a category is empty, render the niche-default images bundled with THIS template (pre-approved by the human, stored in the template's assets) — a client with zero uploads must still look complete and professional.

## The data loader (build this first)

One small module, e.g. `src/lib/client-data.ts`:
- Read `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY` (or publishable key), `VITE_CLIENT_SLUG` from `.env`.
- If all present → fetch the client row: `GET {url}/rest/v1/clients?slug=eq.{slug}&select=*` with the anon apikey header. RLS permits anon SELECT on active clients' public columns — this is by design.
- If absent OR fetch fails → return the **demo client object** (below). The template must always render standalone during design.
- Expose one hook/provider (`useClient()`); every component renders from it. Components never know demo vs live.
- `.env` ships in the template with the real platform URL + anon key filled in (they're identical for every client) and `VITE_CLIENT_SLUG=` left as demo/blank. Per-client remix = change the ONE slug line. (.env stays committed — Lovable requires it; VITE_ values are build-time browser-safe publics.)

## The demo client object

Create `src/lib/demo-client.ts`: a fake business of the chosen niche (e.g. "Apex Plumbing"), shaped EXACTLY like the contract above — every column, all 8+ template_vars keys, a services array with 3-5 realistic entries, a manifest with some categories filled and at least one EMPTY (so fallback rendering is exercised during design). Realistic copy so the human evaluates real-looking design.

## Required page/section structure

Follow the **website-structure skill** (import it alongside this one) for the locked page set, the 4 site-style copy voices, brand-color theming, and the two-mode design system. The design REFERENCES the human uploads govern look/feel/typography/layout aesthetics within that structure.

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
Template is FROZEN (golden-master discipline — no per-client edits, ever; improvements are deliberate + versioned via CHANGELOG, reaching existing clients only by re-remix). Per-client use: Remix → rename → set VITE_CLIENT_SLUG → connect domain → add domain to allowed_origins in the platform admin. See docs/client-onboarding-process.md for the full onboarding flow.
