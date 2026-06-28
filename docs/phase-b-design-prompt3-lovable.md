# Phase B-design — Prompt 3 (per-client admin surfaces) — Lovable build prompt + validation

> Slice 1 (write boundary) + Slice 2 (client PWA) DONE + validated 2026-06-20. This is **Slice 3 — the per-client admin ticket surfaces**, where `postAgencyReply` / `setTicketStatus` finally run end-to-end. **Additive app-layer frontend only — NO migration, NO server-fn change** (consume the Slice-1 fns). Baseline stays `golden-master-v1.7`. **This closes B-design** (the cross-tenant **agency-view** — pending lists across ALL clients — stays Phase C).

---

# PROMPT 3 — paste into Lovable (admin Edit Requests + Support, per active client)

> **Build scope: app-layer frontend only. NO migration, NO server-fn / table / RLS change.** Add two admin routes + two sidebar entries. **Reads go through the authed `supabase` browser client (admin JWT → `is_admin()` RLS branch) — NEVER the service-role client in the admin UI. ALL writes go through the existing Slice-1 server fns** (`postAgencyReply` / `setTicketStatus`), which enforce `isAdmin` server-side and set trust fields authoritatively. When done, report the files changed/added + confirm no migration and no server-fn/table/RLS change.

The agency admin shell (`src/routes/_authenticated/admin.tsx`) is a sidebar that scopes to ONE **active client** at a time (via the existing admin context + client selector). Add two per-client ticket sections that mirror the client PWA's Edit/Support, but with **agency authority** (reply, approve/deny with resolution, resolve).

### Files
| File | Change |
|---|---|
| `src/routes/_authenticated/admin.tsx` | Add two entries to the sidebar `TABS` array: **Edit Requests** (`/admin/edit-requests`) and **Support** (`/admin/support`). |
| `src/routes/_authenticated/admin.edit-requests.tsx` (NEW) | Active client's `edit_request` tickets. |
| `src/routes/_authenticated/admin.support.tsx` (NEW) | Active client's `support` tickets + history filter. |

> **Active client:** read it the SAME way the existing admin tabs do (e.g. `admin.contacts.tsx` / `admin.conversations.tsx` use the admin context / `useActiveClient` from `@/lib/admin-context`). Every React Query key must include `activeClientId` so switching clients refetches cleanly (the established admin pattern).

### Shared admin ticket surface (both routes; `kind` differs)
Build one shared component (parameterized by `kind: 'edit_request' | 'support'`), consumed by both routes — mirroring how the client side shares `TicketSurface`. It has:
- **List** — `supabase.from('tickets').select(...).eq('client_id', activeClientId).eq('kind', kind).order('last_message_at', { ascending: false })`, RLS returns them via the `is_admin()` branch. Poll **15s**. A **filter**: Pending (`status in open,in_progress`) [default] · All · Closed/History. Each row shows subject + status badge + last activity.
- **Thread** — load messages (`ticket_messages` by `ticket_id`, `order created_at`) + attachments (`ticket_attachments`); render as **bubbles** (`sender_side==='agency'` = the agency/right side, `'client'` = left); attachments via **signed URL** (`supabase.storage.from('client-assets').createSignedUrl(storage_path, 60)` — admin can read via the bucket's `is_admin` branch). Poll **10s**. Show a resolution banner when set.
- **Agency actions** (all via the Slice-1 server fns — never direct table writes):
  - **Reply:** `postAgencyReply({ data: { ticketId, body, newStatus } })` — optional `newStatus` limited to `'in_progress'` (the fn only accepts `open`/`in_progress`). Forces `sender_side='agency'` server-side.
  - **`edit_request` decisions:** **Approve** and **Deny** each REQUIRE a resolution — `setTicketStatus({ data: { ticketId, status: 'approved'|'denied', resolution } })` (the fn rejects approve/deny without `resolution`). After implementing an approved edit, **Close** → `setTicketStatus({ data: { ticketId, status: 'closed' } })`. *(No automated re-deploy — "approve" = notify the client + record the resolution; you implement the edit manually in the remix or `admin.settings`.)*
  - **`support` decisions:** **Mark in progress** / **Resolve** → `setTicketStatus({ data: { ticketId, status: 'in_progress'|'resolved' } })`. Resolved threads move under the **History** filter.
- **Notifications fire automatically:** `postAgencyReply` + `setTicketStatus` already call `notify.server.ts` → the client gets an in-app `open_ticket` Alert + an owner-email stub. The admin UI does nothing extra.

### Security invariants (must hold)
- Admin reads: authed `supabase` only (admin JWT, `is_admin()` RLS). **No `supabaseAdmin` / service-role import in any admin route** (matches the `admin.tsx` contract).
- Admin writes: ONLY `postAgencyReply` / `setTicketStatus`. The ticket tables are read-only-RLS + write-REVOKEd for `authenticated`, so a direct table write from the UI would fail anyway — route everything through the fns.
- The client can never be shown an agency-spoofed state and vice-versa — `sender_side`/`status`/`resolution` are set by the fns, not the UI.

### Drift check (report back)
1. Added: `admin.edit-requests.tsx`, `admin.support.tsx`; changed: `admin.tsx` (sidebar TABS only).
2. No migration; no server-fn / table / RLS / enum / trigger change; no `supabaseAdmin` in the admin UI.
3. Build compiles; each query key includes `activeClientId`.

---

# VALIDATION — the deferred §10 step-7 full loop (client ↔ agency)

Logged in as the **admin** (`itsmikeymiami` / `775d20b1`), active client = **TestCo A**; and as the test **`pbd-owner-a`** in the PWA.

1. **Admin sees the client's request:** open **Edit Requests** → the "Add Photo to Gallery" ticket appears (OPEN); open the thread → the client's message + the image attachment render; the attachment **downloads via signed URL**.
2. **Agency reply round-trips:** post an agency reply → in the PWA (as `pbd-owner-a`), the Edit thread shows the agency message, **Alerts shows an `open_ticket` notification** that deep-links to it, and an `owner_email_stub` event was written (check `events`).
3. **Approve with resolution:** Approve the edit with a resolution → PWA shows `status=approved` + the resolution banner + a `ticket_status_changed` Alert. Confirm **approve-without-resolution is blocked** in the UI (the fn rejects it).
4. **Client reply reopens:** as the client, reply on the approved ticket → it reopens to `open` (visible admin-side).
5. **Support path:** client opens a support ticket → admin **Resolves** it → client sees Resolved (in History); client reply reopens.
6. **Isolation spot-check:** switching the admin's active client to TestCo B shows none of A's tickets.

All green = **B-design is functionally complete** (client + admin surfaces + the proven write boundary).

### After the loop is green
1. **Cleanup:** purge the test ticket fixtures (the "Add Photo to Gallery" + any HARNESS leftovers), the `pbd-owner-a` / role grant, and delete the test user.
2. **Skill mirror:** update **`admin-view`** (the edit-requests/support sections + the approve/deny-with-resolution flow + read-via-RLS/write-via-fn contract) and I'll hand you the changed section.
3. **Next:** Phase C (cross-tenant **agency-view** + admin onboarding wizard) — or the parked **Inbox/Conversations enhancements** (`docs/inbox-conversations-enhancements-scope.md`), your call.

---
**App-layer only. No migration. Baseline `golden-master-v1.7` unchanged. Closes B-design once the step-7 loop is green.**
