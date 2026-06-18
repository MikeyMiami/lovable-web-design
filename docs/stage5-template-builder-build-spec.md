# Stage 5 — Template-Builder / Niche-Template System: AUDIT + BUILD SPEC (v2 — corrected layer model)

> **Status:** AUDIT + SPEC only (no build code yet) — same loop as the 1f steps. **v2 (2026-06-17)** supersedes v1 (@ `6083124`): folds in the corrected **3-layer model** (Layout/Template · Style · Niche, with niche DECOUPLED), the **simple branding** model, and the **admin pre-generation console + immutable submission record**. Audit re-grounded against the real backend (`cloud-spark-setup` @ `c491623`).
>
> **Green-light condition (still holds):** the **template-builder itself is a separate frontend-only Lovable project** — it anon-reads `clients` + POSTs to `/api/public/*`, and is **ZERO change to the frozen golden master.** The a2p compliance surface bakes in via `template_vars` (jsonb, already projected by `get_client_public` — verified, strips `notification_email`).
>
> **HONEST CAVEAT (new in v2):** Corrections 2 & 3 (logo upload UX, brand-color capture, the pre-generation console, the immutable submission record) are **admin/onboarding work in Project 1**, NOT in the template project. Most of the *data* is data-only (template_vars + existing storage buckets, no migration), but the *UX* (file-upload widget, submission viewer, console assembly) is **additive admin-app code** that touches Project-1 surfaces → built as separate Stage-5 admin specs, re-validated + re-tagged per the post-freeze contract. **None of it alters frozen automation logic, schema, or RLS.** The template build below is independent of and unblocked by it.

---

## PART 1 — AUDIT FINDINGS (re-grounded against the real backend)

### 1.0 Backend evidence (from `cloud-spark-setup` @ `c491623`)
| Question | Verdict | Evidence |
|---|---|---|
| `template_vars` projected anon by `get_client_public` (strips `notification_email`) | **EXISTS** | `migrations/20260615202126_*.sql:18-36` — `(c.template_vars - 'notification_email')` |
| `clients.logo_url` + `brand_color` + `site_style` + `template_vars` + `allowed_origins` + `notification_email` | **EXIST** | `migrations/20260609034320_*.sql:50-64` (+ `…202126:3` notif_email) |
| `clients.niche` / `segment` column | **MISSING** | no column in migrations/types — niche is not a clients column today |
| Storage buckets `public-assets` (public read, admin write) + `client-assets` (private, client_id-scoped) | **EXIST** | `migrations/20260614222357_*.sql:29-55` |
| Logo **file-upload UI** + admin **image preview/download** | **MISSING** | `admin.settings.tsx:323` = a plain "Logo URL" text input (paste only); no `<img>` preview, no upload-to-storage |
| Immutable **onboarding submission record** (table or column) | **MISSING** | no `onboarding_submissions` table, no `clients.onboarding_*` column; admin writes parsed fields directly (`admin.settings.tsx:241-266`) |
| **Onboarding wizard** component | **MISSING** | only `admin.settings.tsx` (a field editor); no wizard, no assembled pre-gen console |
| Admin tabs | Dashboard, Contacts, Conversations, Feedback, Automations, Upload Customers, Number Pool, Settings | `src/routes/_authenticated/admin.*.tsx` |

