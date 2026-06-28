# Phase B-design — Prompt 2 (client PWA) — Lovable build prompts + validation

> Slice 1 (write boundary) is DONE + validated 2026-06-20. This is **Slice 2 — the client PWA surfaces** — **BUILT + verified 2026-06-20 (2a shell + 2b ticket surfaces both live; upload helper renamed to `ticket-upload.ts` — Lovable SSR strips `*.client.*`)**. **Additive app-layer frontend only — NO migration, NO server-fn changes** (the 5 fns from Slice 1 are consumed as-is). Baseline stays `golden-master-v1.7`. Sub-sliced to de-risk the nav relocation:
> - **PROMPT 2a** — shell: nav restructure (Stats=Home · 3 bottom tabs · ☰ menu · back-arrow) + payment-gate intercept + read-only **Account** + Edit/Support **placeholders**. Verify, then →
> - **PROMPT 2b** — the ticket surfaces: real **Edit** + **Support** views (lists + composer + threads), client-side `client-assets` upload, the `open_ticket` Alerts deep-link.
>
> **Manual-validation prereq (both):** the test users were purged after Slice 1. Re-provision a client login to exercise the PWA — create `pbd-owner-a@example.com` (auto-confirm), `insert into user_roles(user_id, role, client_id) values('<OWNER_A>','client_owner','aaaaaaaa-0000-0000-0000-00000000000a')`, and confirm TestCo A is `status='active'`/`deleted_at null`. Purge again after Slice 2.

---

# PROMPT 2a — paste into Lovable (client PWA shell)

> **Build scope: app-layer frontend only. NO migration, NO database change, NO server-fn change.** Modify the listed routes + add the new ones. When done, report the files changed/added and confirm no migration was generated and no server fn / table / RLS was touched.

We are restructuring the client PWA shell (the `_authenticated/app` route group) and adding the payment-gate intercept + a read-only Account view. **Locked nav model:**
- **Stats = Home** — the app lands on Stats at `/app` (Stats is NOT a bottom-nav tab anymore).
- **Bottom nav = 3 tabs:** Inbox (`/app/inbox`) · Review (`/app/review`) · Alerts (`/app/notifications`).
- **Top-right hamburger (☰) menu = 3 entries:** Account (`/app/account`) · Request an Edit (`/app/edit`) · Support (`/app/support`).
- **Top-left back arrow** on every non-Home view → navigates to `/app` (Home).

### Files
| File | Change |
|---|---|
| `src/routes/_authenticated/app.tsx` | Shell restructure (below): client-row query → payment-gate intercept; top bar (back-arrow + ☰ menu); bottom 3-tab nav; `<Outlet/>`. |
| `src/routes/_authenticated/app.index.tsx` | Becomes the **Stats / Dashboard Home** — move the existing Dashboard content here (from `app.dashboard.tsx`). |
| `src/routes/_authenticated/app.inbox.tsx` (NEW) | **Conversations (Inbox)** — move the existing content from the former `app.index.tsx` verbatim (keep its 15s list / 10s thread polling + the sessionStorage deep-link handoff). |
| `src/routes/_authenticated/app.dashboard.tsx` | **Remove** (content moved to `app.index.tsx`). If anything routes to `/app/dashboard`, redirect it to `/app`. |
| `src/routes/_authenticated/app.notifications.tsx` | Repoint the existing `open_conversation` deep-link target from `/app` → **`/app/inbox`** (the Conversations route moved). No other change in 2a. |
| `src/routes/_authenticated/app.account.tsx` (NEW) | **Read-only Account** (below). |
| `src/routes/_authenticated/app.edit.tsx` (NEW, placeholder) | A simple card: "Request an Edit — coming in the next step." (2b replaces it.) |
| `src/routes/_authenticated/app.support.tsx` (NEW, placeholder) | A simple card: "Support — coming in the next step." (2b replaces it.) |

