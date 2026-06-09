# Build Log — Migration 4: helper EXECUTE fix (PENDING APPLY)

> Status: **DECISION RECORDED — awaiting applied SQL + verify outputs.** Captures the migration-3 bug, the agreed migration-4 fix, and the implementation gotchas. Finalize this note (paste migration 4 SQL + the two verify results) to flip foundation-validation **open-item #3 → RESOLVED**. No secret values stored here.
> Reviewed independently (Claude Code) 2026-06-09; verdict: ship as migration 4 with the amendments below.

## The bug (migration 3)
`20260609034341_*.sql` revoked `EXECUTE` on the 4 SECURITY DEFINER helpers (`has_role`, `is_admin`, `is_agency_owner`, `user_client_ids`) from `PUBLIC, anon, authenticated`.

**Why it breaks everything:** Postgres checks `EXECUTE` on a function against the **calling role, at call time** — and `SECURITY DEFINER` does NOT exempt that check (it only sets whose privileges run *inside* the body). RLS policy expressions evaluate **as the querying role**, not the table owner. So any `authenticated` query against a tenant table whose policy calls `is_admin`/`user_client_ids` throws `permission denied for function`. `pg_proc.proacl` shows no `authenticated=X`/`anon=X`/`PUBLIC=X` → no grant path remains. Confirmed broken.

This also corrects the original validation report's claim ("policies invoke them as the table owner, so RLS still works") — that was the misconception. (It's exactly what foundation open-item #3 flagged: prove with a live query, don't trust the prose.)

## The fix (migration 4) — agreed
1. **`GRANT EXECUTE` back** to `anon, authenticated` on all 4 helpers (required — restores RLS evaluation).
2. **Self-only guard inside each helper** (preserves migration 3's real intent — stop a logged-in user probing OTHER users via `is_admin('<other uuid>')` / `user_client_ids('<other uuid>')`): if the passed `_user_id` is not the caller, return false / empty.
3. **REQUIRED amendment — service_role exemption.** A naive `_user_id IS DISTINCT FROM auth.uid()` guard fails-closed whenever `auth.uid()` is NULL (service-role / no-JWT / server-fn context) → server-side cross-user calls silently return false/empty (bites at the Stage 1d server-fn layer). Guard must exempt trusted context:
   ```
   IF auth.role() <> 'service_role' AND _user_id IS DISTINCT FROM auth.uid() THEN
       -- boolean helpers: RETURN false ;  user_client_ids: RETURN (empty SETOF uuid)
   ```
   Net effect: RLS self-calls work; service-role cross-user calls work; only `authenticated`/`anon` probing of OTHER users is blocked. **Rule:** admin "check another user's access" must go through a service-role server fn, never a direct authed helper call.

## Implementation gotchas (must hold in migration 4)
1. **`CREATE OR REPLACE FUNCTION` does NOT inherit attributes** — re-declare `SECURITY DEFINER`, `STABLE`, and `SET search_path = public` in each replacement, or the existing (correct) hardening is silently lost. Use OR REPLACE (same signature) so dependent policies are untouched.
2. **Return-type correctness in the guard** — boolean helpers `RETURN false`; `user_client_ids` returns `SETOF uuid`, so the guard returns an empty set, not `false`.

## Why not the cleaner alternative
Dropping the `uuid` arg and reading `auth.uid()` internally removes the footgun entirely, but it's a **signature change → forces rewriting every policy → not append-only**. Given append-only migrations, `CREATE OR REPLACE` + guard + service_role exemption is the pragmatic correct path.

## Acceptance — finalize this note when ALL of these are in
- [ ] Migration 4 SQL pasted here (verbatim; secret-scanned — pure DDL, should be clean).
- [ ] Verify A — **live authed SELECT:** seeded `client_owner` SELECTs own `contacts` → rows return, NO `permission denied for function`.
- [ ] Verify B — **service-role smoke:** `select user_client_ids('<some user>')` via the admin/service-role client returns the real set (NOT empty) — proves the service_role exemption works.
- [ ] On all green → flip foundation-schema-snapshot open-item #3 to RESOLVED; append migration 4 to `foundation-migrations.sql`.
