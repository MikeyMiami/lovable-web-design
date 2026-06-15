# Build Log — Stage 4: Golden Master FROZEN

> The shared multi-tenant backend (Project 1) is frozen as the golden master. Recorded 2026-06-15 (Claude Code).

## Frozen artifact
- **Repo:** `MikeyMiami/cloud-spark-setup` (private; Lovable Project 1's own GitHub repo, connected 2026-06-15 — the "confirm the GitHub repo holds the built code" freeze step).
- **Commit:** `126680404a818fc5fee4ef92e87643f3f99f54de` ("Reviewed runner regression"), branch `main`.
- **Tag:** `golden-master-v1` (annotated; tag object `3b288e7cb6ed226374da468df6b85157b953018e`).
- **Planning repo** (`MikeyMiami/lovable-web-design`): tagged `golden-master-v1` at the freeze commit (spec/skills snapshot pinned to the same name as the frozen code).
- **runner_version on main:** `v20260615-2`.

## Verification performed before tagging (cloned main, manifest + net-state)
- ✅ `src/lib/cron/runner.server.ts` → `RUNNER_VERSION = "v20260615-2"` (emitted in the tick output).
- ✅ Stage-3.5 migrations present: `20260615210212` (audit_log + role-mutation trigger), `20260615211022` (assign/revoke_user_role_audited), `20260615211809` + `20260615211906` (export_client_bundle + archive_client + runner archived-client filter).
- ✅ Key DB objects present across migrations: `get_client_public`, `audit_log`, `user_roles_audit`, `assign/revoke_user_role_audited`, `export_client_bundle`, `archive_client`, `claim_due_enrollments`.
- ✅ Server fns present: `src/lib/admin/export.functions.ts`, `src/lib/templates/resolve.server.ts`.
- ✅ **§A net-state correct:** the early `clients_public` VIEW was created then **DROPPED** (`20260614225655`); the final `get_client_public` (`20260615202126`) is `SECURITY DEFINER`, `STABLE`, `SET search_path='public'`, projecting `template_vars - 'notification_email'`. Migrations rebuild to the introspected **RPC-only, no-view** state — matches the §A record.
- ✅ Claim fn (`20260615211906`) carries the per-client fairness (`row_number() PARTITION BY client_id` + `_per_client` slice) **and** the archived filter (`status='active' AND deleted_at IS NULL`).

## Freeze gate state (`/launch-check`)
- **A–D green for the frozen-LOGIC rows.** Stage 3.5 complete; **all 4 isolation guardrails built AND adversarially proven** (G1 RLS-audit `audit_tenant_rls()`=0; G2 per-client fairness — A=50 capped to 5, B/C served in one tick; G3 export-client — bleed=0, in-RPC authz; G4 CORS resolver — forged body `client_id` ignored, attributed to Origin).
- **Deferred to Stage 1f (post-freeze — NOT freeze blockers):** §A Turnstile/rate-limit + parent Twilio auth token; §B real-Twilio 5xx/4xx branch; §C one-year real-time reply-exit + missed-call voice-webhook trigger + owner-email actual send; §D nearly all — real Twilio account/From/SID, status-swap, render-completeness guard, inbound+voice webhooks, real-time reply-driven exits, per-client number/forwarding/GBP.

## Post-freeze contract [LOCKED]
- Only **(1) 1f hardening** (real Twilio swap, Turnstile/rate-limit, real-time reply-driven exits, status-swap, render-completeness guard) and **(2) re-validated bug-fixes** may touch the backend — each re-validated + re-tagged.
- **No per-client backend regeneration, ever.** Per-client launch (Stage 5) = a `client` row + Remix the frontend, pointed at the shared backend.

## What's next
- **Stage 1f** — the deferred hardening, gated by `/launch-check` §E, before any client goes live.
- **Stage 5** — per-client launch via `/new-client-site` (provision client + Remix marketing site + design layer).
