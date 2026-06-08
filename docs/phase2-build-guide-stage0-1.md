# Phase 2 Build Guide — Stage 0 (Wiring) + Stage 1 (Foundation)

How to feed the skills to Lovable to build the golden-master backend, starting with wiring + the foundation. Core principle: **one focused step at a time.** Give Lovable the skill as the build instruction + only the relevant context. Verify each layer before building the next. Don't paste all 11 skills at once — that invites the AI-drift we designed against.

---

## STAGE 0 — Wiring (do these BEFORE feeding skills)
These are setup actions in Lovable/Supabase/Cloudflare, not skill-feeds. From spec §9d.

1. **Stable backend domain** — confirm the shared backend's custom domain (or stable `project--<id>.lovable.app` URL). Gates Twilio webhooks, cron, tracked links.
2. **Enable extensions** — in Supabase: enable `pg_cron` and `pg_net`.
3. **Storage buckets** — create `public-assets` (public read) and `client-assets` (private). RLS policies come with `/scratch-foundation`.
4. **Runtime secrets** — set in Lovable Cloud secrets: `CRON_SECRET`, parent Twilio auth token, Turnstile secret (create the Turnstile widget first to get site+secret keys). AI key only if Lovable's answer to the ❓ says one's needed.
5. **❓ Confirm-in-Lovable items** (don't block Stage 1, but resolve before the email/AI build steps): email from-domain/ESP specifics; native-AI invocation API + context size.

> Note: the migrations + RLS + cron job themselves are built by `/scratch-foundation` in Stage 1 — Stage 0 is just the environment (domain, extensions on, buckets exist, secrets present).

---

## STAGE 1 — Foundation (`/scratch-foundation`)

The most important build. Build it in sub-steps, not one giant prompt — each sub-step is verifiable. Feed Lovable the `/scratch-foundation` skill as the spec, then drive these sub-steps:

### 1a. Schema migrations + enums
Prompt Lovable to apply, in this order (order matters):
1. Enum additions FIRST: `ALTER TYPE contact_status ADD VALUE 'review_completed'; ... 'negative_review'; ... 'reactivation';` and `ALTER TYPE contact_source ADD VALUE 'chat_widget'; ... 'mobile_enroll';` (lowercase_snake).
2. New columns: clients (`allowed_origins`, `call_forwarding_number`, `site_style`, `social_links`, `deleted_at`); contacts (`last_missed_call_textback_at`, `deleted_at`); send_settings (`business_hours`, `daily_enrollment_cap`, overrides); events (`created_by`).
3. New table: `notifications`.
4. **Dedup enrollments FIRST, then** add `UNIQUE (client_id, contact_id, sequence_key)`. (If dupes exist the constraint fails — clean them first.)
5. Unique index on sequences `(client_id, key)` with the global/NULL handling.

Verify: schema matches the skill; no migration errors; enum values present.

### 1b. Helpers + RLS
1. SECURITY DEFINER helpers (`has_role`, `is_admin`, `is_agency_owner`, `user_client_ids`), all STABLE.
2. RLS on every table: `client_id IN (SELECT user_client_ids((SELECT auth.uid())))`, one permissive policy per action, `(SELECT auth.uid())` wrap. Admin override via `is_admin()`.
3. Anon: SELECT only on `clients` public columns WHERE status='active'. NO anon insert/update/delete anywhere.
4. Indexes: the partial `enrollments(next_run_at) WHERE status='active'` + the client_id-leading set + `user_roles(user_id)`.

Verify: `/launch-check` section A — RLS present, no anon writes, indexes present, `(SELECT auth.uid())` wrap, no recursion on user_roles.

### 1c. Three Supabase clients + auth/roles
Browser (anon), authed-server-fn, admin (service-role, server-only). Roles written to `user_roles` on signup/invite.

Verify: a test user gets the right role; RLS scopes their reads to their client_id.

### 1d. Server-fn + public-route skeleton + CORS
1. `withCors()` helper (allowlist from `clients.allowed_origins`, OPTIONS, Content-Type).
2. Public write server fns: admin client + Zod + slug→client_id + server-set source. Rate-limit (pick the store — Durable Objects / KV / DB) + Turnstile verify.
3. Webhook/cron routes under `/api/public/*` (no CORS — server-to-server).

Verify: a public form POST from an allowed origin succeeds; from a non-allowed origin is blocked; anon insert is impossible.

### 1e. Cron drip-runner skeleton
1. The `/api/public/cron/sequences` route with `x-cron-secret` check against `CRON_SECRET`.
2. The pg_cron job (`net.http_post` with the secret header, every 1–5 min).
3. Runner logic: bounded batch, `FOR UPDATE SKIP LOCKED`, group by client_id, blocked→reschedule-without-advancing, allowed→send→event→advance, 5xx→jitter / 4xx→fail, log every decision to events.

Verify: cron fires on schedule; hitting the endpoint without the secret is rejected; a test enrollment advances correctly; blocked sends reschedule without skipping a step.

### 1f. Twilio Option 1 wiring
1. Connector gateway (fetch, no SDK); outbound with per-client From/MessagingServiceSid.
2. Inbound + voice-status webhooks at the parent; route by To→clients row; X-Twilio-Signature verify BEFORE any DB write.
3. STOP/HELP/START + `pass` opt-out handling.

Verify: `/launch-check` section D — webhooks verify signature, route by To, opt-out works.

### Stage 1 gate
Run `/launch-check` sections A + B (foundation invariants + cron engine) + D (telephony). All green → the foundation core is proven. THEN move to Stage 2 (features).

---

## How to feed each sub-step to Lovable (the pattern)
- Give Lovable the **`/scratch-foundation` skill** as the authoritative instruction for the whole stage.
- For each sub-step, prompt the specific slice ("Now apply the schema migrations from the skill, in this order: …").
- After each, **verify against the skill + run the relevant launch-check items** before the next slice.
- If Lovable proposes something that contradicts the skill, the skill wins — correct it, and if the skill was actually wrong, fix the skill (single-source) and re-feed.
- Keep `/launch-check` open as the running checklist.

> Build then test in separate steps — don't combine a big migration + its test in one prompt. Apply, then verify.
