# Stage 5 — Template-Builder / Niche-Template System: AUDIT + BUILD SPEC

> **Status:** AUDIT + SPEC only (no build code yet) — same loop as the 1f steps (audit real artifacts → write spec → Lovable builds → validate → record). Written 2026-06-17. The template-builder is the FIRST Stage-5 productization piece; A2P/LIVE remain gated on TextGrid verification (HANDOFF §2), but the template work is **frontend-only and does NOT touch the frozen backend**, so it proceeds in parallel.
>
> **Core new requirement this spec adds:** the `a2p-site-compliance` skill requires EVERY client site to carry the compliance surface (two-checkbox opt-in, named Privacy/ToS, SMS Program page, footer links, working review page) + the Turnstile widget on every form. **The template is where that gets baked IN, once, so every per-client remix inherits it automatically — zero per-client compliance work.**

---

## PART 1 — AUDIT FINDINGS (reconciled against the real skills + docs)

### 1.1 What template-builder (skill #12) + `client-onboarding-process.md` already define
**The model is sound and stays:** a per-niche/style **frontend-only, data-driven, mail-merge** marketing site, designed once, then **Remixed** per client (exact copy, zero AI at remix). Concretely:
- **Frontend-only [LOCKED]:** no Lovable Cloud, no DB, no auth, no service-role. The template only READS the shared backend (anon, RLS-scoped) and POSTs to its `/api/public/*` routes.
- **Never hardcode business values:** layout/spacing/typography/section-structure = hardcoded + universal; ALL business content renders from a `client` data object via `useClient()`.
- **Data loader + demo client:** `src/lib/client-data.ts` reads `VITE_SUPABASE_URL` + anon key + `VITE_CLIENT_SLUG`; fetches `clients?slug=eq.{slug}`; falls back to `src/lib/demo-client.ts` so the template renders standalone during design.
- **The client data contract:** direct `clients` columns (business_name, tagline, phone_display, email, address, license_number, hours, logo_url, brand_color, service_area, social_links, site_style, review_link) + `template_vars` (jsonb merge keys, shared with the SMS automations) + an asset manifest (`work_examples[]` / `services.{slug}[]` / `staff[]`, every slot with a niche-default fallback).
- **Remix = two env vars:** copy the template, change `VITE_CLIENT_SLUG`, connect the domain, add the domain to `allowed_origins` in Project-1 admin. No AI, no skills at remix time — the code already embodies everything.
- **Freeze + golden-master discipline:** a validated template is frozen; improvements are versioned (CHANGELOG) and reach existing clients only via deliberate re-remix.

**GAP (the central finding):** skill #12 + the onboarding doc **predate `a2p-site-compliance` (skill #14)** and predate the 1f Turnstile work. They contain **no mention** of: the Turnstile widget, the two-checkbox compliance opt-in + verbatim consent, the named Privacy/ToS pages carrying the verbatim a2p copy, the SMS Program page, footer compliance links, or the working review page. Skill #12 rule 4 only says "consent language + terms link from `template_vars.website_terms_page_link`" — a single generic consent, **not** the carrier-required compliance surface. **This spec closes that gap by baking the compliance surface into the template.**

### 1.2 Project structure — confirmed clean separation
- **Project 1 = the frozen backend** = `cloud-spark-setup` (`golden-master-v1.6` @ `c491623`). Owns the DB, admin, tenant app, cron, drips, funnel routes. **Never remixed, never edited per client.**
- **Template projects = separate frontend-only Lovable projects** (`Template — {Niche} — {Style}`). Contain NO client data — only variable slots + a demo object. They **do NOT touch Project 1's code**; they anon-READ `clients` and POST to `/api/public/*`. ✅ **A template physically lives as its own Lovable project (GitHub-backed for backup); it is cleanly separate from the frozen backend and is NOT a backend fork.**
- **Per-client sites = Remixes of a template**, `.env` → Project 1. Frontend-only, anon reads + CORS-guarded POSTs. ✅
- **[FIX — doc reconcile] "Project 2" singular vs "N niche×style templates":** `workspace-knowledge-condensed.md` still says "Project 2 = lean marketing template" (early single-template framing); `client-onboarding-process.md` says "Template projects — one per niche×style." The **N-templates model is current** — fix the condensed-doc line.

