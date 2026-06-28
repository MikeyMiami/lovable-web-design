# Phase C — C-3c-1: Finalize & Invite + Remix handoff checklist (per-client /admin)

> First C-3c slice. **App-layer / UI only — NO schema, NO migration, NO fn-contract change** (`provisionClientOwner` already exists and is reused as-is). Held for review before Lovable. Verified against `cloud-spark-setup` `origin/main` @ `6d48672`.

## Scope (confirmed)
On the per-client `/admin` surface, add a **Finalize & Invite** action that:
1. shows the **Remix handoff checklist** (slug, `VITE_CLIENT_SLUG`, `allowed_origins`, matched `site_style`) — read-only, from the loaded client row;
2. **mints the client login** via `provisionClientOwner({ clientId, email })` using the **Business notification email**.

Operates on **today's active clients** (testable now). The pending→active flip + pending-review queue are **C-3c-2** (deferred, with the pending-status model). Invite is **manual** (agency clicks the button).

## Verified facts (no code change to these)
- `provisionClientOwner` (`src/lib/auth/provisioning.functions.ts`): `createServerFn` POST, `.middleware([requireSupabaseAuth])`, admin/`agency_owner`-gated, input `{ email, clientId, reason? }`, returns `{ ok, userId, invited }`. Idempotent: if the email already has an auth user it resolves the id and still grants the role (`invited:false`). Grant is audited (`assign_user_role_audited` → `audit_log`, `actor_source='fn'`). Invite redirect = `VITE_INVITE_REDIRECT_URL` (env).
- `admin.settings.tsx` `ClientRow` already includes `slug`, `allowed_origins: string[]`, `site_style`, `notification_email`, `email`. The page already derives `notificationEmail = client.notification_email ?? client.email` into state. Server fns are callable from the authed admin page exactly as in `onboard-harness.tsx` (`fn({ data: {...} })`).

## Config prereqs (NOT code — flag, don't block testing)
- `VITE_INVITE_REDIRECT_URL` → the client-PWA set-password route (until set, the invite magic link uses the default redirect).
- Custom SMTP on Supabase Auth (default invite lands in spam).
Both are carried launch items; the invite still creates the auth user + grants the role without them, so C-3c-1 is testable now.

---

# PROMPT C-3c-1 — paste into Lovable

> **App-layer / UI only. NO migration, NO schema/fn-contract change.** Add a "Finalize & Invite" section to the per-client Settings page that shows the Remix handoff checklist and calls the EXISTING `provisionClientOwner` server fn. Report files changed + confirm no migration / no fn change.

## File: `src/routes/_authenticated/admin.settings.tsx`

### 1. Import the existing server fn (top of file)
```tsx
import { provisionClientOwner } from "@/lib/auth/provisioning.functions";
```

### 2. Add an invite mutation (alongside the existing `saveClient` / `saveSend` mutations in `SettingsForm`)
```tsx
const invite = useMutation({
  mutationFn: async () => {
    const email = notificationEmail.trim();
    if (!email) throw new Error("Set the notification recipient email first.");
    // Same call pattern as the validated onboard-harness fns (auth token is carried by the authed admin session).
    return await provisionClientOwner({
      data: { clientId, email, reason: "C-3c finalize/invite" },
    });
  },
  onSuccess: (res: any) => {
    toast.success(res?.invited ? `Invite sent to ${notificationEmail.trim()}` : `Existing user — client_owner granted (${notificationEmail.trim()})`);
  },
  onError: (e: Error) => toast.error(e.message),
});
```

