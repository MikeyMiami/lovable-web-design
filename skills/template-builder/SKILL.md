---
name: template-builder
description: Use when building a client-site TEMPLATE in a NEW frontend-only Lovable project from design references — the data-driven, mail-merge-style marketing site that gets remixed per client. Supplies the client data contract (clients columns + template_vars + asset manifest), the data-loader/demo-object pattern, platform integration points (/api/public/intake, /api/public/r/), and hard rules (never hardcode business values, frontend-only, anon reads only). Import alongside website-structure (page set + 4 style voices). NOT for the shared backend (that's the platform project), NOT for per-client design generation or the page set (use website-structure), NOT for capturing onboarding data (use onboard-from-form).
---

# Template Builder — Create a Data-Driven Site Template from Design References

> **PURPOSE:** Import this skill into a NEW, FRONTEND-ONLY Lovable project to build a reusable client-site template. The human supplies design references (screenshots/links/style direction) + a niche; THIS SKILL supplies the data contract and platform wiring. The output is a mail-merge-style template: all visual design is yours to craft from the references; ALL business-specific content renders from a `client` data object — never hardcoded. One template, designed once, then remixed per client with zero AI edits.
>
> **The human's role after you build: proofread.** So get the wiring right from this skill, not from guesses.
>
> **The template-lifecycle prompt set (canonical home: `docs/`)** — refer to these by name:
> - **`template-build-prompt-TEMPLATE.md`** — the MASTER doc. Contains **PROMPT 1** (build a brand-new template from scratch from design images — the single BUILD PARAMETERS edit block + fixed body), **PROMPT 1-R** (fork+restyle a remix into a new style), and **PROMPT 1-V** (targeted visual/design changes to an EXISTING blessed template, with the copy-ownership guardrails).
> - **`template-build-check-prompt.md`** — PROMPT 2, the in-Lovable acceptance audit (fallback route; costs credits).
> - **`template-claude-audit-runbook.md`** — Route A (default): Claude's free repo+preview audit, incl. the delta-audit mode for post-blessing design changes.
> Never hand-edit a previously FILLED prompt (stale niche/style carryover) — copy fresh from the master each time.

## Hard rules [LOCKED]

1. **This project is frontend-only.** Do NOT enable Lovable Cloud, do NOT create any database, auth, or backend. The backend already exists (the shared platform project); this template only READS from it.
2. **NEVER hardcode business-specific values in components.** No literal business name, phone, tagline, services, hours, colors, or photos anywhere in component code. Every business-specific spot renders from the `client` object (contract below). Layout, spacing, typography, section structure, animations = hardcoded and universal. Content = variables. (Mail-merge model: design the letter, `{merge_fields}` for content.)
   - **Route meta/SEO is part of the data-driven contract [LOCKED].** Each route's `head()` — `title`, `description`, `og:*` — must derive from the **LOADED client** (`business_name`, `template_vars.segment`, `services`, + the dynamic `$slug`/`$area` param), exactly like page bodies. **NEVER hardcode niche/business words in meta** (e.g. "landscape design", "hardscape"), and **NEVER `import` the demo client directly into a route file** for SSR meta — route meta flows through the **same client loader** (`useClient()` / the data-loader) as everything else. A remixed client's niche must flow into meta automatically. (This is where niche literals most often leak — the meta surface, not the body.)
3. **Do not invent the data shape.** Use the exact contract in this skill. If a design calls for content the contract doesn't carry, render it from `client.template_vars.<new_key>` with a sensible fallback and FLAG it to the human (it becomes an onboarding-wizard field) — do not silently hardcode it.
4. **All platform URLs are fixed contracts:** lead form POSTs to `{platform API host}/api/public/intake` (the platform API host = the LOCKED env contract in the data loader §below); any tracked/funnel links use `/api/public/r/...` paths (top-level `/r/*` is auth-gated = dead for logged-out visitors — never use it). The site NEVER writes to the database directly — public writes go only through those `/api/public/*` endpoints.
5. **Anon reads only.** The data loader uses the anon key (RLS-scoped: active clients, public columns). Never request or reference a service-role key in this project.
6. **FINITE GENERATION — no build-time guessing [LOCKED].** Every page identity, route, env-var name, and the service-area / fonts / compliance-render rules are FIXED by the skills (the **canonical page registry** in `/website-structure` + the contracts in this skill). A template build MUST NOT improvise these — if a needed decision isn't covered, **FLAG it for a skill update rather than guessing**, so all templates stay congruent and per-client data populates predictably. (This is what makes generation finite: any template build resolves these the SAME way.)

## Layer model — Layout / Style / Niche [LOCKED — v2]

A client site composes THREE decoupled layers (+ branding + business data):
- **Layout / Template** — the reusable structural site shell (THIS project), built from a design, selectable by niche-fit. **NOT niche-labeled.**
- **Style** — a selectable PRESET (copy voice + photo/visual treatment) that fills the shell and gives it a feel. The 6 definitive styles (display name → slug key): **Professional Modern** (`professional_modern`), **Artistic Unique** (`artistic_unique`), **Corporate** (`corporate`), **Modern Tech** (`modern_tech`), **Family Owned / Local Business** (`family_owned`), **Owner Operated / Local Business** (`owner_operated`) — voices + visual directions in `/website-structure`. Reusable, not client-specific. In v1 the style is embodied IN this project (a `Template — {Style}` project); the style/template selection is an **agency-side pick made outside the app** (2026-07-22: the client-facing onboarding choice + all app `site_style` plumbing were removed; the dormant `clients.site_style` column is never written) — the slug key just names which project to remix, **NOT a render-time branch.**
- **Niche** — a SEPARATE, selectable content/context layer (plumbing, roofing, HVAC, dentist…), applied onto ANY style/layout. **Pure DATA** — `template_vars.segment` + the niche-default fallback images + the two compliance category strings (`{customer_care_category}`/`{marketing_category}`), all keyed to the niche via the `/a2p-site-compliance` niche library (skill #14). The shell is niche-AGNOSTIC; never hardcode niche content.

**DECOUPLE niche from style:** any niche composes with any style → build styles once + grow the niche library independently = **N+M to maintain, not N×M.** Adding a niche works instantly across all styles; adding a style works instantly across all niches. Niche lives in `template_vars` (data-only) — do NOT add a `clients.niche` column.

## Baked-in compliance surface [LOCKED — from `/a2p-site-compliance`]

Compliance + the invisible native PoW bot-shield bake into the STYLE shell (this project), so every style × niche × client combination is compliant by construction. Reproduce VERBATIM from `docs/a2p-compliance-copy-source-of-truth.md` (tokens only — never paraphrase the compliance language):
- **Single-checkbox consent** on all three public forms (lead, discount, chat-optin) — the fixed MARKETING skeleton + `{marketing_category}` from `template_vars` (single-checkbox model 2026-07-22; the customer-care checkbox is gone). Lead form: **unchecked + not a condition of service** (submits without it, display-only) + **mobile phone REQUIRED / email optional**. Discount + chat-optin: the same skeleton as a **REQUIRED** checkbox (`consent: true`).
- **Named Privacy Policy + Terms of Service + SMS Program** pages (rendered from the canonical doc via tokens).
- **Footer** Privacy/Terms/SMS-Program links on EVERY page; all links working, no typos.
- **Working `/review` page** = the always-present "Review Us" page; loads + presents a working review action — a **CTA to `client.review_link`** (Google). **No comment box / no `/api/public/intake` POST** (intake hardcodes `source=web_form` and would create a fake lead enrolled in the lead-form drip). No new backend route. (Matches `/a2p-site-compliance` §C + the build-prompt master.)
- **Invisible native PoW bot shield** on all 3 forms (lead, discount, chat-optin) — challenge from `{platform host}/api/public/challenge` (POST with `{ slug }` body), solved in a Web Worker, submitted as `pow_token` (`challenge.sig.nonce`) + the hidden `website` honeypot input (off-screen positioning, NEVER `display:none`). Zero visible UI; fail-soft on the client. Backend is **fail-closed** → a form WITHOUT the shield = **zero leads.** (Turnstile is RETIRED 2026-07-22 — no widget, no keys, no `turnstile` imports anywhere; the backend still verifies legacy `turnstile_token` server-side only.)

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
| brand_color | text | THE primary theme color — apply as CSS var `--brand` site-wide. **When unset, DERIVE the palette from the ART-STYLE references** (dominant + accent); `#bd703e` is a **last-resort fallback only** (no references + no client colors). NOT a build-prompt parameter — comes from references (demo) or client data (live), never hand-entered. See `/website-structure` Brand-color theming. |
| service_area | text[] | "Serving X, Y, Z" section/strip |
| social_links | jsonb | Footer/contact icons ({instagram, facebook, bbb, tiktok, yelp} — render only the present ones) |
| site_style | text | **DORMANT (2026-07-22)** — never written or read; the template/style selection (which `Template — {Style}` project to remix) is an agency-side pick made outside the app. Slug set + voices/directions live in website-structure. |
| (niche) | template_vars.segment | The **niche selection** (plumbing / roofing / …) — pure data; drives niche content/context + the two compliance category strings via the `/a2p-site-compliance` library. NOT a `clients` column. |
| brand colors | brand_color + template_vars | Primary = `clients.brand_color`; secondary/tertiary = `template_vars.brand_secondary`/`brand_tertiary` (optional). Captured at onboarding, agency-editable. |
| review_link | text | "Leave us a review" CTAs (direct Google link) |
| template_vars | jsonb | Everything below |

### `template_vars` keys (merge values shared with the SMS automations)
`company_owner_first_name`, `company_name`, `review_request_link`, `discount__on_referral`, `company_website_link`, `discount_amount` — plus site-content keys: `services` (array: [{name, slug, description, …}] — the services section LOOPS over this; never a fixed number of hardcoded cards), and any flagged additions (rule 3). (NOTE: `quote_form_link` + `website_terms_page_link` are NOT in the required-keys list (removed 2026-07-23). `quote_form_link` is **fallback-only, no Settings editor** — blank derives from `company_website_link` at render; its verified consumer is the Missed-Call Textback SMS #1. `website_terms_page_link` is the site terms link, may stay blank. Neither should be treated as a must-fill site var.)

### Asset manifest (in template_vars or `site_assets` key)
Categorized media the wizard uploaded: `work_examples[]`, `services.{service_slug}[]`, `staff[]` (storage-bucket URLs). **Every image slot must have a fallback:** if a category is empty, render the niche-default images bundled with THIS template (pre-approved by the human, stored in the template's assets) — a client with zero uploads must still look complete and professional.

## The data loader (build this first)

One small module, e.g. `src/lib/client-data.ts`:
- **Platform connection = HARDCODED CONSTANTS, not `.env` [CORRECTED 2026-07-24 — LOCKED].** The shared-backend `SUPABASE_URL` + anon key are the SAME for every client forever (golden-master = one backend), so they are **constants** and belong in code, NOT `.env`. **Lovable's Remix process regenerates `.env` and STRIPS `VITE_SUPABASE_*`** (proven live) — so a template that reads them only from `.env` renders demo on every remix. Pattern: `const SUPABASE_URL = (import.meta.env.VITE_SUPABASE_URL ?? "").trim() || "https://onbhnkylzadyldpziapo.supabase.co";` (same for the anon key + `VITE_PLATFORM_API_HOST` → `https://app.pierceworks.co`). Only **`VITE_CLIENT_SLUG`** stays env-driven (it's the ONE per-client value; blank = demo, no fallback). Even more robust option: put the slug in a dedicated `src/lib/client-slug.ts` source constant so a remix touches NO `.env` at all.
- **Platform API host [LOCKED env contract — one name only]:** the host for all `/api/public/*` POSTs **defaults to the origin derived from `VITE_SUPABASE_URL`**; the ONLY override env var is **`VITE_PLATFORM_API_HOST`** (do NOT invent variants like `VITE_PLATFORM_HOST`). Resolve once: `host = VITE_PLATFORM_API_HOST ?? new URL(VITE_SUPABASE_URL).origin`. In **demo mode** (blank `VITE_CLIENT_SLUG`), public-write forms **no-op gracefully with a toast** ("Demo mode — submission disabled") — they do NOT POST and never error.
- **TWO SEPARATE FLAGS in `client-data.tsx` — do not merge them [LOCKED 2026-07-29]:** `isDemoMode()` (`SLUG.length === 0`) also **gates the live data fetch** in `fetchClient()`, so making it true for anything else makes the site render the built-in demo business instead of the real client. `isPreviewClient()` (`SLUG.startsWith("demo-")`) is submission-only and is checked as `isDemoMode() || isPreviewClient()` in LeadForm / DiscountForm / ChatWidget. **Why it exists:** agency **Demo Clients** (`/agency/demos`) mint slugs `demo-{name}-{rand}`; pointing a remix at one must render that prospect's REAL data (so `isDemoMode()` must stay false and the RPC fetch must happen) while the forms stay inert (the backend refuses a demo tenant with a 403, which would show a prospect an error toast). Never add `isPreviewClient()` into `fetchClient()`'s guard, and never widen `isDemoMode()`.
- If all present → fetch the client row: `GET {url}/rest/v1/clients?slug=eq.{slug}&select=*` with the anon apikey header. RLS permits anon SELECT on active clients' public columns — this is by design.
- If absent OR fetch fails → return the **demo client object** (below). The template must always render standalone during design.
- Expose one hook/provider (`useClient()`); every component renders from it. Components never know demo vs live.
- The real platform URL + anon key live as **hardcoded fallback constants in `client-data.ts`** (identical for every client; see the CORRECTED note above) — NOT relied on from `.env`, because Lovable's remix strips them. `VITE_CLIENT_SLUG=` ships blank (demo). **Per-client remix = set the ONE slug** (in `.env`, or a `client-slug.ts` constant). Also ship `package.json` `overrides: { "seroval": "^1.5.2" }` (or the current patched version) so the first publish isn't blocked by the dependency audit. (VITE_ values are build-time browser-safe publics; the anon key in code is fine — it's RLS-protected and already in every published bundle.)

## The demo client object

Create `src/lib/demo-client.ts`: a fake business of the chosen niche (e.g. "Apex Plumbing"), shaped EXACTLY like the contract above — every column, all 8+ template_vars keys, a services array with 3-5 realistic entries, a manifest with some categories filled and at least one EMPTY (so fallback rendering is exercised during design). Realistic copy so the human evaluates real-looking design.

## Required page/section structure

Follow the **website-structure skill** (import it alongside this one) for the locked page set, the site-style copy voices, brand-color theming, fonts, and the two-mode design system. The design REFERENCES the human uploads govern look/feel/typography/layout aesthetics within that structure.

**Fonts:** match the ART-STYLE reference imagery's typography as closely as possible (closest available web fonts); never the generic default — see `/website-structure` Fonts & type.

**Page identity is fixed by the canonical page registry in `/website-structure`** [Approach B]: each page has a stable **canonical id + route** (system-facing — use it for route files, data wiring, and cross-page links) and a set of **`allowed_display_labels`** (visitor-facing). The nav/heading label MAY use any allowed synonym to match the style/reference; the **id/route NEVER varies**, and NEVER invent a label outside the allowed set. Compliance pages (Privacy Policy / Terms of Service / SMS Program) have **FIXED labels** — do not flex them.

## Image rendering contract [LOCKED — shipped 2026-07-26]

Every client photo on the site is served through **Supabase Storage image transformations** (enabled on this backend; they resize, honor `resize=cover`, auto-negotiate WebP from the request's `Accept` header, and never upscale past the source). Measured effect: a 286 KB JPEG hero delivered as 43 KB of WebP at 640w.

1. **`src/lib/img.ts`** — the only place transformation logic lives:
   - `imgUrl(url, { width, height?, quality? })` — swaps `/storage/v1/object/public/` → `/storage/v1/render/image/public/`, appends `width`, adds `height` + `resize=cover` when a height is given, `quality` default 78. **Non-Supabase URLs (demo / niche-default stock) pass through untouched.**
   - `srcSet(url, widths, { aspect?, naturalWidth? })` — emits `"url Nw, …"`, **caps candidates at the source's natural width** (when every candidate exceeds it, emit exactly ONE at the cap), and **returns `""` for non-Supabase URLs** so callers omit the attribute rather than emitting duplicate candidates.
2. **`SiteImage`** (`src/components/site/SiteImage.tsx`) wraps `<img>` and is used for every client photo outside the content-page renderer: `{ url, alt, widths, sizes, aspect?, priority?, naturalWidth?, naturalHeight?, className?, style? }`. `priority` → `loading="eager"` + `fetchPriority="high"`; otherwise `loading="lazy"`. Always `decoding="async"`, always emit `width`/`height` (CLS). When `srcSet` returns `""`, omit **both** `srcSet` and `sizes`.
3. **Applied everywhere:** content-page hero (eager, `sizes="100vw"`, widths 640–2048, 16:9 server-side crop) and inline figures (lazy, widths 480–1024); plus the lander hero, the `/about` image and team photos, and every `/gallery` tile (widths 320–768).
4. **`og:image` stays the ORIGINAL object URL** — social scrapers want the full file, not a transformed variant.
5. **`PageImage.focal { x, y }`** (0–1, optional, default 0.5/0.5) → apply as `style={{ objectPosition: `${x*100}% ${y*100}%` }}` on hero + inline. This is how portrait/odd-ratio uploads crop safely; there is deliberately **no** subject detection.
6. **`SiteAsset` may carry `width`/`height`/`orientation`/`lowRes`** (the admin app records these at upload via canvas normalization and can backfill legacy assets). Pass `width` as `naturalWidth` to `srcSet`. A `galleryAssets()`-style helper returning the same ordered list as `galleryUrls()` but as full asset objects is the clean way to look this up per rendered URL.
7. **Layout invariants that make ANY client upload safe — keep these in any new design:** hero = fixed-height box (`h-[52vh] min-h-[380px]`) with absolute `object-cover`; inline images = `<figure className="aspect-[16/9] overflow-hidden">` + `object-cover` + an `onError` that hides the figure. A portrait upload can then never break spacing.
8. **Phone rendering:** format all **visible** phone text (`(419) 750-0242`); `tel:` hrefs and JSON-LD `telephone` stay E.164/digits.
8b. **iOS: set a DARK `html` background or you get a white bar pinned to the top on every phone [root-caused live 2026-07-27].** iOS Safari paints the `<html>` element's background into the regions it owns outside the document flow — behind the status bar/notch and in the pull-to-refresh overscroll area — and that region **stays pinned to the viewport while the page scrolls**. With a light `--background` inheriting up to `html`, that reads as a white bar above the header that never scrolls away, on mobile only (desktop has no such region), and it is invisible in the DOM — no fixed/sticky element exists to find. Fix: `html { background-color: <dark>; }` in `styles.css` (keep `body` on `--color-background` so in-viewport surfaces are untouched) plus a matching `<meta name="theme-color">`. Prefer the template's own dark tone over a neutral black so the status-bar region matches the interior header. **Do NOT add `viewport-fit=cover` as part of this fix** — it is not required, and it extends the layout viewport under the notch so a `top-0` header renders beneath the clock/battery unless you also add `padding-top: env(safe-area-inset-top)`. Symptom triage: "white bar, mobile only, above the header, stays put when scrolling" = this, not the logo, not the header (the header is `absolute` and DOES scroll away).
9. **Two conversion elements every template must ship [added 2026-07-27]:**
   - **Call-Now button** — `src/components/site/CallNowBar.tsx`, rendered INSIDE `Header.tsx`, horizontally centered between the logo and the nav links (**placement revised 2026-07-27** — it is a compact rounded-full pill, NOT a full-width strip, and is NOT mounted in `PageShell`/`HeroShell`; living in the Header already puts it on every page). Composition: small tracked label · thin divider · the number in the display serif, `whitespace-nowrap` on both. The whole pill is ONE `<a href={\`tel:${client.phone_e164}\`}>`; visible number = **`formatPhoneUS(client.phone_display)`** falling back to `phone_e164` (the formatter is REQUIRED — `phone_display` only normalizes on a Settings save and can hold raw digits); label = `resolveCopy("home.call_bar_label")`. **Returns `null` when `phone_e164` is blank** (never a dead `tel:` link). NOT sticky, NOT fixed. `aria-label="Call {business_name} at {display}"`. **MOBILE IS MANDATORY** — the phone is the only device that can place the call, so the pill must remain reachable below `md`. A `hidden md:` wrapper with no mobile counterpart is a DEFECT. **As-built pattern [FINAL 2026-07-27]:** exactly ONE `<CallNowBar />`, in the header bar, rendered at EVERY breakpoint — wrapper `flex flex-1 justify-center px-2 sm:px-6` inside a header row of `gap-2 px-4 py-6 sm:px-6 md:gap-6 md:px-10 md:py-7`. **No `fullWidth` prop and nothing in the mobile-menu dropdown** — two earlier builds tried desktop-only and then hamburger-menu placement; both were rejected (the first hides click-to-call from phones, the second buries the highest-intent action behind a tap). Fit at 360px comes from progressive sizing, not from hiding anything: label `text-[10px] sm:text-xs`, number `text-sm sm:text-base md:text-lg`, `gap-2 sm:gap-3`, `px-3 sm:px-5`, divider ALWAYS visible so it reads "Call Now | number" on a phone, `min-h-[44px]`.
   **⚠ CONTRAST TRAP — check the pill against EVERY surface it lands on.** The reference build shipped the pill at `oklch(0.18 0.012 150)`, which is byte-identical to the interior header background and 0.02 lightness off the mobile-menu background — so it read as a button only over the transparent hero header and visually merged everywhere else. A dark pill on a dark header is invisible-as-a-button even at 44px. **Shipped pattern to copy (reference template `fd8ee02`):** fill `bg-[var(--brand,oklch(0.28_0.02_150))]` + hairline `border border-white/15`, with the text tone derived from `readableForeground(client.brand_color)` in `src/lib/hex-to-oklch.ts` (returns `"light" | "dark"` at a relative-luminance threshold of `L > 0.55`; `"dark"` ⇒ `text-neutral-900`, else `text-white`, and the sub-label/divider opacities flip with it). **On the `var()` fallback:** `ThemeStyle` in `client-data.tsx` emits `--brand` only when `hexToOklch()` succeeds (`${primary ? \`--brand: ${primary};\` : ""}`), so a client with a missing/blank/unparseable `brand_color` gets no injected override — but `styles.css` already defines `--brand: oklch(0.22 0.012 150)` on `:root`, so `var(--brand)` still resolves and the pill is never background-less. The inline `var(--brand, …)` fallback is therefore defence-in-depth, not a fix for a live bug; keep it (it also guards a template whose stylesheet omits the `:root` default), and keep the fallback dark enough for white text since `readableForeground` returns `"light"` for an unparseable hex. **The real, verified trap in this component is CONTRAST, above — not a missing variable.**
   - **Hero chat CTA** — a `<button type="button">` directly under the homepage H1, label = `resolveCopy("home.cta_button")`, onClick `window.dispatchEvent(new CustomEvent("open-chat-widget"))` to open the EXISTING `ChatWidget` popup. Rendered ONLY when `client.chat_widget_enabled !== false`. Never build a second chat UI (`/chat-widget` §1b).
   Both labels are copy slots so the agency can retune them per client in Admin → Content; both defaults are LITERAL micro-copy ("Call Now" / "Chat with us now"), the only slots that don't compose from client data.

## Static-surface slot contract — `template_vars.site_slots` [LOCKED — shipped 2026-07-26]

The admin Photo Board assigns images to `content_pages` rows, but `/about`, `/gallery` and the team block are **static routes with no row**. Without an explicit contract they pick images *by index* out of the flattened `galleryUrls(site_assets)` list, which means JSON key order decides placement and the agency has zero control.

- Read the **optional, additive** key `template_vars.site_slots`: `{ about_image?: string; team?: string[]; gallery?: string[] }` (each value a photo URL).
- Resolution, with **every existing fallback preserved** so a client without the key renders exactly as before:
  - about image = `site_slots.about_image` → `galleryUrls[1]` → `galleryUrls[0]` → `work_examples[1]` → `NICHE_DEFAULTS`
  - team photos = `site_slots.team` (in order, when non-empty) → `validStaff.map(s => s.image)` → names-only
  - gallery grid = `site_slots.gallery` (in order, when non-empty) → `galleryUrls` → `work_examples` → `NICHE_DEFAULTS`
- **The lander hero is deliberately NOT in `site_slots`.** It resolves from the `home` content page's Photo-Board hero (`heroImg?.url ?? galleryUrls[0] ?? work_examples[0] ?? NICHE_DEFAULTS.hero`) — one source of truth per image, or the two drift.
- The app writes this key via an admin-gated server fn doing a **full read-merge-write of `template_vars`** (never a partial replace — locked rule).

## Absolute-URL origin + indexability [LOCKED — shipped 2026-07-26]

- `src/lib/site-url.ts`: `resolveSiteUrl()` = `VITE_SITE_URL` → `window.location.origin` (browser) → template constant (last resort). `isIndexableOrigin(origin)` = **false whenever `VITE_SITE_URL` is unset OR the host ends `.lovable.app`**.
- `pageHeadMeta` **forces** `robots: noindex,follow` when not indexable — a stored `index,follow` must never win. A **dynamic `src/routes/robots[.]txt.tsx`** replaces any static `public/robots.txt`: `Allow: /` only on an indexable origin, else `Disallow: /`, always with an **absolute** `Sitemap: ${origin}/sitemap.xml`. Never export a `SITE_URL` constant that could hardcode the template's own domain.
- **⚠ BUILD TRAP:** never import `@tanstack/react-start/server` (`getRequest`/`getURL`) from a module the CLIENT graph can reach — Start's import protection fails the production build even behind `typeof window === "undefined"` + `await import()`. Route **server handlers** (`server: { handlers: { GET: async ({ request }) => … } }`) *do* receive `request`, so `robots[.]txt.tsx` and `sitemap[.]xml.tsx` should use `new URL(request.url).origin`. Page `head()` cannot — accept the constant fallback (harmless while noindexed) or seed the origin into router context from the SSR entry.
- **⛔ Launch consequence:** `VITE_SITE_URL` is an indexing kill-switch. Until it is set on the remix **and republished** (env bakes at publish), the client's real domain serves `noindex` + `Disallow: /` on every page, silently.

## Platform integration points (wire exactly)

1. **Lead form** → POST to `/api/public/intake` on the platform host (fields per the opt-in-forms skill; the backend resolves the tenant from the request Origin — the form does NOT send client_id; consent language + terms link from `template_vars.website_terms_page_link`).
2. **Quote/discount CTAs** → `template_vars.quote_form_link` / discount form per opt-in-forms.
3. **Review CTAs** → `client.review_link`.
4. **Phone CTAs** → `tel:` links from `phone_display`.
5. **NO chat widget wiring here** — the chat widget (CAPTURE-FIRST lead form in a chat skin, no AI) is injected separately per `docs/chat-widget-inject-prompt.md` / the chat-widget skill; just leave the standard mount point if the structure calls for one.

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
Template is FROZEN (golden-master discipline — no per-client edits, ever; improvements are deliberate + versioned via CHANGELOG, reaching existing clients only by re-remix). Per-client use: Remix → rename → set VITE_CLIENT_SLUG → connect domain → add domain to allowed_origins in the platform admin. (Turnstile-hostname step retired 2026-07-22 — the forms run the invisible native PoW bot-shield, no hostname registry.) See docs/client-onboarding-process.md for the full onboarding flow and docs/stage5-template-builder-build-spec.md for the layer model.

**Pre-generation happens in Project-1 admin, not here:** the onboarding submission assembles in the per-client admin view as a **pre-generation console** (selections + prefilled style + branding + the #14 A2P-prep pack) for the agency to review/edit before remixing, alongside an **immutable read-only record** of the original submission (logo + answers, stored in the `client-assets` bucket). Those are admin-app builds (`/admin-view`, `/onboard-from-form`); this template just renders the resulting client data.
