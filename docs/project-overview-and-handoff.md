# Project Overview & Handoff — lovable-web-design (current @ ff3a365, 2026-06-30)

> **Point a fresh Claude instance here first.** Self-contained overview of what the project is, what's built + why, what's next, the full skills/docs inventory, and the working discipline. The repo (this file + the skills + docs) is the source of truth — pull `main` @ `ff3a365`. (The older `HANDOFF.md` is accurate for the 1f/B-design era but its "current spot" predates the C-3c/C-3d onboarding arc + SEO — this doc supersedes that part.)

---

## 1. What this is
A multi-tenant **SMS-automation + reviews "golden-master" SaaS** for local businesses, built in **Lovable** on **Supabase** (Postgres + Auth + RLS + Storage) with **TanStack Start v1 / React 19** on **Cloudflare Workers**. **ONE shared backend** is built/proven once, **frozen**, and never regenerated per client. A per-client launch = one `clients` row + config on the shared backend + a Remixed marketing site pointed at it. Business logic is never per-client (anti-drift).

**Two repos (both `MikeyMiami`, `gh` authed):**
- **`lovable-web-design`** (THIS repo) — the **planning / source-of-truth library**: the spec, **17 skills**, build-specs, build-logs, roadmap. Claude edits here. **Frozen baseline referenced: `golden-master-v1.7`.**
- **`cloud-spark-setup`** — the **built app code** (Lovable owns it). Cloned at `C:\Users\Pierc\Desktop\cloud-spark-setup`. **Always validate against its live `origin/main`** (`git fetch origin && checkout origin/main`), NOT the stale local clone.

## 2. Working discipline [how every change happens — non-negotiable]
1. Scope a change (read-only) → write a **build-spec** / build prompt in `docs/` (held) → user reviews → pastes into Lovable.
2. Lovable builds → user pastes the report → **Claude validates against the REAL committed code** (`cloud-spark-setup` `origin/main`) + the skills, NOT Lovable's prose.
3. Record a `docs/build-log/*` validation entry → **commit + push to `main`** (this repo) with the `Co-Authored-By: Claude Opus 4.8 (1M context)` footer → **verify `HEAD == origin/main` + clean tree**.
4. **Hand the user VERBATIM mirror lines** (exact old→new text) so their separate "masters" (their Lovable workspace copies) stay byte-identical. The user can only see what's typed in chat — never reference terminal/diff output.
5. **Public repo → no secret VALUES ever committed** (secret-scan every commit). Deploys go straight to `main` (no staging branch).

## 3. Where we are — two tracks
- **(A) App-feature build — ACTIVE.** Onboarding arc **C-3c/C-3d COMPLETE** (§4). Now on the **SEO system** (§5).
- **(B) 1f LIVE-flip — PARKED on TextGrid** (no account yet). All the real-provider swap / inbound webhooks / A2P / pg_cron / the 8 LIVE-flip gates are built in STUB and tagged `golden-master-v1.1…v1.6`; resumes when TextGrid clears (→ Phase D + v1.8). Detail in `HANDOFF.md` §2/§3.

**Frozen baseline = `golden-master-v1.7`** (B-0 client-login auth + ticketing + consent ledger + payment gate + A2P core cols). Everything since is **app-layer (no re-tag)** EXCEPT the **one additive migration** `onboarding_tokens` (`20260628235901`, C-3d-1).

