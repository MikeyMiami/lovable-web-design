# Phase C — C-3c-2b: /admin/review console + immutable submission viewer + shared <FinalizeInvite/>

> Second C-3c-2 slice. **App-layer / UI only — NO schema, NO migration, NO fn-contract change, NO service-role.** Held for review. Verified against `cloud-spark-setup` `origin/main` @ `c036120`.

## Scope (lean v1)
1. **Extract `<FinalizeInvite/>`** from `admin.settings.tsx` into a shared component (single source — no duplicate invite/activate logic), embedded in BOTH Settings and the new console.
2. **New `/admin/review` console** (per-client, active-client scoped): a read-only **immutable submission viewer** (the raw `{clientId}/onboarding-submission.json`) + a link to editable Settings + the embedded `<FinalizeInvite/>`.
3. Add the **Review tab** to the `/admin` nav.

## Verified facts
- Finalize & Invite (Section + `invite` mutation) currently lives inline in `admin.settings.tsx` (C-3c-1 + the C-3c-2a activate flip). Extracting it is a move, not a rewrite.
- `/admin` shell: `TABS` array (`admin.tsx:31`), `useActiveClient`/`ActiveClientProvider`, `fetchAdminBootstrap` lists clients `WHERE deleted_at IS NULL` (not status-filtered → **pending clients already appear in the selector**). Each route is active-client scoped via React Query keys.
- Submission JSON read: `supabase.storage.from("client-assets").createSignedUrl(path, 300)` / `.download(path)` — authed admin, `is_admin` storage RLS allows it (same pattern as `AdminTicketSurface.tsx:566`). **No service-role, no new fn.**
- `provisionClientOwner` + the `clients.update({status:'active'})` flip are unchanged — just relocated into the shared component.

## No schema / fn-contract change
All UI + an existing-storage read. `provisionClientOwner` untouched; no migration; no service-role.

---

# PROMPT C-3c-2b — paste into Lovable

> **App-layer / UI only. NO migration, NO schema/fn-contract change, NO service-role.** Extract the Finalize & Invite into a shared component, add the `/admin/review` console with an immutable submission viewer, and add the Review nav tab. Report files changed + confirm no migration.

## File 1 (NEW): `src/components/admin/FinalizeInvite.tsx`
Move the existing Finalize & Invite Section + its `invite` mutation here, parameterized by the client row. Derive the invite email from `client.notification_email ?? client.email`. Keep the handoff checklist, the `window.confirm` guard, the pending→active flip, and the `VITE_INVITE_REDIRECT_URL` warning.
```tsx
import { useMutation } from "@tanstack/react-query";
import { toast } from "sonner";
import { supabase } from "@/integrations/supabase/client";
import { provisionClientOwner } from "@/lib/auth/provisioning.functions";
import { Button } from "@/components/ui/button";

type FinalizeClient = {
  id: string; slug: string; business_name: string;
  site_style: string | null; allowed_origins: string[];
  notification_email: string | null; email: string | null;
};

export function FinalizeInvite({ client, onDone }: { client: FinalizeClient; onDone?: () => void }) {
  const email = (client.notification_email ?? client.email ?? "").trim();
  const invite = useMutation({
    mutationFn: async () => {
      if (!email) throw new Error("Set the notification recipient email first.");
      const res = await provisionClientOwner({ data: { clientId: client.id, email, reason: "C-3c finalize/invite" } });
      // pending → active (idempotent for already-active)
      const { error } = await supabase.from("clients").update({ status: "active" }).eq("id", client.id);
      if (error) throw error;
      return res;
    },
    onSuccess: (res: any) => {
      toast.success(res?.invited ? `Invited ${email} — client activated` : `Existing user — client_owner granted; client activated`);
      onDone?.();
    },
    onError: (e: Error) => toast.error(e.message),
  });

  return (
    <section className="rounded-lg border bg-card p-5 space-y-4">
      <div>
        <h2 className="font-semibold">Finalize & Invite</h2>
        <p className="text-xs text-muted-foreground mt-0.5">Invite the client owner, activate the client, and use the handoff checklist to spin up their marketing-site Remix.</p>
      </div>
      <div className="rounded-md border bg-muted/30 p-3 space-y-1.5 text-sm">
        <div className="font-medium text-xs text-muted-foreground">Remix handoff checklist</div>
        <div className="flex gap-2"><span className="w-40 text-muted-foreground">Client slug</span><code>{client.slug}</code></div>
        <div className="flex gap-2"><span className="w-40 text-muted-foreground">VITE_CLIENT_SLUG</span><code>{client.slug}</code></div>
        <div className="flex gap-2"><span className="w-40 text-muted-foreground">Site style template</span><span>{client.site_style ? client.site_style : <span className="italic text-muted-foreground">not set</span>}</span></div>
        <div className="flex gap-2"><span className="w-40 text-muted-foreground">allowed_origins</span><span className="break-all">{(client.allowed_origins ?? []).length ? (client.allowed_origins ?? []).join(", ") : <span className="italic text-muted-foreground">none set</span>}</span></div>
      </div>
      <div className="flex items-center gap-3">
        <span className="text-sm">{email ? <>Invite will be sent to <code>{email}</code></> : <span className="text-destructive">Set the notification recipient email first (Settings → Template Variables).</span>}</span>
        <Button size="sm" disabled={!email || invite.isPending}
          onClick={() => { if (window.confirm(`Send a login invite to ${email} and activate "${client.business_name}"?`)) invite.mutate(); }}>
          {invite.isPending ? "Inviting…" : "Finalize & Invite"}
        </Button>
      </div>
      {!import.meta.env.VITE_INVITE_REDIRECT_URL && (
        <p className="text-[11px] text-amber-700 dark:text-amber-300">Note: VITE_INVITE_REDIRECT_URL is not set — the invite link uses the default redirect until the client-PWA set-password route is configured.</p>
      )}
    </section>
  );
}
```

