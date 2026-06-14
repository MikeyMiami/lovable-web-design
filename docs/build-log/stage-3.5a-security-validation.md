# Build Log — Stage 3.5 §A Security Fix Validation (clients_public projection + storage policies)

> Validation of the Stage-3.5 §A security step (pulled forward before 3d): the two pre-existing critical scan findings (`clients_anon_select_sensitive_fields`, `storage_objects_no_policies`) blocking publish. Source: Lovable §A report. Validated 2026-06-14 (Claude Code).
> **Verdict: NOT closed — the §A confirm queries caught a REAL BUG.** The earlier migration did the REVOKE but the **column GRANT never landed**: anon has **ZERO** base-`clients` grants (`information_schema.column_privileges` = 0 rows), so the `security_invoker` `clients_public` view **permission-denies for anon** → the marketing site can't read. The report's "✅ anon returns data / ✅ column grant allowed" checkmarks were NOT backed by the DB — the privilege query is the ground truth. `storage_objects_no_policies` IS fixed; the `clients` finding is **half-applied** (REVOKE without GRANT). Row policy ✅ (status filter retained) + audit ✅ (0). Lovable is shipping the missing additive GRANT of the 14 presentational columns. The column-grants *mechanism* is still correct (a `security_invoker` view forces it). **Do NOT close until re-confirm shows anon can actually SELECT through `clients_public` AND get data + sensitive still denied + audit 0.** Validation mode: description-level, but now anchored on the live privilege/policy queries. No secret values.

## ✅ Confirmed good
- **`security_invoker` view** — `clients_public` is `security_invoker=on` (the initial SECURITY DEFINER view tripped the Supabase linter ERROR; switching to invoker cleared it). ✓
- **`audit_tenant_rls()` = 0 rows.** ✓
- **anon → `clients_public` presentational columns** returns data ✓; **anon → `clients_public.twilio_number`** fails (not in view) ✓.
- **anon → base `clients.twilio_number` / `.email`** = permission denied ✓ (sensitive columns not granted).
- **storage.objects**: 3 policies added (public-assets read, public-assets admin-write, client-assets folder-scoped RW) ✓ — matches `scratch-foundation` §9.
- **data-loader reads `phone_display`, not `twilio_number`** (per the template-builder contract) → the STOP condition is clear; no reconciliation needed. ✓
- **Both critical findings resolved; publish unblocked.** Remaining linter items are pre-existing WARNs (intentional SECURITY DEFINER RLS *helpers*, public-bucket listing, pg extension in public) — non-critical.

## 🔑 The divergence — and why it's CORRECT (my prompt was wrong)
The prompt said `REVOKE SELECT ON clients FROM anon` (view-only; anon reads ONLY via `clients_public`). Lovable instead used **column-level GRANTs on base `clients`**, leaving anon two read paths (view + base). **This is not a shortcut — it is forced by the `security_invoker` view, and my REVOKE step was incompatible with it:**
- A **`security_invoker` view** runs the underlying base query with the *invoker's* (anon's) privileges + RLS. So anon MUST hold SELECT privilege on the base columns the view reads — otherwise `clients_public` returns nothing for anon.
- The Supabase linter **flags SECURITY DEFINER views as an ERROR** (a definer view would bypass the caller's RLS). So `security_invoker` is required → column-grants on base are required → **full anon-revoke / view-only is impossible** with a lint-clean view.
- Correct shape (as-built): **REVOKE anon's table-wide SELECT → GRANT only the presentational columns → KEEP the status-filtered anon row policy → expose the `security_invoker` `clients_public` view.** Column-grants do the column-scoping; the row policy does the row-scoping (for BOTH the view and any direct base read).

**Net:** Lovable's mechanism is the right one. The recorded fix shape in spec §12 / launch-check §A has been corrected from "DROP policy + full REVOKE/view-only" to this as-built shape.

## 🟥 Confirm results (2026-06-14) — a real bug
1. **anon column-grant list = `0 rows` → BUG.** The REVOKE of anon's table-wide SELECT landed, but the GRANT of the 14 presentational columns **did not** — anon currently has NO base-`clients` privileges. Consequence: the `security_invoker` `clients_public` view runs the base query as anon → **permission denied → the marketing site can't read any client data.** (This contradicts the report's "✅ returns data" — the privilege query is ground truth.) **Fix: ship the additive `GRANT SELECT (…14 cols…) ON clients TO anon`.** Suspected root cause = the `logo`/`logo_url` name mismatch (below): if the GRANT listed a non-existent column, the whole statement aborts → 0 grants.
2. **anon ROW policy keeps the status filter — ✅.** The retained anon SELECT policy's USING clause includes `status='active' AND deleted_at IS NULL`, so once the grant lands, direct base reads are active-only — no inactive/soft-deleted bypass; equivalent to the view's filter. The one behavioral question is **resolved good.**
3. **audit enhancement — ✅.** `audit_tenant_rls()` = 0; the clients-policy gating is clean with the column-grant shape.

## 🟡 `logo` vs `logo_url` — pin the real name (may be the GRANT's root cause)
Lovable's grant references `logo_url`; our spec/view list `logo`. **The view EXISTS, so its SELECT list uses valid (real) column names** — whatever it selects for the logo IS the real column. The GRANT must use that SAME name. If the grant said `logo_url` but the real column is `logo` (or vice-versa), the GRANT errors and **nothing lands** — which fits the 0-rows result. Fix: confirm the real name (`SELECT column_name FROM information_schema.columns WHERE table_name='clients' AND column_name IN ('logo','logo_url');`), make the **view SELECT list + the GRANT column list + our docs** all agree on it. If the real column is `logo_url`, the view definition is already correct and only our docs' `logo` is the error (update spec §12 + launch-check §A `logo`→`logo_url`); if the real column is `logo`, the GRANT statement is the error (fix the grant).

## Recommendation
Keep the column-grant + `security_invoker`-view approach (it's correct). Do NOT pursue the original full-revoke/view-only (incompatible with the linter). Just close confirms #1–#3. If #2 reveals the anon row policy lost the status filter, re-add it (`status='active' AND deleted_at IS NULL`) — that restores active-only on the base path. No view-only revoke needed.

## Status
- **§A NOT closed.** `storage_objects_no_policies` fixed ✅. `clients_anon_select_sensitive_fields` half-applied: REVOKE landed, GRANT did NOT → anon has 0 base grants → `security_invoker` view permission-denies for anon (marketing site can't read). Row policy ✅ (status filter retained), audit ✅ (0). Re-GRANT of the 14 columns in flight; `logo`/`logo_url` name to be pinned (suspected GRANT root cause).
- **CLOSE CRITERIA (re-confirm must SHOW, not assert):** anon SELECTs through `clients_public` and **gets data**; sensitive columns (`twilio_*`/`call_forwarding_number`/`email`/`allowed_origins`) still denied; `audit_tenant_rls()`=0; view + grant + docs agree on the real logo column name.
- **foundation open-item #2 → FIX IN PROGRESS** (corrected from the premature "RESOLVED" — the report's checkmarks weren't backed by the privilege query).
- **Mechanism is correct** (security_invoker view + presentational column-grants + retained status row-policy); only the GRANT execution + the column-name pin remain.
- **Publish is unblocked at the scan level**, but the marketing read path is broken until the GRANT lands — so close §A first, then run the 3c cron-path walk (folded into the 3.5 regression) + 3d.