## 4. The onboarding arc — C-3c + C-3d [COMPLETE, validated]
The full client-acquisition loop (all app-layer on v1.7 except `onboarding_tokens`):
- **Agency** (`/agency` Onboarding tab): **"Generate onboarding link"** (`generateOnboardingLink` → a one-time token → `/onboard/$token` URL) + **"Email this link"** (a `mailto:` composer with an editable subject/body template persisted in `localStorage` — sends from the agency's real address, no email provider). OR the agency **self-fills** at `/onboard`.
- **Client** (public `/onboard/$token`): the **mode-aware `OnboardWizard`** in client mode → **uploads via a token-gated service-role proxy** (`/api/public/onboarding/upload` → `public-assets` under the token's `draft_id`; rate-limit + image/10MB caps) → **submits** via `/api/public/onboarding/submit` (**claim-first** single-use token → shared **`insertClientFull`** forces `status='pending'`, slug-collision auto-resolve → back-links `created_client_id`) → **"All Set!"** success.
- **Lifecycle:** created client = **`status='pending'`** (free-text status, zero-schema; dormant — no automations, not anon-visible, but admin-selectable) → appears in the **`/agency` Onboarding queue** (badge, 15s poll) → **Open** → **`/admin/review`** console (status pill + **immutable submission viewer** + missing-required-`template_vars` reminder + the shared **`<FinalizeInvite/>`**) → **Finalize & Invite** (`provisionClientOwner` → invite the business email + audited `client_owner` grant + flip `status` pending→active + the Remix handoff checklist: slug / `VITE_CLIENT_SLUG` / `allowed_origins` / `site_style`).
- **Onboarding wizard = an 8-step stepper** (`onboard.tsx` → `OnboardWizard`): Account Setup · Content · Branding · Industry & Style · Photos · **Social Links** · Texting Registration · Review & Create. Captures into `clients` cols / `template_vars` / `send_settings` / `public-assets` + an immutable submission JSON.
- **Social links:** the "Reviews" step became **"Social Links"** — collects the **Google Business Profile link** (→ `template_vars.google_business_profile_link`) + **Instagram / Facebook / LinkedIn** (→ `clients.social_links` jsonb), each with an "I don't have one" box. Admin Settings → Brand & Site has **friendly IG/FB/LinkedIn editors** (merge-safe into `social_links`). Discount + the formatted review link are **agency-set** in admin (removed from onboarding).
- **Turnstile on the public submit = BACKLOGGED** (decided against — single-use token + rate-limit + private links suffice; revisit only if onboarding goes public).
- Full detail: `docs/phase-c-scope.md`, `docs/phase-c-3*.md` build-specs, `docs/build-log/stage-c3*.md`.

## 5. The SEO system [IN PROGRESS — 2 skills shipped, plan signed off]
Derived from **5 expert local-SEO transcripts** (7-figure agency) → signed-off master plan.
- **Core insight:** local SEO = **Google Business Profile ranking** (3-pack; 60–70% of clicks). **Entity-based** (business↔services↔geography must match). **The website MIRRORS the GBP.**
- **The Core 30 structure:** homepage (GBP landing page + the **8 consistency signals**) + **3–4 category pages** + **25–30 service pages** (one per GBP category/service) + genuinely-local **neighborhood pages** + **supporting/FAQ pages**; **editorial in-content internal linking** (nav/footer pass ~no authority).
- **Two skills shipped:** **`seo-build`** (site/template STRUCTURE + technical: 8 signals, Core 30, titles/meta/one-H1/schema JSON-LD/semantic/alt/canonical/OG/sitemap/robots, the **`content_pages` content-store + dynamic render-route contract**, Core Web Vitals) + **`seo-content`** (content PRODUCTION: quality bar, local-specificity, per-page-type patterns, the **8-pass writing pipeline**, PAA/Reddit research, editorial linking, and the **rank-map topical-vs-geographic decision + monthly loop**). **`website-structure` reconciled** to the Core 30 (retired the old service-area-lander model).
- **Operator view:** `docs/seo-operator-guide.md` — per skill: what to **COLLECT** (nothing new from clients; agency-set categories/services-by-category/geo), the **ADMIN** actionables (an SEO/Core-30 panel + a content queue later), what it **CREATES**, and how to **TEST** (Claude's code drift-check + operator checks: Google Rich Results Test, the 8 signals, sitemap, PageSpeed). **This guide is updated after every SEO piece.**
- **Canonical spec:** `docs/seo-system-analysis-and-skill-plan.md` (full transcript analysis + the locked O1–O8 master plan).
- **OUT of scope for Lovable** (agency ops / 3rd-party tools): off-site links (chambers/sponsorships/directories/"best of"), GBP edits + posts + review responses, **Lead Snap** rank-map tracking + GBP management, Screaming-Frog content audits.

### SEO — what's next (each = a normal scope→build→validate→commit cycle)
1. **Content store** — the additive `content_pages` backend table (anon-read, tenant-scoped, keep `audit_tenant_rls()` satisfied) + the marketing-template **dynamic render routes** (the CMS-backed endpoint — pages are DATA the site renders; the build + tool write rows). **The one real schema add.**
2. **Admin SEO panel** — categories / services-by-category (the Core-30 map) / geo — AI-derived + agency-confirmed.
3. **Content-automation tool** (the "Core-30-Agent" equivalent) — gap-analysis + PAA/Reddit/local research + 8-pass writing → writes `content_pages` rows; + **rank-map CSV input** (→ top-3% → next-batch topical/geographic recommendation). A later module (like CRM/reactivation were).

## 6. Skills inventory (17 — all committed @ ff3a365; pull to mirror)
| Skill | What it is | Changed this arc? |
|---|---|---|
| `scratch-foundation` | Backend data model + tenant lifecycle (status='pending', `onboarding_tokens`, `insertClientFull`, isolation guardrails) | ✅ (C-3c-2a, C-3d) |
| `onboard-from-form` | The 8-step onboarding wizard capture (mode-aware/client-facing; Social Links step; field→destination map) | ✅ (C-3, C-3d, social) |
| `admin-view` | `/admin` tabs + per-client Settings (discount agency-set, Review Config GBP/`review_request_link` sync, social editors, Finalize & Invite, Review & Finalize console + submission viewer) | ✅ (C-3c, C-3d, social) |
| `agency-view` | `/agency` cross-tenant (Pending tickets · Onboarding queue + generate-link + email · Payment Access) | ✅ (C-1, C-3c-2c, C-3d) |
| `new-client-site` | Per-client launch orchestrator (provision → telephony → Remix → design → launch-check) | ✅ (C-3c-1 note) |
| `website-structure` | Per-client design layer — **now the Core 30**, reconciled to seo-build/seo-content | ✅ (SEO reconcile) |
| `template-builder` | Style-template build authority (bakes SEO scaffolding once) | — |
| `mobile-app` | The client PWA (tickets, payment-gate shell, per-client branding) | ✅ (B-design) |
| `features` · `automation-config` · `opt-in-forms` · `chat-widget` | The automation/feature layer | — |
| `a2p-site-compliance` | Carrier-compliance copy (verbatim) | — |
| `textgrid-provider` | Messaging provider (1f, parked) | — |
| `launch-check` | Per-client go-live gate (gets an SEO subsection) | — |
| **`seo-build`** | **NEW** — SEO site/template structure + technical standard | ✅ NEW |
| **`seo-content`** | **NEW** — SEO content-production standard + monthly loop | ✅ NEW |

## 7. Key docs (canonical — in `docs/`, 90 total)
- **`HANDOFF.md`** — 1f/B-design-era handoff (its current-spot is superseded by THIS doc).
- **`pathway-to-completion.md`** — the master roadmap (phases A–E; SEO logged in Phase A + backlog).
- **`platform-spec-source-of-truth.md`** — the platform spec.
- **`seo-system-analysis-and-skill-plan.md`** — SEO master plan (5-transcript analysis + O1–O8).
- **`seo-operator-guide.md`** — SEO operator view (collect/admin/create/test).
- **`phase-c-scope.md`** + `phase-c-3*.md` build-specs + `build-log/stage-c3*.md` — the onboarding arc.

## 8. How to get current in a fresh instance
1. `git -C <lovable-web-design> pull --ff-only origin main` (→ `ff3a365`).
2. Read THIS file → `pathway-to-completion.md` → `seo-system-analysis-and-skill-plan.md` + `seo-operator-guide.md` → the relevant skills.
3. For code truth: `git -C C:\Users\Pierc\Desktop\cloud-spark-setup fetch origin && git checkout origin/main`.
4. Resume the SEO thread at **§5 "what's next" → the content store scope**. Follow the discipline in §2.
