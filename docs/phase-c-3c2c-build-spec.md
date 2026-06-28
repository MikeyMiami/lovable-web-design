# Phase C — C-3c-2c: agency Pending-onboarding queue + badge (closes C-3c-2)

> Final C-3c-2 slice. **App-layer / UI only — NO schema, NO migration, NO fn-contract change, NO service-role.** Mirrors the C-1 agency Pending pattern. Held for review. Verified against `cloud-spark-setup` `origin/main` @ `53aba32`.

## Scope
Surface pending clients in the agency UI: a new **Onboarding** tab in `/agency` listing `clients WHERE status='pending'`, a **count badge**, **15s poll**, and **"Open" → `localStorage["admin.activeClientId"]` → `/admin/review`** (the C-3c-2b console). This is the slice that finally makes a client-submitted (or self-fill) pending client visible + actionable cross-tenant.

## Verified facts (mirror C-1)
- `agency.tsx` shell: a `pendingCount` query (`tickets`, 15s `refetchInterval`) drives a tab `badge`; tabs array at `:63`. We add a second count query (pending clients) + a tab.
- `agency.index.tsx`: the queue pattern — 15s-poll query, list rows, `openInAdmin()` = `localStorage.setItem("admin.activeClientId", id)` + `navigate(...)`. We clone it for pending clients → `/admin/review`.
- `clients_select` RLS = `is_admin OR user_client_ids` (not status-filtered) → the agency reads pending rows via the **authed browser supabase** (agency-view LOCKED contract: no service-role). ✓
- A pending client flips to `active` from `/admin/review` (C-3c-2b) → it drops out of this queue on the next poll/refetch.

## No schema / fn-contract change
Two UI files; browser `is_admin` RLS reads; no service-role, no new fn, no migration.

---

# PROMPT C-3c-2c — paste into Lovable

> **App-layer / UI only. NO migration, NO schema/fn-contract change, NO service-role.** Add an "Onboarding" pending-clients queue + badge to the agency view, mirroring the existing Pending (tickets) tab. Report files changed + confirm no migration.

## File 1: `src/routes/_authenticated/agency.tsx` — add the badge count + tab
1. Add an icon to the existing `lucide-react` import (e.g. `UserPlus`).
2. Add a second count query alongside the existing `pendingCount` query (same 15s poll, gated on `isAgencyAdmin`):
```tsx
const { data: onboardingCount } = useQuery({
  queryKey: ["agency-onboarding-count"],
  enabled: !!isAgencyAdmin,
  refetchInterval: 15000,
  queryFn: async () => {
    const { count, error } = await supabase
      .from("clients")
      .select("id", { count: "exact", head: true })
      .eq("status", "pending")
      .is("deleted_at", null);
    if (error) throw error;
    return count ?? 0;
  },
});
```
3. Add the tab to the `tabs` array (between Pending and Payment Access):
```tsx
{ to: "/agency/onboarding", label: "Onboarding", icon: UserPlus, exact: false, badge: onboardingCount ?? 0 },
```
(The existing nav already renders `badge > 0`.)

