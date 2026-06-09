# Build Log — Foundation Schema Snapshot (golden-master build record)

> As-built record of the Stage 1 foundation, validated against `skills/scratch-foundation/SKILL.md`. Source: Lovable validation report (live `pg_enum` / `information_schema` / `pg_policies` / `pg_indexes` / `pg_proc` dumps + migration SQL). Captured 2026-06-09.
> **No secret VALUES are stored here** — DDL/policy/schema only.
>
> **Validation verdict:** PASS on all locked invariants. Open items at the bottom (review_gate_mode enum mismatch vs `/admin-view`; anon column-scope advisory; helper-EXECUTE runtime verify; RLS-audit gate TODO tracked in spec §12).

## Migrations (apply order)
| File | Purpose |
|---|---|
| `20260609032253_*.sql` | pre-foundation: enable `pg_cron`, `pg_net` |
| `20260609034320_*.sql` | foundation — extensions, 4 enums, `tg_set_updated_at()`, 12 tables (+GRANTs/RLS/policies), 4 SECURITY DEFINER helpers, indexes (494 lines) |
| `20260609034341_*.sql` | lockdown — REVOKE EXECUTE on the 4 helpers from PUBLIC/anon/authenticated |

### Migration 1 — pre-foundation (verbatim)
```sql
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;
```

### Migration 3 — helper lockdown (verbatim)
```sql
REVOKE EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.is_admin(uuid)                 FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.is_agency_owner(uuid)          FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.user_client_ids(uuid)          FROM PUBLIC, anon, authenticated;
```

> Migration 2 (foundation, 494 lines) raw SQL is now **archived verbatim** in `foundation-migrations.sql` (migrations 1–4, secret-scanned). Cross-checked: migration 2 matches these live dumps. **One divergence flagged — see Open items #5** (`sending_subdomain`/`dkim_status` not built).

