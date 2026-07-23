# Client Onboarding — Master Order of Operations & Walkthrough

**Purpose:** the single, definitive "what do I do, in what order, and when" for onboarding ONE new client from signing to live — plus the walkthrough test matrix, the internal-message fixes, the SEO cadence, and the proposed admin checklist. Synthesized 2026-07-14 from the actual skills/docs (not memory). Source files cited per section.

> **Mental model:** ONE frozen multi-tenant backend (Project 1) serves every client. The only per-client NEW code is a *Remixed* marketing site (one `.env` line). Everything else is DATA written into the shared backend by the onboarding wizard + agency config. Business logic is never regenerated per client — that's the anti-drift core.

---

## 1. One-time prerequisites (TRUE before ANY client onboards — not per client)

| # | Prereq | State |
|---|---|---|
| P1 | **Golden-master backend built + frozen** (current tag v1.12). Never remixed/regenerated per client. | done |
| P2 | **Stage 1f shipped — HARD GATE ("NO client launches pre-1f").** TextGrid send swap + inbound/voice webhooks (`X-TextGrid-Signature` HMAC-SHA1) + live Turnstile+rate-limit on all 3 public forms + pg_cron drip-runner scheduled LAST at the prod cron URL. | inbound live-validated 2026-07-11; **verify full 1f flip before a paying client** |
| P3 | **First marketing-site template built + frozen** for the client's niche×style (see §4). Don't pre-build a library — build the first real niche, prove the loop, grow on demand. | family-owned template built; others on demand |

Sources: `docs/client-onboarding-process.md`, `docs/1f-*`, `skills/launch-check/SKILL.md`.

---

## 2. Critical path at a glance (9 phases, in order)

1. **Phase 0 — Sign + provision provider + kick off A2P.** Collect onboarding form; **new clients go on Telnyx (the default + only selectable provider — TextGrid is frozen legacy; `clients.provider`) and kick off the Telnyx Brand→Campaign** (2–4 day vet overlaps the build — the single longest external dependency).
2. **Phase A — Data capture.** Generate/email the `/onboard/$token` link (or self-fill `/onboard`) → client completes the 8–10 step wizard → row written `status='pending'` + immutable submission JSON.
3. **Phase A.5 — Review + provision.** Onboarding queue → `/admin/review` → **Finalize & Invite** (`provisionClientOwner`: magic-link invite + `client_owner` grant + flip `status`→`active`).
4. **Phase B — Agency config.** Review link/Place ID/threshold; messaging + `call_forwarding_number`; `allowed_origins`; discount/quote/caps/timezone.
5. **Phase C — Telephony/A2P finish.** subaccount → Brand (EIN) → Campaign (compliance copy from `/a2p-site-compliance`) → buy+attach number → wire webhooks + forwarding → write the number (Settings → Messaging (Telnyx) → "Telnyx number") + set the website display phone (Settings → Business Identity → "Phone (display)") → place on GBP.
6. **Phase D — Remix the site.** Remix template → rename → set `VITE_CLIENT_SLUG` → connect domain → add domain to `allowed_origins`. (Turnstile-hostname step RETIRED 2026-07-22 — native bot-shield needs no hostname registry.)
7. **Phase E — Design + compliance.** `/website-structure` page generation → generate ToS/Privacy/SMS-Program + single-checkbox opt-in (verbatim) → invisible native bot-shield on all 3 forms.
8. **Phase F — Verify + launch.** `/launch-check` §E (data QA) → end-to-end smoke test (lead → contact → drip → SMS → owner notified) → **Live.**
9. **(Pro clients) SEO program** runs continuously post-launch (see §5).

**Ordering couplings that bite if violated:** `allowed_origins` set *before* the lead form works · `status='active'` (Finalize) *before* the site renders live data · compliance pages (E.2) *before* Campaign registration (C.3, it consumes the T&C/privacy URLs) · the native bot-shield on all forms *or zero leads* (fail-closed; `POW_SECRET` set).

---

## 3. Phase-by-phase detail

### Phase 0 — First contact / sign / kick off A2P early *(agency ops + provider registration)*
- **0.1 Sign & collect raw inputs.** Owner fills the onboarding content (business details, services, hours, brand colors, logo, categorized photos, EIN, GBP link). *Full shipping address is AGENCY-OPS ONLY (mail business cards) — not stored in the app.*
- **0.2 Provision provider + start A2P at signing.** New clients go on **Telnyx** (the default + only provider offered for new clients; **TextGrid is frozen legacy** — used only for a client already on it; `clients.provider`), then begin the Telnyx Brand→Campaign immediately (10DLC Brand→Campaign; the legacy TextGrid path is subaccount→Brand→Campaign); it vets **independently, ~2–4 days**. Gate: **client EIN must be ≥15 days old** (flagged as possibly-stale TCR-era rule — verify with the provider). *Why now: waiting until the site is done adds ~2–4 dead days.*