### Shell — `app.tsx` (payment-gate intercept + nav)
Load the logged-in client's row once (RLS returns only their own row via `clients_select`) and use it for the gate + header. **Do NOT use the service-role client anywhere in the PWA** — only the RLS-scoped browser `supabase`.
```tsx
const { data: client } = useQuery({
  queryKey: ["app-client"],
  queryFn: async () => {
    const { data, error } = await supabase
      .from("clients")
      .select("id, business_name, logo_url, access_suspended")
      .limit(1).maybeSingle();          // RLS → only this client_owner's row
    if (error) throw error;
    return data;
  },
  staleTime: 30_000,
});

// PAYMENT-GATE INTERCEPT — render the gate INSTEAD OF nav/menu/Outlet.
if (client?.access_suspended) {
  return (
    <div style={{ minHeight: "100dvh", display: "grid", placeItems: "center", padding: 24, textAlign: "center" }}>
      <div style={{ maxWidth: 420 }}>
        {client.logo_url ? <img src={client.logo_url} alt="" style={{ height: 48, margin: "0 auto 16px" }} /> : null}
        <h1 style={{ fontSize: 18, marginBottom: 8 }}>{client.business_name}</h1>
        <p>There was an issue with your payment method. Please correct to regain access to your mobile app.</p>
      </div>
    </div>
  );
}
```
Otherwise render the normal shell:
- **Top bar:** left = a back-arrow button shown only when the current path ≠ `/app`, which navigates to `/app`; right = a ☰ button opening a menu/sheet with the 3 MENU links.
- **`<Outlet/>`** in the middle.
- **Bottom nav:** 3 equal items (Inbox / Review / Alerts) — a 3-col grid (replaces the old 4-col TABS).
```tsx
const BOTTOM_TABS = [
  { to: "/app/inbox", label: "Inbox", icon: MessageSquare },
  { to: "/app/review", label: "Review", icon: Send },
  { to: "/app/notifications", label: "Alerts", icon: Bell },
] as const;
const MENU = [
  { to: "/app/account", label: "Account" },
  { to: "/app/edit", label: "Request an Edit" },
  { to: "/app/support", label: "Support" },
] as const;
```

### Read-only Account — `app.account.tsx`
Read the client's own row via the RLS-scoped `supabase` (same source the agency sees in admin-view — `clients` + `template_vars`). **Display only — NO inputs, NO writes, NO mutations.** Sections:
- **Business identity:** `business_name`, `tagline`, `address`, `phone_display`, `email`, `service_area`, `hours`.
- **Branding:** `logo_url` (preview), `brand_color` (+ `template_vars.brand_secondary`/`brand_tertiary`) as read-only swatches.
- **Links:** `review_link`, `template_vars.company_website_link`, `social_links`.
- A **"Request a change"** button → navigates to `/app/edit`. (No other action.)
```tsx
const { data: c } = useQuery({
  queryKey: ["account-client"],
  queryFn: async () => {
    const { data, error } = await supabase
      .from("clients")
      .select("business_name, tagline, address, phone_display, email, service_area, hours, logo_url, brand_color, review_link, social_links, template_vars")
      .limit(1).maybeSingle();
    if (error) throw error;
    return data;
  },
});
```

### Drift check (report back)
1. Changed: `app.tsx`, `app.index.tsx`, `app.notifications.tsx`; removed `app.dashboard.tsx`; added `app.inbox.tsx`, `app.account.tsx`, `app.edit.tsx`, `app.support.tsx`.
2. No migration; no server-fn / table / RLS / enum / trigger change; service-role client NOT used in the PWA.
3. Build compiles; the relocated Inbox + Stats render the same data as before.

### Validate 2a (manual, logged in as the test client_owner)
- App opens on **Stats (Home)** at `/app`; the 3 bottom tabs + ☰ menu route correctly; back-arrow returns to Home from every view; Inbox + Review + Alerts still work; Account renders read-only with a working "Request a change" → `/app/edit`.
- **Payment-gate (§10 step 6):** toggle TestCo A suspended, then reload the PWA as the client.
  ```sql
  -- service-role (SQL editor) — the guard trigger allows service-role/admin:
  update public.clients set access_suspended = true  where id = 'aaaaaaaa-0000-0000-0000-00000000000a';  -- gate appears
  update public.clients set access_suspended = false where id = 'aaaaaaaa-0000-0000-0000-00000000000a';  -- access returns
  ```
  Confirm: suspended → full-screen message, no nav/tabs/menu; restored → normal shell. (Agency/admin surfaces unaffected; not gated.)

---

# PROMPT 2b — paste into Lovable AFTER 2a verifies (the ticket surfaces)

> **Build scope: app-layer frontend only. NO migration, NO server-fn change** (consume the Slice-1 fns). Replace the two placeholder routes + extend Alerts. Report files changed + no-migration confirmation.

