# Build Log — Migration 4: helper EXECUTE fix (PENDING APPLY)

> Status: **APPLIED & VERIFIED GREEN (2026-06-09).** Migration 4 shipped with the required `service_role` exemption; all three verifications passed (below). Foundation open-item #3 → **RESOLVED**. Remaining bookkeeping: archive migration 4's raw SQL into `foundation-migrations.sql` (raw SQL pending paste — alongside migration 2). No secret values stored here.
> Reviewed independently (Claude Code) 2026-06-09; verdict was: ship as migration 4 with the amendments below — which it did.

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

## Verification results (2026-06-09) — ALL GREEN
- [x] **Verify A — live authed SELECT:** seeded `client_owner` SELECTed own `contacts` → rows returned, **no `permission denied for function`**. RLS evaluation restored. ✅
- [x] **Verify B — service-role smoke:** `user_client_ids('<user>')` via the admin/service-role client returned the **real client set, not empty** → the `service_role` exemption works. ✅
- [x] **Bonus — anon cross-user probe:** anon RPC calling a helper with **another** uuid returned `[]` → the self-guard blocks cross-user probing as intended. ✅
- [ ] **Archive migration 4 raw SQL** into `foundation-migrations.sql` — **pending paste** (the `[paste it]` placeholder didn't arrive). Will secret-scan + append when supplied, together with migration 2's raw SQL.

## Linter note — the 8 SECURITY DEFINER warnings are EXPECTED, do not "fix"
Supabase's linter flags the 4 helpers as SECURITY DEFINER (×2 each → 8 warnings). **This is the deliberate, correct boundary — leave it.** The security model is: `EXECUTE` granted to anon/authenticated (REQUIRED for RLS policy evaluation) **+ the in-body self-guard** (`auth.role() <> 'service_role' AND _user_id IS DISTINCT FROM auth.uid()`) as the actual access boundary. **Do NOT REVOKE EXECUTE to silence the linter** — that is precisely what migration 3 did and it broke all authed RLS evaluation. The guard, not the EXECUTE revoke, is the boundary.
