# Lovable Build Prompt — First STYLE Template: "Family-Owned" (Plumbing seed niche)

> **What this is:** the copy-paste build prompt + setup steps for the FIRST Stage-5 style template. The artifact is the **reusable Family-Owned style shell** (layout + copy voice + photo treatment + baked compliance/Turnstile) — NOT "the plumbing template." Plumbing is only the **demo-client niche data** proving style+niche+branding composition end-to-end. STUB-appropriate; **no A2P submission** (this produces the compliant template only). Sanity-check against `docs/stage5-template-builder-build-spec.md` (v2) before running.

## Setup (do before prompting)
1. **New Lovable project, frontend-only** — decline Cloud/DB/auth. Name it **`Template — Family-Owned`**.
2. **Import skills** (GitHub subdirectory URLs): `template-builder`, `website-structure`, `opt-in-forms`, `a2p-site-compliance`.
3. **Attach references:** the Family-Owned design references (screenshots/links) + the Mike's Plumbing logo (`Mike-Logo-New-1.webp`) for the demo client.
4. **`.env`:** set `VITE_SUPABASE_URL` + anon key to the shared platform (Project 1) values; leave `VITE_CLIENT_SLUG=` blank (demo mode).
5. **Turnstile:** use the **Cloudflare test keys** (always-pass site key `1x00000000000000000000AA`) — no real keys in the template.

## The build prompt (paste into Lovable)

> Build a **frontend-only, data-driven client-site TEMPLATE** per the imported `template-builder` + `website-structure` + `a2p-site-compliance` skills. This is the reusable **Family-Owned STYLE** shell; the **niche is a separate data layer** (we're seeding **plumbing** via the demo client to prove composition — do NOT hardcode anything plumbing-specific into components).
>
> **Hard rules (from template-builder):** frontend-only — no Lovable Cloud, no DB, no auth, no service-role. Build the **data loader (`src/lib/client-data.ts`) + demo client (`src/lib/demo-client.ts`) + `useClient()` hook FIRST**, then design everything rendering through `useClient()`. NEVER hardcode business-specific values (name, phone, tagline, services, hours, colors, logo, photos, niche content) — layout/spacing/typography/section-structure are universal; all content is variables. Anon reads only; if `VITE_CLIENT_SLUG` is blank/fetch fails → render the demo client.
>
> **Style — Family-Owned:** warm, community-rooted, personal copy voice; photo treatment favoring real team/owner + local work photos. Apply this as the shell's voice + visual feel (universal, not per-client).
>
> **Branding from data:** theme from `client.brand_color` (primary; default `#bd703e`) + `client.template_vars.brand_secondary`/`brand_tertiary` if present (convert hex→oklch for theme tokens); logo from `client.logo_url` (fallback: text-render `business_name`).
>
> **Page set (website-structure):** Home/Lander, Contact Us, Gallery, Thank You, Review + Referral Follow-up Form, Discount Funnel, Review Us, Terms & Conditions, Privacy Policy, **SMS Program**; data-driven Service pages (loop `template_vars.services`, max 12) + Service-Area pages (loop `service_area`, max 14). Service-area pages = the lander re-focused per area.
>
> **Compliance surface (a2p-site-compliance — reproduce copy VERBATIM from `docs/a2p-compliance-copy-source-of-truth.md`, fill `{tokens}` only, NEVER paraphrase):**
> - **Two consent checkboxes** on every lead form (lead form, discount form, chat opt-in): both **unchecked by default and NOT required** (the form submits without them); phone field optional. Use the FIXED skeleton + `client.template_vars.customer_care_category` / `client.template_vars.marketing_category`: *"I consent to receive {customer_care_category} from {business_name}. Message frequency varies, up to 4 messages per month. Message & data rates may apply. Text HELP for assistance, reply STOP to opt out."* (and the marketing variant).
> - **Privacy Policy page** = verbatim canonical §B (IMPORTANT NOTICE header + SMS section + SMS Data Protection Statement), tokens only.
> - **Terms of Service page** = verbatim canonical §A (SMS Messaging clauses 1–8 + TCPA/CTIA line + general terms), tokens only.
> - **SMS Program page** = verbatim canonical §D.
> - **Footer on EVERY page** links to Privacy / Terms / SMS Program; no broken links, no typos.
> - **`/review` page** = the "Review Us" page: loads + presents a working review action (CTA to `client.review_link`; optional comment box POSTing to `/api/public/intake`). No new backend route.
>
> **Turnstile (website-structure prereq):** render the Cloudflare Turnstile widget (use the test site key `1x00000000000000000000AA`) on all 3 lead forms and include the resulting token as `turnstile_token` in the POST body. Backend is fail-closed — a form without the widget/token = zero leads.
>
> **Platform integration (fixed contracts):** lead form → POST `{platform host}/api/public/intake` (tenant resolved server-side from Origin — do NOT send client_id; consent + terms link from `template_vars`); discount form → the discount route; review CTAs → `client.review_link`; phone → `tel:` from `phone_display`; tracked/funnel links → `/api/public/r/...`. NO direct DB writes; leave a chat-widget mount point only (widget injected separately).
>
> **Demo client (`demo-client.ts`) — a plumbing business** shaped EXACTLY like the contract: every `clients` column + all `template_vars` keys including `segment: "Home services / Plumbing / HVAC / Trades"`, `customer_care_category` + `marketing_category` (the seeded plumbing strings from the a2p niche library), `privacy_url`/`terms_url`/`optin_url`/`support_email`/`effective_date`/`contact_person`, `brand_secondary`/`brand_tertiary`, a `services` array of 3–5 realistic plumbing services, and an asset manifest with some categories filled and **at least one empty** (to exercise niche-default fallback images). Use the Mike's Plumbing logo + realistic copy so the design + compliance pages render real-looking.
>
> **Self-check before handoff:** zero hardcoded business/niche literals outside `demo-client.ts`; services section loops (change demo count → adapts); brand color re-themes; empty asset category → fallback renders; both consent checkboxes unchecked + optional + form submits without them; Privacy/ToS/SMS-Program render verbatim with demo tokens; footer links on every page work; Turnstile widget on all 3 forms with `turnstile_token`; `/review` loads + has a working action; **no literal `{token}` survives to any rendered page**; blank slug → demo renders, real slug → live data renders.

## Testable on the demo client (no live backend needed)
Everything in the self-check renders standalone in demo mode. To test LIVE data: set `.env` `VITE_CLIENT_SLUG` to a test client in Project 1 (with the seed `template_vars` keys populated) → every field + compliance page fills from their data; a lead-form submit lands a contact (test client's domain in `allowed_origins`). **No A2P submission** in this build.

## Freeze
After validation, GitHub-connect for backup; this `Template — Family-Owned` project is the remixable golden master for the Family-Owned style. New niches (roofing, HVAC, …) need NO change to this project — they're added as data (`template_vars.segment` + an a2p niche-library row); they compose onto this style automatically.
