---
name: agency-view
description: Use when building, modifying, or reviewing the cross-tenant AGENCY dashboard at /agency — the all-clients Pending ticket queue + cross-client Payment-Access control. This is the agency-wide layer ABOVE the per-client admin. NOT the per-client admin view (use admin-view) and NOT the client mobile app (use mobile-app).
---

# Agency View — cross-tenant agency dashboard at `/agency`

The agency-wide layer above the per-client `/admin`. **All-clients scope** (no single active client), gated to `admin`/`agency_owner`. It exists so the agency sees what needs attention across EVERY client without drilling into each, and controls payment access from one place. **[BUILT — Phase C-1, 2026-06-20; app-layer on `golden-master-v1.7`, no migration.]**

**Distinct from `/admin` [LOCKED].** The per-client `/admin` shell scopes to ONE active client (the client selector + `useActiveClient`). The agency view is deliberately a **separate `/agency` shell** because it is cross-tenant — mixing the two would fight the active-client model.

## Role model + access gate
Agency-scoped surface (`admin`/`agency_owner` — `is_admin()` covers both). The shell role-gates via `user_roles` (a `client_owner` hitting `/agency` sees "Not authorized"). **NEVER payment-gated** (the `access_suspended` gate suspends only the client PWA).

## Surfaces
- **Shell** (`src/routes/_authenticated/agency.tsx`): role-gate + a 3-tab nav (**Pending** · **Onboarding** · **Payment Access**) + an `<Outlet/>` + a "← Admin" link back to `/admin`. **Pending** carries a **count badge** = open/in-progress tickets; **Onboarding** carries a **count badge** = `clients` with `status='pending'` (both 15s poll).
- **Pending queue** (`agency.index.tsx`, `/agency`): the cross-tenant attention queue — all `open`/`in_progress` **edit-request + support tickets across every client**, client-labelled (joined `clients(business_name)`), newest by `last_message_at`, **15s poll**. Each row's **"Open"** action routes into that client's per-client admin thread: it writes `localStorage["admin.activeClientId"] = clientId` (the `/admin` shell's `STORAGE_KEY`, read on mount) then navigates to `/admin/edit-requests` or `/admin/support` by `kind`. **Route-only — no inline reply** (replies/approvals happen in the per-client admin surface; the queue just routes there).
- **Onboarding queue** (`agency.onboarding.tsx`, `/agency/onboarding`) **[BUILT — C-3c-2c]**: the cross-tenant **pending-onboarding** queue — all `clients WHERE status='pending'` (not deleted), newest by `created_at`, client-labelled (business_name + slug), **15s poll** + a count badge. Each row's **"Open"** writes `localStorage["admin.activeClientId"] = clientId` then navigates to **`/admin/review`** (the C-3c-2b Review & Finalize console — status pill + immutable submission viewer + missing-required-`template_vars` reminder + the shared `<FinalizeInvite/>`). Finalizing a client (pending→active) drops it from the queue on the next poll. Reads via the authed browser `is_admin()` RLS (`clients_select` is not status-filtered) — **no service-role**.
- **Payment Access** (`agency.access.tsx`, `/agency/access`): every non-deleted client with an `access_suspended` status pill + a **Suspend ↔ Restore** toggle → `setClientAccessSuspended`. One place to gate/un-gate client PWAs.

## Security contract [LOCKED]
- **Reads** go through the authed browser `supabase` (admin JWT → the `is_admin()` RLS branch, which returns rows across ALL clients). **NO `supabaseAdmin`/service-role in any agency route.**
- **The ONLY mutation is `setClientAccessSuspended`** (`src/lib/clients/access.functions.ts` — input `{ clientId, suspended, reason? }`; re-verifies `admin`/`agency_owner` server-side; updates `clients.access_suspended` + writes an `events` row `client_access_suspended`/`client_access_restored`). No direct `clients`/`tickets` writes from the agency UI.
- Suspending gates **only** that client's PWA shell (the already-built payment-gate intercept) — never the agency/admin surfaces, never the automations (which key off `status`/`deleted_at`).

## Relationship to the rest
- **Consumes** the B-design ticket tables (read-only here, via `is_admin()` RLS) + `setClientAccessSuspended` (v1.7). The 5 ticket write-fns + the per-client reply/approve/resolve UI live in **`admin-view`** (the queue routes into them). Data model = **`scratch-foundation`** (`tickets`) + `clients.access_suspended`.

## Build / extension notes
- **Deep-link to a specific ticket** (vs routing to the client's tab + the agency clicking it) would require threading a ticket id into `AdminTicketSurface` — deferred; v1 routes to the tab with the active client pre-set.
- **New-request flagging** = the Pending count badge + newest-first ordering (v1). A richer unread/seen model is future.
- **Cross-client overview/analytics** (status, suspended, pending counts per client as one board) = future extension of `agency.access.tsx`.
- Reachability: a single "Agency (all clients)" link in the `/admin` sidebar points to `/agency` (the only change C-1 made to `admin.tsx`).
