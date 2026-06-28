# Stage C-3c-2a — pending model + pending→active flip — validation

> Point-in-time validation record, 2026-06-28. **App-layer only — no schema, no migration, no fn-contract change** (`clients.status` is free text; `createClientFull` signature unchanged). Verified against `cloud-spark-setup` `origin/main`. Build spec: `docs/phase-c-3c2a-build-spec.md`.

## What shipped
The unified pending lifecycle:
- **`createClientFull` inserts `status='pending'`** (`src/lib/clients/onboarding.functions.ts`) — every wizard create (agency self-fill; later client-submit) starts pending/dormant.
- **Finalize & Invite flips pending→active** — the EXISTING C-3c-1 invite mutation (`admin.settings.tsx`) now does a direct-RLS `clients.update({status:'active'})` after the successful `provisionClientOwner` call. No new button, no new fn, no duplicate logic.

## Why zero-schema / no fn-contract change
`clients.status` = `text NOT NULL DEFAULT 'active'`, no CHECK/enum → `'pending'` is a valid value with no migration. The `status='active'` allowlist filters (`get_client_public`, `clients_anon_select`, enrollment-claim) auto-exclude pending. `clients_select` (authenticated) is `is_admin OR user_client_ids` (not status-filtered) → admin still selects pending; `clients_update` is `is_admin`-gated → the flip is allowed. `createClientFull`'s signature/input/output are unchanged — only the inserted `status` value.

## Validation (PASS — full lifecycle on client `bot-buddiez`)
- **Part A (create = pending + dormant):** wizard create → `status='pending'`; `get_client_public('bot-buddiez')` returns **no row** (anon-excluded / dormant); still appears in the `/admin` client selector (admin `is_admin` RLS). ✅
- **Part B (Finalize & Invite = active):** → `status='active'`; `get_client_public` now returns the row (live); `client_owner` granted (C-3c-1 behavior intact). ✅
- **Part C (no backfill):** existing `active` clients untouched. ✅
- **Drift:** `onboarding.functions.ts` (insert `status:"pending"`) + `admin.settings.tsx` (invite mutation gains the activate step); no migration/schema/fn change; `tsc` passes. ✅

## Skills brought to parity (mirror lines handed)
- `admin-view` — the Finalize & Invite bullet's `[C-3c-2]` forward-pointer becomes BUILT (flips pending→active).
- `scratch-foundation` — §11 records the Onboard→Activate→Offboard lifecycle (create=pending → Finalize&Invite=active → archived).
- `onboard-from-form` — the as-built block notes `createClientFull` creates as `status='pending'` (dormant until Finalize & Invite).

## Next
**C-3c-2b** — `/admin/review` pre-gen console (lean v1) + immutable submission viewer + extract the shared `<FinalizeInvite/>` (embedded in both Settings and the console).
