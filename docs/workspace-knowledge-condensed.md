# Platform — Always-On Context (condensed)

Multi-tenant Reviews/SMS automation SaaS for local service businesses (white-label, replaces GoHighLevel). This is the always-on north star. Full detail lives in the per-feature Skills; build from whichever Skill is loaded, governed by these rules.

## Core architecture [LOCKED — never violate]
- **ONE shared multi-tenant backend** ("golden master") serves ALL clients. Built once, frozen, NEVER regenerated per client. Every tenant row keyed by `client_id`; isolation via RLS.
- **Per-client launch** = add a client row + config to the shared backend + Remix only that client's marketing site (frontend-only). NOT a backend clone, NOT an AI-regenerate.
- **Why shared:** per-client backends reintroduce AI-drift (every fix re-prompted across N projects). Shared = one codebase, one place to fix. Do not reopen.
- **Project structure:** Project 1 = shared backend + admin dashboard + client PWA (today served on the SHARED origin `app.pierceworks.co`; per-client `app.theirdomain.com` = future white-label). **N STYLE templates** (one frontend-only Lovable project per style preset; the AGENCY picks the shell — the client site-style choice was removed; niche = decoupled DATA layer via `template_vars.segment` + the a2p niche library). Per-client sites = Remixes of the chosen template, `.env` `VITE_CLIENT_SLUG` → Project 1's Supabase. Templates bake in: the a2p-compliant surface (**SINGLE-checkbox** marketing-skeleton consent, named Privacy/ToS/SMS-Program, footer links, `/review/<token>` 302 redirect) + the **invisible native PoW bot-shield** + the **hero-embedded shared lead form** (mobile phone REQUIRED, email optional; copy from `template_vars.lead_form_headline/subhead/cta`; ONE shared component drives hero card + /contact).
- **Data is LIVE:** remixes fetch client data EVERY page load via the `get_client_public` RPC (+ anon content-page RPCs). Admin Settings edits and `content_pages` rows appear on live sites at next load; only DESIGN/layout is baked at build.
- **Onboarding lifecycle:** 7-step wizard (agency `/onboard` or one-time tokenized client link; collects identity, content, discount offer, support/contact emails, A2P identity + optional CP 575 letter upload) → `status='pending'` → agency `/admin/review` → **Finalize & Activate** (flips `active` + silently creates the `client_owner` login — **NO email**) or **Decline** (admin fn, pending-only guard = PERMANENT purge of row + storage). The client's ONE email comes later: **Send Client Welcome** (same page, active-only, agency-editable message) at LAUNCH, after the site is live — 3 links: their website / set-password (`app.pierceworks.co/set-password`) / app download (`/download?c=`). Re-sendable = the agency-side password reset.
- **Domain map [LOCKED]:** client's own domain = their marketing site (+ `/review/<token>` 302 → funnel) · `app.pierceworks.co` = the app — admin, client PWA, login, set-password, download · `notif.pierceworks.co` = Resend sender identity · `reviewbatch.com` = the shared review-funnel backend (`/api/public/r/*` only; every other path 302s to the app). Env `PUBLIC_APP_URL` is the REVIEW-link base (= reviewbatch.com), **NOT** the app origin — never use it to build app URLs.

## Stack [LOCKED]
TanStack Start v1 (React 19 + Vite 7), SSR, Cloudflare Workers (pure JS + fetch, NO native deps). Lovable Cloud/Supabase. Server logic = `createServerFn` + `src/routes/api/public/*`; provider webhooks = **Supabase Edge Functions**. RLS on EVERY table; roles in `user_roles`; SECURITY DEFINER + STABLE helpers. Three Supabase clients: browser (anon), authed-server-fn (JWT, RLS-scoped), admin (service-role, server-only — NEVER in a browser or a Remixed site).

## Frontend-only vs shared-backend split [LOCKED]
- **Remixed site = frontend-only:** reads via `get_client_public` RPC (**the SOLE anon door** — no `clients_public` view, no direct anon SELECT on clients; owner PII stripped) + CORS-guarded POSTs to public write routes. NO service-role, NO DB-writing server fns.
- **Admin + client PWA = shared backend** (authed, DB-touching).
- **Tracked/funnel routes** (`/api/public/r/*`) = backend domain. Optional per-client `review_link_domain` → review SMS links become `clientdomain.com/review/<token>` (site 302s to the funnel).

## Security conventions [LOCKED]
- **NO anon INSERT/UPDATE/DELETE anywhere.** Public writes go through routes with: Zod + `client_id` resolved SERVER-SIDE from Origin → `allowed_origins` (slug fallback; NEVER from the body) + CORS + OPTIONS + DB rate-limit + the **PoW bot-shield** (`pow_token` minted at `/api/public/challenge`, solved in a Web Worker; sig + 3s–10min age + difficulty + one-time replay; legacy `turnstile_token` accepted during transition) + hidden `website` honeypot (non-empty → silent fake-success, nothing created). `POW_SECRET` secret required; fail-CLOSED on bad checks, fail-OPEN+alert on infra error.
- RLS tenant pattern: `client_id IN (SELECT user_client_ids((SELECT auth.uid())))`; admin override `is_admin(...)`; wrap `auth.uid()` as `(SELECT auth.uid())`.
- `source` columns server-set; phones E.164 (`phone_e164`).
- **Per-client provider creds live in the server-only `client_provider_secrets` table** (RLS on, ZERO policies; admin writes via the write-only ProviderSecretsPanel; values never readable by any browser). EIN letters = private `client-assets/{id}/a2p/`, admin-viewed via 5-min signed URLs.

