# Phase C — C-3 Onboarding Wizard — major revision pass (33 items)

> Captured 2026-06-21. Line-by-line mapping of all 33 corrections + the 3 deep dives (#14 styles, #28 timing-hours, #33 image routing) + the contract/schema flags. **Build held until sign-off** on the deep-dive scope items (esp. #33). Files in play: `src/routes/_authenticated/onboard.tsx`, `src/lib/clients/onboarding.functions.ts`, + a NEW public-assets upload helper.

## Contract / schema impact — the punchline
- **ZERO schema changes.** Everything lands in existing destinations (`clients` columns, `template_vars` jsonb [open], `submission` jsonb [open], `send_settings`, storage buckets).
- **ONE fn-contract change:** #14 — update the `siteStyle` enum in `ClientFields` from the old 4 (`corporate/standard/family_owned/owner_operated`) to the finalized 6 slugs. (`site_style` DB column is free text — no migration.)
- **Already shipped:** #8 depends on the `hours` field added to `ClientFields`/`clientPatch` (the prior tweak).
- **Net-new app-layer file:** a **public-assets** upload helper (the logo + site photos need `public-assets`, admin-write; `ticket-upload.ts` targets `client-assets`). UX/thumbnail reused, bucket differs.
- Everything else = `onboard.tsx` UI + assembly changes; new captured values flow through the **open** `templateVars`/`submission` records → no contract change.

## Proposed step structure AFTER the revision (was 10 steps)
1. **Identity** · 2. **Content** (+ public hours + timezone) · 3. **Branding** · 4. **Industry & Style** · 5. **Photos** (categorised) · 6. **Reviews** (just the Google review link) · 7. **Returning-Customer Discount** · 8. **Texting registration (A2P)** · 9. **Review & Create**.
→ The old **Step 8 Config collapses** (everything removed except timezone, which moves into Content). Net: **9 steps**.

---

## Line-by-line mapping (all 33)

### Step 1 · Identity
| # | Change | Where / mapping | Contract? |
|---|---|---|---|
| 1 | Owner full name — append to hint: *"This can be adjusted later if needed."* | hint text only | no |
| 2 | Business name — reword hint: *"…It appears on your website, can sometimes appear in text automations, and is how your AI chat assistant identifies you to help customers on your website."* | hint text only | no |
| 3 | **Slug — HIDE from UI**; keep silent auto-derive + in payload | remove the visible `<Field>`/`<Input>`; keep `slugTouched`/`slugify` deriving into `s.slug`; still send `slug` | no |
| 4 | Business phone → **rename "Personal Cell / Personal Business Number"**; hint: *"Your real phone number, where missed calls can be set to forward to, and so we can send you updates about your website. This is NOT the number shown publicly on your website."*; **no country code input** (mask `(305) 555-0142`), store **E.164 `+1…`** via the existing `normalizePhone` on assembly | `clients.call_forwarding_number`; UI mask + normalize-on-save (call-forwarding `<Dial>` needs E.164) | no |
| 5 | Display address — reword: *"…Be sure to include street, city, state, zip. Also helps your local search ranking."* | `clients.address`; hint only | no |
| 6 | Website → **rename "Website Domain"**; **"I don't have a domain" button** → reveal: field *"Do you have a preferred website domain you'd want? Example: mikesplumbing.com"* + button *"Just get me the closest domain to my business name."* Both just RECORD the request (no live search). Has-domain hint: *"Your current website domain if you already have one. Example: evergreenlandscape.com"* | has-domain → `template_vars.company_website_link`; **domain request/preference → `submission.domain_request` `{ hasDomain, preferred, wantsClosest }`** (private agency action item) | no (submission open) |
| 7 | Notification email — tag "agency"→**"business"**; append hint: *"(alerts also show in your app, this can be turned off later)"* | `clients.notification_email`; tag + hint | no |

### Step 2 · Content
| # | Change | Where / mapping | Contract? |
|---|---|---|---|
| 8 | **Public business hours picker** — Sat & Sun show selectable times **by default** (same as weekdays), not blank/closed-assumed | `clients.hours` via `fields.hours` (the shipped tweak); picker outputs `{"mon":["09:00","17:00"],…}`; default-populate all 7 days, user toggles closed | no (hours field already added) |
| — | *(also here: timezone field moved from old Step 8 — see #28)* | `send_settings.timezone` | no |

### Step 3 · Branding
| # | Change | Where / mapping | Contract? |
|---|---|---|---|
| 9 | **Logo — REPLACE URL field with image upload + preview** (reuse the ticket upload+thumbnail UX). Upload → **`public-assets`** at `<client_id>/logo/<uuid>-<file>`; set `clients.logo_url` = its public URL | NEW public-assets upload helper; `fields.logoUrl` = public URL | no (logoUrl exists) — **flag: net-new helper + bucket = public-assets (admin-write)** |
| 10 | Logo **"I don't have a logo"** → reveal *"Would you like us to make one for you for your website? Yes / No."* Record | `submission.logo_request` `{ needsLogo, makeForMe }` | no |
| 11 | Colors — **draggable spectrum/gradient picker** auto-filling hex as you drag (each of primary/secondary/tertiary) | `clients.brand_color` + `template_vars.brand_secondary`/`brand_tertiary`; UI component only | no |
| 12 | Colors **"not sure"** (above the pickers): *"Not sure which colors to choose? Select here and we will choose them for you based on what looks best with your business."* Record | `submission.color_request` `{ chooseForMe }` | no |

### Step 4 · Industry & Style
| # | Change | Where / mapping | Contract? |
|---|---|---|---|
| 13 | Niche → **rename "Business Industry / Niche"**; example *"(Plumber, Pet Groomer, Roofer, Phone Repair, etc.)"* | `template_vars.segment`; label/example | no |
| 14 | Site style → **the finalized 6 template styles** (deep dive below); **also update the `ClientFields` `siteStyle` enum** to the 6 slugs. *(FUTURE: per-style preview images — note, don't build.)* | `clients.site_style` (free text); **`onboarding.functions.ts` enum change** | **YES — fn enum (app-layer, no schema)** |

### Step 5 · Photos *(depends on #33 sign-off)*
| # | Change | Where / mapping | Contract? |
|---|---|---|---|
| 15 | **Separate categories**, each with ticket-style upload+preview (rounded square + upload icon → thumbnail): **Previous work, Gallery, About, Services, Staff** | uploads → `public-assets` `<client_id>/<category>/…`; manifest → `template_vars.site_assets` | no (site_assets = open template_vars) — **flag: net-new manifest + helper (#33)** |
| 16 | **Staff** — per member: image + name + position, repeatable | `template_vars.site_assets.staff = [{ name, position, path, url }]` (public — staff render on About) | no |
| 17 | Categories **tag photos** so they route to the right site sections | the `site_assets` manifest keys = the categories (placement at template-build time — see #33) | no |
| 18 | Top option: *"Don't have photos? That's okay. Select here and we will design this section for you."* Record | `submission.photo_request` `{ designForMe }` (+ optionally per-category flags) | no |

### Step 6 · Reviews
| # | Change | Where / mapping | Contract? |
|---|---|---|---|
| 19 | Google review link — hint mentions *the link to leave a review on your Google My Business profile* | `clients.review_link`; hint | no |
| 20 | **REMOVE** star threshold, review-gate toggle, direct review URL from the form (agency-view-only; keep DB defaults `star_threshold=4`, `google_review_toggle=gated`; `review_request_link` auto-derives = `review_link`) | stop sending `starThreshold`/`googleReviewToggle`/`reviewRequestLink`; defaults apply | no |

### Step 7 · Returning-Customer Discount
| # | Change | Where / mapping | Contract? |
|---|---|---|---|
| 21 | Section title → **"Returning Customer Discount Offer."** | UI | no |
| 22 | Reword: *"When we follow up with your past customers, you can offer a discount as an incentive for repeat business. What would you like the discount amount to be? Example: 5% off your next job!"* | `template_vars.discount__on_referral`; copy | no |
| 23 | Discount amount — clarify it's just the exact number/value of the discount | `template_vars.discount_amount`; hint | no |

### Step 8 · Config — collapses (see #28 deep dive)
| # | Change | Where / mapping | Contract? |
|---|---|---|---|
| 24 | **REMOVE** SMS window start/end (agency default; DB default 9–7) | stop sending `smsSendWindow` | no |
| 25 | **REMOVE** daily send cap + enrollment cap (DB defaults 500/50) | stop sending those | no |
| 26 | **REMOVE** marketing domains | stop sending `allowedOrigins` | no |
| 27 | **REMOVE** quote-form link + terms link (site doesn't exist yet) | stop sending `quoteFormLink`/`termsLink` | no |
| 28 | **DROP** the private timing-hours field; **DERIVE** `send_settings.business_hours` from the public hours (#28 deep dive) | assembly: `sendSettings.businessHours = fields.hours` | no (fixes the `{raw}` bug) |
| — | **Result:** only **timezone** remains → move it into Step 2; **delete the standalone Config step** | `send_settings.timezone` | no |

### Step 9 · A2P
| # | Change | Where / mapping | Contract? |
|---|---|---|---|
| 29 | **EIN required** to advance | UI validation; `submission.ein` | no |
| 30 | **All A2P fields required** to advance **EXCEPT DBA** | UI validation | no |
| 31 | **REMOVE Entity type** (always the same for us) | remove field + `submission.entityType` | no |

### Step 10 · Review & Create
| # | Change | Where / mapping | Contract? |
|---|---|---|---|
| 32 | **No raw JSON dump** — render a readable, grouped, filled-out proofread summary **including logo + photo thumbnails** | UI: build a summary view from state + preview the uploaded `public-assets` URLs | no |

### Cross-cutting
| # | Change | Where / mapping | Contract? |
|---|---|---|---|
| 33 | **Image routing / custom values** — deep dive below; store + organize via `template_vars.site_assets` manifest (placement at build time) | NEW helper + manifest | no schema; **sign-off required** |

---

## Deep dive #14 — the finalized template styles
Source: `website-structure` skill ("the 6 definitive styles"). `clients.site_style` holds the **slug key** (free text, no migration). Replace the dropdown AND the `ClientFields` enum with these 6:

| Display name (option label) | Slug key (`site_style` value) |
|---|---|
| Professional Modern | `professional_modern` |
| Artistic Unique | `artistic_unique` |
| Corporate | `corporate` |
| Modern Tech | `modern_tech` |
| Family Owned / Local Business | `family_owned` |
| Owner Operated / Local Business | `owner_operated` |

**Change:** `onboarding.functions.ts` → `siteStyle: z.enum(["professional_modern","artistic_unique","corporate","modern_tech","family_owned","owner_operated"]).optional()`. (Only `professional_modern` is *built* today — styles 2–6 are Phase A — but all 6 are the finalized selectable set.) **FUTURE (noted, not built):** per-style preview thumbnails in the dropdown.

## Deep dive #28 — timing hours: DERIVE (recommended)
Public display hours (`clients.hours`) and lead-reply timing (`send_settings.business_hours`) use the **identical shape** and, in practice, the **same hours** (if you're open, send the in-hours reply). So:
- **Recommendation: DERIVE.** In the assembly, set `sendSettings.businessHours = fields.hours` (the public hours the owner entered). The owner sets hours **once**; both columns get the correct shape. The agency can override the timing later in `/admin` Settings if it ever needs to differ.
- This **fixes the `{raw}` bug** (business_hours now gets `{"mon":[…]}`, not `{raw:"text"}`).
- **Step 8 fallout:** after #24–28 the only remaining owner-relevant value is **timezone** → move it next to the public-hours picker in Step 2 and **delete the standalone Config step**. Caps + SMS window ride their DB defaults (500 / 50 / 9–7); the agency tunes them in admin.

## Deep dive #33 — image routing (THE sign-off item)
**Finding:** nothing is built. No `site_assets` references anywhere; the wizard logo is URL-paste; the photos step is a placeholder. The marketing site (the separate Remix repo) is the real image renderer; this repo only needs to **store + organize** the images so the site can place them at build time.

**Buckets (verified):** `public-assets` = **public-read, admin-write**; `client-assets` = private. → logo + all site photos go to **`public-assets`** (anon site must read them). `ticket-upload.ts` (→ `client-assets`) can't be reused as-is; we need a **public-assets** variant.

**Recommended approach (store + organize; placement happens at template-build):**
1. **NEW upload helper** (e.g. `src/lib/clients/site-image-upload.ts`) — same UX as `ticket-upload`, but `supabase.storage.from("public-assets").upload(...)`, path `<client_id>/<category>/<uuid>-<filename>`, returns the public URL. (Admin-write → fine for the agency-filled wizard; **client-facing mode (future) needs a server-fn proxy** since clients aren't admins on `public-assets`.)
2. **Manifest** in `template_vars.site_assets` (anon-public — the site reads it):
   ```json
   {
     "logo":     { "path": "<cid>/logo/uuid-logo.png", "url": "https://…" },
     "work":     [{ "path": "...", "url": "..." }],
     "gallery":  [{ "path": "...", "url": "..." }],
     "about":    [{ "path": "...", "url": "..." }],
     "services": [{ "path": "...", "url": "..." }],
     "staff":    [{ "name": "Jane Doe", "position": "Lead Designer", "path": "...", "url": "..." }]
   }
   ```
3. **"Design-for-me" / request flags → `submission`** (private agency action items, NOT the public manifest): `logo_request`, `color_request`, `photo_request`, `domain_request`.
4. **Placement contract:** the wizard CANNOT place images on pages (the site doesn't exist at onboarding) — it tags by category in `site_assets`. The **per-client Remix reads `site_assets` at build time** and drops each category into its section (work/gallery → Gallery; about → About; services → Service pages; staff → About/Team). **Record this `site_assets` contract in `website-structure`** (same as the hours shape), so templates consume it.

**Scope:** the new helper + the manifest assembly in `onboard.tsx` + the per-category upload UI (Step 5). **No schema, no fn-contract change** (`template_vars` + `submission` are open; `logo_url` exists). The only "routing" v1 does is **categorise + store**; actual page placement is a template-build (Phase A) responsibility that reads `site_assets`.

**Options for sign-off:**
- **(A · recommended)** Build the `public-assets` helper + the `site_assets` category manifest now (store+organize); placement deferred to template-build. App-layer, no schema.
- **(B · minimal)** Logo upload only now (→ `public-assets` + `logo_url`); categorised photos = a follow-on slice. Smaller Step-5.
- **(C)** Defer all uploads; keep paste/placeholder for this pass, do uploads as a dedicated later slice.

---

## Proposed build slicing (after sign-off)
1. **R-1 — fn + copy/removal pass (no uploads):** `siteStyle` enum (#14); all hints/labels/renames (#1,2,4,5,7,13,19,21–23); slug-hide (#3); removals (#20,24–27,31); derive-hours (#28) + Step-8 collapse + timezone move; A2P required rules (#29,30); domain/logo/color "request" reveals → `submission` (#6,10,12); weekends-default hours (#8); phone mask/normalize (#4). All `onboard.tsx` + the one enum line.
2. **R-2 — uploads + manifest (#9, #15–18, #33):** the `public-assets` helper + logo upload + categorised photos + staff repeater + `site_assets` manifest + "design-for-me" flags.
3. **R-3 — review page (#32):** readable grouped summary + thumbnails (depends on R-2 for the image previews).

Each app-layer, no schema. R-1 ships first (it's the bulk of the corrections + the contract enum change); R-2 gated on the #33 sign-off; R-3 last.

---
**Awaiting sign-off: #33 option (A/B/C), #28 derive (confirm), #14 the 6 styles (confirm). Then I produce the R-1/R-2/R-3 build prompts for review. No schema anywhere; one fn enum change (#14).**
