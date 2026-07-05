# template_vars content editors (esp. SEO/AI-write feeders) — READ-ONLY SCOPE

> Scope + recommend only, **no build.** Surface the `template_vars` fields the operator needs post-onboarding — especially the ones that feed `aiWritePage`'s PROVIDED CONTEXT — as friendly editors instead of raw JSON. Grounded on `cloud-spark-setup` `origin/main` @ `3433f9f`. Commits held.

## Why now (the trigger)
Validating fresh pages, the "hallucinated" claims (same-day / 10-year warranty / licensed & insured) turned out **grounded** — `test-landscaping.template_vars.differentiators = "Same-day service, 10-year warranty, licensed & insured, free estimates"` — and the ctx-aware validator correctly ALLOWED them. **`differentiators` directly governs what claims the AI is allowed to make**, yet it's only visible/editable by hand-editing raw JSON. The operator must be able to edit it (and its siblings) without touching JSON.

## What feeds the AI/SEO (the consumers) [verified in seo.functions.ts]
- **`aiWritePage` PROVIDED CONTEXT:** `business_name` (col), resolved `city` (`template_vars.seo.city ?? service_area[0] ?? address`), page `type`/`h1`/`target_keyword` (row), **`template_vars.about_us`**, **`template_vars.differentiators`**, public phone (`twilio_number ?? phone_display`).
- **`seedCoreThirty`:** `business_name`, `address`, `service_area`, `template_vars.seo` (the map).
- **`proposeSeoMap`:** `business_name`, **`template_vars.services`** (free-text), `template_vars.segment`.

## Field audit — editable today vs JSON-only
| Field | Feeds | Editable today? |
|---|---|---|
| `business_name`, `tagline`, `phone_display`, `email`, `address`, `license#`, `logo_url`, `brand_color`, `site_style` | identity/schema/NAP | ✅ Settings (identity/brand) |
| `service_area` | seed city + areas | ✅ Settings (comma-separated) |
| `twilio_number` | public phone/NAP | ✅ Settings (messaging) |
| `notification_email`, `allowed_origins` | ops | ✅ Settings |
| `social_links` (IG/FB/LinkedIn) | schema/footer | ✅ Settings (friendly + JSON) |
| `discount__on_referral`, `discount_amount` | campaign | ✅ Settings (discount) |
| `review_link`/`place_id`/`threshold`/`toggle` + GBP link + `review_request_link` | reviews | ✅ Settings (review config, merge-synced) |
| `template_vars.seo` (map) | seed/propose | ✅ admin.seo panel |
| `hours` / `business_hours`, send windows/caps, timezone | SMS/schema | ✅ Settings (some via JSON textareas) |
| **`differentiators`** | **aiWritePage PROVIDED CONTEXT (allowed claims)** | ❌ **raw JSON only** |
| **`about_us`** | **aiWritePage PROVIDED CONTEXT + About page** | ❌ **raw JSON only** |
| **`services`** (free-text) | **proposeSeoMap (map AI-seed)** | ❌ **raw JSON only** |
| **`segment`** | **proposeSeoMap (industry)** | ❌ **raw JSON only** |
| `company_owner_first_name`, `company_name`, `company_website_link`, `website_terms_page_link`, `quote_form_link` | message merge vars / links | ❌ raw JSON only |
| `hero_headline`, `hero_subhead`, `about_intro` | template display copy (home/hero) | ❌ raw JSON only |
| `brand_secondary`, `brand_tertiary` | brand colors | ❌ raw JSON only |
| `site_assets` (photos) | images (Photo-Board reads it) | ❌ (uploaded at onboarding; no post-onboarding add/edit UI — separate gap) |
| pricing / price ranges | (would feed aiWritePage per method) | ❌ **NOT captured at all** (see note) |