## Isolation guardrails [LOCKED]
1. RLS-audit gate — every tenant table has a `client_id`-scoped policy.
2. Per-client cron fairness — runner round-robins clients.
3. Export-client fn (offboard = `status='archived'`+`deleted_at`).
4. CORS resolver — `client_id` from server-resolved Origin, never the body.

## Data model essentials [LOCKED]
- Enrollments key by `sequence_key` (text); UNIQUE (client_id, contact_id, sequence_key) — dedup BEFORE adding. Real Postgres ENUMs (lowercase_snake).
- `timezone` on `send_settings`. Merge values in `template_vars` (anon-safe ONLY — never PII/secrets; owner email = dedicated `notification_email` column, recipient = `notification_email ?? email`).
- Soft-delete `deleted_at` on contacts/clients. Partial index `enrollments(next_run_at) WHERE status='active'`.
- Tiers **297 Starter / 397 Growth / 749 Pro**; the only tier gate = `seo_cadence` (monthly SEO) on 749.

## Send timing [LOCKED]
- Marketing/follow-up SMS (review, one-year, reactivation): **9am–7pm client tz** (Send Window); outside → defer to 9am, preserve order.
- Lead-form drip = transactional — branches on **Business Hours** (separate setting). Missed-call textback = 24/7.
- Caps: daily send cap; daily enrollment cap (default 50). Reactivation: 50/day + 2/20min + required consent attestation; sends from the client's own number via the normal runner (the agency number-POOL model was REMOVED).
- Cron runner: bounded batch, `FOR UPDATE SKIP LOCKED`, blocked→reschedule WITHOUT advancing, 5xx→jitter / 4xx→fail, 2× retry, every decision → `events`, `x-cron-secret`. pg_cron + pg_net → `/api/public/cron/sequences`; **UNSCHEDULED until the launch gate** (`?ping=1` health check; schedule only the canonical prod URL).

## External dependencies [CONFIRMED]
- **Owner notifications = 3 channels:** in-app feed + **email via Resend** (ONE platform sender `alerts@notif.pierceworks.co`; per-client recipient + on/off toggle) + **web push** (VAPID, installed PWA). NOT per-client sending domains.
- **Messaging = dual-provider via `clients.provider`:** **Telnyx = DEFAULT** (single account, ONE `TELNYX_API_KEY`; per-client `telnyx_number` / messaging-profile / TeXML-app / brand / campaign columns; live webhooks = `telnyx-*` Edge Functions, Ed25519-verified; voice ringback + AMD missed-call detection live-validated). **TextGrid = FROZEN LEGACY** (existing clients only; edge fns verify `X-TextGrid-Signature` HMAC keyed by `client_provider_secrets.webhook_secret`). **A2P 10DLC registration runs on a SEPARATE external platform**, fed by onboarding-collected identity (legal name/EIN/legal address/vertical/TCPA + CP 575) — client sites stay a2p-compliant by design anyway.
- **Chat widget = CAPTURE-FIRST:** a lead form in a chat skin — **NO AI** (AI Q&A path PARKED). Greeting/confirmation from `template_vars`; posts `/api/public/chat/optin` (consent REQUIRED); same lead-form drip.
- **Google:** NO OAuth/API — stored strings only (`review_link`, `review_place_id`).
- **Storage:** `public-assets` (public), `client-assets` (private, client_id-scoped).
- **Rate-limiter: DB-backed** — `rate_limit_hits` + atomic `check_rate_limit()` RPC (also the PoW replay guard). NO KV/Durable Objects/in-memory.

## Terminology [LOCKED]
- **Review funnel:** `/api/public/r/<token>` → rate 1–5 (threshold default 4, inclusive) → ≥thr Google + **Review Completed** (→ One-Year drip); <thr private feedback + **Negative Review** (no One-Year).
- **Drips:** Review Request (4 SMS), One-Year (5 SMS, exit on reply/opt-out/discount-claim), Lead-Form (business-hours branched), Missed-Call Textback, Reactivation (CSV, same 4 texts as review).
- Opt-out **"pass"** = SOLE-word (whole message exactly "pass") + STOP/HELP/START at the inbound webhook.
- `{first_name}` customer-facing; `{full_name}` internal.
- **SEO pages are DATA** (`content_pages` rows; the template is a generic renderer; sitemap from the store). Admin `/admin/seo`: AI-seed map from services → correct vs the real GBP → Seed Core-30 → AI-write → Publish; ongoing geo/supporting ~monthly (749 cadence). Publishing never touches the Lovable project.

## Build discipline [LOCKED]
- ONE layer/skill at a time → validate (migrations + live DB queries > prose) → next. Additive migrations. Skill wins over Lovable suggestions; if a skill is wrong, fix the skill. Build and test in separate turns.

> Full per-feature detail (exact SMS copy, timing, build steps) is in the loaded Skill. This doc is the governing context; the Skill is the build instruction.
