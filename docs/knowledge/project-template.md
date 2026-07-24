# Marketing-Site TEMPLATE (style shell → client Remixes)

This project is a frontend-only marketing-site TEMPLATE. Per-client sites are exact REMIXES of it — this code is the master for every future client site of this style. Workspace rules apply, especially: frontend-only, data is LIVE, no service-role.

## The contract [LOCKED]
- **Platform connection = HARDCODED CONSTANTS in `src/lib/client-data.tsx`, NOT `.env` [LOCKED 2026-07-24].** `SUPABASE_URL`, the anon key, and the API host (`https://app.pierceworks.co`) are the same for every client forever, so they live as hardcoded constants (with an `import.meta.env.X ?? "hardcoded"` fallback). This is deliberate: **Lovable's Remix regenerates `.env` and strips `VITE_SUPABASE_*`**, so relying on `.env` for them = demo mode on every remix. The API host matters because the supabase origin 404s `/api/public/*` and the lovable.app host 302s (breaks CORS preflight) — only the app custom domain answers. `package.json` carries a `seroval` override so the first publish clears the dependency audit.
- **The ONLY per-remix change = the slug** (`VITE_CLIENT_SLUG` in `.env`, blank = demo; or a `client-slug.ts` source constant). Nothing else in `.env` matters.
- NEVER hardcode a specific client's name, copy, phone, images, or data into code. Everything client-specific renders from live data at page load (`get_client_public` RPC + content-page RPCs + template_vars). The same code must serve ANY client.
- No DB writes, no service-role, no DB-touching server fns. Public writes = POSTs to `{VITE_PLATFORM_API_HOST}/api/public/*` only; the tenant is resolved server-side from the request Origin (the site's domain must be in the client's `allowed_origins`) — NEVER send client_id in a request body.

## Data the site renders (all LIVE per page load)
`get_client_public`: business identity (name, phone_display, hours, address), branding (logo_url, brand_color + `template_vars.brand_secondary/tertiary`), template_vars (`services` array — LOOP over it, never a fixed number of hardcoded cards; `about_us`; `differentiators`; `lead_form_headline/subhead/cta`; `chat_widget_greeting/confirmation`; consent/category tokens), social_links, review config, `chat_widget_enabled`. `content_pages` rows drive the SEO pages — generic renderers (home / category / service / geo / supporting) + sitemap from the store.

## Forms (3: lead / discount / chat-optin) [LOCKED]
- ONE shared lead-form component drives BOTH the hero-embedded card and `/contact`. Phone REQUIRED, email optional. Copy from `template_vars.lead_form_*`.
- SINGLE consent checkbox (marketing skeleton), UNCHECKED + optional, verbatim a2p compliance copy; terms link → the on-site terms page.
- Invisible PoW bot-shield on ALL forms: mint at `{HOST}/api/public/challenge` → solve in a Web Worker → submit `pow_token` + the hidden `website` honeypot field. No visible widget. A form missing the shield = zero leads (backend is fail-closed).
- Chat widget = capture-first lead form in a chat skin (NO AI); render the bubble when `chat_widget_enabled`; posts `/api/public/chat/optin` (consent REQUIRED there).

## Required pages
Home (hero + embedded lead form), Contact, Gallery, Thank You, Discount Funnel, Review Us, ToS, Privacy, SMS Program (compliance copy VERBATIM from the a2p source doc), the content_pages renderers, and **`/review/$token` → 302 → `https://reviewbatch.com/api/public/r/$token`** (the review-link redirect — never remove; it is what makes review SMS links work on the client's own domain). Footer on every page: named Privacy / ToS / SMS-Program links, socials, business identity.

## Design
Theme from `brand_color` (+ secondary/tertiary) injected in the shell head; this template's style preset is its identity — keep its layout/spacing system consistent. Hero lead form: the header block owns the spacing to the form. No lorem/placeholder text in committed code — demo mode (blank slug) renders the demo dataset.

## Testing
In-editor iframe origins are ephemeral and CORS-blocked BY DESIGN — test forms only from the stable PUBLISHED origin, after adding it to the client's `allowed_origins` in the app's admin Settings. If client data renders blank: the slug is wrong, the client isn't `status='active'`, or the origin isn't allowlisted.
