# Platform — Always-On Context (condensed)

Multi-tenant Reviews/SMS automation SaaS for local service businesses (white-label, replaces GoHighLevel). This is the always-on north star. Full detail lives in the per-feature Skills; build from whichever Skill is loaded, governed by these rules.

## Core architecture [LOCKED — never violate]
- **ONE shared multi-tenant backend** ("golden master") serves ALL clients. Built once, frozen, NEVER regenerated per client. Every tenant row keyed by `client_id`; isolation via RLS.
- **Per-client launch** = add a client row + config to the shared backend + Remix only that client's marketing site (frontend-only). NOT a backend clone, NOT an AI-regenerate.
- **Why shared (not per-client backends):** per-client backends reintroduce AI-drift (every fix re-prompted across N projects, diverges). Shared = one codebase, one place to fix. Do not reopen.
- **Project structure:** Project 1 = shared backend + admin dashboard + tenant app (`app.theirdomain.com`); owns the DB. Project 2 = lean marketing template. Per-client sites = Remixes of Project 2, `.env` → Project 1's Supabase.
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
- NO `client_secrets` table in v1 (reserved for Option-2 BYO-Twilio only).

## Send timing [LOCKED]
- Marketing/follow-up SMS (review, one-year, reactivation): only **9am–7pm client tz** (SMS Send Window). Outside → defer to 9am next day, preserve order.
- Lead-form drip is **transactional** — branches on **Business Hours** (a SEPARATE per-client setting), not the Send Window.
- Missed-call textback fires **24/7** (live signal, not gated).
- Caps: daily SMS send cap; daily enrollment cap (default 50, enforced at enrollment path). Reactivation: 50/day + 2/20min.
- Cron runner: bounded batch, `FOR UPDATE SKIP LOCKED`, blocked→reschedule WITHOUT advancing step (never skip/drop), 5xx→jitter / 4xx→fail, 2× send retry, log every decision to `events`, `x-cron-secret` (`CRON_SECRET`).

## External dependencies [CONFIRMED]
- **Email (owner notifications):** Lovable native transactional, ONE platform agency sender (NS-delegated domain, `notify@myagency.com`), ~120/min. NOT per-client. Needs Lovable Cloud.
- **Twilio Option 1:** ONE parent account via connector gateway (fetch, NO SDK). Per-client From/MessagingServiceSid (non-secret, on `clients`); parent auth token = runtime secret. Inbound + voice-status webhooks at parent, route by `To`. Verify `X-Twilio-Signature` BEFORE any DB write.
- **AI chat widget:** Lovable AI Gateway `https://ai.gateway.lovable.dev/v1`, auth `LOVABLE_API_KEY` (ambient server runtime, never browser), model `google/gemini-3-flash-preview`. Streaming chat → `src/routes/api/chat.ts` (AI SDK `streamText`/`toUIMessageStreamResponse`, client `useChat`); one-shot → `createServerFn`. Knowledge = per-request system-prompt injection. Handle 429/402.
- **Google:** NO OAuth/API — stored strings only (`review_link`, `review_place_id`).
- **Storage:** Supabase `public-assets` (public-read), `client-assets` (private, client_id-scoped).
- **Scheduling:** pg_cron + pg_net → `/api/public/cron/sequences`.
- **Bot protection:** Cloudflare Turnstile (site key public, secret runtime).
- **Rate-limiter:** Durable Objects / KV / DB (NOT in-memory — Workers isolates).

## Terminology [LOCKED]
- **Review Completed** = clicked review link / rated ≥ threshold → went to Google → enrolls into One-Year drip.
- **Negative Review** = rated < threshold → private feedback page → does NOT enroll One-Year.
- **Review funnel:** `/api/public/r/<token>` (tracked) → `/api/public/r/rate` (1–5 stars, threshold default 4 inclusive) → ≥thr Google + Review Completed, <thr `/api/public/r/feedback` + Negative Review.
- **Drips:** Review Request (4 SMS), One-Year Follow-Up (5 SMS, exit on reply/opt-out), Lead-Form (business-hours branched), Missed-Call Textback, Reactivation (CSV upload, same 4 texts as review).
- Opt-out keyword **"pass"** + STOP/HELP/START, whole-word, handled at inbound webhook.
- Naming: `{first_name}` customer-facing, `{full_name}` internal notifications.

## Build discipline [LOCKED]
- Build ONE layer/skill at a time → validate (migration files + live DB queries > prose) → next. Additive migrations only (never drop; nullable+default). Skill wins over Lovable suggestions; if a skill is wrong, fix the skill, don't patch around it. Build then test in separate turns.

> Full per-feature detail (exact SMS copy, timing, build steps) is in the loaded Skill for each feature. This doc is the governing context; the Skill is the build instruction.