### Phase A — Data capture (the onboarding wizard) *(app-layer only; no schema change)*
Writes to existing `clients` columns / `template_vars` / `send_settings` / `public-assets`. Creates the row **`status='pending'`** (dormant — no automations, not anon-visible).
- **A.1 Generate/send the link.** `/agency` Onboarding tab → **"Generate onboarding link"** (`generateOnboardingLink` → one-time token → public `/onboard/$token`) + **"Email this link"** (mailto composer, sends from the agency's real address). Alt: agency self-fills at authed `/onboard`.
- **A.2 Complete the stepper** (`OnboardWizard`, mode-aware). Steps & destinations:
  1. **Account/Identity** — owner name → `template_vars.company_owner_first_name`; business name → `business_name`+`company_name`; **slug** (auto from name, editable, `^[a-z0-9-]+$`); business phone → `call_forwarding_number` (E.164); address; website → `company_website_link`; notification email → `notification_email` (private).
  2. **Content** — `about_us`, `services`, `differentiators`; service areas (≤14) → `service_area[]`; per-day hours → public `clients.hours` (canonical `{"mon":["09:00","17:00"],…}`) with `send_settings.business_hours` derived equal; timezone.
  3. **Branding** — logo upload → `logo_url`; brand colors → `brand_color` + `template_vars.brand_secondary/tertiary`. ("I don't have one" paths write `submission.*_request`.)
  4. **Industry & Style — STEP REMOVED (2026-07-22).** Niche → `template_vars.segment` (DATA, no column) is now captured at the top of Content (step 2). The site-style choice is agency-made outside the app; all app `site_style` plumbing removed (`clients.site_style` dormant — never written).
  5. **Photos** — categorized uploads (`work/gallery/about/services` + staff) → `template_vars.site_assets` manifest; missing categories fall back to niche-default images. Client-mode uploads via token-gated service-role proxy.
  6. **Social Links** — GBP link → `template_vars.google_business_profile_link` (+immutable submission copy); IG/FB/LinkedIn → `clients.social_links`. **Does NOT set `review_link`** (agency-set in Phase B).
  7. **Texting Registration (A2P)** — EIN, legal name, **legal business address** (the registered address exactly as on the client's IRS documents — for 10DLC brand registration; MAY DIFFER from the public site address), vertical/industry, TCPA attestation (required to advance); DBA optional. Captured to immutable `submission` JSON; **legal business address ALSO → the new `clients.legal_address` column** (editable in admin Settings so the agency confirms/corrects it against the IRS documents before registration). **wizard PREPARES, never submits** (`a2p_status='not_started'`). **[2026-07-22]** Optional **CP 575 EIN Confirmation Letter upload** under the EIN field → PRIVATE `client-assets/{clientId}/a2p/` (submission JSON records the path); agency cross-checks the typed identity against it via the 5-min-signed-URL "View document" in `/admin/review`/Settings before Phase-C registration (documents-first).
  8. **Review & Create** — proofread summary → **Create** (`createClientFull` → `insertClientFull`, forces `status='pending'`).
- **A.3 Row exists (`pending`).** One data-entry point; site AND automations both read what the wizard wrote (no site-vs-text drift). Immutable submission stored at `client-assets/{client_id}/onboarding-submission.json` (PII, read-only).

### Phase A.5 — Agency review + provision login (Finalize & Invite)
- **A.5.1** Client appears in `/agency/onboarding` queue (badge, 15s poll) → **Open** (writes `localStorage["admin.activeClientId"]` → `/admin/review`).
- **A.5.2 Review console** (`/admin/review`, admin/`agency_owner`) — status pill + immutable submission viewer + **missing-required-`template_vars` reminder** (advisory today) + `<FinalizeInvite/>`.
- **A.5.3 Finalize & Invite** — `provisionClientOwner`: (1) magic-link invite to `notification_email ?? email`, (2) audited `client_owner` grant, (3) **flip `status` pending→active** (now anon-visible + automation-eligible), (4) surfaces the Remix handoff checklist (slug / `VITE_CLIENT_SLUG` / `allowed_origins`; the site_style row was removed 2026-07-22).
- **A.5.alt DECLINE [2026-07-22]** — the other exit from the queue: "Decline" on the `/agency/onboarding` row or "Decline & delete" on `/admin/review` = **PERMANENT FULL PURGE** (confirm-guarded; `declineOnboardingClient` fn refuses any non-`pending` client): storage prefixes wiped (submission JSON + all uploads incl. token draft uploads) + hard row delete (FK cascades clear all data tables; the claimed onboarding-token record survives with `created_client_id` nulled). Not recoverable. Button hard-requires an email + `window.confirm` (sends a real email). *Prereq: Supabase Auth Site URL / `VITE_INVITE_REDIRECT_URL` must resolve to the tenant app + custom SMTP or the invite lands in spam.*

### Phase B — Agency-set config in `/admin` → Settings *(the plumbing the owner doesn't fill)*
- **B.1 Google review config** — set `review_link` + `review_place_id` + formatted `review_request_link` (from the GBP link). Defaults: `star_threshold=4`, `google_review_toggle='gated'`. *Whole review engine depends on a working GBP link.*
- **B.2 Messaging config + forwarding** — placeholders for `twilio_number` + `twilio_messaging_service_sid` (filled in Phase C); `call_forwarding_number` (seeded from owner phone; agency value wins).
- **B.3 Marketing domain → `allowed_origins`** — the CORS trust for lead-form POSTs. *Without it the site renders but the lead form is rejected.*
- **B.4 Other** — timezone, daily send cap, daily enrollment cap (50), SMS send window (09:00–19:00), quote form link, referral discount (`discount__on_referral` + `discount_amount`). *[BUILD] admin logo is URL-paste only today.*

### Phase C — Per-client telephony + A2P *(completes the Phase-0 kickoff)*
> **PROVIDER FORK (Telnyx-default 2026-07):** telephony routes per client via `clients.provider` (admin "Messaging Provider" select — now Telnyx-only for new clients). **Telnyx** (the DEFAULT + only choice for new clients — native ringback, AMD missed-call detection, full APIs): follow `/telnyx-provider` §4 (10DLC brand → campaign from the same a2p pack → number → Messaging Profile → TeXML app → flip; single account, one API key). **TextGrid** (FROZEN LEGACY — existing clients only, not offered for new clients): the steps below. Same a2p compliance pack feeds both.
- **C.1 Subaccount** — `POST /Accounts.json` → store the subaccount SID, auth token, and webhook secret in the server-only **`client_provider_secrets`** table (2026-07-22 — moved OFF clients; set via the admin Settings write-only ProviderSecretsPanel).
- **C.2 Brand (client EIN)** — `POST /campaigns/brand/nonblocking`, `entityType: PRIVATE_PROFIT` typical → `brandId`, `identityStatus: PENDING`. Needs EIN, legal name, website, **legal business address** (`clients.legal_address` — from the client's IRS documents; the brand's registered address, MAY DIFFER from the public site address), **contact email whose domain == site domain (#1 hard decline rule)**, **`vertical` (23-value enum, NOT free text)**. Sole-prop path = no EIN + SMS OTP.
- **C.3 Campaign** — qualify use-case → `POST /campaigns/campaign` with `usecase`, `description` (must contain "message frequency may vary"), opt-in/out/help, `sample1..5` (real drip copy, real names, ≥2 with STOP), `termsAndConditionsLink`+`privacyPolicyLink` (REQUIRED), `embeddedLink:true` → `campaignId`. **All copy/URLs come PRE-GENERATED from `/a2p-site-compliance` — do NOT re-author.** DCA2 $15/submission; `expediteCampaign:true` +$27.
- **C.4 Buy + attach number** — local area code matching the market → attach to campaign.
- **C.5 Wire webhooks + forwarding** — per-number `smsUrl`/`voiceUrl`/`statusCallback` → `/api/public/*`; forward to `call_forwarding_number`. **Signing key = the per-client webhook secret (`client_provider_secrets.webhook_secret`, server-only)** (NOT account AuthToken); signed = `request.url + raw body`. *TextGrid REST read APIs unreliable → diagnose inbound via webhook.site repoint.*
- **C.6 Write + place the number [TWO admin inputs — exact locations; do AFTER the number is provisioned; can be before OR after the site remix (the site reads data LIVE, so a late fill updates it on next page load); A2P approval gates SENDS, not these inputs]:**
  1. **Telnyx number** — Admin → Settings → **"Messaging (Telnyx)" card → "Telnyx number"** input (E.164, e.g. `+14075551234`). *The client's platform texting/voice number — single source that all SMS automations, inbound routing, and missed-call detection key off.* (Legacy TextGrid client: the "Messaging (TextGrid)" card's "TextGrid number" instead.)
  2. **Website display phone** — Admin → Settings → **"Business Identity" card → "Phone (display)"** input. *The phone number the client's WEBSITE shows (header/footer/tap-to-call) — set it to the SAME Telnyx number so customer calls/texts flow through the platform; the live site updates on next page load.*
  3. External placement: put the number on the **Google Business Profile** (+ business cards). The client keeps their personal number everywhere else; the platform number forwards to `call_forwarding_number`.

### Phase D — Remix the site (~minutes)
- **D.1** Remix the matching `Template — {Style}` project (exact copy, no AI/credits). **D.2** Rename. **D.3** Edit `.env` → change ONE line `VITE_CLIENT_SLUG=<slug>` (Supabase URL+anon key already correct — always Project 1). **D.4** Connect the client's domain (marketing at root, app at `app.theirdomain.com`). **D.5 — the "DOMAIN IS LIVE" TRIO [MUST-DO, in this order — the same moment, three Settings fields; complete scope verified 2026-07-22, nothing else needs the domain]:**
  1. **`allowed_origins`** — Admin → Settings → **"Marketing Domains (CORS allowlist)" card**, one origin per line: `https://theirdomain.com` + `https://www.theirdomain.com`. *The trust list that lets THEIR site's forms submit + resolves which client a submission belongs to.* FIRST because it's functional: forms are DEAD (silent zero leads) until set. Also REMOVE the Lovable preview origin here if it was added during the build. (The old "+ Turnstile hostname" step is RETIRED 2026-07-22 — native bot-shield, no hostname registry.)
  2. **Company website link** — Admin → Settings → **"Brand & Site" card → "Company website link"** input = the URL as it should read in texts, e.g. `https://www.theirdomain.com`. *The website URL merged into SMS drips and used as the quote-link fallback in Missed-Call Textback SMS #1;* a no-prior-domain client has it BLANK until now (amber-flagged).
  3. **Review link domain** — Admin → Settings → **"Review Config" card → "Review link domain (optional)"** input = `https://theirdomain.com`. *Makes review-request SMS links carry the client's own domain* (`theirdomain.com/review/<token>` → 302 → backend funnel; route baked into the template). Verify `theirdomain.com/review/test` redirects. Cosmetic — blank = shared funnel domain (always works); NEVER set before the domain is live.
  *(NOTHING of the platform's own subdomains — app./notif.pierceworks.co — ever goes in any of these; the platform talks to itself same-origin. Future candidate build: ONE "Domain" input that derives all three.)*
  ~~3. website_terms_page_link · 4. contact_email domain-match~~ **SUPERSEDED 2026-07-22 [operator, SETTLED]: A2P registration happens on a SEPARATE external platform**, fed by the client's onboarding-collected identity (legal name/EIN/legal address/vertical/TCPA + the CP 575 upload). These two items apply to that platform, not here — leave the fields blank per client. The client site nonetheless STAYS fully a2p-compliant by design (single-checkbox consent model; zero marginal cost, baked into the template; protective under carrier spot-review) — the a2p-site-compliance docs remain authoritative for the SITE surface as-is.
  *(Site URL on the Google Business Profile = C.6 — separate external step.)*

### Phase E — Design layer + compliance pages
- **E.1** `/website-structure`: generate pages from onboarding — the **Core-30 / GBP-mirror** service page set (~25–30 service pages mirroring the Google Business Profile — **no max-12 cap**), service-area page per area (max 14), plus always-present pages (Home, Contact, Gallery, Thank You, Discount Funnel, Review Us, ToS, Privacy, SMS Program). Steer by the agency-chosen style preset, theme the brand color, mimic agency-uploaded reference screenshots. *Only build pages the onboarding supports.*
- **E.2** Generate ToS/Privacy/SMS-Program + single-checkbox opt-in — copy **VERBATIM** from `docs/a2p-compliance-copy-source-of-truth.md`. Store terms URL in `template_vars.website_terms_page_link`. *These URLs feed C.3.* The lead form's single consent checkbox (marketing skeleton) must be unchecked + optional; contact email domain == site domain.
- **E.3** Invisible native bot-shield on ALL 3 forms (lead/discount/chat-optin) — `pow_token` + hidden `website` honeypot. *Missing shield = zero leads (fail-closed); `POW_SECRET` Cloud secret must be set.*
- **E.4 SEO ordering [2026-07-22 — pages are DATA rows; publishing never touches the Lovable project]:**
  - **PRE-LAUNCH (any time after Finalize, before or during the site build):** Admin → **SEO tab** → AI-seed the map from services/areas → **correct the categories against the client's REAL GBP** → Save (+ optionally Seed Core-30 draft rows). This defines STRUCTURE only — cheap, safe, no visible output yet.
  - **POST-LAUNCH (yellow-checklist item — after the site is live on its domain):** AI-write the pages → **Publish** → review the RENDERED pages on the live site (they only become viewable/checkable once the site is up — which is why content finalization waits). Ongoing geo/supporting pages ~monthly (Pro/749 `seo_cadence`).

### Phase F — Verify + go live (`/launch-check` §E — data QA)
- **F.1 Gate:** 1f shipped; cron scheduled at prod URL; client row + config present; **all 11 required `template_vars` populated** (`company_owner_first_name`, `company_name`, `company_website_link`, `review_request_link`, `discount__on_referral`, `discount_amount`, `quote_form_link`, `website_terms_page_link`, `about_us`, `services`, `differentiators`); timezone/hours/window/caps set; review link+Place ID+threshold; number provisioned+forwarded+placed; **A2P Brand+Campaign approved**; `allowed_origins` set; site remixed+pointed at shared env; Turnstile on all forms.
- **F.2 Smoke test:** submit a lead from the LIVE domain → contact created → drip enrolls → SMS sends → owner notified. Click a tracked review link → funnel loads logged-out → events recorded.
- **F.3 Live.**

---

## 4. Website template (one-time) — the prompt, the reference, the lead-form accuracy

**Layer model (N+M, not N×M):** Layout (structural shell) · Style (**finalized style presets**, one Lovable project each, `Template — {Style}`) · Niche (pure DATA in `template_vars.segment`, composes onto any style — no `clients.niche` column).

**The build prompt:**
- **Canonical parameterized master:** `docs/template-build-prompt-TEMPLATE.md` ("Reusable Style-Template Build Prompt — PARAMETERIZED MASTER"). Fill 7 blanks (style display/slug/voice/visual + demo niche display/segment/business/services + consent-note). **Never hand-edit a previously-filled prompt** (stale niche/style carryover).
- **Worked example:** `docs/stage5-family-owned-template-lovable-prompt.md` (master filled for `family_owned` / demo Plumbing).
- **Build spec / rules:** `docs/stage5-template-builder-build-spec.md`, `skills/template-builder/SKILL.md`, `skills/website-structure/SKILL.md`.

**The "reference design"** = agency-uploaded **screenshots** attached in Lovable at build time (PAGE-LAYOUT refs → structure; ART-STYLE refs → palette/typography/feel). Rule: **mimic closely**, not loosely inspire. (Not an onboarding field.) Winners get captured as a named reusable design template pulled via Lovable cross-project @-referencing — but per-client is ALWAYS Remix + `VITE_CLIENT_SLUG`, never @-referencing.

**Where template creation sits:** one-time, before any client that uses it. Per-client Remix (Phase D) happens AFTER the client record exists and AFTER A2P is kicked off; A2P *approval* gates go-live (Phase F).

**Lead-form business-type accuracy — the critical distinction:** the field SET is **fixed & locked** (lead → `/api/public/intake`: First/Last/Phone/Email/Your Message, message key = **`notes`**, **mobile phone REQUIRED + email optional (form-level 2026-07-22; the route still accepts either)**; discount → `/api/public/discount`: First/Last/Phone/Your Message, message key = **`your_message`**, phone REQUIRED, `consent:z.literal(true)`). Business-type accuracy lives in **DATA tokens**, driven by `template_vars.segment` → the **a2p niche library** (`skills/a2p-site-compliance`), which fills `customer_care_category` / `marketing_category` consent strings + services/about/differentiators. **Where it's set:** wizard Content step (segment — the old Step 4 was removed 2026-07-22) → niche library maps categories → frozen template renders via `useClient()`.

**Where the lead form can be WRONG (and the fix):**
1. **Unseeded niche → silent generic DEFAULT copy** (library has only ~3 seed entries). Fix: append an approved niche row to the library (flows to `template_vars` + keeps the A2P campaign byte-consistent).
2. Lead-form consent checkboxes are display-only (no `intake` consent field) BUT **carrier-load-bearing** — must byte-match the A2P Campaign CTA or risk a decline.
3. Building fields from the a2p §C "Request Information" block instead of `opt-in-forms` → wrong fields. Field set ALWAYS comes from `opt-in-forms` + the frozen route.
4. Swapping `notes`↔`your_message` between the two forms → silently mis-stored data.

---

## 5. SEO program — how to use + cadence + per-client checklist

**Tier gating:** `seo_cadence` entitlement = **749 / Pro** (top tier; renumber confirmed — §9). Non-Pro clients get the full Core-30 structure + map editor + single-pass ai-write; **Pro adds the 8-pass deep-write + the monthly cadence board + rank-map-driven expansion.**

**Operator flow (per client SEO tab `/admin/seo`):**
> **This exact order-of-operations is now surfaced IN-APP** via a **"?" helper** on the SEO tab (a 7-step "How to set up SEO for this client" checklist) + an **"Onboarding vs SEO map"** comparison panel that flags when the client's services aren't in the map yet ("click AI-seed"). [admin-view]
1. Fill inputs: Services & Pricing, Competitor URLs, Business & SEO Content, Service Area & Locations.
2. **SEO map editor** — primary category (prefills from segment) → 3–4 secondary categories → services (with price ranges) nested under categories. **"AI-seed from services"** (`proposeSeoMap`, never writes) → review/edit → **Save** (slugs frozen once minted).
3. **Generate Core-30 (draft)** (`seedCoreThirty`) → ~30 draft rows (1 home + 3–4 category + 25–30 service). Pages tree shows title/type/slug/URL/status.
4. **Write content** — per page, pick ONE: **AI-write** (single pass, all clients) or **Deep write** (8-pass, resumable, **Pro-gated**).
5. **Photos** — 2–3/page via Photo-Board (hero + 2 inline). Preview in sandboxed iframe.
6. **Publish** — `setPageStatus` draft→published (no rebuild; template renders live rows).
7. **One-click flows (shortcut):** "Build All Core Pages" / "Build Geo Pages" / "Build Supporting Pages" collapse the above (~5–8 min vs ~25–35).
8. **Monthly cadence board `/agency/seo-status`** (Pro) — last-reviewed / next-due chips, due badge; per-client "SEO Updated" button (resets 30-day clock) + `topical_status` (building|established|dominating) + `close_towns[]`.

**Cadence / timeframes (concrete):**
- **Day 0:** build + **publish the ENTIRE Core-30 at once** (~30 pages) + 1 authority link per page. No geo, no supporting yet.
- **Day ~30:** run a rank map → compute top-3% → compare to threshold (25–50% of leading competitors). **Below →** ~10–20 supporting pages. **At/above →** ~10–20 geo pages (positions 4–6), published in waves.
- **Monthly (Day 60/90/…):** re-run rank map (geo ~every 2 weeks); alternate topical↔geo waves ~10–20 pages; retainer floor ≈ 12 articles/mo. Click "SEO Updated" each cycle.
- **Dominating → maintain** (stop the wave machine; add pages only for genuinely new services).

**Manual vs automated:** operator confirms the map, supplies competitor URLs + the per-page authority-link URL, assigns photos, runs the external rank map (Lead Snap) and feeds the 3-state signal, approves supporting questions, clicks publish + "SEO Updated." Everything else (seeding, writing, research fan-out, geo seeding, wave publish) is automated. **Off-app agency ops:** actual GBP edits, inbound backlinks (chambers/sponsorships/$25–35 links), Lead Snap, Screaming-Frog audits.

**Not-yet-built (don't promise as live):** auto monthly scheduler (cadence is a due-board reminder, not auto-fire), Lead Snap CSV ingestion (rank read is manual), backlink tracker, AI image-fill for empty slots.

---

## 6. Walkthrough test matrix — every automation, end-to-end

| # | Feature | Trigger | Customer sends | Internal notification |
|---|---|---|---|---|
| 1 | **Review Request Drip** | Mobile "Review Request" form (First/Last/Phone). Re-enroll guard; 50/day cap | 4 SMS (0, +4d, +7d, +7d) w/ tracked `{review_link}`; click any stage → exit → `Review Completed` | terminal notif after SMS4+48h no click |
| 2 | **One-Year Follow-Up** | Auto-handoff on review-drip completion (unless opted out / Negative) | 5 SMS (30d, +8wk, +3mo, +3mo, +3mo) w/ discount links | interest notif on any reply (+`{message.body}`); 3-mo notif after SMS2; final after SMS5 |
| 3 | **Website Lead-Form Drip** | Public lead form → `/api/public/intake`. Branches on **Business Hours** | in-hours SMS#1; after-hours single SMS | ~30s client notif; after-hours owner notif; **day-10 reminder** (Auto-Enroll button) |
| 4 | **Discount-Claim Drip** | Discount form → `/api/public/discount` (consent required). In One-Year → EXITS them | +2min one SMS → end | immediate client notif |
| 5 | **Missed-Call Textback** | Voice status busy/no-answer/canceled/failed. 24/7, 7-day re-eligibility. **Telnyx: AMD detects a voicemail answer → textback FIRES on machine (live 2026-07-20). TextGrid-only caveat: voicemail (`completed`) does NOT fire** | +1min SMS#1; +2min SMS#2 only if no reply | notif with SMS#1 (`{caller_phone}`,`{call_time}`) |
| 6 | **Reactivation** *(LIVE — client's own Telnyx number; rewired 2026-07-21, no number pool)* | Admin CSV → `enrollReactivation` (**REQUIRED consent attestation**). Caps 50/day, 2/20min; delivered from `clients.telnyx_number` by the normal runner | 4 SMS (immediate, +24h ×3) | click notif to owner |
| 7 | **Inbound SMS** | Supabase edge fn `sms-inbound` (TextGrid, HMAC-SHA1) / `telnyx-sms-inbound` (Telnyx, Ed25519). STOP/`pass`→opt-out; HELP→info; START→opt-in; else upsert conversation | keyword replies | drives #2 reply-exit + #5 reply-skip |
| 8 | **Tracked review link + Funnel** | `{review_link}` → `/r/<token>` → `review_clicked` → `/r/rate` | ≥threshold → `Review Completed` → Google → enroll One-Year; <threshold → `/r/feedback` → `Negative Review` | below-threshold → "We Saved You From a Negative Review" email+notif |
| 9 | **Chat Widget (capture-first, no AI)** | Corner bubble → greeting → lead form (First/Last/Phone+msg, consent, Turnstile) → `/api/public/chat/optin`. Source `chat_widget` | enrolls the Lead-Form drip immediately (BH branch); message → Conversations tab (`channel='chat'`) | "New Website Chat Lead" |

**Cross-cutting:** `pass`+STOP exits ALL drips (universal pre-send guard); every send writes an `events` row (live+stub); marketing honors send window + cap + pacing; lead-form/missed-call are transactional. Owner **emails** (Resend, live 2026-07-14) mirror every in-app notif, gated by `email_notifications_enabled`.

Also test during walkthrough: **SEO creation** (§5 Day-0 flow), **app access** (client login via magic-link → PWA), **audit enrollments** (re-enroll guard, day-10 auto-enroll), **lead forms carry the right fields for the niche** (§4).

---

## 7. Internal-message wording punch-list (stale remnants to fix)

Source: `skills/automation-config/SKILL.md`. Fix these; leave the A2P copy alone.

1. **🚩🚩 Missed-call notif (#5): literal `[Open conversation button]`** sits in the message BODY. Should be an `action`-jsonb button (like the day-10 reminder), not bracketed text. **Highest priority.**
2. **🚩 Review-Request terminal notif (#1): `Name: {first_name}`** violates the `{full_name}` convention used by every other internal notif → owner sees only a first name. Change to `{full_name}`.
3. **🚩 `{your_message}` vs `notes` mismatch** — the lead-form internal notif (#3) AND the two "New Website Lead" **emails** use `{your_message}`, but `/api/public/intake` stores the message as **`notes`**. If unmapped, `Message:` renders **blank**. Verify the merge maps `notes`→`{your_message}` for lead-form (discount route genuinely posts `your_message`, so it's fine).
4. **"(Do NOT reply to this message; it's not the client!)"** — appended to every internal notif; reads oddly, and now that these also ship as **emails**, "Do NOT reply" is confusing in an inbox. Candidate for a clarity rewrite across all.
5. **Grammar:** One-Year 3-mo notif "if you want to reach out / or they contact you" — draft-y; smooth it.
6. **Cosmetic:** `{discount__on_referral}` double-underscore token name — functional, looks like leftover naming.

**DO NOT "fix" (carrier-approved, load-bearing — changing breaks byte-consistency):** A2P sample/description copy — `"in the mean time"`, `"We only ask for reviews we do not filter these reviews"`, `"Msg volume may vary"` (no period). Also note A2P samples 4–5 reference a support-ticket use case no automation actually sends (approved-copy vs reality gap — aware, don't touch).

---

## 8. Proposed admin-view Onboarding Checklist feature (scope for later)

**Best hook point:** the `invite` mutation in `src/components/admin/FinalizeInvite.tsx`, gating the **`pending → active`** transition — the single chokepoint every client passes through (both `/admin/review` and `/admin/settings`, both self-fill and client-submit). Block here = an incomplete client physically cannot be activated/invited.

**Build shape:**
- **UI:** render the checklist beside `<FinalizeInvite/>` on `/admin/review`; disable Finalize until all required items checked (mirrors the existing email-required disable + promotes the today-advisory `required-template-vars.ts` reminder to blocking).
- **Server enforcement (recommended):** introduce a dedicated admin-gated `finalizeClient` server fn (`supabaseAdmin`) that verifies checklist items, does the status flip, then the UI calls `provisionClientOwner` — converting the current unguarded RLS `update({status:'active'})` into an enforced gate.
- **Data (additive, low-migration):** one `clients.onboarding_checklist jsonb` (private, NOT projected by `get_client_public`) = `{ item_key: { checked, by, at } }`. Checklist definition in code (`onboarding-checklist.ts`, like `required-template-vars.ts`).

**Candidate checklist items** (prune when building): business_name+slug · owner first name · address · logo present · brand_color · about/services/differentiators · service_area · public hours (canonical shape) · timezone · send window · business_hours (canonical, not `{raw:…}`) · send/enrollment caps **confirmed enforced in runner** · allowed_origins = real domain · review_link works + threshold + toggle · review_request_link synced · discount + quote + terms links · all 11 required `template_vars` · EIN/legal/entity/vertical in submission · **legal business address (`clients.legal_address`) confirmed against IRS docs** · TCPA attested · twilio_number + messaging SID provisioned · call_forwarding_number · **A2P Brand+Campaign approved** · notification_email set · `VITE_INVITE_REDIRECT_URL` + SMTP configured · site Remixed + allowed_origins + Turnstile hostname · submission.json reviewed.

---

## 9. Spec-drift — RESOLVED (verified against current skills 2026-07-14)

- **Tier numbers → 297 / 397 / 749** (Starter/Growth/Pro); `seo_cadence` gated to **749/Pro**. No `497` remains anywhere in the skills; the only `497` left is in historical build-log validation files (point-in-time records — leave them). Renumber confirmed applied.
- **site_style set → exactly 6 slugs:** `professional_modern`, `artistic_unique`, `corporate`, `modern_tech`, `family_owned`, `owner_operated` — now purely the **agency-side style catalog** (`website-structure` Site styles). **2026-07-22: the client-facing onboarding choice + all app `site_style` plumbing were REMOVED; `clients.site_style` is dormant.** The older "4 slugs incl. `standard`" was a historical phase-c build prompt — **there is NO `standard` slug.**
- **Offers (discount / discount_amount) → AGENCY-SET in admin Settings**, NOT a wizard step (`onboard-from-form`: "no longer collected at onboarding") → `template_vars.discount__on_referral` + `discount_amount`.
- **`review_place_id` → AGENCY-SET in admin Settings** (agency grabs it from the client's GBP; setup task if none yet) — `clients.review_link` + `clients.review_place_id`. Not in the onboarding wizard.

Still external / open:
- **⚠️ CRON DRIP RUNNER IS CURRENTLY OFF (found 2026-07-15):** no scheduled tick since 2026-07-14 — no drip sends process for ANY client until pg_cron is re-scheduled (manual ticks via the cron route + `x-cron-secret` work). **Re-enabling the scheduled runner is a HARD go-live prerequisite** (launch-check F.1) — put it on the walkthrough ops checklist.
- **EIN ≥15 days rule:** possibly-stale (Twilio/TCR-era, not in TextGrid docs). Verify with TextGrid.
- **Turnstile on the public onboarding submit:** backlogged/not built (single-use token + rate-limit only).
- **Admin logo:** URL-paste only today (file-upload is a BUILD item).

---

## 10. Backlog / parked

- **Voice ringing issue + call statuses** — **RESOLVED via Telnyx (native ringback + AMD voicemail detection, live-validated 2026-07-20)**; the TextGrid support ticket is moot on the go-forward path. Missed-call textback depends on correct `CallStatus`/`DialCallStatus` + AMD semantics.
- **Businesses with phone-line MENUS / IVR routing** — how to set statuses for missed-call textback when calls route through a menu/forward tree. **Decide once TextGrid confirms status behavior.** (Recorded as a first-class backlog item.)
- **iOS PWA home-screen text label** shows "Pierceworks" for all clients (shared-origin manifest identity limitation); only fixable via per-client subdomain rearchitecture — accepted-as-is 2026-07-14.

---

*Source skills/docs: `client-onboarding-process.md`, `onboard-from-form`, `new-client-site`, `template-builder`, `website-structure`, `launch-check`, `textgrid-provider`, `agency-view`, `admin-view`, `a2p-site-compliance`, `automation-config`, `features`, `opt-in-forms`, `platform-spec-source-of-truth.md`, `project-overview-and-handoff.md`, `LAUNCH.md`, `template-build-prompt-TEMPLATE.md`, `stage5-*`, `seo-operator-guide.md`, `master-seo-timeline-expert-grounded.md`, `1f-step6-a2p-registration-field-requirements.md`, `a2p-compliance-copy-source-of-truth.md`.*