### Files
| File | Change |
|---|---|
| `src/routes/_authenticated/app.edit.tsx` | Replace placeholder with the **Request-an-Edit** surface (`kind='edit_request'`). |
| `src/routes/_authenticated/app.support.tsx` | Replace placeholder with the **Support** surface (`kind='support'`). |
| `src/routes/_authenticated/app.notifications.tsx` | Add an **`open_ticket`** branch to the action renderer (alongside `auto_enroll`/`open_conversation`). |
| `src/lib/tickets/ticket-upload.ts` (NEW, optional) | Small client-side helper: upload to `client-assets` then call `recordTicketAttachment`. |

### Each ticket surface (Edit and Support share one pattern; only `kind` + labels differ)
Reads via the RLS-scoped browser `supabase` (tenant_read returns only this client's tickets); writes via the Slice-1 server fns. Get `clientId` from the client row (`supabase.from('clients').select('id').limit(1).maybeSingle()`).
- **List view** — this client's tickets of that `kind`, newest by `last_message_at`, with a status badge. Poll **15s** (`refetchInterval: 15000`). A "New request" / "New message" button opens the composer.
- **Composer (new ticket)** — subject + body (+ optional attachments) → `openTicket({ data: { clientId, kind, subject, body } })`; then for each file run the upload helper against the returned `ticketId`.
- **Thread view** — messages as **bubbles** (reuse the Conversations style; `sender_side==='agency'` one side, `'client'` the other), attachments as download links (signed URL from `client-assets`), and a **pinned resolution banner** when `status ∈ {approved, denied, resolved}` showing `resolution`. Poll **10s**. A reply composer → `postClientMessage({ data: { ticketId, body } })` (the fn reopens a resolved/closed ticket automatically). Attachments via the helper.
- **Support history** — within the Support surface, a `resolved`/`closed` filter renders those threads read-only.
- **Status display:** show the human label (Open / In progress / Approved / Denied / Resolved / Closed). The client never sets status — that's agency-only (Prompt 3 admin UI).

### Upload helper — `ticket-upload.ts`
```ts
import { supabase } from "@/integrations/supabase/client";
import { recordTicketAttachment } from "@/lib/tickets/tickets.functions";

const MAX = 25 * 1024 * 1024;
const okMime = (t: string) => t.startsWith("image/") || t === "application/pdf" || ["video/mp4","video/quicktime","video/webm"].includes(t);

export async function uploadTicketFile(clientId: string, ticketId: string, file: File) {
  if (!okMime(file.type)) throw new Error("Unsupported file type");      // layer 2 (client-side)
  if (file.size > MAX) throw new Error("File exceeds 25MB");
  const path = `${clientId}/tickets/${ticketId}/${crypto.randomUUID()}-${file.name}`;
  const up = await supabase.storage.from("client-assets").upload(path, file, { upsert: false });
  if (up.error) throw up.error;
  await recordTicketAttachment({ data: { ticketId, storagePath: path, fileName: file.name, contentType: file.type, sizeBytes: file.size } });
  return path;
}
```

### Alerts `open_ticket` action (in `app.notifications.tsx`)
The Slice-1 notifications carry `action: { open_ticket: true, ticket_id, kind }`. Add a branch: render an **"Open"** button that navigates to `/app/edit` (kind `edit_request`) or `/app/support` (kind `support`) and deep-links to that thread — reuse the sessionStorage handoff pattern already used by `open_conversation`.

### Config prerequisite (before testing uploads) — DONE 2026-06-20
Bucket `client-assets` `file_size_limit = 26214400` (25 MB), set via SQL on `storage.buckets` (layer 1 = size only). **MIME is enforced at the app layer** — the `ticket-upload.ts` helper (layer 2) + `recordTicketAttachment` (layer 3) — **NOT a bucket-wide `allowed_mime_types` list** (that would break existing logo/asset uploads). Chosen approach: **size cap at the bucket, MIME at the app layers.**

### Validate 2b (manual, as the test client_owner)
- Create an edit request + attach an image → ticket appears in the list; the attachment registers (a `ticket_attachments` row + a `client-assets` object under `<clientId>/tickets/<ticketId>/`). A `>25 MB` or disallowed type is rejected client-side.
- Open a thread → bubbles render; posting a follow-up appends a `client` message.
- An `open_ticket` Alerts entry deep-links into the right thread.
- *(Full client-sees-agency-reply + approve/deny-with-resolution e2e = §10 step 7, exercised once the Prompt 3 admin surfaces exist.)*

---
**App-layer only. No migration (2a or 2b). Baseline `golden-master-v1.7` unchanged. Sequence: 2a → verify shell + gate → 2b → verify ticket surfaces → Prompt 3 (admin per-client surfaces).**
