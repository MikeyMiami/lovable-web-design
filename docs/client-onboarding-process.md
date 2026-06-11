# Client Onboarding Process — Plain-English Explanation

> **What this doc is:** the simple, step-by-step explanation of how a client goes from "signed up" to "live site + running automations" on this platform. Written to be re-read anytime the process needs re-explaining. No jargon, literal steps, with WHERE each step happens.
>
> **Status note:** this describes the TARGET process. The admin onboarding wizard is built in Stage 3 (`onboard-from-form` skill); site templates are built after Stage 4 (backend freeze). Until those exist, the data-entry steps happen manually against the database instead of through the wizard — same destination, same data, just without the nice UI yet.

---

## The big picture (read this first)

There are **three kinds of Lovable projects** in the workspace:

1. **Project 1 — THE PLATFORM.** The shared backend + admin + database. Holds ALL client data. The cron runner, the drips, the funnel routes all live here. Built once, validated, frozen. **Never remixed, never edited per client.** This is the live, running brain.
2. **Template projects — one per niche×style** (e.g. "Template — Plumbing — Modern"). Frontend-only marketing sites, designed once with care, then **frozen**. They contain NO client data — every business-specific spot in the design is a **variable slot** (like a mail-merge document: `{client.business_name}` where the name goes, brand color from `client.brand_color`, services looped from `template_vars`, photos from the asset manifest). A demo client object fills the slots during design so the template looks real while being built.
3. **Client sites** — a **Remix of a template** (exact copy, zero AI generation), pointed at Project 1 by editing ONE line in `.env`.

**The one rule that makes it all work:** data flows in ONE direction — `onboarding form → admin wizard → database → site/automations read it`. The form is entered ONCE in the admin. The site and the SMS automations both render from the SAME client row + template_vars. Nothing is ever typed twice; the template is never edited per client.

**"Linking" a remix to Project 1 is NOT magic:** it's two environment variables. The template's code fetches `clients` by slug from the backend URL in `.env`. Remixing copies that code; you change `VITE_CLIENT_SLUG` to the new client's slug; done. No prompts, no skills, no AI at remix time — the skills governed how the TEMPLATE was built; by remix time the code already embodies everything.

---

## Onboarding a client — the literal steps

### PHASE A — Data entry (WHERE: Project 1's admin, the onboarding wizard)

1. **Receive the client's completed onboarding form** (their business info, services list, hours, brand colors, logo, categorized photos: work examples / per-service examples / staff).
2. **Open Project 1's admin → onboarding wizard.** Enter/upload everything from the form:
   - Business details → writes the `clients` row (business_name, slug, phone, hours, service_area, tagline, review_link, star_threshold, etc.)
   - Brand assets → `logo_url`, `brand_color`
   - Services + site content values → `template_vars` (jsonb)
   - Photos/videos → storage buckets under structured paths (`{client_id}/work-examples/…`, `{client_id}/services/{service}/…`, `{client_id}/staff/…`) + an asset manifest so the site knows what exists. Missing categories will fall back to pre-approved niche-default images.
   - Send settings → timezone, send window, caps (`send_settings` row)
   - Record the chosen **niche + site style** (`clients.site_style`) — this just tells YOU which template to remix in Phase B.
3. **The onboarding form is now DONE.** Its data lives in the database. The form itself is never uploaded into any Lovable project. Both the website AND the SMS automations will read from what the wizard just wrote — one entry, no double data entry, no drift between site and texts.

### PHASE B — Site creation (WHERE: the Lovable workspace, ~minutes)

4. **Open the matching template project** (per the niche/style chosen in step 2) → click **Remix**. This creates an exact copy — no AI, no generation, no credits burned on design.
5. **Rename the remix** (e.g. "Client — Joe's Plumbing").
6. **Edit `.env` in the remix — change ONE line:** `VITE_CLIENT_SLUG=joes-plumbing` (the backend URL + anon key lines are already correct from the template — they're the same for every client, always Project 1). The site now renders Joe's data, fetched live from Project 1.
7. **Connect the client's domain** to the remixed project (Lovable's domain settings).
8. **In Project 1's admin: add the client's domain to their `allowed_origins`.** This is what makes the backend trust lead-form submissions from their site (the CORS resolver). Without this step the site renders but the lead form is rejected.

### PHASE C — Verify (WHERE: the live site + admin; this is DATA QA, not site QA)

