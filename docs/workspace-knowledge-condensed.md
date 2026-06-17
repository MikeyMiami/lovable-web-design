# Platform — Always-On Context (condensed)

Multi-tenant Reviews/SMS automation SaaS for local service businesses (white-label, replaces GoHighLevel). This is the always-on north star. Full detail lives in the per-feature Skills; build from whichever Skill is loaded, governed by these rules.

## Core architecture [LOCKED — never violate]
- **ONE shared multi-tenant backend** ("golden master") serves ALL clients. Built once, frozen, NEVER regenerated per client. Every tenant row keyed by `client_id`; isolation via RLS.
- **Per-client launch** = add a client row + config to the shared backend + Remix only that client's marketing site (frontend-only). NOT a backend clone, NOT an AI-regenerate.
- **Why shared (not per-client backends):** per-client backends reintroduce AI-drift (every fix re-prompted across N projects, diverges). Shared = one codebase, one place to fix. Do not reopen.
- **Project structure:** Project 1 = shared backend + admin dashboard + tenant app (`app.theirdomain.com`); owns the DB. **N STYLE templates** (one frontend-only Lovable project per style preset — Family-Owned, Owner-Operated, Corporate/Professional, Modern Professional, Local Professional; niche is a decoupled DATA layer, not a separate project). Per-client sites = Remixes of the chosen style template, `.env` → Project 1's Supabase. Each style template **bakes in the a2p compliance surface** (two-checkbox opt-in, named Privacy/ToS, SMS Program page, footer links, `/review`) **+ the Turnstile widget**, so every remix is compliant by construction; niche fills `template_vars.segment` + the two consent-category strings from the `/a2p-site-compliance` library. (Layer model: `/template-builder` + `docs/stage5-template-builder-build-spec.md`.)
- **Subdomain routing [LOCKED]:** tenant app `app.theirdomain.com`; marketing root `theirdomain.com`.

## Stack [LOCKED]
TanStack Start v1 (React 19 + Vite 7), SSR, Cloudflare Workers (pure JS + fetch, NO native deps). Lovable Cloud/Supabase. Server logic = `createServerFn` + `src/routes/api/public/*`. RLS on EVERY table; roles in `user_roles`; SECURITY DEFINER + STABLE helpers. Three Supabase clients: browser (anon), authed-server-fn (JWT, RLS-scoped), admin (service-role, server-only — NEVER in browser or a Remixed marketing project).

## Frontend-only vs shared-backend split [LOCKED]
- **Remixed marketing site = frontend-only:** anon SELECT on public `clients` columns + CORS-guarded POSTs to the backend's public write routes. NO service-role, NO DB-writing server fns.
- **Admin view + mobile app = shared backend** (authed, DB-touching), served on `app.theirdomain.com`.
- **Tracked-link + funnel routes (`/api/public/r/<token>`, `/api/public/r/rate`, `/api/public/r/feedback`) = shared backend domain** (they write the DB), NOT the client marketing domain.

## Security conventions [LOCKED]
- **NO anon INSERT/UPDATE/DELETE anywhere.** All public writes go through server fns (admin client + Zod + `client_id` resolved server-side from the public slug / Origin → `clients.allowed_origins`, NEVER from the request body) + CORS allowlist + OPTIONS + rate-limit + Turnstile.
- RLS tenant pattern: `client_id IN (SELECT user_client_ids((SELECT auth.uid())))`; admin override `is_admin(...)` in ONE permissive policy per action per table. Wrap `auth.uid()` as `(SELECT auth.uid())` (InitPlan perf).
- `source` columns are server-set (CHECK/enum), never client-supplied. Phones normalized to E.164 (`phone_e164`).