### 1.1 The corrected 3-layer model — does the structure support it cleanly? **YES, data-only.**
- **LAYOUT / TEMPLATE** = the reusable structural site shell (a Lovable project, built from a design, selectable by niche-fit). **NOT niche-labeled.**
- **STYLE** = a selectable PRESET (copy voice + photo selection/treatment) that fills the shell and gives it a feel. Set of 6 (display → slug): **Professional Modern** (`professional_modern`), **Artistic Unique** (`artistic_unique`), **Corporate** (`corporate`), **Modern Tech** (`modern_tech`), **Family Owned / Local Business** (`family_owned`), **Owner Operated / Local Business** (`owner_operated`) — voices/directions in `/website-structure`. Reusable, NOT client-specific.
- **NICHE** = a SEPARATE, selectable content/context layer (plumbing, roofing, HVAC, dentist…), applied onto ANY style/layout. **Same niche concept as skill #14's niche library** — the niche selection drives BOTH the site's content/context AND the `{customer_care_category}`/`{marketing_category}` compliance strings, from that **one keyed source**, so they stay in sync.
- **DECOUPLING [the structural win]:** niche composes with any style → build the styles once + grow the niche library independently = **N+M to maintain, not N×M.** Adding a niche works instantly across all styles; adding a style works instantly across all niches.
- **How it maps to artifacts (v1):** the **STYLE TEMPLATE** is one frontend-only Lovable project = layout shell + style preset + **baked-in compliance + Turnstile** (see 1.4). The **NICHE is pure data** — `template_vars.segment` + the two category strings (from #14's library) + niche-default content/images. A client site = chosen style template (Remix) + chosen niche (data) + branding (data) + business data (data).
- **Zero-frozen-change confirmed:** niche lives in **`template_vars`** (NOT a new `clients.niche` column — that would be a migration). `template_vars.segment` + `template_vars.customer_care_category` + `template_vars.marketing_category` are anon-safe public content, projected as-is. **[FIX]** do NOT add a `clients.niche` column; use `template_vars.segment` as the niche selection key.
- **`site_style` = the template/style SELECTION key, NOT a render-time branch** (the v1 [FIX] stands). `site_style` is free text (not enum), so revising the value set to the 6 presets is convention/UI only — **no migration.**

### 1.2 Branding (Correction 2) — simple, mostly data-only; logo UX needs admin build
- **Brand colors:** onboarding captures **primary / secondary / third (optional)** + a fallback ("don't have brand colors? we'll create them"). Stored in **`template_vars`** (e.g. `brand_primary`/`brand_secondary`/`brand_tertiary`; `clients.brand_color` already holds the primary hex). **Data-only, no migration.** Agency-editable in admin (the Settings `template_vars` JSON editor + `brand_color` field exist today; a dedicated 3-color picker is a nicety **[BACKLOG]**).
- **Logo — storage layer EXISTS, UX PARTIAL:** `clients.logo_url` + `public-assets` bucket + public projection all exist. **MISSING:** (a) an onboarding/admin **file-upload-to-storage** flow (today it's URL-paste at `admin.settings.tsx:323`), and (b) an admin **image preview + download** per client. → "logo uploads somewhere" is true; **"I can grab this client's logo from their admin view" is NOT wired** — needs an admin-app build (upload to `public-assets` → set `logo_url` → render `<img>` + download link). **Additive admin UI; no schema/logic change.**

### 1.3 Admin pre-generation console + immutable submission record (Correction 3) — NEEDS BUILDING (Project-1 admin)
- **Pre-generation console:** there is **no onboarding wizard** and **no assembled console** today — only the per-field Settings editor. The "review/approve/edit before generation" surface (onboarding selections + prefilled style + branding + the #14 A2P-prep pack, all in one place) is **NEEDS-BUILDING** admin work, layered on the existing Settings editor + the (also-unbuilt) #14 A2P-prep panel.
- **Immutable submission record:** **NEEDS-BUILDING.** No raw as-submitted record is preserved. Two distinct things to model: **(a) the EDITABLE pre-generation config** (prefilled from the submission → the existing `clients`/`template_vars` write path) and **(b) the IMMUTABLE submission record** (read-only, for congruence cross-checking).
  - **Data-only path (RECOMMENDED — no migration):** write the raw submission (answers + logo reference) as a JSON object to the existing **`client-assets`** private bucket at `{client_id}/onboarding-submission.json`; the authenticated admin reads it back into a read-only viewer. **Keeps the immutable record OUT of anon-readable `template_vars` (it contains PII: owner name, shipping address, consent)** and needs **no new table/column.** What needs building = the write-on-submit + the admin read-only viewer (admin-app code).
  - **Alternative (migration):** a `clients.onboarding_submission jsonb` column or an `onboarding_submissions` table — additive but a Project-1 migration (re-validate + re-tag). **Prefer the storage-bucket path** to stay migration-free.

### 1.4 Compliance + Turnstile bake into the STYLE TEMPLATE (not the niche)
Every style template carries the full a2p compliance surface + the Turnstile widget. Since the niche composes onto any style template, **every style × niche × client combination is compliant by construction.** Surface (verbatim copy from `docs/a2p-compliance-copy-source-of-truth.md`, tokens only):
- Two unchecked/optional consent checkboxes — fixed skeleton + `{customer_care_category}`/`{marketing_category}` from `template_vars`.
- Named Privacy Policy (§B) + ToS (§A) + SMS Program page (§D).
- Footer Privacy/Terms/SMS-Program links on every page.
- Working `/review` page (1.6).
- Cloudflare Turnstile widget on all 3 lead forms (lead/discount/chat-optin), `turnstile_token` in the POST body — backend fail-closed, so no widget = zero leads.

### 1.5 Cross-project referencing — NOT the template→remix mechanism (unchanged from v1)
Template→client = **Lovable REMIX + `VITE_CLIENT_SLUG`**. Cross-project @-referencing (read-only) is the **build-time design-library-growth** mechanism (codify a winning style shell), not the per-client instantiation path. Not on the first template's critical path.

### 1.6 [BLOCKER-1] /review resolution — STILL HOLDS
The always-present "Review Us" page IS `{site_url}/review`: a **frontend** page that loads + presents a working review action (CTA to `client.review_link` / Google; optional comment box POSTing to the **existing** `/api/public/intake`). Satisfies "carriers may click it" with **no new backend route, no frozen change.** **[FIX]** relax skill #14 §C wording from "records a review internally" to "loads + accepts the review action" for the frontend-only v1; **[BACKLOG]** a real on-site review-capture route later.

---

## PART 2 — BUILD SPEC

### 2.1 What a STYLE TEMPLATE project contains
Frontend-only Lovable project `Template — {Style}` (e.g. `Template — Family-Owned`), built per skill #12 + website-structure, with the compliance surface baked in:
- **Foundation:** data loader (`client-data.ts`), demo client (`demo-client.ts`), `useClient()`, `.env` (platform URL + anon key filled, `VITE_CLIENT_SLUG` blank).
- **Page set:** website-structure always-present pages (+ SMS Program page) + data-driven service/area pages (looped, capped 12/14); brand-color theming from `template_vars` colors; the **style preset** (copy voice + photo treatment).
- **Compliance + Turnstile (1.4):** baked into the shell; verbatim copy via tokens.
- **Niche composition (data):** all niche-specific content/context (services framing, niche-default fallback images, the two consent-category strings) comes from `template_vars` + the asset manifest + #14's library — NOT hardcoded. The shell is niche-agnostic.

### 2.2 Token / data model (build time vs remix time) — all data-only
- **Build time:** the demo client carries every token (business data + a2p tokens + brand colors + `segment` + the 2 category strings) with realistic plumbing values, so the whole site (incl. compliance pages) renders real-looking.
- **Remix time:** tokens fill from the live `clients` row + `template_vars` (no AI). Fixed compliance language never changes; only tokens vary.
- **`template_vars` keys to populate at onboarding** (additive, jsonb, zero frozen change): `segment` (niche key), `customer_care_category`, `marketing_category` (from #14's library, keyed by `segment` → single source shared with the #14 admin A2P pack = byte-consistent), `privacy_url`, `terms_url`, `optin_url`, `support_email`, `effective_date`, `contact_person`, `brand_primary`/`brand_secondary`/`brand_tertiary`, plus the existing content keys. (`business_name`/`phone`/`address`/`email`/`logo_url`/`brand_color` are columns.)

### 2.3 Niche + style composition → remix
1. Onboarding records `site_style` (→ which style template to remix) + `segment`/niche (→ data layer).
2. **Remix** the chosen style template (exact copy).
3. Set `VITE_CLIENT_SLUG`; connect domain; add domain to `allowed_origins` (CORS) + as a Turnstile hostname.
4. The client's data (columns + template_vars incl. niche + a2p tokens + colors + asset manifest) fills every slot live.

### 2.4 Data: baked vs backend-read vs backend-write
| Baked into the style template | Read from backend (anon) | Written to backend (POST) |
|---|---|---|
| Layout shell, the style's copy voice + photo treatment | All `clients` columns by slug | Lead form → `/api/public/intake` |
| Fixed compliance skeleton (ToS/PP/SMS-Program structure, consent mechanics) | `template_vars` (a2p tokens, brand colors, **niche `segment` + 2 category strings**) | Discount → discount route |
| Turnstile widget markup (public site key) | Asset manifest; `logo_url`, `brand_color`, `review_link`, `social_links` | Chat opt-in → `/api/public/chat/optin` |
| Niche-default fallback images (per the shell's defaults) | `service_area`, `hours`, `site_style` (label) | (tracked/funnel → `/api/public/r/*`, backend domain) |

### 2.5 Buildable + testable NOW — the FIRST style template
**Build ONE reusable Family-Owned STYLE template, seeding Plumbing as the first niche** to prove style+niche+branding composition end-to-end. Family-Owned matches the Mike's Plumbing voice; plumbing is seeded in #14's niche library and the Mike's verbatim copy + logo are on hand. **The artifact is the reusable Family-Owned shell — NOT "the plumbing template."** Plumbing is just the demo-client niche data proving composition.

**Testable on the demo client:** all skill #12 self-checks (zero hardcoded literals, services loop, brand-color theme, asset fallbacks, demo-vs-live) + compliance checks (both consent checkboxes unchecked/optional + form submits without them; verbatim Privacy/ToS/SMS-Program render with demo tokens; footer links on every page; Turnstile widget on all 3 forms with `turnstile_token`; `/review` loads + has a working action; no literal `{token}` survives). STUB-appropriate — **no A2P submission** (this produces the compliant template only).

---

## PART 3 — BLOCKERS / EDGE CASES

- **[BLOCKER-1 — /review]** RESOLVED for v1: "Review Us" page = `{site_url}/review`, posts to existing `/api/public/intake`, no new route. **[FIX]** relax #14 §C wording; **[BACKLOG]** real review-capture route.
- **[BLOCKER-2 — submission record is NOT pure-data-only]** Preserving the IMMUTABLE as-submitted record can't go in `template_vars` (PII + must be immutable, but template_vars is anon-readable + editable). **Resolution (migration-free):** store as JSON in the existing private `client-assets` bucket (`{client_id}/onboarding-submission.json`); admin reads it. The **write-on-submit + admin viewer are admin-app builds** (Project 1, additive UI/server-fn, no schema/logic change). Flag: this is NOT in the template project and is a separate Stage-5 admin spec.
- **[FIX — skill #12 template-builder]** rewrite to the corrected 3-layer model: Layout/Template (shell) · Style (copy voice + photo preset, the bake target for compliance+Turnstile) · Niche (decoupled data layer from `template_vars` + #14 library); `site_style` = selection key (not render branch); add the baked compliance surface + Turnstile + `/review`; cross-ref `/a2p-site-compliance`.
- **[FIX — niche = template_vars, not a column]** use `template_vars.segment`; do NOT add `clients.niche` (avoids a migration). The 2 category strings come from #14's library → `template_vars` → read by both site + #14 admin pack (single source, anti-drift).
- **[FIX — logo UX]** admin needs file-upload-to-`public-assets` + image preview/download (today URL-paste only). Additive admin build.
- **[FIX — doc reconciles]** `workspace-knowledge-condensed` "Project 2 singular" → N style templates; website-structure 4 styles → the 6 style presets (copy voice + photo treatment) + niche decoupled (data-only, `site_style` free text — no migration); a2p §C /review wording relaxed.
- **[BACKLOG]** pre-generation console assembly (onboarding selections + style + branding + #14 A2P pack in one review surface); dedicated 3-color brand picker; onboarding wizard; template-library growth via cross-project referencing; additional niches (add #14 library rows + verbatim examples first); the other 4 style templates.
- **Prereq (restated):** Turnstile widget baked on every lead form (template) + per-client Turnstile hostname add at launch (launch-check §E).

---

## PART 4 — GREEN-LIGHT GATE
Audit clean for the **template build**: the 3-layer model is data-only and supported; compliance + Turnstile bake into the style shell with **zero frozen-backend change**; niche decouples cleanly via `template_vars` + #14's library; /review holds. The admin/onboarding pieces (logo UX, submission record, pre-gen console) are **separate, additive Project-1 Stage-5 builds** — they do NOT block or alter the template build. **→ Cleared to draft the Lovable build prompt for the first Family-Owned style template (Plumbing seed niche).**