## Enums (live)
- `app_role` : admin, agency_owner, client_owner, client_staff, client
- `contact_source` : web_form, review_enroll, missed_call, import, manual, **chat_widget**, **mobile_enroll**
- `contact_status` : new, contacted, replied, customer, review_requested, review_clicked, **review_completed**, **negative_review**, **reactivation**, opted_out
- `review_gate_mode` : gated, direct  *(RESOLVED: 2-mode locked; `/admin-view` updated to match — see Open items #1)*

All values lowercase_snake. The 5 spec-required adds are present. ✅

## Tables (12) — column counts + notes
| Table | Cols | Notes |
|---|---|---|
| clients | 27 | slug UNIQUE; brand_color default `#bd703e`; service_area text[]; allowed_origins text[]; template_vars jsonb; soft-delete `deleted_at` |
| user_roles | 5 | UNIQUE (user_id, role, client_id); FK → auth.users |
| send_settings | 10 | UNIQUE client_id; **timezone here, not on clients**; daily_enrollment_cap default 50 |
| contacts | 16 | phone_e164, consent_*, opted_out_at, last_missed_call_textback_at, soft-delete |
| conversations | 6 | |
| messages | 8 | direction CHECK ∈ {inbound, outbound} |
| templates | 6 | partial-unique on (client_id,key) and on (key) where global |
| sequences | 7 | partial-unique on (client_id,key) and on (key) where global |
| enrollments | 8 | UNIQUE (client_id, contact_id, sequence_key); sequence_key text, no FK (value-match) |
| review_feedback | 9 | |
| events | 7 | created_by uuid; append-only (no INSERT policy → service-role only) |
| notifications | 7 | service-role inserts only |

## RLS policies (18, live `pg_policies`)
Postgres normalizes `(SELECT auth.uid())` → `( SELECT auth.uid() AS uid )`; logic identical to authored SQL.

**clients (5):**
- `clients_select` (SELECT, authenticated): `USING (is_admin((SELECT auth.uid())) OR id IN (SELECT user_client_ids((SELECT auth.uid()))))`
- `clients_anon_select` (SELECT, anon): `USING (status='active' AND deleted_at IS NULL)`
- `clients_insert` (INSERT, authenticated): `WITH CHECK (is_admin((SELECT auth.uid())) OR is_agency_owner((SELECT auth.uid())))`
- `clients_update` (UPDATE, authenticated): `USING`/`WITH CHECK (is_admin(...) OR id IN (SELECT user_client_ids(...)))`
- `clients_delete` (DELETE, authenticated): `USING (is_admin((SELECT auth.uid())))`

**user_roles (1):**
- `user_roles_self_select` (SELECT, authenticated): `USING (user_id = (SELECT auth.uid()) OR is_admin((SELECT auth.uid())))` — writes service-role only.

**Standard tenant tables — `*_all` (FOR ALL, authenticated), identical shape:** `contacts`, `conversations`, `enrollments`, `messages`, `review_feedback`, `send_settings`
```
USING      (is_admin((SELECT auth.uid())) OR client_id IN (SELECT user_client_ids((SELECT auth.uid()))))
WITH CHECK (is_admin((SELECT auth.uid())) OR client_id IN (SELECT user_client_ids((SELECT auth.uid()))))
```

**events / notifications — SELECT-only (writes service-role):**
- `events_select` / `notifications_select` (SELECT, authenticated): `USING (is_admin(...) OR client_id IN (SELECT user_client_ids(...)))`

**templates / sequences (2 each) — global-row pattern:**
- `*_select` (SELECT, authenticated): `USING (client_id IS NULL OR is_admin(...) OR client_id IN (SELECT user_client_ids(...)))`
- `*_write` (FOR ALL, authenticated): `USING`/`WITH CHECK (is_admin(...) OR (client_id IS NOT NULL AND client_id IN (SELECT user_client_ids(...))))` — globals (client_id IS NULL) are read-by-all-authed, **writable only by admin**.

## Indexes (live `pg_indexes`, beyond PK/UNIQUE)
- contacts: `idx_contacts_client_status (client_id, status)`, `idx_contacts_client_phone (client_id, phone_e164)`
- conversations: `idx_conversations_client_contact (client_id, contact_id)`
- messages: `idx_messages_convo_created (conversation_id, created_at DESC)`, `idx_messages_client_created (client_id, created_at DESC)`
- enrollments: `idx_enrollments_due (next_run_at) WHERE status='active'` (partial; cron hot path), `idx_enrollments_client (client_id)`, `enrollments_client_id_contact_id_sequence_key_key` (UNIQUE backing dedup)
- events: `idx_events_client_type_created (client_id, type, created_at DESC)`
- notifications: `idx_notifications_client_created (client_id, created_at DESC)`
- review_feedback: `idx_review_feedback_client_created (client_id, created_at DESC)`
- user_roles: `idx_user_roles_user_id`, `idx_user_roles_client_id`
- templates/sequences: `uq_*_client_key` + `uq_*_global_key` (partial uniques)

## Helper functions (live `pg_proc`)
| Function | SECURITY DEFINER | Volatility | EXECUTE ACL |
|---|---|---|---|
| has_role(uuid, app_role) | yes | STABLE | postgres, service_role, sandbox_exec (anon/authenticated REVOKED) |
| is_admin(uuid) | yes | STABLE | same |
| is_agency_owner(uuid) | yes | STABLE | same |
| user_client_ids(uuid) | yes | STABLE | same |
| tg_set_updated_at() | no | VOLATILE | trigger-only (default ACL) |

All four security-definer helpers `search_path=public`.

## Open items (tracked — NOT yet resolved)
1. ~~**`review_gate_mode` enum = {gated, direct}** vs `/admin-view`'s `gated|all|off`.~~ **RESOLVED (2026-06-09):** locked 2-mode `{gated, direct}`; `/admin-view` updated to match the DB (gated = funnel; direct = straight to Google; no "off" — suppress by not enrolling). No migration needed.
2. **anon `clients` SELECT is row-level only** — exposes all 27 columns to anon (incl. twilio_number/messaging_service_sid/sending_subdomain/call_forwarding_number). No secret values on the row, but deviates from "public columns only." Fix later via public view / column GRANTs.
3. ~~**Helper EXECUTE revoked from `authenticated`**~~ — **RESOLVED (2026-06-09):** migration 4 applied (GRANT EXECUTE back + self-only guard + `service_role` exemption); verified green — authed SELECT works, service-role exemption returns real set, anon cross-user probe returns []. The 8 SECURITY DEFINER linter warnings are the expected boundary (do NOT re-REVOKE). Full record: `migration-4-helper-execute-fix.md`. *(Bookkeeping: migration 4 + migration 2 raw SQL still to be archived into `foundation-migrations.sql`.)*
4. **RLS-audit gate (guardrail 1)** — TODO tracked in spec §12; recommended to build now against this schema.
5. **`sending_subdomain` / `dkim_status` NOT built** — migration 2's `clients` table (27 cols) omits both, but `scratch-foundation` §1 / `admin-view` / `onboard-from-form` still describe them as "columns exist (deferred-v1)." Consistent with the decision (one platform sender; per-client email deferred) but the skill TEXT is now inaccurate. Fix: update those 3 skills to "not created in v1 (deferred; ADD COLUMN later if per-client email is built)." Append-only — no migration needed now. Not a 1e blocker. *(Decision pending: confirm skill edit.)*
