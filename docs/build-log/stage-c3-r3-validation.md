# Stage C-3 R-3 — Review & Create summary + refinements — validation

> Point-in-time validation record, 2026-06-28. App-layer / UI only — **no schema, no migration, no fn-contract change, no assembly change.** Verified against `cloud-spark-setup` **`origin/main` @ `10a8d40`** ("Updated staff upload UI") — the live built code, NOT the frozen `golden-master-v1.7` tag and NOT the stale local clone.

## What shipped
The full **C-3 onboarding-wizard revision pass is built + UI-validated** (`src/routes/_authenticated/onboard.tsx`):
- **R-1** — copy/structure: 9-step stepper, renames/help-text, hidden auto-slug, phone E.164 mask, per-day hours picker (`clients.hours` public; `send_settings.business_hours` derived equal), the 6 site-style slugs, A2P required rules (EIN/legal/vertical/TCPA; DBA optional; entity type removed), removals (Place ID / star threshold / review-gate / SMS window / caps / domains / quote-form + terms links / standalone Config step).
- **R-2** — uploads + manifest: `src/lib/clients/site-image-upload.ts` (→ `public-assets`, public URL); logo upload; categorized photo uploads (`work`/`gallery`/`about`/`services`); staff; `template_vars.site_assets` manifest; `submission.photo_request`. Multi-file upload + section header included.
- **R-3** — Review & Create (revision item #32): the raw code/JSON dump replaced with a **readable, grouped proofread summary** (`src/components/onboard/ReviewSummary.tsx`) — 8 sections in wizard order, formatted phone, per-day hours list, friendly timezone/style names, brand hex swatches, plain-language request flags, photo counts per category, staff entries with thumbnails; empty/skipped fields read gracefully ("Not provided" / hidden).
- **Two refinements** (folded in with R-3):
  - **Native color pickers** — `ColorField` wraps `<input type="color">` + a hex `<Input>` on all 3 brand fields (primary/secondary/tertiary).
  - **Staff individual/group toggle** — each staff entry is tagged `type`: **individual** (name + position) or **group** ("Label Group Photo").

## As-built shapes (verified in code @ `10a8d40`)
- `type StaffAsset = { url; path; type: "individual" | "group"; name?; position?; label? }` (lines 65–73).
- `ColorField` → native `<input type="color">` swatch + hex text input (lines 1036–1063).
- Assembly (`buildPayload`, lines 248–314): `templateVars.site_assets = { work, gallery, about, services, staff }`; `submission.photo_request = { designForMe }`; `fields`/`sendSettings` unchanged; returns `{ slug, fields, sendSettings, submission }` → `createClientFull`. **Payload byte-identical to R-2** (R-3 is presentation only).

## Validation
- **Method:** full test walk-through (UI). The Review page renders all 8 grouped sections readably — formatted phone (E.164 captured), per-day hours list, friendly timezone/style names, brand hex colors, plain-language request flags, photo counts per category, staff entries. No code dump. `createClientFull` call byte-identical (payload unchanged).
- **Result: PASS (UI-validated).**

## Open caveat — staff individual/group DATA SHAPE pending SQL confirmation
The staff `type` (individual/group) manifest shape is **UI/code-confirmed but NOT yet SQL-verified** against the live `template_vars->'site_assets'->'staff'` rows. Documented as built; **confirm the persisted data shape on the next test pass** (SQL introspection of a created client). Recorded the same caveat in the `website-structure` `site_assets` contract.

## Skills brought to parity (mirror lines handed)
- **`onboard-from-form`** — replaced the stale "wizard BUILT in Stage 3" line with the as-built 9-step C-3 wizard (field set, visibility/help text, hidden slug, E.164 mask, per-day hours + derived `business_hours`, 6 styles, A2P requireds/no-entity-type, `public-assets` uploads via `site-image-upload.ts`, native color pickers, `site_assets` manifest); site-style row corrected 4→6 slugs.
- **`website-structure`** — `site_assets` staff entries now carry `type` (individual `{…,name,position}` / group `{…,label}`), marked pending-SQL-confirmation; placement note covers both (individual → headshots; group → team/group photo).

## Next
Capture UI is done. Remaining Phase C: **C-3c** (finalize/invite — pre-gen console wiring + `provisionClientOwner` using the Business Email + the Remix handoff checklist; carried prereqs: custom SMTP + `VITE_INVITE_REDIRECT_URL`), then **C-3d** (client-facing onboarding via the token / public-route pattern + a server-fn upload proxy, since `public-assets` is admin-write).
