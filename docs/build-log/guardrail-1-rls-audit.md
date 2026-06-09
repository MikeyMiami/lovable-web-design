# Build Log — Guardrail 1: RLS-audit gate (`audit_tenant_rls()`)

> Validation of the RLS-audit gate against `skills/scratch-foundation/SKILL.md` §3 (isolation guardrail 1). Source: Lovable build report. Validated 2026-06-09 (Claude Code, independent review).
> **Verdict: PASS — `audit_tenant_rls()` built and returns 0 violations. Guardrail 1 RESOLVED.** Was the last lingering guardrail. Two non-blocking enhancements noted. *(Function body not pasted — contract recorded; archive the SQL when available.)*

## What shipped (contract)
- `public.audit_tenant_rls()` — SECURITY DEFINER, STABLE, **service_role-only EXECUTE** (revoked from anon/authenticated). ✓ consistent with the other internal helpers.
- **Scope:** every `public.*` BASE TABLE with a `client_id` column, **excluding `clients`** (the tenant root — id-scoped, not client_id-scoped).
- **Per-command rule:** SELECT/DELETE → `USING` must reference `user_client_ids(` or `is_admin(`; INSERT → same on `WITH CHECK`; UPDATE/ALL → both (when `with_check` present).
- **Output contract:** **0 rows = PASS**; each violation = `(table_name, policy_name, cmd, reason)`.
- **Run:** `SELECT * FROM public.audit_tenant_rls();` → currently **(0 rows)**.

## Validation vs §3 + scrutiny

**1. Coverage ✓ (one blind spot noted).**
- Excluding `clients` is **correct** — it has no `client_id` column (PK `id`), is scoped via `id IN user_client_ids()` / `is_admin()` in its own validated policies (clients_select/insert/update/delete, migration 2). The audit keys off "has a client_id column," so `clients` wouldn't qualify anyway; the explicit exclusion just avoids a false violation. ✓
- **No tenant table is scoped only indirectly** — the foundation denormalizes `client_id` onto EVERY tenant table (messages, conversations, etc. carry `client_id` directly, not just a parent FK), so none are missed. ✓
- `templates`/`sequences` (nullable client_id globals) pass — their policies contain `is_admin(`/`user_client_ids(` alongside the `client_id IS NULL` global clause. ✓ `user_roles` (has nullable client_id) passes via its `is_admin(`-referencing self-select; writes are service-role-only (no policy needed). ✓
- **Blind spot (enhancement A):** because `clients` is excluded, the gate does NOT guard `clients`' own RLS — a future migration could weaken a `clients` policy without tripping the audit. Recommend extending the audit with a special-case assertion that `clients` has RLS + `is_admin(`/`user_client_ids(`-scoped policies. Non-blocking (clients policies are correct + validated now).

**2. Qual string-matching — good-enough as a CI tripwire, NOT a proof.**
- It checks the policy expression literally references `user_client_ids(` or `is_admin(`. This reliably catches the most likely regression: **a new tenant table with no RLS / no tenant check.** ✓ as a convention-enforcing gate.
- **False positives:** a correctly-scoped policy that inlines `client_id IN (SELECT ur.client_id FROM user_roles ur WHERE ur.user_id = auth.uid())` (no helper call) would be flagged. Acceptable — it enforces the "scope via the helpers" convention.
- **False negatives (the real limit):** a policy can contain `is_admin(`/`user_client_ids(` yet be logically wrong and still PASS — e.g. `USING (true OR is_admin(...))` (leaks all), wrong arg `user_client_ids(<not auth.uid()>)`, or the helper referenced in an ineffective position. String-match can't see these.
- **Judgment:** keep it as the first-line CI tripwire (catches the common, likely regression cheaply). It does **not** replace policy review or prove isolation. **Enhancement B (before go-live):** add a *functional* cross-tenant isolation test — seed 2 clients + a client_owner of A, assert an authed query as A returns **0** of B's rows across every tenant table. That's the actual proof of isolation; the string-audit is the cheap regression guard.

**3. Linter WARNs — all pre-existing/by-design; this migration introduced none. ✓**
- 9 WARNs = 1 `extension_in_public` (pg_net/pg_cron in public — expected) + 8 SECDEF-executable-by-anon/authenticated = the 4 helpers (`has_role`, `is_admin`, `is_agency_owner`, `user_client_ids`) × {anon, authenticated}. Those EXECUTE grants are **intentional** (migration 4 — RLS policies must call them; the in-body self-guard is the boundary; **do NOT re-REVOKE** per `migration-4-helper-execute-fix.md`).
- `audit_tenant_rls()` (new) and `claim_due_enrollments` are **service_role-only** → correctly NOT in the SECDEF-anon/auth warn set (the 8 = 4 helpers × 2). The new function added **no** new warning. ✓ (Minor: the report's parenthetical loosely lists `claim_due_enrollments` among the warned objects; the 4×2 math shows the 8 are the 4 helpers — confirm `claim_due_enrollments` isn't actually in the list, but it's revoked so it shouldn't be.)

**4. CI wiring — yes, but no harness yet → manual for now.**
- It SHOULD be wired as `assert (SELECT count(*) FROM public.audit_tenant_rls()) = 0` after every migration — that's guardrail 1's whole point (build-time gate).
- **There is no CI harness yet** (the build runs through the manual spec-author ↔ Claude Code ↔ Lovable validation loop). So: **run `SELECT * FROM public.audit_tenant_rls()` manually after every migration, require 0 rows** (now in `/launch-check` §A + LAUNCH.md discipline). Wire it as an automated assertion if/when a CI pipeline is set up against the Lovable app repo (GitHub Action: apply migrations to a throwaway DB → assert count = 0).

## Status
- **Guardrail 1 RESOLVED.** All 4 isolation guardrails now built: (1) RLS-audit gate ✓, (2) cron per-client fairness ✓ (1e), (3) export-client fn — *still a foundation BUILD item (lifecycle), not yet built*, (4) CORS resolver ✓ (1d). *(Note: export-client fn from scratch-foundation §11 is part of the tenant-lifecycle build, separate from this gate — track when built.)*
- Recommended enhancements (non-blocking, tracked in spec §12 guardrail-1 line): (A) extend audit to gate `clients`; (B) functional cross-tenant isolation test before go-live.
