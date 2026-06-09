# Build Log — Stage 1d Validation (clients + auth/roles + server-fn/CORS skeleton)

> As-built validation of Stage 1d against `skills/scratch-foundation/SKILL.md` §4 (three Supabase clients), §5 (auth/roles bootstrap), §6 (server-fn + public-route skeleton + CORS resolver / isolation guardrail 4). Source: Lovable 1d report. Validated 2026-06-09 (Claude Code, independent review).
> **Verdict: PASS — clear to build 1e (cron runner).** No hard blockers. 4 carry-forward items below. No secret values stored.

## PASS — verified against the skill

**§4 — three Supabase clients ✓**
- Browser (anon) — `src/integrations/supabase/client.ts`; publishable key + session; anon SELECT on public `clients` columns.
- Authed server-fn — `src/integrations/supabase/auth-middleware.ts` (`requireSupabaseAuth`); Bearer/JWT, RLS as that user.
- Admin (service-role) — `src/integrations/supabase/client.server.ts` (`supabaseAdmin`); `.server.ts` + dynamic `await import()` inside handlers; **never** shipped to browser/Remix. Matches §4.

**§5 — auth/roles bootstrap ✓**
- No self-signup auto-role (zero `user_roles` until invited); `assignUserRole` authed-only.
- Authorization matrix: admin/agency_owner → assign any role; client_owner → only `client_staff`/`client` within own `client_id`; else Forbidden.
- Shape validation: platform roles (admin/agency_owner) require `client_id = NULL`; tenant roles require a `client_id`. Consistent with the `user_roles` table.
- Tenant-scoped grants append `events(type='role_assigned', created_by=callerId)`.

**§6 — CORS resolver (isolation guardrail 4) ✓ (independently confirmed)**
- `client_id` resolved SERVER-SIDE from Origin/Host → `clients.allowed_origins` via `.contains('allowed_origins',[candidate])`; **body never participates** (Zod schema excludes `client_id`).
- Unknown origin → `null` → 403. Matched origin **echoed, never `*`**.
- `.server.ts` isolation on `tenant-resolver.server.ts` + `client.server.ts` (bundler refuses client import).
- Host-fallback matched against the same allowlist (forged Host only resolves a tenant that already registered it — same trust model as Origin).
- Files: `src/lib/cors.ts`, `src/lib/tenant-resolver.server.ts`, `src/lib/auth/roles.functions.ts`, `src/routes/api/public/intake.ts`.

## Carry-forward items (none block 1e)

1. **Duplicate detection is message-regex (`/duplicate/i.test(insErr.message)`)** — fragile vs SQLSTATE. Switch to `insErr.code === '23505'`, or make the insert idempotent via `.upsert({…}, { onConflict:'user_id,role,client_id', ignoreDuplicates:true })`. **Fix at the source now** — this pattern is the template for every public route. Code nit, no migration.
2. **`revokeUserRole` authorization UNVERIFIED** — report shows only `assignUserRole`; revoke is prose. Must confirm it enforces the same matrix (client_owner can't revoke admin/agency_owner/client_owner; scoped to own client_id; platform-admin can revoke any). Tracked: spec §12 `[VERIFY — TODO]`. Verify before any UI calls revoke.
3. **Platform-role grants are unaudited** — `assignUserRole` only writes `events` when `client_id` is truthy; admin/agency_owner grants (`client_id NULL`) skip the audit row because `events.client_id` is NOT NULL. The most sensitive action is the one not logged. Fix = separate `audit_log` table (NOT nullable `events`). Tracked: spec §12 `[BUILD — TODO]`. Land before go-live.
4. **Intake skeleton has no Turnstile/rate-limit (deferred to 1f) + slug-path CORS nits:**
   - Safe NOW only because no real client exists (no live slug/allowed-origin a direct POST could target). **CORS is browser-only — it does NOT stop a direct/non-browser POST**; the real server-side guard is `resolveTenant` returning non-null. → **Stage 1f (Turnstile + rate-limit) MUST precede ANY client launch.** Tracked: spec §12 `[GATE]` + `/launch-check` §E gate line.
   - `resolveTenantBySlug` returns `allowed_origins?.[0] ?? ""` → empty ACAO fails closed for browsers (insert still tenant-scoped for non-browser). Minor: **omit the ACAO header when no valid origin** instead of echoing `""`. Note: slug is a weaker boundary than origin (guessable slug + no-bot-protection = the spam vector pre-1f).

## Acceptance to close the carry-forwards
- [ ] #1 duplicate-detection switched to `23505`/upsert (template).
- [ ] #2 `revokeUserRole` code reviewed + confirmed (paste pending).
- [ ] #3 `audit_log` table migration landed (before go-live).
- [ ] #4 Stage 1f shipped before first client launch; optional ACAO-omit nit.
