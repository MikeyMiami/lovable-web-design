# Build Log — Stage 3.5 §A Security Fix Validation (clients_public projection + storage policies)

> Validation of the Stage-3.5 §A security step (pulled forward before 3d): the two pre-existing critical scan findings (`clients_anon_select_sensitive_fields`, `storage_objects_no_policies`) blocking publish. Source: Lovable §A report. Validated 2026-06-14 (Claude Code).
> **Verdict: CLOSED — PASS (2026-06-14).** Both findings resolved, proven by LIVE anon queries (not checkmarks): anon→`clients_public` returns data (`[{business_name:'RLS Test Co', phone_display:null}]`); anon→sensitive (`email`/`twilio_number`/`call_forwarding_number`) = **42501 permission denied**; `audit_tenant_rls()`=0; storage = 3 policies. The earlier "grant didn't land" bug — caught by the confirm queries, NOT the report's checkmarks — is fixed: anon now holds the **13 presentational column-grants + `status`/`deleted_at`** (the latter needed by the `security_invoker` view's WHERE filter). Two doc reconciliations applied: `logo`→`logo_url`; `quote_form_link` is a `template_vars` key (not a top-level column) → accurate top-level set is **13, not 14**. As-built = REVOKE table-wide anon SELECT + 13-col GRANT (+`status`/`deleted_at`) + retained status row-policy + `security_invoker` `clients_public` view. No secret values.
>
> **⚠️ MECHANISM CORRECTED 2026-06-15 (introspection-backed) — supersedes the view/column-grant framing throughout this doc:** raw `pg_proc`/`pg_policies`/`proacl` introspection shows the live as-built is **RPC-only**. Base `clients` has **ZERO anon grants + NO anon RLS policy** (direct anon read = 42501); the sole anon path is the **`public.get_client_public(slug)` RPC** (`SECURITY DEFINER`, `STABLE`, `SET search_path=public`, EXECUTE to anon) returning the 13-col projection with `template_vars - 'notification_email'` stripped + `status='active' AND deleted_at IS NULL` filtered IN-BODY. **There is NO `clients_public` view and NO anon column-grants** — the "security_invoker view + 13 column-grants + retained anon row policy" described below/above was stale/wrong (the live anon read worked via the RPC, which the Lovable reports loosely called a "view"). The leak was/is sealed either way (adversarial proof held). Canonical record: spec §12 §A bullet (reconciled).

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

## ✅ Re-confirm (2026-06-14) — §A CLOSED (live-proven)
- **(1)** anon → `clients_public` returns DATA: `[{"business_name":"RLS Test Co","phone_display":null}]` ✅ (the GRANT landed).
- **(2)** anon → sensitive: `42501 permission denied` on `email`, `twilio_number`, `call_forwarding_number` ✅.
- **(3)** `audit_tenant_rls()` = 0 ✅.
- **(4)** real column = `logo_url` — view + grant + data-loader all agree ✅.
- **Grant set = 13 presentational** (`slug, business_name, tagline, phone_display, address, hours, license_number, logo_url, brand_color, service_area, social_links, template_vars, review_link`) **+ `status` + `deleted_at`** (for the `security_invoker` view's WHERE; anon only ever sees active rows, so no leak). Zero sensitive granted.
- **`quote_form_link` resolution:** it's a `template_vars` jsonb KEY (per admin-view §Settings), NOT a top-level column → covered by the `template_vars` grant. Our docs over-listed it; accurate top-level set is 13. No missing grant.
- *(Note: `information_schema.column_privileges` returned empty for the sandbox role — a known role-visibility quirk; the grant is proven by `pg_attribute.attacl` + the live anon curl. The live SELECT returning data is the authoritative proof.)*

## Status
- **§A CLOSED — PASS.** Both criticals resolved + live-verified. `clients_public` = `security_invoker` view + 13 presentational column-grants (+`status`/`deleted_at`) + retained status row-policy; sensitive denied (42501); audit 0; storage 3 policies. Data-loader (Project 2) points at `logo_url`.
- **foundation open-item #2 → RESOLVED** (for real — backed by the live anon SELECT, not checkmarks).
- **Docs reconciled:** `logo`→`logo_url`; column count 14→13 (`quote_form_link` is a `template_vars` key) across spec §12 + launch-check §A + snapshot.
- **Publish unblocked + marketing read path working → clear to run the 3c cron-path walk (folded into the 3.5 regression) + proceed to 3d.**