## File 2 (NEW): `src/routes/_authenticated/agency.onboarding.tsx` — the queue
Clone the `agency.index.tsx` pattern for pending clients; "Open" routes into the per-client Review & Finalize console.
```tsx
import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";

export const Route = createFileRoute("/_authenticated/agency/onboarding")({
  head: () => ({ meta: [{ title: "Agency · Onboarding" }] }),
  component: AgencyOnboarding,
});

type Row = { id: string; slug: string; business_name: string | null; created_at: string | null };

function relTime(iso: string | null): string {
  if (!iso) return "";
  const diff = Date.now() - new Date(iso).getTime();
  const s = Math.floor(diff / 1000);
  if (s < 60) return `${s}s ago`;
  const m = Math.floor(s / 60); if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60); if (h < 24) return `${h}h ago`;
  return `${Math.floor(h / 24)}d ago`;
}

function AgencyOnboarding() {
  const navigate = useNavigate();
  const { data: pending, isLoading, error } = useQuery({
    queryKey: ["agency-onboarding"],
    refetchInterval: 15000,
    queryFn: async () => {
      const { data, error } = await supabase
        .from("clients")
        .select("id, slug, business_name, created_at")
        .eq("status", "pending")
        .is("deleted_at", null)
        .order("created_at", { ascending: false });
      if (error) throw error;
      return (data ?? []) as Row[];
    },
  });

  function openReview(clientId: string) {
    window.localStorage.setItem("admin.activeClientId", clientId);
    navigate({ to: "/admin/review" });
  }

  return (
    <div className="p-6 space-y-4 max-w-5xl mx-auto">
      <div>
        <h1 className="text-xl font-semibold">Onboarding</h1>
        <p className="text-sm text-muted-foreground">
          New client submissions awaiting review &amp; invite (status <code>pending</code>) across all clients.
        </p>
      </div>

      {isLoading && <div className="text-sm text-muted-foreground">Loading…</div>}
      {error && <div className="text-sm text-destructive">{(error as Error).message}</div>}

      {!isLoading && pending && pending.length === 0 && (
        <div className="rounded-xl border bg-muted/30 p-8 text-center text-sm text-muted-foreground">
          No pending onboardings. All caught up.
        </div>
      )}

      <ul className="space-y-2">
        {(pending ?? []).map((c) => (
          <li key={c.id} className="flex items-center gap-3 rounded-xl border bg-card p-3">
            <div className="min-w-0 flex-1">
              <div className="text-sm font-medium truncate">{c.business_name ?? "Unnamed client"}</div>
              <div className="text-sm text-muted-foreground truncate">{c.slug}</div>
              <div className="text-xs text-muted-foreground mt-0.5">submitted {relTime(c.created_at)}</div>
            </div>
            <Button size="sm" onClick={() => openReview(c.id)}>Open</Button>
          </li>
        ))}
      </ul>
    </div>
  );
}
```
*(If `created_at` isn't selectable on `clients`, order by `business_name` ascending and drop the "submitted …" line.)*

## Drift check (report back)
1. `agency.tsx` (icon import + `onboardingCount` query + Onboarding tab) + NEW `agency.onboarding.tsx`.
2. **No migration, no schema change, no fn-contract change, no service-role** — browser `is_admin` RLS reads only (agency-view contract).
3. `tsc` passes.

---

# VALIDATION — C-3c-2c (as `itsmikeymiami`)

1. **Queue surfaces pending:** create a client via the wizard (lands `pending`). Go to `/agency` → the **Onboarding** tab shows it; the **badge** count includes it; 15s poll.
2. **Open routes to review:** click **Open** → lands on `/admin/review` with that client active (status pill `pending`, submission viewer + Finalize & Invite present).
3. **Finalize removes it:** click Finalize & Invite (activates) → within ~15s the client **drops off** the Onboarding queue and the **badge decrements** (it's now `active`).
4. **Only pending shows:** active clients never appear in the Onboarding queue.
5. **Authz:** a `client_owner` hitting `/agency` still sees "Not authorized" (existing shell gate); confirm no service-role used.

**Pass:** pending clients appear in `/agency` → Onboarding with a live badge; Open → `/admin/review`; finalize drops them from the queue; only pending listed; authed-RLS only. Cleanup: delete the test client + auth user.

### After C-3c-2c is green
→ **C-3c is COMPLETE** (the full agency review → finalize/invite lifecycle for pending clients). Next: **C-3d** (client-facing capture — one-time token, public route, mode-aware wizard, upload proxy, public submit → pending-create → notify) which feeds this queue.

---
**App-layer / UI only. No schema, no fn-contract change, no service-role. Mirrors C-1: pending-clients queue + badge in /agency, Open → /admin/review.**
