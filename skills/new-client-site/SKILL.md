---
name: new-client-site
description: Use to launch a new client — the per-client orchestrator. Provisions the client on the ONE shared backend (client row + settings + Twilio number + onboarding capture), Remixes the marketing site for the client's domain (frontend-only, pointed at the shared backend), invokes the design layer, and runs the launch check. Does NOT clone or regenerate the backend. Run AFTER the golden master exists. Sequences the other per-client skills; doesn't reimplement them.
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

### 2. Telephony (Twilio Option 1)
- Provision a number under the ONE parent Twilio account; store From / MessagingServiceSid on the clients row (non-secret).
- Forward the number to `call_forwarding_number`; ensure inbound + voice-status route by To → this client.
- Confirm the agency's A2P 10DLC campaign covers the new number (no per-client re-vetting).
- Place the number on the site + Google Business Profile.

### 3. Remix the marketing site (frontend-only)
- Remix the marketing-site project for the client's domain. Do NOT enable Cloud / provision a new Supabase.
- Point it at the SHARED backend: set VITE_SUPABASE_URL + anon key + project_id to the golden master's values.
- Keep it frontend-only: no service-role key, no DB-hitting server fns. Public reads via anon SELECT; form POSTs go to the shared backend's CORS-guarded public routes.

### 4. Invoke the design layer
- Run **`/website-structure`**: generate the page set from onboarding (services/areas up to 12/14, only what's supported), steer copy + visual by `site_style`, theme the brand color, load assets, mimic the agency-uploaded reference screenshots.
- Generate the A2P-compliant terms/privacy page (§9b.C) → store its URL in template_vars.
- As the template library matures, prefer applying a proven design template (Mode 2) over generating fresh (Mode 1).

### 5. Verify (gate)
- Run **`/launch-check`** (per-client go-live subset, section E): config complete, template_vars populated, Twilio forwarded + placed, allowed_origins set, site pages match onboarding, terms page linked, consent present.
- End-to-end smoke test: submit a lead form from the live domain → contact created on the shared backend → drip enrolls → SMS sends → owner notified.
- All green → client is live.

## Order & dependencies
`/onboard-from-form` (data) → telephony → Remix site → `/website-structure` (design) → `/launch-check` (gate). The backend (`/scratch-foundation`) and the feature/automation skills are NOT run per client — they're already in the frozen golden master. This skill only adds the client and their frontend.

## Build notes
- Everything backend-side is config/data on the shared system; nothing regenerates the backend.
- The only per-client NEW code is the Remixed marketing site (design layer).
- If onboarding data is incomplete, block at step 1 (don't launch with blank merge vars or missing review link).
- Repeatable: each new client is steps 1–5 again, against the same unchanged backend.
