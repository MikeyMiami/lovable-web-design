# Build Log — Stage 3.5 §A Security Fix Validation (clients_public projection + storage policies)

> Validation of the Stage-3.5 §A security step (pulled forward before 3d): the two pre-existing critical scan findings (`clients_anon_select_sensitive_fields`, `storage_objects_no_policies`) blocking publish. Source: Lovable §A report. Validated 2026-06-14 (Claude Code).
> **Verdict: SUBSTANTIALLY PASS — both critical findings cleared, publish unblocked, sensitive fields protected. The "divergence" (column-grants on base vs full-revoke view-only) is actually CORRECT — and my original prompt's REVOKE/view-only step was WRONG.** 3 confirms outstanding (all hygiene/low-severity), the one behavioral one being the status-filter on direct base reads. Validation mode: description-level (Lovable cloud), grounded in spec/foundation + Postgres `security_invoker` semantics. No secret values.

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

## 🟡 Confirms outstanding (relayed to Lovable)
1. **(hygiene) Enumerate the exact anon column-grant list on base `clients`** — must equal the 14 presentational columns and NOTHING sensitive. The report proves `twilio_number` + `email` are denied; confirm `call_forwarding_number`, `twilio_messaging_service_sid`, `allowed_origins` are also NOT granted (full enumeration). `SELECT column_name FROM information_schema.column_privileges WHERE table_name='clients' AND grantee='anon';`
2. **(the one behavioral question) Does the retained anon ROW policy keep `status='active' AND deleted_at IS NULL`?** The view's `WHERE` enforces active-only, but a **direct base read** (via column-grants) is filtered only by the anon ROW policy — NOT the view's WHERE. If that policy retains the status filter → direct base reads are active-only → no bypass, fully equivalent to the view. If it was dropped/broadened → anon could read presentational columns of **inactive/soft-deleted** clients directly from base (a status-filter bypass; low-severity — presentational data only, no sensitive fields — but it means archive/offboard doesn't fully take effect for anon). `SELECT polname, roles, pg_get_expr(polqual,polrelid) FROM pg_policy WHERE polrelid='public.clients'::regclass;` — confirm the anon SELECT policy's USING clause. **Since the `security_invoker` view returns data, an anon row policy MUST exist; the only question is its filter.** Likely retained (= secure); confirm.
3. **(audit semantics) Did the Step-4 audit enhancement get applied, and is its assertion correct?** With `security_invoker` forcing column-grants, the enhancement must assert **"anon's base grants ⊆ the presentational set + the anon row policy keeps the status filter"** — NOT "no anon base SELECT at all" (which is impossible here and would false-flag the correct as-built). The spec/launch-check enhancement text has been corrected accordingly.

## Recommendation
Keep the column-grant + `security_invoker`-view approach (it's correct). Do NOT pursue the original full-revoke/view-only (incompatible with the linter). Just close confirms #1–#3. If #2 reveals the anon row policy lost the status filter, re-add it (`status='active' AND deleted_at IS NULL`) — that restores active-only on the base path. No view-only revoke needed.

## Status
- **§A security fix SUBSTANTIALLY PASS — both critical findings cleared, publish unblocked, sensitive fields denied to anon.** Mechanism (security_invoker view + presentational column-grants + retained row policy) is correct and recorded as-built.
- **3 confirms outstanding** (grant enumeration; anon row-policy status filter — the one behavioral item; audit-enhancement semantics) — none block publish; #2 is low-severity (presentational data of inactive clients, if the filter was dropped).
- **foundation open-item #2 → RESOLVED (mechanism documented here); the status-filter confirm tracked as the residual.**
- **Publish unblocked → clear to (a) run the 3c cron-path live walk (folded into the 3.5 regression) and (b) proceed to 3d.**