9. Walk the launch checklist (`/launch-check`) — because the code is the same proven template every time, verification is mostly **checking the DATA**: clients row complete? template_vars all set (the 8 required keys)? assets present or falling back cleanly? domain in allowed_origins? send_settings/timezone right? Twilio number assigned + A2P (per launch gates)?
10. **Test the loop end-to-end:** submit the site's lead form → contact appears in admin → lead-form drip enrolls → (stub or live) SMS fires per schedule. Click a tracked review link → funnel pages load logged-out → events recorded.
11. Live.

---

## Why it's built this way (the 10-second version)

- **Remix, not regenerate:** AI generation per client = drift, mistakes, credits. Remix = byte-for-byte copy of a proven design. All design intelligence is spent ONCE per template.
- **Data-driven, not find-and-replace:** the template never contains "Apex Plumbing" hardcoded — only variable slots. So "populating a site" is writing database rows, not editing code.
- **One data entry point:** the wizard writes the row; site + SMS templates + automations all read it. Site says what the texts say, always.
- **A remix CANNOT touch the backend:** template remixes are frontend-only — no Cloud backend, no migrations, anon-key reads only (RLS-scoped). The database can only change through Project 1.

## Template design rules (for when building a NEW template)

### How to literally spin one up (step-by-step)

1. **In the Lovable workspace: create a NEW project.** When prompted about backend/Cloud features — decline. This project is frontend-only (it reads from Project 1; it has no backend of its own). Name it `Template — {Niche} — {Style}` (e.g. "Template — Plumbing — Modern").
2. **Import two skills into this new project** (GitHub subdirectory URLs, same as always): `template-builder` (the data contract + wiring rules) and `website-structure` (page set + the 4 copy voices + design system). Optionally `opt-in-forms` (lead-form field reference).
3. **First prompt to Lovable:** state the niche, attach your design references (screenshots/links/style direction), and say: *"Build a client-site template per the template-builder skill: frontend-only, build the data loader + demo client object first, then design from my references — all business-specific content renders from the client object per the skill's contract, never hardcoded."*
4. **Iterate on the design freely** ("bolder hero", "different font", more references) — this is the one-time credit spend. Visual edits don't touch the data wiring.
5. **Run the skill's self-check** (in template-builder §Build workflow step 5): zero hardcoded business literals, services section loops, brand color re-themes, asset fallbacks render, lead form → `/api/public/intake`, demo renders without a slug / live data renders with one.
6. **Validate against a real test client:** set the `.env` slug to a test client in Project 1 → every field renders their data, lead form lands a contact (domain must be in their allowed_origins).
7. **FREEZE.** GitHub-connect for backup. This Lovable project is now the remixable golden master for this niche×style.

WHEN: the FIRST template is built after Stage 4 (backend freeze). Don't pre-build a library — first real niche, prove the loop, grow on demand.

### The rules the template must follow

1. New **frontend-only** Lovable project (no Cloud), named `Template — {Niche} — {Style}`.
2. Design freely against a **demo client object** shaped exactly like the real `clients` row + `template_vars` contract + asset manifest. Iterate on look/feel as much as needed — this is the one-time credit spend.
3. **Standing prompt rule:** "All business-specific content (name, tagline, phone, colors, logo, services, photos, hours) renders from the `client` data object — NEVER hardcoded in components." Layout/spacing/fonts/section structure = hardcoded and universal; content = variables.
4. Data loader: real slug+URL in `.env` → fetch real client; otherwise → demo object (template still renders standalone during design).
5. Lead form POSTs to the shared backend `/api/public/intake`; tracked-link/funnel URLs use `/api/public/r/...` paths.
6. Build against the `website-structure` skill; validate once against a test client's slug (every field renders, brand color themes, fallbacks work, lead form lands a contact); then **FREEZE**. GitHub-connect for backup; the remixable Lovable project is the operative artifact.
7. Don't pre-build a template library — build for your FIRST real niche, prove the loop with a real client, then expand on demand. Keep a CHANGELOG; template improvements reach existing clients only via deliberate re-remix.

## Where this connects to the build stages

- **Stage 3** builds the admin onboarding wizard (Phase A) — `onboard-from-form` skill (+ extend with niche/style selector, categorized asset upload, manifest, fallback images).
- **Stage 4** freezes Project 1.
- **After Stage 4** build the first template; **Stage 5** = Phases B+C per client.
- Foundation pieces that make this work (already built + validated): anon SELECT on active clients (the site's read path), CORS resolver + allowed_origins (the lead form's trust path), template_vars contract (the shared merge-field set), storage buckets.