### 1.3 What the per-client site must contain (website-structure + new-client-site + a2p-site-compliance) — the template must produce ALL of it
- **website-structure page set [LOCKED]:** Always-present — Home/Lander, Contact Us, Gallery, Thank You, Review + Referral Follow-up Form, Discount Funnel, Review Us, Terms & Conditions, Privacy Policy **(+ SMS Program page, per the a2p mirror line)**. Data-driven — Service page per service (max 12), Service-Area page per area (max 14). 4 site-style copy voices; brand-color theming (hex→oklch).
- **website-structure Turnstile prereq [1f step-3 dependency]:** every public lead-intake form (lead, discount, chat-optin) MUST render the Cloudflare Turnstile widget (public site key) + submit `turnstile_token`. Backend is **fail-closed** → a form without the widget = **zero leads**. **The template is where the widget is baked.**
- **a2p-site-compliance compliance surface (skill #14):** two unchecked/optional consent checkboxes (fixed skeleton + `{customer_care_category}`/`{marketing_category}` niche slots), named (not generic) Privacy Policy + ToS carrying the verbatim carrier copy, SMS Program page, footer Privacy/Terms/SMS-Program links on every page, a working review page. **Copy is reproduced VERBATIM from `docs/a2p-compliance-copy-source-of-truth.md` — tokens only.**

### 1.4 Lovable cross-project referencing — NOT the template→remix mechanism
Reconciled: there are **two distinct mechanisms**, and the docs occasionally blur them:
- **Template → per-client site = Lovable REMIX** (exact byte-for-byte copy) + change `VITE_CLIENT_SLUG`. This is the per-client instantiation path. **No @-referencing involved.**
- **Cross-project @-referencing (read-only)** = the **build-time, library-growth** mechanism (website-structure Mode-2 "bridge"): when authoring a NEW template, pull design patterns from a proven reference template via @mention. It is **design-codification across templates**, NOT how a client site is created.
- **Verdict:** the current plan uses Remix for template→client (correct). Cross-project referencing is reserved for growing the template library later and is **not on the critical path for the first template.**

### 1.5 Niche vs style — definition + the composition model
- **Niche = the content/context layer** (plumber vs roofer vs review-service): drives copy context + the niche-default fallback images + services framing + **the two `a2p` consent-category strings** (`{customer_care_category}`/`{marketing_category}`, keyed by `{segment}` in skill #14's niche library).
- **Style = the visual + copy-voice layer:** one of the 4 `site_style` voices (corporate / standard / family_owned / owner_operated) — steers both copy tone and visual feel.
- **Composition [reconciled — RECOMMENDED model]:** a template = **one niche × one style**, named `Template — {Niche} — {Style}`. The **style is baked into the template's crafted visual design + copy voice**; `clients.site_style` is the **template-SELECTION key** ("which template to remix," per onboarding-process step 2), not a render-time branch. A remix fills the variable slots with the client's data; niche + style are fixed by which template was remixed.
  - **[FIX — skill #12 wording]** skill #12 lists `site_style` as a rendered "which of the 4 copy voices this client uses" field, implying a render-time branch. Clarify: in the niche×style model it is the **selection key + label**; the template already embodies one style. (If a future lower-template-count model is wanted — one niche template that branches all 4 styles at render — document it explicitly; do NOT leave it ambiguous.)

---

## PART 2 — BUILD SPEC

### 2.1 What a template project contains
A frontend-only Lovable project (`Template — {Niche} — {Style}`) built per skill #12 + website-structure, **plus the baked-in compliance surface**:

**A. Foundation (skill #12, unchanged):** data loader (`client-data.ts`), demo client (`demo-client.ts`), `useClient()` hook, `.env` with the platform URL + anon key filled + `VITE_CLIENT_SLUG` blank.

**B. Page set (website-structure):** all always-present pages + data-driven service/area pages (looped from `template_vars.services` / `service_area`, capped 12/14), brand-color theme, the chosen style's voice/visuals.

**C. Baked-in compliance surface (NEW — from skill #14, verbatim copy via tokens):**
1. **Two-checkbox opt-in** on every lead form (lead, discount, chat-optin): both **unchecked by default + not a condition of service**; phone optional; the **FIXED compliance skeleton** + two niche slots:
   - "I consent to receive **{customer_care_category}** from {business_name}. Message frequency varies, up to 4 messages per month. Message & data rates may apply. Text HELP for assistance, reply STOP to opt out."
   - "I consent to receive **{marketing_category}** from {business_name} at the phone number provided. …"
2. **Privacy Policy page** — full verbatim render of canonical §B (IMPORTANT NOTICE header + §3 SMS section + SMS Data Protection Statement), tokens only.
3. **Terms of Service page** — full verbatim render of canonical §A (SMS Messaging clauses 1–8 + TCPA/CTIA line + general terms), tokens only.
4. **SMS Program page** — verbatim canonical §D.
5. **Footer** — Privacy / Terms / SMS Program links on **every** page; all links working, no typos.
6. **Working review page** — the always-present "Review Us" page serves as `{site_url}/review` (see §2.5 + [BLOCKER-1]); loads + presents a working review action.

**D. Turnstile widget (NEW):** rendered on all 3 lead forms with the agency PUBLIC site key; submit the token as `turnstile_token` in the POST body. (Backend enforcement already shipped at 1f step 3; the template supplies the widget.)

**E. Platform integration (skill #12, unchanged):** lead form → `/api/public/intake`; discount → discount route; review CTAs → `client.review_link`; phone → `tel:`; funnel/tracked links → `/api/public/r/*` (backend domain). NO direct DB writes.

### 2.2 The token model — build time vs remix time
The compliance copy is **just more variable slots** rendered through `useClient()` — same mechanism as all other content. No new wiring concept.
- **Build time:** the demo client object carries every a2p token (filled with realistic demo values, e.g. "Apex Plumbing") so the compliance pages render real-looking during design.
- **Remix time:** tokens fill from the live `clients` row + `template_vars` (no AI). The fixed compliance language never changes; only tokens vary.
- **Where the a2p tokens live [KEY DECISION — zero frozen-backend change]:** add the a2p token slots to **`template_vars` (jsonb)** — NOT new `clients` columns. `template_vars` is already projected wholesale by the `get_client_public` RPC (minus `notification_email`), is anon-safe public content, and is the existing shared merge-field set. Adding keys to a jsonb blob is a **data/onboarding-capture change with ZERO frozen-code change** (no migration, no RPC edit). New keys to populate at onboarding: `privacy_url`, `terms_url` (have `website_terms_page_link`), `optin_url`, `support_email`, `effective_date`, `contact_person`, `segment`, **`customer_care_category`**, **`marketing_category`** (+ business_name/phone/address/email already covered by columns/keys). All anon-safe — no owner PII (notification_email stays its dedicated column).
- **The two niche category strings = single source [FIX — anti-drift]:** `{customer_care_category}`/`{marketing_category}` are populated at onboarding **from skill #14's niche library (keyed by `{segment}`)** and stored in `template_vars`. Then BOTH the site form AND the admin A2P-prep panel (skill #14 §3) read the **same** `template_vars` values → byte-consistent (a carrier requirement). **The template never hardcodes divergent category copy.**

### 2.3 How niche + style compose into a remix
1. Onboarding records `niche` + `site_style` → tells the operator **which `Template — {Niche} — {Style}` to remix.**
2. **Remix** that template (exact copy).
3. Set `VITE_CLIENT_SLUG`.
4. Connect the client domain; add it to `allowed_origins` in Project-1 admin (CORS trust for form POSTs).
5. The client's data (columns + template_vars incl. a2p tokens + asset manifest) fills every slot live; niche + style are fixed by the template chosen.

### 2.4 Data: pulled from the backend vs baked into the template
| Baked into the template (universal) | Pulled from shared backend (anon read) | Written to backend (POST) |
|---|---|---|
| Layout, typography, section structure, animations | All `clients` columns (by slug) | Lead form → `/api/public/intake` |
| The chosen **style** visuals + copy voice | `template_vars` (incl. the a2p tokens + 2 niche category strings) | Discount form → discount route |
| **Niche-default fallback images** | Asset manifest (`work_examples`/`services.*`/`staff`) | Chat opt-in → `/api/public/chat/optin` |
| **Fixed compliance skeleton** (consent mechanics, ToS/PP/SMS-Program structure) | `brand_color`, `logo_url`, `review_link`, `social_links` | (tracked/funnel links → `/api/public/r/*`, backend domain) |
| **Turnstile widget markup** (public site key) | `site_style` (selection/label), `service_area`, `hours` | |

### 2.5 What's buildable + testable NOW (first reference template)
**Recommendation: build ONE reference template — Home-services / Plumbing niche × one style — now.** Rationale: plumbing is a **seeded niche in skill #14's library** (`{customer_care_category}`/`{marketing_category}` already defined from Mike's Plumbing), and the Mike's Plumbing ToS/Privacy verbatim copy + logo asset are on hand. Style recommendation: **Local Family-Owned** or **Owner-Operated Local** (matches the Mike's Plumbing voice); confirm with the operator. Do **not** pre-build a library — prove the loop on the first real niche, grow on demand (onboarding-process rule 7).

**Testable now (the self-check, extended):** all skill #12 checks (zero hardcoded literals, services loop, brand-color theme, asset fallbacks, demo-vs-live) **plus the compliance checks:**
- [ ] Both consent checkboxes render unchecked + optional; the form submits without them; the fixed skeleton is verbatim; the two category strings render from `template_vars`.
- [ ] Privacy / ToS / SMS Program pages render verbatim (demo tokens filled); footer links to all three on every page; no broken links / typos.
- [ ] Turnstile widget renders on all 3 forms; `turnstile_token` is in the POST body; a live test client's lead lands a contact (domain in `allowed_origins`).
- [ ] `{site_url}/review` loads + presents a working review action.
- [ ] No literal `{token}` survives to the rendered page (blank-on-missing is the failure mode; required a2p `template_vars` keys validated at launch — see launch-check).

---

## PART 3 — BLOCKERS / EDGE CASES

- **[BLOCKER-1 — review page "records internally"]** Skill #14 §C says the `/review` page "records a review internally." A **frontend-only** template **cannot write the DB directly**, and a brand-new generic public review route = a **frozen-backend change (NOT allowed without re-validate + re-tag).** **Resolution for v1:** the `/review` page = the existing always-present "Review Us" page; it must **load + present a working review action** (CTA to `client.review_link` / Google, optionally a comment box POSTing to the existing `/api/public/intake`). This satisfies "carriers may click it" with **no frozen-backend change.** **[FIX]** relax skill #14 §C wording to "loads + accepts the review action" for the frontend-only v1; **[BACKLOG]** a real on-site review-capture pipeline (new public route) when the review system is built.
- **[BLOCKER-AVOIDED — confirm]** a2p tokens via `template_vars` (jsonb) → **NO frozen-backend code change** (get_client_public already projects template_vars; adding jsonb keys is data-only). This is the green-light condition for "template work doesn't touch the golden master." Confirm all added keys are anon-safe public content (they are) so none belong in a PII column.
- **[FIX — skill #12]** add to template-builder: the Turnstile-widget rule, the two-checkbox compliance opt-in, the baked-in Privacy/ToS/SMS-Program pages (verbatim via tokens), the footer compliance links, the `/review` page, and a cross-ref to `a2p-site-compliance` + the canonical copy doc.
- **[FIX — niche-library sync]** the template's consent category strings MUST equal skill #14's niche-library row for the niche. Enforce by sourcing them from `template_vars` (filled from the library at onboarding) — ONE source, never hardcode divergent copy. If a niche isn't in skill #14's library, add the library row FIRST (DEFAULT block as fallback), then build/remix.
- **[FIX — doc reconcile]** condensed-doc "Project 2 singular" → "N niche×style templates"; skill #12 `site_style` "render field" → "selection key + label" (niche×style model).
- **[BACKLOG]** template-library growth via Lovable cross-project @-referencing (design codification); additional niches (add skill #14 library rows + Mike-style verbatim examples as needed); the 4-style coverage per niche.
- **Prereq (not a blocker, restated):** Turnstile widget on EVERY lead form + the client domain added as a Turnstile hostname at launch (website-structure / launch-check §E). The template bakes the widget; the per-client hostname add is a launch step.

---

## PART 4 — GREEN-LIGHT GATE
Audit is **clean**: the template model is sound, the project separation is confirmed, and the compliance surface can be baked **with zero frozen-backend change** (template_vars + existing public routes + frontend-only Turnstile). The only true blocker (BLOCKER-1) has a no-backend-change v1 resolution. **→ Cleared to draft the Lovable build prompt for the first reference template (Plumbing × style TBD) on the operator's go.**
