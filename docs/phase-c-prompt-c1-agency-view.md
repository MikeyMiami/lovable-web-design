# Phase C — C-1 (Agency-View) — Lovable build prompt + validation

> Slice C-1 of `docs/phase-c-scope.md` — the cross-tenant **agency-view**. **Additive app-layer frontend only — NO migration, NO server-fn change** (reuses `is_admin()` RLS reads + the existing `setClientAccessSuspended`). Baseline stays `golden-master-v1.7`. **Contract verified against LIVE v1.7** (origin/main `c8a56f9`), not the stale clone.

## Verified live-v1.7 facts this prompt relies on
- **`setClientAccessSuspended`** (`src/lib/clients/access.functions.ts`): `createServerFn` input `{ clientId: uuid, suspended: boolean, reason?: string }` → `{ ok, suspended }`; gated to `admin`/`agency_owner`; updates `clients.access_suspended` + writes an `events` row (`client_access_suspended`/`client_access_restored`).
- **Active-client handoff:** the `/admin` shell initialises its active client from **`localStorage["admin.activeClientId"]`** (its `STORAGE_KEY`). `useActiveClient()` (`@/lib/admin-context`) is provided **only inside the `/admin` shell**, so `/agency` cannot call `setActiveClientId` directly — it writes that localStorage key then navigates.
- Per-client ticket surfaces exist: `admin.edit-requests.tsx` / `admin.support.tsx` → `<AdminTicketSurface kind activeClientId />`.
- `tickets.client_id` → `clients.id` FK; admin reads cross-tenant via the `is_admin()` RLS branch (no `client_id` filter needed). `clients.access_suspended` is readable by admins via the authed `supabase` (only the anon `get_client_public` RPC strips it).

---

# PROMPT C-1 — paste into Lovable

> **Build scope: app-layer frontend only. NO migration, NO server-fn / table / RLS change.** Add a new top-level `/agency` shell + two sub-views + one link from the admin sidebar. **All reads via the authed `supabase` browser client (admin JWT → `is_admin()` RLS, which returns rows across ALL clients). The ONLY write is the existing `setClientAccessSuspended` server fn — do NOT write `clients`/`tickets` directly.** When done, report files changed/added + confirm no migration and no server-fn/table/RLS change.