## Isolation guardrails (what makes shared-backend safe) [LOCKED]
1. **RLS-audit gate** — CI/test fails if any tenant table lacks a `client_id`-scoped policy.
2. **Per-client cron fairness** — runner round-robins clients (one big client can't starve others).
3. **Export-client server fn** — `WHERE client_id=$1` across tenant tables → bundle (offboarding/portability); offboard via `status='archived'`+`deleted_at`.
4. **CORS resolver** — `client_id` from server-resolved Origin/Host, never request body.

## Data model essentials [LOCKED]
- Enrollments key by `sequence_key` (text, value-matches `sequences.key`, no FK). UNIQUE (client_id, contact_id, sequence_key) — dedup BEFORE adding.
- Enums are real Postgres ENUMs (need `ALTER TYPE ADD VALUE`). Add: `contact_status` += review_completed, negative_review, reactivation; `contact_source` += chat_widget, mobile_enroll. All values lowercase_snake.
- `timezone` lives on `send_settings` (not clients). Merge values live in `template_vars` (e.g. `review_request_link`), not as columns.
- Soft-delete `deleted_at` on contacts/clients. `events.created_by`. Partial index `enrollments(next_run_at) WHERE status='active'`.
- NO `client_secrets` table in v1 (reserved for Option-2 BYO-provider/BYO-Twilio only).

## Send timing [LOCKED]
- Marketing/follow-up SMS (review, one-year, reactivation): only **9am–7pm client tz** (SMS Send Window). Outside → defer to 9am next day, preserve order.
- Lead-form drip is **transactional** — branches on **Business Hours** (a SEPARATE per-client setting), not the Send Window.
- Missed-call textback fires **24/7** (live signal, not gated).
- Caps: daily SMS send cap; daily enrollment cap (default 50, enforced at enrollment path). Reactivation: 50/day + 2/20min.
- Cron runner: bounded batch, `FOR UPDATE SKIP LOCKED`, blocked→reschedule WITHOUT advancing step (never skip/drop), 5xx→jitter / 4xx→fail, 2× send retry, log every decision to `events`, `x-cron-secret` (`CRON_SECRET`).

## External dependencies [CONFIRMED]
- **Email (owner notifications):** Lovable native transactional, ONE platform agency sender (NS-delegated domain, `notify@myagency.com`), ~120/min. NOT per-client. Needs Lovable Cloud.
- **Messaging provider = TextGrid** (Twilio-API clone; fetch, NO SDK): agency master account → **per-client subaccount → Brand (client EIN) → Campaign → number**; each vets independently per-client (~2–4 days). Per-client From/MessagingServiceSid (non-secret, on `clients`, column names retained); master auth token = runtime secret; per-client `provider_webhook_secret` for webhook verification. **Inbound + voice-status webhooks are NET-NEW at 1f** (do NOT exist in the frozen master): per-client subaccount routes under `/api/public/*`, route by `To`, verify **`X-TextGrid-Signature`** BEFORE any DB write. Outbound `from` is caller-resolved; the send primitive stays SEND-ONLY.
- **AI chat widget:** Lovable AI Gateway `https://ai.gateway.lovable.dev/v1`, auth `LOVABLE_API_KEY` (ambient server runtime, never browser), model `google/gemini-3-flash-preview`. Streaming chat → `src/routes/api/chat.ts` (AI SDK `streamText`/`toUIMessageStreamResponse`, client `useChat`); one-shot → `createServerFn`. Knowledge = per-request system-prompt injection. Handle 429/402.
- **Google:** NO OAuth/API — stored strings only (`review_link`, `review_place_id`).
- **Storage:** Supabase `public-assets` (public-read), `client-assets` (private, client_id-scoped).
- **Scheduling:** pg_cron + pg_net → `/api/public/cron/sequences` (drip runner) AND `/api/public/cron/reactivation` (agency-pool runner). **UNSCHEDULED by design until LAST in 1f** (manual ticks during build); cron route has a `?ping=1` deploy-promotion health-check; schedule only the canonical prod URL, never a `*-preview` alias.
- **Bot protection:** Cloudflare Turnstile (site key public, secret runtime). Enforced server-side **fail-CLOSED** on the 3 public lead-intake routes (`intake`/`discount`/`chat/optin`); **fail-OPEN+alert** on a siteverify infra failure; `chat/request` = rate-limit-only; webhooks/cron excluded (1f step 3, shipped). The widget is **baked into the marketing template** — no widget = no token = zero leads; add the per-client domain as a Turnstile hostname at launch.
- **Rate-limiter:** **DB-backed** — `rate_limit_hits` table + atomic `check_rate_limit()` RPC, per-IP (10/10m) + per-client (60/10m) from `CF-Connecting-IP`, 429+`Retry-After` (1f step 3, shipped). **NO KV / Durable Objects in the Lovable/Nitro runtime** — the DB is the store (NOT in-memory; Workers isolates).

## Terminology [LOCKED]
- **Review Completed** = clicked review link / rated ≥ threshold → went to Google → enrolls into One-Year drip.
- **Negative Review** = rated < threshold → private feedback page → does NOT enroll One-Year.
- **Review funnel:** `/api/public/r/<token>` (tracked) → `/api/public/r/rate` (1–5 stars, threshold default 4 inclusive) → ≥thr Google + Review Completed, <thr `/api/public/r/feedback` + Negative Review.
- **Drips:** Review Request (4 SMS), One-Year Follow-Up (5 SMS, exit on reply/opt-out), Lead-Form (business-hours branched), Missed-Call Textback, Reactivation. **Reactivation is now the AGENCY number-POOL model** (separate `reactivation_*` tables + a finite-campaign runner + `/cron/reactivation`; sends from a pool number with agency master creds, auto-releases when the campaign's last follow-up fires). The legacy per-client reactivation drip (sent from `clients.twilio_number`, same 4 texts as review, CSV upload) is **LOGICALLY DEPRECATED** — frozen code intact, routes zero traffic.
- Opt-out keyword **"pass"** = **SOLE-word** (whole inbound msg must be exactly "pass"; tightened from `\bpass\b`, which false-positived "pass this along") + STOP/HELP/START, at the **net-new inbound webhook** (1f; verifies `X-TextGrid-Signature` before any DB write).
- Naming: `{first_name}` customer-facing, `{full_name}` internal notifications.

## Build discipline [LOCKED]
- Build ONE layer/skill at a time → validate (migration files + live DB queries > prose) → next. Additive migrations only (never drop; nullable+default). Skill wins over Lovable suggestions; if a skill is wrong, fix the skill, don't patch around it. Build then test in separate turns.

> Full per-feature detail (exact SMS copy, timing, build steps) is in the loaded Skill for each feature. This doc is the governing context; the Skill is the build instruction.