### 3. Add the "Finalize & Invite" Section (place it LAST, after "Marketing Domains" — the finalize step after config)
```tsx
{/* ───── Finalize & Invite (launch handoff) ───── */}
<Section
  title="Finalize & Invite"
  hint="Once the config above is set, invite the client owner and use the handoff checklist to spin up their marketing-site Remix."
>
  {/* Remix handoff checklist — read-only, from the loaded client row */}
  <div className="rounded-md border bg-muted/30 p-3 space-y-1.5 text-sm">
    <div className="font-medium text-xs text-muted-foreground">Remix handoff checklist</div>
    <div className="flex gap-2"><span className="w-40 text-muted-foreground">Client slug</span><code>{client.slug}</code></div>
    <div className="flex gap-2"><span className="w-40 text-muted-foreground">VITE_CLIENT_SLUG</span><code>{client.slug}</code></div>
    <div className="flex gap-2"><span className="w-40 text-muted-foreground">Site style template</span>
      <span>{client.site_style ? client.site_style : <span className="text-muted-foreground italic">not set</span>}</span>
    </div>
    <div className="flex gap-2">
      <span className="w-40 text-muted-foreground">allowed_origins</span>
      <span className="break-all">
        {(client.allowed_origins ?? []).length
          ? (client.allowed_origins ?? []).join(", ")
          : <span className="text-muted-foreground italic">none set — add the client's domain(s) in Marketing Domains above</span>}
      </span>
    </div>
  </div>

  {/* Invite */}
  <Field
    label="Invite the client owner"
    hint="Sends a Supabase invite to the notification recipient email (set in Template Variables above) and grants the client_owner role. Idempotent — safe to re-run."
  >
    <div className="flex items-center gap-3">
      <span className="text-sm">
        {notificationEmail.trim()
          ? <>Invite will be sent to <code>{notificationEmail.trim()}</code></>
          : <span className="text-destructive">Set the notification recipient email first (Template Variables section).</span>}
      </span>
      <Button
        size="sm"
        disabled={!notificationEmail.trim() || invite.isPending}
        onClick={() => {
          if (window.confirm(`Send a login invite to ${notificationEmail.trim()} and grant client_owner for "${client.business_name}"?`)) {
            invite.mutate();
          }
        }}
      >
        {invite.isPending ? "Inviting…" : "Finalize & Invite"}
      </Button>
    </div>
  </Field>
  {!import.meta.env.VITE_INVITE_REDIRECT_URL && (
    <p className="text-[11px] text-amber-700 dark:text-amber-300">
      Note: VITE_INVITE_REDIRECT_URL is not set — the invite link will use the default redirect until the client-PWA set-password route is configured.
    </p>
  )}
</Section>
```

### Notes / guardrails
- **Reuse `provisionClientOwner` exactly** — do NOT add a new server fn, migration, or schema. The fn is admin-gated server-side; the button just calls it.
- The invite email = the page's existing `notificationEmail` (`client.notification_email ?? client.email`). No new field.
- `window.confirm` guard because this sends a real email (outward-facing). Keep it.
- Do not touch the other sections, the assembly, or any save path.

## Drift check (report back)
1. `admin.settings.tsx` only (import + `invite` mutation + one new Section).
2. **No migration, no schema change, no fn-contract change** — `provisionClientOwner` reused as-is.
3. Build compiles; the handoff checklist renders from the client row; the button calls `provisionClientOwner`.

---

# VALIDATION — C-3c-1 (as `itsmikeymiami`)

Pick an existing **active** test client with a notification email set (or set one in the Template Variables section first).

1. Open `/admin` → Settings → **Finalize & Invite**:
   - Handoff checklist shows the correct **slug**, **VITE_CLIENT_SLUG** (= slug), **site_style**, and **allowed_origins** (or the "none set" hint).
   - "Invite will be sent to <email>" shows the notification email; button disabled if blank.
2. Click **Finalize & Invite** → confirm → success toast. Then verify:
```sql
-- role granted (client_owner) for this client
select ur.role, ur.client_id
from public.user_roles ur
join auth.users u on u.id = ur.user_id
where u.email = '<the notification email>' and ur.client_id = '<clientId>';
-- EXPECT: one row, role='client_owner'.

-- audited grant (actor_source='fn')
select actor_source, action, target_role, client_id
from public.audit_log
where client_id = '<clientId>'
order by created_at desc limit 3;
-- EXPECT: a client_owner grant row, actor_source='fn'.

-- auth user exists (invited)
select email, invited_at from auth.users where email = '<the notification email>';
```
3. **Idempotency:** click again with the same email → success toast reads "Existing user — client_owner granted"; no crash; no duplicate-role error.
4. **Authz sanity:** the fn is admin-gated server-side (a non-admin can't call it) — no UI test needed, but confirm no service-role key is used in the page.

**Pass:** handoff checklist correct; invite creates the auth user + grants `client_owner` (audited, `actor_source='fn'`); idempotent re-run; no schema/fn change. Cleanup: remove the test auth user + role grant via the Supabase dashboard if desired.

### After C-3c-1 is green
→ **C-3c-2** (pending-status model `status='pending'` + the pre-gen console / immutable submission viewer + the agency pending-review queue; the pending→active flip folds into the Finalize & Invite action here).

---
**App-layer / UI only. No schema, no fn-contract change — `provisionClientOwner` reused. Config prereqs (VITE_INVITE_REDIRECT_URL + SMTP) flagged, don't block testing.**
