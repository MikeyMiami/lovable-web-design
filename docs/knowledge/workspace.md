# PierceWorks Platform — Workspace Rules

These rules govern the PierceWorks platform projects: the shared-backend APP ("Project 1"), the marketing-site TEMPLATE projects, and every per-client REMIX. First identify which project type you are editing (taxonomy below), then apply its rules. Project knowledge adds the specifics for each project and wins on conflict.

## Project taxonomy — know where you are before editing
- **APP (Project 1)** — shared multi-tenant backend + admin dashboard + client PWA. Has `src/routes/api/public/*`, server fns, migrations. Origin `app.pierceworks.co`.
- **TEMPLATE** — a frontend-only marketing-site shell (one project per style preset). `.env` has `VITE_CLIENT_SLUG=` blank (demo mode).
- **REMIX (client site)** — an exact copy of a template with ONE change: `VITE_CLIENT_SLUG=<slug>`. Frontend-only forever.

## Golden-master architecture [LOCKED — never violate]
- ONE shared backend serves ALL clients; every tenant row keyed by `client_id`; isolation via RLS. Built once, frozen — NEVER regenerated or cloned per client.
- Per-client launch = client row + config in the shared backend + a template REMIX (frontend-only). NOT a backend clone, NOT an AI-regenerate. Why: per-client backends reintroduce AI-drift; one codebase, one place to fix. Do not reopen.
- Data is LIVE: remixes fetch client data EVERY page load via the `get_client_public` RPC (+ anon content-page RPCs). Admin edits appear on live sites at next load; only design/layout is baked at build.
- Frontend/backend split: remixed sites are FRONTEND-ONLY — reads via `get_client_public` (the SOLE anon door; owner PII stripped) + CORS-guarded POSTs to `/api/public/*` routes. NO service-role, NO DB-writing server fns, NO direct table access from any client site. Admin + client PWA = the app (authed, DB-touching).

## Domain map [LOCKED]
- Client's own domain = their marketing site (+ `/review/<token>` 302 → funnel).
- `app.pierceworks.co` = THE APP: admin, client PWA, `/login`, `/set-password`, `/download`. App URLs build from `PUBLIC_APP_ORIGIN ?? https://app.pierceworks.co`.
- `notif.pierceworks.co` = Resend sender domain (`alerts@` owner notifications; `onboarding@` client welcome/onboarding; reply-to → monitored inbox).
- `reviewbatch.com` = shared review-funnel backend (`/api/public/r/*` only; all other paths 302 → the app).
- ⚠ Env `PUBLIC_APP_URL` is the REVIEW-link base (= reviewbatch.com), NOT the app origin. NEVER build app URLs from it.

## Security absolutes [LOCKED]
- NO anon INSERT/UPDATE/DELETE anywhere. Public writes only via `/api/public/*` routes: Zod + `client_id` resolved SERVER-SIDE from Origin → `allowed_origins` (slug fallback; NEVER from the body) + CORS + OPTIONS + DB rate-limit + PoW bot-shield + hidden `website` honeypot. Fail-CLOSED on bad checks; fail-OPEN+alert on infra error.
- RLS on EVERY tenant table: `client_id IN (SELECT user_client_ids((SELECT auth.uid())))`; admin override `is_admin()`; wrap `auth.uid()` as `(SELECT auth.uid())`.
- Service-role client is server-only — NEVER in a browser or remix. Secrets never in chat, code, or template_vars.
- `template_vars` is anon-readable — anon-safe merge values ONLY; owner PII lives in dedicated non-projected columns (e.g. `notification_email`).
- `template_vars` writes MUST read-merge-write the FULL object (server-side re-read + overlay only your keys). A partial write wipes client data.
- Per-client provider creds → server-only `client_provider_secrets` (RLS on, zero policies; write-only panel). EIN letters → private `client-assets`, 5-min signed URLs.

## Stack [LOCKED]
TanStack Start v1 (React 19 + Vite 7), SSR, Cloudflare Workers (pure JS + fetch, NO native deps). Lovable Cloud/Supabase. Server logic = `createServerFn` + `src/routes/api/public/*`; provider webhooks = Supabase Edge Functions. Three Supabase clients: browser (anon), authed server-fn (JWT/RLS), admin (service-role, server-only).

## Build discipline [LOCKED]
- ONE layer/skill at a time → validate (type check; migrations + live DB queries > prose) → next. Build and test in separate turns.
- Migrations are ADDITIVE and schema-only. NEVER commit test/probe data ops as migrations (SQL editor only).
- Respect prompt scope: when a prompt says "change nothing else", change nothing else. No refactors, renames, or "improvements" outside the stated scope.
- [LOCKED] markers are settled decisions — do not reopen; if one seems wrong, SAY so instead of silently deviating.
- Skills win over your own suggestions; if a skill is wrong, flag it — don't diverge silently.
- Env vars & secrets bake at DEPLOY — a change does nothing until the project is re-published.
