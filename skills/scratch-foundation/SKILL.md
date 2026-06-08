---
name: scratch-foundation
description: Use when building or rebuilding the shared multi-tenant backend core from nothing — the database schema, RLS policies, SECURITY DEFINER helpers, the three Supabase clients, auth/roles, server-function skeleton, public write routes with CORS, the cron drip-runner, storage buckets, and runtime secrets. This is the FIRST skill run when building the golden master. Everything else (features, automations, mobile app, forms) sits on top of this. NOT for per-client launch (that's new-client-site) and NOT for feature copy/logic (features/automation-config).
---

# Scratch Foundation — the shared multi-tenant backend core

Builds the ONE shared multi-tenant backend (the golden master) from nothing, deterministically, in a fixed order. Run this FIRST. Every client lives in this one backend, scoped by `client_id` + RLS. Never regenerated per client. Validated against Lovable's environment (one-shared-backend, server-fn public writes, Twilio one-parent-account, pg_cron drip runner).

## Stack invariants
TanStack Start v1 (React 19, Vite 7), SSR on Cloudflare Workers — **pure JS + fetch, no native/Node-only deps** (this rules out the Twilio SDK; use fetch). Lovable Cloud / Supabase (Postgres + Auth + RLS + Storage). Server logic via `createServerFn` + routes under `src/routes/api/public/*` (these bypass the auth gate — used for webhooks + public form intake + cron). Phones stored E.164. Naming: `{first_name}` customer-facing, `{full_name}` internal.

## Build order (deterministic)
1. Extensions + schema (tables) → 2. SECURITY DEFINER helpers → 3. RLS policies + indexes → 4. The three Supabase clients → 5. Auth/roles bootstrap → 6. Server-fn + public-route skeleton (incl. CORS) → 7. Cron drip-runner skeleton → 8. Storage buckets → 9. Runtime secrets. Do them in this order; later steps depend on earlier ones.

---

## 1. Schema (core tables)
> RECONCILED against the live DB. Existing tables/columns confirmed; net-new additions marked **[ADD]** (need a migration). Enums are real Postgres enums — new values need `ALTER TYPE … ADD VALUE`.

All tenant tables carry `client_id uuid not null references clients(id)`. uuid PKs (`gen_random_uuid()`), `created_at timestamptz default now()`.

- **clients** (existing) — id, slug (unique), business_name, address, phone_display, email, license_number, hours (jsonb), logo_url, brand_color (default `#bd703e`), service_area (text[]), tagline, review_place_id, review_link, google_review_toggle (enum `review_gate_mode`, default `gated`), star_threshold (smallint, default 4), twilio_number, twilio_messaging_service_sid, sending_subdomain, dkim_status, status (default `active`), template_vars (jsonb), created_at, updated_at.
  - **[ADD]** `allowed_origins text[]` (marketing domains → CORS allowlist), `call_forwarding_number text`, `site_style text` (corporate|standard|family_owned|owner_operated), `deleted_at timestamptz` (soft-delete). Note: `review_request_link` — confirm if it's a column or lives in `template_vars` (pick one source of truth).
- **send_settings** (existing, per-client) — holds **`timezone`** (NOT on clients), sms_send_window, **[ADD]** business_hours (separate window for lead-form branching), daily_send_cap, **[ADD]** daily_enrollment_cap (default 50), per-sequence overrides (reactivation: 50/day enroll + 2/20min pacing).
- **user_roles** (existing) — id, user_id (→ auth.users), role (enum `app_role`: admin|client|agency_owner|client_owner|client_staff), client_id (nullable), created_at. UNIQUE (user_id, role, client_id). Roles live HERE.
- **contacts** (existing) — id, client_id, first_name, last_name, phone_e164, email, status (enum `contact_status`), source (enum `contact_source`), consent_basis, consent_at, opted_out_at, notes, created_at, updated_at.
  - `contact_status` enum (existing values): `new, contacted, replied, customer, review_requested, review_clicked, opted_out`. **[ADD VALUES]** needed for our funnel: `review_completed`, `negative_review`, `reactivation` (or map — see Enum reconciliation below).
  - `contact_source` enum (existing values): `web_form, review_enroll, missed_call, import, manual`. **[ADD VALUES]**: `chat_widget`, `mobile_enroll`.
  - **[ADD]** `last_missed_call_textback_at timestamptz` (§9 7-day re-eligibility), `deleted_at timestamptz`.
- **conversations** (existing) — id, client_id, contact_id, last_message_at, status.
- **messages** (existing) — id, client_id, conversation_id, direction, body, twilio_sid, status, created_at.
- **templates** (existing) — id, client_id (NULL = global), key, body.
- **sequences** (existing) — id (uuid PK), client_id (nullable, NULL = global), **key (text, NOT NULL)** — this is what `enrollments.sequence_key` matches BY VALUE (not a FK), name, steps_json (jsonb default `[]`), updated_at. No unique on `key` today (globals have client_id NULL). **[ADD]** a unique index that respects the global/tenant split, e.g. `UNIQUE (client_id, key)` (with a partial unique on `key WHERE client_id IS NULL` for globals).
- **enrollments** (existing) — id, client_id, contact_id, **sequence_key (text)** — matches `sequences.key` by value, current_step (int, default 0), next_run_at, status (text, default `active`), created_at. **[ADD]** UNIQUE (client_id, contact_id, sequence_key) — the DB-level re-enrollment/dedup guard (§4/§6/§9); **dedup existing rows first** before adding. No FK to sequences (value-match by design — keep).
- **review_feedback** (existing) — client_id, contact_id, name, email, phone, rating, comment, created_at.
- **events** (existing) — id, client_id, type, contact_id, payload jsonb, created_at. **[ADD]** `created_by uuid` (nullable, audit); new `type` values as needed (sms_sent, review_clicked, inbound_sms, lead_submitted, cron_decision, …). Append-only; ALL cap/dedupe/throttle logic reads `events`.
- **notifications** **[ADD — net-new table]** — id, client_id, type, body, related_contact_id, action jsonb (nullable {type, payload}), created_at. No read/unread state (§8).

### Enum reconciliation [DECISION FLAGGED]
Our funnel (§4) marks contacts `Review Completed` and `Negative Review`; the live `contact_status` enum has neither (it has `review_clicked`, `review_requested`, etc.). Two options:
- **(A) Add values:** `ALTER TYPE contact_status ADD VALUE 'review_completed'; … 'negative_review';` and use them explicitly. Cleanest mapping to the spec.
- **(B) Map onto existing:** treat `review_clicked` as the Review-Completed signal and add only `negative_review`. Less new surface, but `review_clicked` semantically = "clicked," which under our funnel = landed = completed, so it nearly fits.
Recommend (A) for clarity (the spec speaks in Review Completed / Negative Review). Confirm before building. Either way: enum value names should be lowercase_snake to match the existing enum convention (so the spec's "Review Completed" → DB value `review_completed`).

## 2. SECURITY DEFINER helpers
Create as `SECURITY DEFINER`, `STABLE`, `set search_path = public`:
- `has_role(uid, role)`, `is_admin(uid)`, `is_agency_owner(uid)`, `user_client_ids(uid)` → returns the set of client_ids the user may access.
- These query `user_roles`. Because they're SECURITY DEFINER, RLS policies can call them WITHOUT recursion. **Never write a non-SECURITY-DEFINER policy on `user_roles` that references `user_roles`** (recursion trap).

## 3. RLS policies + indexes
RLS on EVERY table. Patterns:
- **Tenant tables:** `client_id IN (SELECT user_client_ids((SELECT auth.uid())))`. Wrap `auth.uid()` as `(SELECT auth.uid())` so Postgres treats it as an InitPlan (evaluated once per query, not per row) — the single biggest perf win at scale.
- **Admin override:** combine into ONE permissive policy per action per table: `is_admin((SELECT auth.uid())) OR client_id IN (SELECT user_client_ids((SELECT auth.uid())))`. Do NOT create multiple permissive policies for the same action (they OR and each runs).
- **`clients` anon read:** anon may SELECT only PUBLIC columns of `clients WHERE status='active'` (slug, business identity, branding, template_vars, review_link, quote_form_link). Twilio fields are non-secret but need not be anon-exposed — scope the anon SELECT to the public columns the marketing site needs. NO secret columns exist on the row (parent Twilio token is a runtime secret).
- **NO anon INSERT/UPDATE/DELETE anywhere.** All public writes go through server functions (§6).

**Indexes (cheap now, painful later):**
- `contacts (client_id, status)`, `contacts (client_id, phone_e164)` (inbound-SMS lookup).
- `messages (conversation_id, created_at DESC)`, `messages (client_id, created_at DESC)`.
- `enrollments (next_run_at) WHERE status='active'` — PARTIAL index; the cron hot path.
- `events (client_id, type, created_at DESC)` — powers throttle counters.
- `user_roles (user_id)` — hit on every request by the helpers.

## 4. The three Supabase clients
- **browser (anon):** for authed UI reads under RLS + anon public reads on `clients`.
- **authed server-fn:** user's JWT, RLS-scoped — for admin/mobile actions.
- **admin (service role):** bypasses RLS — used ONLY server-side in server fns / webhooks / cron. NEVER shipped to the browser, NEVER in a Remixed marketing project.

## 5. Auth & roles bootstrap
Supabase Auth. On signup/invite, write the user's role into `user_roles` (agency_owner / admin / client_owner / client_staff) with the appropriate client_id. The mobile app + admin view gate on these roles via the helpers.

## 6. Server-fn + public-route skeleton (CORS)
**All public writes** (lead form, discount form, review funnel, chat-widget opt-in) POST to server functions / `src/routes/api/public/*` routes:
- Validate every field with **Zod** (min/max, regex, enum). Resolve `client_id` from the public **slug** (never trust a client_id from the caller). Insert via the **admin (service-role)** client. Set `source` server-side (CHECK-constrained column).
- **CORS:** public lead-intake routes are called cross-origin from the Remixed marketing domains. Provide a shared `withCors()` helper: emit `Access-Control-Allow-Origin` (from the client's `allowed_origins` allowlist — NOT `*` in production), handle `OPTIONS` preflight, allow `Content-Type`. Apply **rate-limiting + Turnstile/hCaptcha** on these routes. The anon key is NOT a security boundary here — Zod + allowlist + bot-protection are.
- **Webhook + cron routes** (`/api/public/twilio/*`, `/api/public/cron/*`) are server-to-server → NO CORS. They get signature/secret checks instead (§7, Twilio).

## 7. Cron drip-runner skeleton
**pg_cron + pg_net** hitting `/api/public/cron/sequences` every 1–5 min (no native scheduler / Cloudflare Cron in this stack). Protect the route with a **shared secret**: check `process.env.CRON_SECRET` against an `x-cron-secret` header (NOT the anon key — that leaks to every marketing site). pg_cron passes the header via `net.http_post`'s headers arg.

Runner shape (per tick):
- Claim due work: `SELECT … FROM enrollments WHERE status='active' AND next_run_at <= now() ORDER BY client_id, next_run_at LIMIT ~500 FOR UPDATE SKIP LOCKED` (bounded batch keeps the Worker under the 30s CPU limit; SKIP LOCKED prevents overlapping ticks double-sending).
- Group by `client_id`; load `send_settings` + overrides.
- For each enrollment, evaluate throttle (SMS send window 9–7 client tz, daily_send_cap, per-sequence pacing like reactivation's 2/20min — all counted from `events`):
  - **Blocked** → set `next_run_at = nextEligibleSlot()` and **do NOT advance `current_step`** (never drop/skip a step). If blocked by daily_cap or batch pacing, break this client's loop (defer the rest).
  - **Allowed** → render template → send via Twilio (§ below) → insert `message` + `event('sms_sent')` → advance `current_step`, set `next_run_at = now() + nextStep.offset`. If no more steps → `status='completed'` (+ any terminal action, e.g. §4 final notification).
- Twilio errors: 5xx → reschedule with jitter; 4xx (bad number) → `status='failed'`. Send-layer retries failed sends up to 2× before marking failed (the GHL "max retries" equivalent).
- **Log every decision** into `events` (sent / blocked-window / blocked-cap / blocked-batch / rescheduled) for observability.

Enrollment caps (e.g. reactivation 50/day) are enforced at the **enrollment-creation server fn** (count today's enrollments for that client+sequence before inserting), NOT at send time.

## 8. Twilio integration (Option 1 — one parent account)
**One parent Twilio account**, wired via Lovable's connector gateway (`connector-gateway.lovable.dev/twilio/...`, **fetch + URLSearchParams, NOT the SDK** — SDK pulls Node deps that break on Workers). Per-client `From` / `MessagingServiceSid` come from the `clients` row (non-secret). The ONLY Twilio secret is the parent auth token (a runtime secret).
- **Outbound:** gateway POST to `/Messages.json` with the per-client `From`/`MessagingServiceSid`.
- **Inbound SMS** (`/api/public/twilio/inbound`) + **voice-status** (`/api/public/twilio/voice-status`): ONE set of webhook URLs at the parent level. **Verify `X-Twilio-Signature` (HMAC-SHA1 over URL + sorted POST params, parent auth token) BEFORE any DB write** — these routes have no auth gate. Resolve the client by the `To` number → `clients` row.
- STOP/UNSUBSCRIBE/CANCEL/END/QUIT + **`pass`** (whole-word) → set `opted_out_at`, cancel active enrollments, send confirmation. HELP/INFO → info reply. START/YES/UNSTOP → opt back in.
- (Option 2, BYO-Twilio, NOT v1: per-client accountSid/authToken in a server-only `client_secrets` table, bypassing the gateway. Reserved.)

## 9. Storage buckets
- **public-assets** (public read) — client logos, hero images the marketing sites display.
- **client-assets** (private, client_id-scoped) — uploaded photos / private files. RLS via `(storage.foldername(name))[1]::uuid IN (SELECT user_client_ids((SELECT auth.uid())))`, paths prefixed `client_id/...`.

## 10. Runtime secrets (never on a row, never anon-reachable)
- `CRON_SECRET` (x-cron-secret header check).
- Parent Twilio auth token.
- (NO `client_secrets` table in v1 — Option-2/BYO-Twilio only.)

## Done-right checklist (the validated invariants)
- [ ] `(SELECT auth.uid())` wrap in every policy; helpers SECURITY DEFINER + STABLE; one permissive policy per action per table.
- [ ] No anon INSERT/UPDATE/DELETE; all public writes via server fns (admin client + Zod + slug→client_id + server-set source).
- [ ] CORS + allowlist + OPTIONS + rate-limit + captcha on public lead-intake; none on webhook/cron routes.
- [ ] `enrollments` UNIQUE (client_id, contact_id, sequence_key).
- [ ] Partial index `enrollments(next_run_at) WHERE status='active'` + the client_id index set.
- [ ] Cron: bounded batch, FOR UPDATE SKIP LOCKED, reschedule-without-advancing, jitter/fail handling, 2× send retry, decision logging, CRON_SECRET header.
- [ ] Twilio via fetch/gateway, signature-verify-before-write, route by To, per-client From/SID from row, parent token as secret.
- [ ] Two storage buckets (public-assets / client-assets).
- [ ] soft-delete `deleted_at` on contacts/clients; `events.created_by`.
- [ ] All caps/dedupe/throttle read `events`; sends write `events` in live AND stub mode.
- [ ] Enum reconciliation done: `contact_status` has `review_completed` + `negative_review` (+ `reactivation` if used); `contact_source` has `chat_widget` + `mobile_enroll` (via `ALTER TYPE … ADD VALUE`). All enum values lowercase_snake.
- [ ] `timezone` read from `send_settings` (NOT clients). `service_area` is text[] on clients. `brand_color` default `#bd703e`.
- [ ] Net-new migrations applied: clients (allowed_origins, call_forwarding_number, site_style, deleted_at); contacts (last_missed_call_textback_at, deleted_at); send_settings (business_hours, daily_enrollment_cap, overrides); events.created_by; notifications table; enrollments dedup→UNIQUE; sequences (client_id, key) unique.
