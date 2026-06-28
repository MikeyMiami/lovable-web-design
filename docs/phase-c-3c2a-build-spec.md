# Phase C — C-3c-2a: pending model + pending→active flip

> First C-3c-2 slice. **App-layer only — NO schema, NO migration, NO fn-contract change.** `clients.status` is free text (`text NOT NULL DEFAULT 'active'`, no CHECK/enum — verified), so `'pending'` is zero-schema. Held for review before Lovable. Verified against `cloud-spark-setup` `origin/main` @ `0015450`.

## Scope
- `createClientFull` inserts **`status='pending'`** → every wizard-created client (agency self-fill AND, later, client-submit) starts pending (dormant: no automations, not anon-visible).
- Extend the **existing C-3c-1 Finalize & Invite mutation** (in `admin.settings.tsx`) to flip **pending→active** via a direct-RLS `clients.update({status:'active'})` right after the successful `provisionClientOwner` invite. **No new button, no new fn, no duplicate logic** — same mutation.

Touches `onboarding.functions.ts` + the C-3c-1 mutation only. **No new route** (that's C-3c-2b).

## Why zero-schema / no fn-contract change
- `clients.status` = free text, default `'active'`, **no CHECK/enum** → `'pending'` is a valid value with no migration. The `status='active'` allowlist filters (`clients_anon_select` RLS, `get_client_public`, the enrollment-claim fn) **auto-exclude** pending → dormant by construction.
- `clients_select` (authenticated) is `is_admin OR user_client_ids` (not status-filtered) → the agency still sees + selects pending clients in `/admin`. `clients_update` is `is_admin`-gated → the flip is allowed via the authed browser client.
- `createClientFull`'s **signature/input/output are unchanged** — only the inserted `status` value changes (app-layer behavior).

---

# PROMPT C-3c-2a — paste into Lovable

> **App-layer only. NO migration, NO schema/fn-contract change.** Two edits: (1) `createClientFull` inserts `status='pending'`; (2) extend the existing Finalize & Invite mutation to flip `pending→active` on invite. Report files changed + confirm no migration.

## Edit 1: `src/lib/clients/onboarding.functions.ts` — create as pending
In `createClientFull`'s handler, the `clients` insert currently is:
```ts
const insert: Record<string, unknown> = { slug: data.slug, business_name: data.fields.businessName, ...clientPatch(data.fields) };
```
Add an explicit `status: "pending"`:
```ts
const insert: Record<string, unknown> = {
  slug: data.slug,
  business_name: data.fields.businessName,
  status: "pending",                // C-3c-2: wizard creates start pending; activated by Finalize & Invite
  ...clientPatch(data.fields),
};
```
(`clientPatch` does not set `status`, so this is the authoritative value. No other change — `send_settings` upsert + submission JSON write stay as-is. `status` is free text; no migration.)

## Edit 2: `src/routes/_authenticated/admin.settings.tsx` — flip pending→active on invite
Extend the EXISTING `invite` mutation (from C-3c-1) — after the successful `provisionClientOwner` call, flip the client to active via the page's existing authed browser `supabase` client (the `clients_update` RLS allows `is_admin`). Do NOT add a second button or a new fn.
```ts
const invite = useMutation({
  mutationFn: async () => {
    const email = notificationEmail.trim();
    if (!email) throw new Error("Set the notification recipient email first.");
    const res = await provisionClientOwner({
      data: { clientId, email, reason: "C-3c finalize/invite" },
    });
    // C-3c-2a: finalize → activate the client (pending → active). Idempotent for already-active.
    const { error } = await supabase.from("clients").update({ status: "active" }).eq("id", clientId);
    if (error) throw error;
    return res;
  },
  onSuccess: (res: any) => {
    toast.success(res?.invited ? `Invited ${notificationEmail.trim()} — client activated` : `Existing user — client_owner granted; client activated`);
    onSaved(); // refresh the loaded client so status reflects active
  },
  onError: (e: Error) => toast.error(e.message),
});
```
(`supabase`, `clientId`, `notificationEmail`, `onSaved` all already exist on the page. The invite stays idempotent; the activate is a plain set-to-active — a no-op if already active.)

## Drift check (report back)
1. `onboarding.functions.ts` (insert `status:"pending"`) + `admin.settings.tsx` (the existing invite mutation gains the activate step).
2. **No migration, no schema change, no fn-contract change** (`createClientFull` signature unchanged; `provisionClientOwner` untouched; `status` is free text).
3. No new route, no new button, no duplicate invite logic.
4. `tsc` passes.

---

# VALIDATION — C-3c-2a (as `itsmikeymiami`)

### Part A — wizard create lands PENDING + dormant
Create a client via the wizard (slug `pending-test`). Then:
```sql
-- created pending
select slug, status from public.clients where slug = 'pending-test';
-- EXPECT status = 'pending'.

-- dormant: not visible to the public projection (anon allowlist is status='active')
select public.get_client_public('pending-test');
-- EXPECT: no row / null (pending is excluded).

-- dormant: not eligible for automations (claim filters status='active')
-- (a pending client with an active enrollment would NOT be claimed — status gate)
```
Also confirm the pending client **still appears in the `/admin` client selector** (admin reads it via `is_admin` RLS) so the agency can finalize it.

### Part B — Finalize & Invite flips to ACTIVE + role grant still works
Open `/admin` for `pending-test`, set the notification email, click **Finalize & Invite** → confirm. Then:
```sql
-- flipped to active
select status from public.clients where slug = 'pending-test';
-- EXPECT status = 'active'.

-- role grant still works (C-3c-1 behavior intact)
select ur.role from public.user_roles ur
join auth.users u on u.id = ur.user_id
where u.email = '<the notification email>'
  and ur.client_id = (select id from public.clients where slug='pending-test');
-- EXPECT role = 'client_owner'.

select actor_source, action, target_role from public.audit_log
where client_id = (select id from public.clients where slug='pending-test')
order by created_at desc limit 3;
-- EXPECT a client_owner grant, actor_source='fn'.

-- now anon-visible (active)
select public.get_client_public('pending-test');
-- EXPECT: a row (now active).
```

### Part C — existing active clients untouched (no backfill)
```sql
select slug, status from public.clients where status = 'active' and slug <> 'pending-test' limit 5;
-- EXPECT: pre-existing clients still 'active' (we only changed NEW creates).
```

**Pass:** wizard create = `pending` + dormant (no anon projection, no automation eligibility) but admin-selectable; Finalize & Invite flips to `active` AND still grants `client_owner` (audited); existing actives unchanged; no schema/fn-contract change. Cleanup: `delete from public.clients where slug='pending-test';` + remove the test auth user via the dashboard.

### After C-3c-2a is green
→ **C-3c-2b** (pre-gen console `/admin/review` + immutable submission viewer; extract the shared `<FinalizeInvite/>` and embed it there).

---
**App-layer only. No schema (status is free text), no fn-contract change. Unified lifecycle: wizard creates start pending; the existing Finalize & Invite activates them — no duplicate logic.**