Build the **agency-view** — the cross-tenant layer above the per-client `/admin`. It is **all-clients scope** (no single active client), gated to `admin`/`agency_owner`. Two sections: a **Pending queue** (edit-requests + support tickets needing attention across every client) and **Payment Access** (suspend/restore each client's PWA from one place).

### Files
| File | Change |
|---|---|
| `src/routes/_authenticated/agency.tsx` (NEW) | Agency shell: role-gate (`admin`/`agency_owner`) + a 2-tab nav (**Pending** · **Payment Access**) + `<Outlet/>` + a "← Admin" link to `/admin`. |
| `src/routes/_authenticated/agency.index.tsx` (NEW) | **Pending queue** (`/agency`). |
| `src/routes/_authenticated/agency.access.tsx` (NEW) | **Payment Access** (`/agency/access`). |
| `src/routes/_authenticated/admin.tsx` (MODIFY) | Add ONE link to `/agency` (e.g. an "Agency (all clients)" item at the top of the sidebar) so the agency view is reachable. Nothing else in this file changes. |

### `agency.tsx` — shell + role gate (reuse the `admin.tsx` authz pattern)
```tsx
const { data: isAgencyAdmin, isLoading } = useQuery({
  queryKey: ["agency-authz"],
  queryFn: async () => {
    const { data, error } = await supabase
      .from("user_roles").select("role").in("role", ["admin", "agency_owner"]);
    if (error) throw error;
    return (data ?? []).length > 0;
  },
  staleTime: 60_000,
});
// isLoading → spinner; !isAgencyAdmin → a "Not authorized — requires admin/agency_owner" panel
// (mirror admin.tsx's not-authorized branch). Otherwise render the 2-tab nav + <Outlet/>.
```
The 2-tab nav links to `/agency` (Pending) and `/agency/access`. Show a small **count badge** on Pending = number of pending tickets.

### `agency.index.tsx` — Pending queue
Cross-tenant read (RLS `is_admin()` returns all clients); poll 15s; join the client name.
```tsx
const { data: pending } = useQuery({
  queryKey: ["agency-pending"],
  refetchInterval: 15000,
  queryFn: async () => {
    const { data, error } = await supabase
      .from("tickets")
      .select("id, client_id, kind, status, subject, last_message_at, clients(business_name)")
      .in("status", ["open", "in_progress"])
      .order("last_message_at", { ascending: false });
    if (error) throw error;
    return data ?? [];
  },
});
```
Render a list (newest first): each row shows **business name**, **kind** (Edit Request / Support), **status** badge, **subject**, relative time. An **"Open"** action routes into that client's per-client admin thread by setting the active client then navigating:
```tsx
function openInAdmin(clientId: string, kind: string) {
  window.localStorage.setItem("admin.activeClientId", clientId);  // the /admin shell reads this on mount
  navigate({ to: kind === "edit_request" ? "/admin/edit-requests" : "/admin/support" });
}
```
*(Optional: group/filter by kind. New-request flagging = the count badge + newest-first ordering is enough for v1. Deep-linking to the exact ticket would require touching `AdminTicketSurface` — out of scope for C-1; routing to the client's tab is sufficient.)*

### `agency.access.tsx` — Payment Access
List every client + their suspend status; toggle via the existing fn.
```tsx
import { setClientAccessSuspended } from "@/lib/clients/access.functions";

const { data: clients } = useQuery({
  queryKey: ["agency-clients"],
  queryFn: async () => {
    const { data, error } = await supabase
      .from("clients")
      .select("id, business_name, slug, access_suspended")
      .is("deleted_at", null)
      .order("business_name", { ascending: true });
    if (error) throw error;
    return data ?? [];
  },
});

async function toggle(clientId: string, current: boolean) {
  await setClientAccessSuspended({ data: { clientId, suspended: !current } });
  // then invalidate ["agency-clients"] so the row reflects the new state
}
```
Render each client as a row: business name + slug, a **Suspended / Active** status pill, and a toggle/button (Suspend ↔ Restore) calling `toggle`. After the call, refetch. (Suspending gates only that client's PWA shell — never the agency/admin surfaces — handled by the already-built payment-gate intercept.)

### Security invariants
- Reads: authed `supabase` only (admin JWT → `is_admin()` RLS returns cross-tenant rows). **No `supabaseAdmin`/service-role import in any agency route.**
- The only mutation is **`setClientAccessSuspended`** (server fn, re-verifies `admin`/`agency_owner` server-side). No direct `clients`/`tickets` writes from the UI.
- `/agency` is gated to `admin`/`agency_owner` (the shell's role check) — a `client_owner` hitting `/agency` sees "Not authorized."

### Drift check (report back)
1. Added: `agency.tsx`, `agency.index.tsx`, `agency.access.tsx`; changed: `admin.tsx` (one `/agency` link only).
2. No migration; no server-fn / table / RLS / enum / trigger change; no `supabaseAdmin` in any agency route.
3. Build compiles; `setClientAccessSuspended` imported from `@/lib/clients/access.functions`.

---

# VALIDATION

**Account:** your **`itsmikeymiami`** admin — that's all you need (C-1 is read + the suspend toggle; **no client-owner login required**, so the purged `pbd-*` users are not needed).

**Test-setup flag — the Pending queue needs at least one open ticket to show content** (the B-design test tickets were purged). Seed 1–2 transient tickets via the SQL editor (service-role), then clean up:
```sql
-- seed: one open edit_request + one open support ticket for a test client (TestCo A)
with t as (
  insert into public.tickets (client_id, kind, status, subject, created_by)
  values
    ('aaaaaaaa-0000-0000-0000-00000000000a','edit_request','open','C1 TEST edit','4efaaa92-a5cd-4dbd-842f-4446fbeebce7'),
    ('aaaaaaaa-0000-0000-0000-00000000000a','support','open','C1 TEST support','4efaaa92-a5cd-4dbd-842f-4446fbeebce7')
  returning id, client_id
)
insert into public.ticket_messages (ticket_id, client_id, sender_user_id, sender_side, body)
select id, client_id, '4efaaa92-a5cd-4dbd-842f-4446fbeebce7','client','seed body' from t;
```

**Checks (logged in as `itsmikeymiami`):**
1. **Reachable + gated:** `/agency` loads from the admin-sidebar link; the count badge shows 2. *(Sanity: a non-admin would see "Not authorized" — optional, no spare user needed.)*
2. **Cross-tenant queue:** both seeded tickets appear, labelled **TestCo A**, newest first.
3. **Routing:** "Open" on the edit row lands on `/admin/edit-requests` with **TestCo A** already the active client (the localStorage handoff); the ticket is in that list. Same for support → `/admin/support`.
4. **Payment Access:** the client list renders with status pills; **Suspend** TestCo A → its pill flips to Suspended + an `events` row `client_access_suspended` is written; **Restore** → back to Active. (Optionally confirm the PWA gate engages, but that was already proven in B-design.)
5. **Isolation sanity:** the queue spans clients (seed a ticket for a second client to confirm both show).

**Cleanup after validation:**
```sql
delete from public.tickets where subject like 'C1 TEST %';  -- cascades the seeded messages
-- restore TestCo A if you left it suspended:
update public.clients set access_suspended = false where id = 'aaaaaaaa-0000-0000-0000-00000000000a';
```

### After C-1 is green
Mirror the **NEW `agency-view` skill** (I'll draft it), then → **C-2 (wizard orchestration fns)**.

---
**App-layer only. No migration. Baseline `golden-master-v1.7` unchanged. C-1 → validate → agency-view skill → C-2.**