## File 2: `src/routes/_authenticated/admin.settings.tsx` — use the shared component
- **Remove** the inline Finalize & Invite `<Section>` and the `invite` mutation (now in the component).
- Import and render it where the Section was: `<FinalizeInvite client={client} onDone={onSaved} />` (`client` is the loaded row; `onSaved` already exists). `client.notification_email`/`email`/`site_style`/`allowed_origins`/`slug`/`business_name`/`id` are all already on the loaded `ClientRow`.
- **Behavior note:** the component reads the **persisted** `notification_email ?? email`. Save the notification email (Template Variables section) before finalizing.

## File 3 (NEW): `src/routes/_authenticated/admin.review.tsx` — the pre-gen console
Active-client scoped (like `admin.settings.tsx`). Read the full client row + the immutable submission JSON via the authed admin; render read-only + the shared `<FinalizeInvite/>`.
```tsx
import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { useActiveClient } from "@/lib/admin-context";
import { FinalizeInvite } from "@/components/admin/FinalizeInvite";

export const Route = createFileRoute("/_authenticated/admin/review")({
  head: () => ({ meta: [{ title: "Admin · Review & Finalize" }] }),
  component: AdminReview,
});

async function fetchReview(clientId: string) {
  const { data: client, error } = await supabase
    .from("clients")
    .select("id, slug, business_name, status, site_style, allowed_origins, notification_email, email")
    .eq("id", clientId).maybeSingle();
  if (error) throw error;

  // Immutable onboarding submission (private client-assets; is_admin RLS allows the read).
  let submission: any = null;
  let submissionError: string | null = null;
  const { data: blob, error: dlErr } = await supabase.storage
    .from("client-assets").download(`${clientId}/onboarding-submission.json`);
  if (dlErr) submissionError = "No onboarding submission on file for this client.";
  else { try { submission = JSON.parse(await blob.text()); } catch { submissionError = "Submission file is not valid JSON."; } }

  return { client, submission, submissionError };
}

function AdminReview() {
  const { activeClientId } = useActiveClient();
  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ["admin", "review", activeClientId],
    queryFn: () => fetchReview(activeClientId!),
    enabled: !!activeClientId,
  });

  if (!activeClientId) return <div className="p-6 text-sm text-muted-foreground">Select a client.</div>;
  if (isLoading) return <div className="p-6 text-sm text-muted-foreground">Loading…</div>;
  if (error) return <div className="p-6 text-sm text-destructive">{(error as Error).message}</div>;
  if (!data?.client) return <div className="p-6 text-sm text-destructive">Client row missing.</div>;

  const c = data.client;
  return (
    <div className="p-6 space-y-6 max-w-4xl">
      <header className="flex items-center gap-3">
        <h1 className="text-xl font-semibold">Review & Finalize</h1>
        <span className={`text-xs rounded-full px-2 py-0.5 ${c.status === "pending" ? "bg-amber-100 text-amber-800 dark:bg-amber-950/40 dark:text-amber-300" : "bg-emerald-100 text-emerald-800 dark:bg-emerald-950/40 dark:text-emerald-300"}`}>
          {c.status}
        </span>
      </header>
      <p className="text-sm text-muted-foreground">
        Review the client's onboarding submission, adjust config in{" "}
        <Link to="/admin/settings" className="text-primary underline-offset-2 hover:underline">Settings</Link>, then Finalize & Invite.
      </p>

      <FinalizeInvite client={c} onDone={() => refetch()} />

      <section className="rounded-lg border bg-card p-5 space-y-3">
        <div>
          <h2 className="font-semibold">Onboarding submission (read-only)</h2>
          <p className="text-xs text-muted-foreground mt-0.5">The raw, as-submitted answers. Immutable record — edit config in Settings, not here.</p>
        </div>
        {data.submissionError ? (
          <p className="text-sm text-muted-foreground italic">{data.submissionError}</p>
        ) : (
          <pre className="text-xs font-mono bg-muted/40 rounded-md p-3 overflow-x-auto max-h-[480px]">
            {JSON.stringify(data.submission, null, 2)}
          </pre>
        )}
      </section>
    </div>
  );
}
```