## SEO-critical priority (feed the AI/SEO — do these first)
1. **`differentiators`** [HIGHEST] — governs the exact claims `aiWritePage` is allowed to state. The operator MUST curate this (it's the difference between grounded vs fabricated claims). A textarea.
2. **`about_us`** — the business description `aiWritePage` writes from. A textarea.
3. **`services`** (free-text) — feeds `proposeSeoMap`'s map AI-seed. A textarea.
4. **`segment`** — industry context for `proposeSeoMap`. An input.
*(City is covered via `service_area`/`address`; phone via `twilio_number` — already editable.)*

## Recommended UI location
- **Primary: a new "Business & SEO Content" section in `admin.settings`** — friendly editors for `about_us` (textarea), `differentiators` (textarea), `services` (textarea), `segment` (input), plus the remaining scalar required keys (`company_owner_first_name`, `company_website_link`, `website_terms_page_link`, `quote_form_link`, `company_name`) as inputs, and optionally the template display copy (`hero_headline`/`hero_subhead`/`about_intro`) + brand secondary/tertiary. Matches the `admin-view` LOCKED note: *"every onboarding value must be editable in Settings; no captured value invisible/uneditable."* Keep the raw `template_vars` JSON textarea as the power-user fallback.
- **Secondary (SEO panel affordance): in `admin.seo`, a compact read-only preview** of `differentiators` + `about_us` near the Generate / AI-write actions, with an **"Edit in Settings"** link — so the operator sees *what claims the AI is allowed to make* (and can fix them) **before** generating/AI-writing. Single source stays Settings; the SEO panel just surfaces + links.
- *(Not the onboarding wizard's edit mode — onboarding is one-time intake; ongoing edits belong in admin. Reuse onboarding's field components if handy.)*

## Safe-merge pattern (no clobber)
`template_vars` is written wholesale — any partial write wipes siblings (the `admin-view` LOCKED rule). Two acceptable patterns:
- **[REC] Server-side-merge fn `updateClientContent(clientId, contentFields)`** mirroring `saveSeoMap`: `requireSupabaseAuth` + `assertAgencyAdmin` → **re-read the client's current `template_vars` server-side → overlay ONLY the provided content keys → write the merged object** (`statusCode`-on-throw). Zero stale-blob clobber; matches the preferred pattern for structured `template_vars` edits (per `admin-view` / `seo-content`). A blank field deletes that key (like the social editor).
- **[Acceptable alt] Reuse `updateClientSettings` with a client-side read-merge-write** — exactly the existing discount/social editors in Settings (`base = {...template_vars}; overlay; saveClient.mutate({ template_vars: base })` + re-seed the JSON textarea). Lower effort, already precedented, but carries the small stale-blob risk the server-side merge eliminates.
- Either way: **re-seed the raw JSON textarea after save** (dual-writer guard) so the two editors agree.

## Notes / adjacent gaps
- **Pricing is not captured anywhere** — the method wants price ranges on service pages (`seo-content` §3 note), but there's no field. When added it's likely a **per-service** value (structured, alongside the SEO map's services), feeding `aiWritePage` PROVIDED CONTEXT — its own small capture slice, not a flat `template_vars` key.
- **`site_assets` post-onboarding add/edit** (upload more photos after intake) is a separate gap — the Photo-Board *reads* `site_assets` but there's no post-onboarding *upload* UI. Flag for later (onboarding per-service capture / a Settings uploader).
- **`family-owned` / `since 2009`** on the validated page: NOT in the differentiators JSON → mild extrapolation or stale pre-guard content; a fresh AI-write on the strengthened guard would confirm it's gone (the guard now forbids ownership/founding claims unless provided).

## Slicing recommendation
- **CONTENT-EDIT-1 [SEO-critical, do first]:** the "Business & SEO Content" Settings section for `differentiators` + `about_us` + `services` + `segment` (the AI/SEO feeders) via the safe-merge fn + the admin.seo read-only preview/link. Small, high-value (unblocks operator control of AI claims without JSON).
- **CONTENT-EDIT-2:** the remaining scalar required keys + template display copy + brand secondary/tertiary editors (completeness of "all values editable in Settings").
- **(later)** pricing capture; `site_assets` post-onboarding uploader.

---
**Read-only scope. Gap = the AI-write feeders (`differentiators` — governs allowed claims — plus `about_us`, `services`, `segment`) are raw-JSON-only. Recommend a friendly "Business & SEO Content" section in admin.settings (+ a read-only preview/link in admin.seo) via a server-side-merge `updateClientContent` fn (saveSeoMap posture, no clobber). Prioritize `differentiators`. No build; commits held.**
