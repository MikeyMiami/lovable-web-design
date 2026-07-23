---
name: new-client-site
description: Use to launch a new client — the per-client orchestrator. Provisions the client on the ONE shared backend (client row + settings + messaging-provider (Telnyx default; TextGrid legacy) number + onboarding capture), Remixes the marketing site for the client's domain (frontend-only, pointed at the shared backend), invokes the design layer, and runs the launch check. Does NOT clone or regenerate the backend. Run AFTER the golden master exists. Sequences the other per-client skills; doesn't reimplement them.
---

# New Client Site — per-client launch orchestrator

Launches one client on top of the proven golden-master backend. This is an ORCHESTRATOR — it sequences the other skills in the right order; it does NOT clone the backend, regenerate it, or reimplement features. The backend is the ONE shared multi-tenant system (already built/proven); a new client = a new row + config + a Remixed frontend (§0).

**What this is NOT:** not a backend clone, not a regenerate-from-scratch. The shared backend stays frozen; only the per-client marketing site is new.

## Launch sequence

### 1. Provision the client on the shared backend
- Create the `clients` row (slug, business identity) + related config via the onboarding capture / `updateClientSettings` server fn (admin client).
- Capture all §9b data → run **`/onboard-from-form`** (owner fields → clients columns / template_vars / send_settings; agency config; assets → buckets; assemble the AI knowledge bundle).
- Set `allowed_origins` to the client's marketing domain(s) (so CORS will pass for their site's form POSTs).
- Validate template_vars required keys are all populated.
- **[BUILT — C-3c-1] Finalize & Invite (per-client `/admin` → Settings):** once config is set, mint the client login via **`provisionClientOwner`** (invite → the business notification email = `notification_email ?? email`; audited `client_owner` grant) and read the **Remix handoff checklist** there (slug, `VITE_CLIENT_SLUG`, `allowed_origins`) — which feeds step 3 (Remix). Manual + idempotent. Detail: `/admin-view` → Finalize & Invite; spec `docs/phase-c-3c1-build-spec.md`.

### 2. Messaging provider + per-client A2P registration (Telnyx default; TextGrid legacy)
> **Provider fork (Telnyx-default 2026-07):** new clients are **Telnyx** — `clients.provider` defaults to `telnyx` (the admin "Messaging Provider" select was RETIRED 2026-07-22; there is nothing to choose). **Telnyx path (default for new clients)** = `/telnyx-provider` §4 (10DLC brand → campaign from the same a2p pack → number → Messaging Profile → TeXML app → flip provider; single account, one API key). **TextGrid path** = the steps below — now **FROZEN LEGACY, used only for an existing client already on `textgrid`; it is not offered for new clients.** Either way: register at signing (3–7d Telnyx / 2–4d TextGrid vet overlaps the site build), and the number/webhooks must be wired before `/launch-check`.
- Create the client's **subaccount** under the agency master account; store `provider_subaccount_sid` / `provider_webhook_secret` in the server-only **`client_provider_secrets`** table (2026-07-22 hardening — moved OFF the clients row; set via the admin Settings write-only ProviderSecretsPanel; values never round-trip to any browser).
- Register **Brand** (client EIN, ≥15 days old) → **Campaign** (use-case, sample messages, opt-in/out/help language, T&C + privacy links from the marketing site) → **provision + attach a number** (local area code). Each subaccount vets **INDEPENDENTLY per-client** (~2–4 days — register at signing so it vets during the site build). Detail: `skills/textgrid-provider` §4.
- Store From / MessagingServiceSid on the clients row (non-secret, column names retained).
- Set per-number webhooks (`smsUrl` / `voiceUrl` / `statusCallback`) → the Supabase **edge functions** (TextGrid's inbound/status handlers, verified by `X-TextGrid-Signature`). **Telnyx fork:** point the Messaging-Profile / TeXML webhooks at the `telnyx-*` edge fns (`telnyx-sms-inbound`/`telnyx-sms-status`, `telnyx-voice-inbound`/`telnyx-voice-status`), verified by **Ed25519**. Then forward the number to `call_forwarding_number`.
- Write the provisioned number to `clients.twilio_number` (**TextGrid path only** — single-source; the unchanged runner picks it up). **Telnyx fork:** write `telnyx_number` (+ the other `telnyx_*` columns — `telnyx_messaging_profile_id`, `telnyx_texml_app_id`, `telnyx_brand_id`, `telnyx_campaign_id`); routing keys off `clients.provider`, NOT `twilio_number`. Place the active number on the site + Google Business Profile.
- Brand/Campaign copy + URLs (Description, CTA, samples, T&C + privacy links) come **pre-generated from `/a2p-site-compliance`** (the admin A2P-prep panel; verbatim copy `docs/a2p-compliance-copy-source-of-truth.md`); the contact email domain MUST equal the site domain.

### 3. Remix the marketing site (frontend-only)
- Remix the marketing-site project for the client's domain. Do NOT enable Cloud / provision a new Supabase.
- Point it at the SHARED backend: set VITE_SUPABASE_URL + anon key + project_id to the golden master's values.
- Keep it frontend-only: no service-role key, no DB-hitting server fns. Public reads via anon SELECT; form POSTs go to the shared backend's CORS-guarded public routes.

### 4. Invoke the design layer
- Run **`/website-structure`**: generate the page set from onboarding (services/areas up to 12/14, only what's supported), steer copy + visual by the agency-chosen style preset, theme the brand color, load assets, mimic the agency-uploaded reference screenshots.
- Generate the A2P-compliant terms/privacy page (§9b.C) → store its URL in template_vars.
- Generate the compliance pages (single-checkbox opt-in, named Privacy/ToS, SMS Program page, footer links, working `/review` page) per `/a2p-site-compliance` — copy reproduced VERBATIM from `docs/a2p-compliance-copy-source-of-truth.md` (tokens only).
- As the template library matures, prefer applying a proven design template (Mode 2) over generating fresh (Mode 1).

### 5. Verify (gate)
- Run **`/launch-check`** (per-client go-live subset, section E): config complete, template_vars populated, provider number forwarded + placed (per-client A2P Campaign approved), allowed_origins set, site pages match onboarding, terms page linked, consent present.
- End-to-end smoke test: submit a lead form from the live domain → contact created on the shared backend → drip enrolls → SMS sends → owner notified.
- All green → client is live.

## Order & dependencies
`/onboard-from-form` (data) → telephony → Remix site → `/website-structure` (design) → `/launch-check` (gate). The backend (`/scratch-foundation`) and the feature/automation skills are NOT run per client — they're already in the frozen golden master. This skill only adds the client and their frontend.

## Build notes
- Everything backend-side is config/data on the shared system; nothing regenerates the backend.
- The only per-client NEW code is the Remixed marketing site (design layer).
- If onboarding data is incomplete, block at step 1 (don't launch with blank merge vars or missing review link).
- Repeatable: each new client is steps 1–5 again, against the same unchanged backend.
