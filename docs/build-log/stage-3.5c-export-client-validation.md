# Build Log — Stage 3.5 item 2 (export-client + archive) Validation

> Validation of isolation guardrail 3 — `export_client_bundle` (per-client portability snapshot) + `archive_client` (soft offboard) — against spec §12 export-client bullet + `scratch-foundation` §11. Source: Lovable build report (5 proofs, live). Validated 2026-06-15 (Claude Code).
> **Verdict: CLOSED — PASS.** All 5 proven; in-RPC authz on line 1 (the item-1 lesson applied proactively); catalog-derived table list (no hardcoded drift); live `cross_tenant_bleed=0`; archive STOPS drips at the claim fn (11→0). **This completes isolation guardrail 3 → all 4 guardrails done.** No secret values.

## ✅ Validated (the 5 points)
1. **Derived table list — CATALOG-DRIVEN ✓ (the key win).** `export_client_bundle` enumerates `information_schema` BASE TABLES with a `client_id` column (minus `user_roles`) → resolved 11 tenant tables (contacts, conversations, enrollments, events, messages, notifications, review_feedback, send_settings, sequences, templates, tracked_links). A future tenant table is auto-included, zero code change — **no hardcoded list to silently omit a table** (the same set `audit_tenant_rls()` scans, so they stay consistent). `clients` row added explicitly (id-scoped). *(`user_roles` excluded — FK to `auth.users`, not portable; see lifecycle note re: role re-grant on import.)*
2. **Strict scoping ✓.** Each table via `format('… %I t WHERE t.client_id=$1', tname)` + `EXECUTE … USING _client_id` — table name `%I`-quoted from the trusted catalog, `client_id` a bound param (injection-safe). Live: 107 rows, `cross_tenant_bleed=0` (adversarial check — 0 rows with a different `client_id`).
3. **In-RPC authz on line 1 ✓ (item-1 lesson applied).** `IF _actor IS NULL OR NOT is_admin(_actor) THEN RAISE … 42501` BEFORE any read; `REVOKE ALL FROM PUBLIC` + `EXECUTE` to `service_role` only; server fn also `assertIsAdmin`. Defense-in-depth. Tested: non-admin → Forbidden, client_owner-only → Forbidden, admin → bundle. The hole we closed on the audit RPCs was NOT repeated.
4. **Archive STOPS drips ✓ — enforced at the claim fn.** `claim_due_enrollments` (SECURITY DEFINER) JOINs `clients` and filters `c.status='active' AND c.deleted_at IS NULL` → the runner gets it for free (a future code path can't forget it). Live: active → 11 claimable, archived → 0. The "written-but-unread" risk (3f class) is avoided — archive genuinely stops automation.
5. **Bundle shape ✓ — re-importable.** Versioned JSON (`version`, `exported_at`, `client_id`, full `client` row, `derived_tables`, `excluded_tables`, `tables{}` each `to_jsonb(t)` ordered by id for determinism). The A→B peel-out artifact (§0). *(Re-import to a fresh backend needs FK-dependency ordering — an import-tooling concern, not an export defect; the bundle is complete + deterministic.)*

Plus: `audit_tenant_rls()`=0 post-migration; server fn `requireSupabaseAuth` + `assertIsAdmin` + RPC re-check.

## Clarify (a) — archive lifecycle [LOCKED]
**Confirmed intended lifecycle:** archive = **SOFT** offboard — `archive_client()` sets `status='archived'` + `deleted_at`. Effect: the runner **stops** (claim filter) and the data **PERSISTS** (soft-delete, not hard-delete). The **export bundle is a SEPARATE portability artifact** (taken before/independent of archive — the A→B escape hatch). **NO automatic hard-delete** — purging an archived client's data would be a deliberate, separate operation (not built). *(Future decision: a data-retention/purge policy for long-archived clients — PII retention — is unbuilt; today archived data persists indefinitely. Backlog, not a blocker.)*

## 🟢 Minor notes (non-blocking)
- **`user_roles` excluded** → the client's user-role assignments aren't in the bundle (they FK `auth.users`, which don't port). On A→B re-import, roles are re-granted (now via the audited RPCs). Acceptable boundary; documented.
- **Re-import ordering** — FK-dependency order is an import-tooling concern (clients → contacts → conversations/enrollments → messages …); the export is complete, the importer handles ordering.

## Status
- **Item 2 CLOSED — PASS.** export-client + archive: catalog-derived, scoped (bleed=0), in-RPC authz (line 1), archive-stops-drips (claim filter), re-importable bundle. Lifecycle = soft + persists + no auto-hard-delete [LOCKED].
- **Isolation guardrail 3 DONE → ALL 4 GUARDRAILS COMPLETE** (1 RLS-audit gate ✓, 2 per-client cron fairness ✓, 3 export-client ✓, 4 CORS resolver ✓).
- **Stage 3.5: 2 of 3 done.** Remaining: **item 3 — regression re-test** (runner-renders-real-bodies full drip set + send-primitive regression + `runner_version` deploy verification). Then `/launch-check` A–D green → Stage 4 freeze.