## File 4: `src/routes/_authenticated/admin.tsx` — add the nav tab
In the `TABS` array, add (e.g. after Settings, or before it — your call), using a lucide icon already importable (e.g. `ClipboardCheck`):
```tsx
{ to: "/admin/review", label: "Review & Finalize", icon: ClipboardCheck, exact: false },
```
(Add `ClipboardCheck` to the existing `lucide-react` import.)

## Drift check (report back)
1. NEW `src/components/admin/FinalizeInvite.tsx`; `admin.settings.tsx` (inline Section + mutation → `<FinalizeInvite/>`); NEW `admin.review.tsx`; `admin.tsx` (TABS + icon import).
2. **No migration, no schema change, no fn-contract change, no service-role** (`provisionClientOwner` unchanged; submission read via authed-admin `is_admin` storage RLS).
3. Finalize & Invite is a SINGLE shared component used in both Settings and the console (no duplicate logic).
4. `tsc` passes.

---

# VALIDATION — C-3c-2b (as `itsmikeymiami`)

1. **Single-source check:** the Finalize & Invite UI appears in BOTH `/admin/settings` and `/admin/review` and is the same component (one definition).
2. **Console on a pending client:** create a client via the wizard (lands `pending`), select it in `/admin`, open **Review & Finalize**:
   - Status pill shows **pending**.
   - The **submission viewer** renders the raw `onboarding-submission.json` (pretty-printed); a client with no file shows "No onboarding submission on file."
   - Handoff checklist shows correct slug / VITE_CLIENT_SLUG / site_style / allowed_origins.
3. **Finalize from the console:** click **Finalize & Invite** → confirm → success toast; verify (same as C-3c-2a):
   ```sql
   select status from public.clients where id = '<clientId>';                 -- EXPECT 'active'
   select ur.role from public.user_roles ur join auth.users u on u.id=ur.user_id
   where u.email='<email>' and ur.client_id='<clientId>';                      -- EXPECT 'client_owner'
   ```
   The status pill flips to **active** (refetch).
4. **Finalize from Settings still works** (regression): the shared component behaves identically there.
5. **No service-role:** confirm the review route uses only the authed browser `supabase`.

**Pass:** shared `<FinalizeInvite/>` in both surfaces (single source); `/admin/review` shows status + immutable submission viewer + handoff + finalize; finalize activates + grants from either surface; graceful empty-submission; no schema/fn/service-role change. Cleanup: delete the test client + auth user.

### After C-3c-2b is green
→ **C-3c-2c** (agency Pending-onboarding queue + badge: `clients WHERE status='pending'`, mirror C-1, routes into `/admin/review`).

---
**App-layer / UI only. No schema, no fn-contract change, no service-role. Single shared `<FinalizeInvite/>`; lean console = submission viewer + Settings link + finalize.**
