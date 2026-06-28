# Phase B-design (Core) Build Spec — ticketing surfaces + the 5 write-fns + payment-gate shell

> **Status:** APPROVED — **§6 decisions LOCKED 2026-06-20; ready to hand to Lovable** (slice it per §11). **App-layer only** (server fns + frontend) on top of `golden-master-v1.7`. **No migration, no new golden-master tag** (see §0). This is **Slice 1 of Phase B-design** — the tightly-coupled feature core. The separable PWA infra (dynamic per-host manifest, service worker, hex→oklch per-client branding **port**) is **Slice 2**, spec'd separately afterward (scope noted in §9, NOT detailed here).
>
> Grounded against the real frozen clone (`C:\Users\Pierc\Desktop\cloud-spark-setup`, stale at `v1.6` but the reused patterns predate v1.7) + the v1.7 spec `docs/phase-b-backend-v1.7-build-spec.md` §4c (the write-fn authz is LOCKED there; this spec realizes it, byte-faithful). Read-only; frozen backend untouched; nothing built until approved.

---

## 0. Schema impact — NONE (app-layer only; no re-tag) — **CONFIRMED**

The feature core is **purely app-layer**. Evidence (real frozen code):
- `notifications.type` = **`text NOT NULL`** (`migrations/20260609034320…sql:478`); `events.type` = **`text`** (`:454`). New ticket-notification types + the owner-email stub are TS string literals on `text` columns → **no `ALTER TYPE`**.
- Every table/column the 5 write-fns touch already exists in v1.7: `tickets`/`ticket_messages`/`ticket_attachments` (read-only RLS + service-role write grant), `consent_records`, `clients.access_suspended`, the `client-assets` bucket. The fns make the existing tables **writable via the service-role path** — they do **not** alter schema.
- `notifications` + `events` already grant `SELECT` to `authenticated` / `ALL` to `service_role`, with tenant-scoped SELECT RLS — the exact pattern the ticket tables already use.

**Therefore:** baseline stays **`golden-master-v1.7`**. No new migration, no new golden-master tag. The work commits to the Lovable repo and is recorded via a build-log + skill mirror-lines when green. The next tag (`v1.8`) is reserved for **Phase D**'s extended A2P columns (a real schema change).

> **GUARDRAIL [catch at validation]:** this build must emit **zero migrations**. A migration in the diff = a red flag — investigate before accepting (likely Lovable over-reaching). The only DB-side prerequisite is the **`client-assets` bucket caps** config (§7), which is a **Storage-dashboard setting, not SQL**.

---

## 1. Surface / component inventory (PWA · admin-view · shared)

### Shared — the write boundary (server fns; `requireSupabaseAuth` + `supabaseAdmin`)
| File (NEW) | Contents |
|---|---|
| `src/lib/tickets/authz.ts` | The two shared helpers the §4c spec assumes but the repo **does not have yet** (role checks are currently inlined, e.g. `roles.functions.ts`): `isAdmin(callerId)` = caller has `admin`/`agency_owner` in `user_roles`; `isMemberOf(callerId, clientId)` = `clientId ∈ user_client_ids(callerId)`. Both read `user_roles` via `supabaseAdmin` (server-only). |
| `src/lib/tickets/tickets.functions.ts` | The **5 service-role write-fns** (§3): `openTicket`, `postClientMessage`, `postAgencyReply`, `setTicketStatus`, `recordTicketAttachment`. Match repo convention (`*.functions.ts`, `createServerFn`). |
| `src/lib/tickets/notify.server.ts` | Ticket notification + owner-email helper `notifyTicketEvent(...)`. Writes the in-app **`notifications`** row directly via `supabaseAdmin` (body composed inline — ticket notifications are short/dynamic and kept OUT of the automation-copy template registry; `notifications.type` is `text`, so `ticket_agency_reply`/`ticket_status_changed` need no enum change) with `action:{open_ticket,ticket_id,kind}`, AND the **owner-email stub** (`events.type='owner_email_stub'` + `resolveOwnerEmail(clientId)`, the `r/feedback.ts` pattern). Reuses `resolveOwnerEmail`; no new send infra. |

### PWA — client surfaces (`client_owner`/`client_staff`; shell `app.tsx`)
**Nav model [LOCKED — Decision N]:** **Stats is Home** (the app lands on Stats on open; it is NOT a bottom-nav tab). **Bottom nav = 3 tabs, left→right: Inbox · Review · Alerts.** **Top-right hamburger (☰) menu = 3 entries: Account · Edit · Support.** Any tab/menu view shows a **top-left back arrow** that returns to the Stats Home (Home → view → back → Home).

| File | Change |
|---|---|
| `src/routes/_authenticated/app.tsx` | Shell restructure: (a) **Home = Stats** (lands here on open). (b) **Bottom nav (3): Inbox · Review · Alerts.** (c) **Top-right ☰ menu: Account · Edit · Support.** (d) **Top-left back arrow** on every non-Home view → navigate to `/app`. (e) **Payment-gate shell intercept** (§5): read `access_suspended` from the RLS-scoped `clients` row; if `true`, render the full-screen gate **instead of** Home/nav/menu/`<Outlet/>`. |
| `src/routes/_authenticated/app.index.tsx` | Becomes the **Stats / Dashboard Home** view — **relocate the existing Dashboard content here** (the former `app.dashboard.tsx`); this is the landing view at `/app`. |
| `src/routes/_authenticated/app.inbox.tsx` (relocated) | **Conversations** (Inbox) — relocate from the former `app.index.tsx`; now reached via the bottom-nav Inbox tab at `/app/inbox`. Polling unchanged (15s list / 10s thread). |
| `src/routes/_authenticated/app.review.tsx` | **Review** — unchanged (bottom-nav tab). |
| `src/routes/_authenticated/app.notifications.tsx` | **Alerts** (bottom-nav tab). Extend the hardcoded action renderer (currently `auto_enroll` / `open_conversation`) with **`open_ticket`** → deep-link button into the relevant Edit/Support thread (§6 Decision **NS**). |
| `src/routes/_authenticated/app.account.tsx` (NEW, ☰) | **Account — READ-ONLY (v1).** Read-friendly display of the client's business info / identity from **the same source the agency sees in the per-client admin view** — the `clients` row + branding (one source of truth; **no schema change**). Client **cannot edit**. A **"Request a change"** action deep-links to the Edit (Request-an-Edit) flow (consistent with CFG — no self-serve config in v1). |
| `src/routes/_authenticated/app.edit.tsx` (NEW, ☰) | **Request-an-Edit** (Feature A, `kind='edit_request'`): list this client's edit-request tickets; "new request" composer (subject + body + **asset upload**); thread view; client posts follow-ups (`postClientMessage`) until decided; shows the agency **resolution** (approve/deny + description). |
| `src/routes/_authenticated/app.support.tsx` (NEW, ☰) | **Support** (Feature B, `kind='support'`): list support tickets; new support message; thread; client replies until agency marks **resolved**; resolved → read-only history. |

### Admin-view — per-client agency surfaces (`admin`/`agency_owner`; sidebar shell `admin.tsx`)
> Reads via the authed `supabase` client (admin JWT → `is_admin()` RLS branch); writes via the service-role fns. **Never** service-role in the admin UI (matches the `admin.tsx` contract).

| File | Change |
|---|---|
| `src/routes/_authenticated/admin.tsx` | Add `Edit Requests` + `Support` to the sidebar `TABS` array. |
| `src/routes/_authenticated/admin.edit-requests.tsx` (NEW) | Active client's edit-request tickets (pending first); open thread; **download attachments**; reply (`postAgencyReply`); **approve / deny WITH resolution** (`setTicketStatus`). |
| `src/routes/_authenticated/admin.support.tsx` (NEW) | Active client's support tickets; reply; set `in_progress` / `resolved`; **support-history = a `resolved`/`closed` filter within this route** (§6 Decision **SH**), not a separate route. |

> **Pathway reconciliation [surface]:** `pathway-to-completion.md` slotted "admin-view additions" in Phase C. Per your scope call, the **per-client** admin ticket sections move **into this core slice** — they are required to exercise + validate the agency-authority fns (`postAgencyReply`/`setTicketStatus`) end-to-end. The **cross-tenant agency-view** (pending lists spanning ALL clients, new-request flagging, routing, payment-toggle-across-clients) stays **Phase C / the new `agency-view` skill** and consumes these same 5 fns — **no rework** (§8).

---

## 2. Build order within the core
1. **`authz.ts`** — `isAdmin` / `isMemberOf` (foundation for all fns).
2. **The 5 write-fns** + `notify.server.ts` (§3).
3. **Validate the write boundary at the fn/SQL level** (§ Validation) **before any UI** — prove a client can't self-approve or spoof an agency message; prove admin-only fns reject `client_owner`.
4. **PWA surfaces** — (a) the **nav restructure** (`app.tsx` shell: Stats=Home, 3 bottom tabs, ☰ menu, back-arrow; relocate Dashboard→`app.index`, Conversations→`app.inbox`); (b) **Account** read-only view (`app.account.tsx`); (c) **Edit + Support** tabs (`app.edit.tsx` + `app.support.tsx`) → call `openTicket` / `postClientMessage` / `recordTicketAttachment` + client-side upload to `client-assets`.
5. **Admin per-client sections** (`admin.edit-requests.tsx` + `admin.support.tsx`) → call `postAgencyReply` / `setTicketStatus`.
6. **Payment-gate shell intercept** in `app.tsx` (§5).
7. **Notification + owner-email wiring** — agency reply / status change → client in-app notification (`writeNotification`) + owner-email stub (§6 Decision **NS**).
8. **End-to-end validation** + payment-gate toggle proof (§ Validation).

---

## 3. The 5 write-fns — authz contract (matches v1.7 spec §4c **exactly**)

**Invariants for ALL five:** `createServerFn({method:"POST"}).middleware([requireSupabaseAuth])` → `context.userId` = caller. Use `supabaseAdmin` for writes. **Trust fields — `sender_side` / `status` / `created_by` / `assigned_to` / `resolution` — are set AUTHORITATIVELY in the fn, NEVER read from client input.** All inputs Zod-validated. Authz via `authz.ts`.

1. **`openTicket({ clientId, kind, subject, body })` → `{ ticketId }`**
   - authz: `isAdmin(caller) || isMemberOf(caller, clientId)` else `Forbidden`. Validate `clientId` exists, `status='active'`, `deleted_at IS NULL`.
   - INSERT `tickets`: `client_id`, `kind` (enum-validated `edit_request|support`), `subject`, `status='open'`, `created_by=caller`.
   - INSERT first `ticket_messages`: `sender_side = isAdmin(caller) ? 'agency' : 'client'` (forced), `sender_user_id=caller`, `client_id=clientId`, `body`; bump `last_message_at=now()`.

2. **`postClientMessage({ ticketId, body })` → `{ messageId }`**
   - Load ticket. authz: `isMemberOf(caller, ticket.client_id)` else `Forbidden`. (Admins use `postAgencyReply`.)
   - INSERT message: `sender_side='client'` (forced), `sender_user_id=caller`, `client_id=ticket.client_id`; bump `last_message_at`. **If ticket was `resolved`/`closed`/`approved`/`denied` → reopen to `open`** (client reply reopens — explicit choice; §4).

3. **`postAgencyReply({ ticketId, body, newStatus? })` → `{ messageId }`**
   - authz: `isAdmin(caller)` **only**.
   - INSERT message: `sender_side='agency'` (forced), `sender_user_id=caller`, `client_id=ticket.client_id`; set `assigned_to=caller` if null; apply optional `newStatus` (validated against §4 per-kind lifecycle); bump `last_message_at`.
   - Fires the client notification + owner-email (§6 Decision **NS**).

4. **`setTicketStatus({ ticketId, status, resolution? })` → `{ ok }`**
   - authz: `isAdmin(caller)` **only** (approve/deny/resolve = agency authority).
   - **Per-kind validation:** `edit_request` → `approved`/`denied` **REQUIRE** `resolution` (the description returned to the client). `support` → `in_progress`/`resolved`/`closed`. Set `status`, `resolution`, and `resolved_at` when terminal.
   - Fires the client notification (§6 Decision **NS**).
   - *(A client closing their own support ticket = a future narrowly-scoped `clientCloseTicket` fn — NOT folded here; deferred, §6 Decision **TL**.)*

5. **`recordTicketAttachment({ ticketId, messageId?, storagePath, fileName, contentType, sizeBytes })` → `{ attachmentId }`**
   - authz: `isAdmin(caller) || isMemberOf(caller, ticket.client_id)`.
   - **Finding D:** if `messageId` given, verify it belongs to `ticketId` → else reject.
   - **Finding E:** verify `storagePath` starts with `<ticket.client_id>/tickets/<ticketId>/` (bucket ACL ↔ metadata coherence).
   - **Decision 5:** `contentType ∈ {image/*, application/pdf, video/mp4, video/quicktime, video/webm}` **and** `sizeBytes ≤ 25*1024*1024`; else reject.
   - INSERT `ticket_attachments` with `client_id=ticket.client_id`, `uploaded_by=caller`.
   - **Binary path:** the client uploads the file to `client-assets` at `<client_id>/tickets/<ticketId>/<uuid>-<filename>` (authed; `client_assets_rw` authorizes `folder[1] ∈ user_client_ids`), **then** calls this fn to register metadata. (No direct-to-bucket upload code exists today — net-new client-side, using the anon/authed `supabase.storage.from('client-assets').upload(...)`.)

---

## 4. Ticket-status lifecycle per kind, and how surfaces drive it

`ticket_status` enum (v1.7): `open · in_progress · approved · denied · resolved · closed`.

### `edit_request` (Feature A — agency implements manually; no auto-redeploy)
```
open ──(agency acks, optional)──▶ in_progress
  └─(agency decides, setTicketStatus, resolution REQUIRED)─▶ approved │ denied
                                                               │         │
              (agency implements in remix / admin.settings)    ▼         ▼
                                                            closed     closed
client postClientMessage on approved/denied/closed ──▶ reopens to open
```
- **approved** = accepted, will be implemented; `resolution` = what we'll do. **denied** = won't be done; `resolution` = why. Both shown to the client in-thread + as a pinned banner.
- After implementing (or after a denial is acknowledged), the agency sets **closed** to archive the instance.
- **Drives:** client = `openTicket`/`postClientMessage`; agency = `postAgencyReply` (optional `in_progress`) + `setTicketStatus` (`approved`/`denied` + resolution, then `closed`).

### `support` (Feature B — `resolved` closes the instance → support history)
```
open ──▶ in_progress ──▶ resolved  (terminal; appears in support-history)
client postClientMessage on resolved/closed ──▶ reopens to open
```
- Per the handoff: "mark **resolved** (CLOSES the instance)." `resolved` is the terminal state for support; `closed` reserved for hard-archive.
- **Drives:** client = `openTicket`/`postClientMessage`; agency = `postAgencyReply` (optional `in_progress`) + `setTicketStatus` (`in_progress`/`resolved`).

---

## 5. Payment-gate shell intercept

- **Where:** the `_authenticated/app` layout (`app.tsx`) — the shell that renders bottom-nav + `<Outlet/>`.
- **Read:** `access_suspended` from the caller's OWN `clients` row via the authed/RLS `supabase` client (`clients_select` RLS lets `client_owner` read their own row). React Query, short `staleTime`; flipping back to `false` restores access on the next refetch/navigation.
- **Render when `true`:** a single full-screen message — **NO nav, NO tabs, NO `<Outlet/>`**:
  > "There was an issue with your payment method. Please correct to regain access to your mobile app."
  - Fixed string for v1 (pathway §4b; agency-configurable text = deferred). May include the client's `business_name`/logo + a "contact us" line; keep minimal.
- **Scope [LOCKED from pathway §4]:** this is a **UX access hold, not a hard data boundary** — a suspended client's data is still RLS-theirs (they could `curl` it). v1 shell-gate is sufficient. Hard server-side denial (an `access_suspended` check inside the authed data fns) = deferred option.
- **Never gates:** the agency account + per-client admin view (agency-scoped). **Public marketing site unaffected** (anon `get_client_public` does NOT project `access_suspended`). **Automations keep running** (runner keys off `status='active' AND deleted_at IS NULL`, never `access_suspended`).

---

## 6. Design decisions — **LOCKED** (settled 2026-06-20)

**N — PWA navigation model [LOCKED]:** **Stats = Home** — the app lands on Stats on open; Stats is NO LONGER a bottom-nav tab. **Bottom nav = 3 tabs, left→right: Inbox (Conversations) · Review (Review Request) · Alerts (Notifications).** **Top-right hamburger (☰) menu = 3 entries: Account · Edit (Request-an-Edit) · Support.** **Top-left back arrow** on every non-Home view (any bottom-nav screen or ☰ view) returns to the Stats Home (Home → view → back → Home). **Account view = READ-ONLY (v1):** read-friendly display of the client's business info / identity from the **same source the agency sees in the per-client admin view** (the `clients` row + branding — one source of truth, **no schema change**); the client cannot edit; a **"Request a change"** action deep-links into the Edit flow (consistent with CFG). *(Implemented in §1: relocate Dashboard→`app.index`, Conversations→`app.inbox`, add `app.account.tsx`.)*

**CFG — Self-serve-config-edit vs Request-an-Edit split [LOCKED — no self-serve in v1]:** **ALL** client-requested changes to their marketing site / branding / business config route through **Request-an-Edit** tickets; the agency implements manually. No direct self-serve editing of any client field in v1 (a deliberate **later** expansion, not this slice). The client PWA's only **direct-write** surfaces stay the operational data they own: enrolling review-request contacts (Review tab) + replying in SMS threads (Inbox) — their CRM/comms, not site config. The read-only **Account** view surfaces the same config the agency manages and routes any change request to Edit.
  - *Agency-side clarification (the client never sees this):* "manually implement" splits two ways — live-projected fields (`template_vars`, `hours`, `brand_color`, `logo_url`, `social_links`, `review_link`) the agency edits in `admin.settings` reflect **instantly** (the site reads them live via `get_client_public`, no redeploy); structural/layout/copy/new-photo changes baked into the Remixed frontend need an agency edit + redeploy. One ticket covers both; the agency picks the path.

**NS — Notification surfacing [LOCKED]:** **agency → client** (reply or status change) fires **both** (a) an in-app **Alerts** entry via `writeNotification` with new `type`s (`ticket_agency_reply`, `ticket_status_changed`) + `action:{ open_ticket:true, ticket_id, kind }` (rendered as an "Open" deep-link button — extends the hardcoded action renderer), **and** (b) an **owner-email stub** (`resolveOwnerEmail(ticket.client_id)` + `events.type='owner_email_stub'`), per the handoff "in-app + owner-email on reply." **client → agency** (new ticket / client reply): surfaced in the **per-client admin pending lists** (this slice). **Agency-wide flagging across all clients = Phase C** (`agency-view`) — v1 core has no cross-tenant dashboard, so the agency reviews per active client until Phase C (explicit gap).

**TUX — Ticket-thread UX [LOCKED]:** reuse the **Conversations-tab bubble pattern** — `sender_side` drives left/right alignment (agency vs client), status badge + resolution as a pinned banner at top, composer (text + attach) at bottom. Poll **10s** in an open thread, **15s** on the list (reuse the existing cadence).

**SH — Support-history [LOCKED]:** a `resolved`/`closed` **filter within `admin.support.tsx`** (+ a read-only history section in the PWA Support surface), not a separate route.

**ATT — Attachments [LOCKED]:** allowed on **both** kinds (reuse `recordTicketAttachment`).

**TL — Client-initiated close [LOCKED — deferred]:** a future `clientCloseTicket` fn (never folded into the admin `setTicketStatus`). v1: only the agency resolves/closes; a client reply reopens a terminal ticket.

---

## 7. Config prerequisites (config-not-code; from v1.7 §4d)
- **`client-assets` bucket caps** — **DONE 2026-06-20:** bucket `file_size_limit = 26214400` (25 MB) set via SQL on `storage.buckets` (size only). **MIME enforced at the app layer** (`ticket-upload.ts` helper + `recordTicketAttachment`), **NOT a bucket-wide `allowed_mime_types` list** — a bucket-wide MIME list would break existing logo/asset uploads. Chosen approach: size cap at the bucket, MIME at the app layers (the three-layer enforcement, with layer-1 = size only).
- **Custom SMTP** (carried from B-0) — not blocking this build; blocks real client invites. Owner-email-on-reply uses the existing transactional-email stub path, independent of the Supabase Auth SMTP.

---

## 8. Skills touched (mirror-lines handed AFTER build + validate — not now)
- **`mobile-app`** (primary) — the **nav restructure** (Stats=Home, 3 bottom tabs Inbox·Review·Alerts, ☰ menu Account·Edit·Support, back-arrow), the read-only **Account** view, the two new ticket surfaces (Request an Edit + Support), the payment-gate shell intercept, ticket-notification types + owner-email-on-reply, the `open_ticket` notification action, the thread polling cadence. *(per-client branding + dynamic manifest + SW = Slice 2.)*
- **`admin-view`** (primary) — per-client edit-requests + support sections + the support-history filter; read-via-RLS / write-via-service-role-fn; the approve/deny-with-resolution flow; `postAgencyReply`/`setTicketStatus`.
- **`scratch-foundation`** — already owns the v1.7 ticketing data model + the read-only-RLS/service-role-write **contract** (DONE). Add a pointer: the 5 write-fns + the `src/lib/tickets/authz.ts` (`isAdmin`/`isMemberOf`) helper module now **realize** that contract (app-layer).
- **`agency-view`** (NEW — Phase C, NOT built here) — note the handoff: cross-tenant pending-edit/pending-support lists + new-request flagging + cross-client payment-toggle consume these same 5 fns; no rework.
- **`platform-spec-source-of-truth`** — reflect the B-design surfaces as built (app-layer).

---

## 9. Slice 2 (spec'd next, NOT here) — PWA infra
Scope only, for continuity: **dynamic per-host manifest** (serve `/manifest.webmanifest` from a route that resolves the client by `Host` → that client's name/colors/icon; today it's a static `public/manifest.webmanifest`, no per-host logic), **service worker + installability** (none exists today), and the **hex→oklch per-client branding PORT** — **verify the injection against the Professional Modern template project before specifying** (it is NOT present in `cloud-spark-setup`; it lives in the Remixed template, so it's a port, not a reuse). Each is independently build→validate.

---

## 10. Validation plan (fn-level boundary first, then end-to-end; no migration expected)
1. **Admin-only lockout:** an impersonated `client_owner` calling `postAgencyReply` / `setTicketStatus` → `Forbidden`.
2. **Sender-side authority:** `openTicket` by client → first message `sender_side='client'`; by admin → `'agency'`. A client CANNOT produce an `'agency'` message via any fn or direct DB write (the v1.7 §5.4 direct-write-lockout still holds — unchanged by app-layer).
3. **`postClientMessage`** forces `'client'`; reopens a `resolved`/`closed`/`approved`/`denied` ticket to `open`.
4. **`setTicketStatus`** per-kind rules: `edit_request` `approved`/`denied` without `resolution` → reject; `support` accepts `in_progress`/`resolved`/`closed`.
5. **`recordTicketAttachment`** rejects: `messageId` not in `ticketId` (D); `storagePath` not under `<client_id>/tickets/<ticketId>/` (E); bad MIME / >25 MB (Decision 5); cross-tenant path.
6. **Payment-gate:** flip `access_suspended=true` (via `setClientAccessSuspended`) → PWA shell shows the gate, nav/Outlet hidden; admin + agency surfaces unaffected; flip `false` → access returns. Confirm automations untouched (a drip tick still sends for the suspended client in stub mode).
7. **End-to-end:** client opens an edit request + uploads a photo → agency sees it in `admin.edit-requests`, downloads the asset, replies + approves with a resolution → client sees the resolution + an Alerts entry + (stub) owner-email event; client reply reopens.
8. **Nav + Account:** app opens on **Stats Home**; the 3 bottom tabs + ☰ menu route correctly; the back-arrow returns to Home from every view. The **Account** view is **read-only** (no writable field; "Request a change" deep-links to Edit).
9. **Schema diff is clean** — **zero migrations** emitted (§0 guardrail).

---

## 11. Recommended execution — slice the Lovable hand-off (validate the boundary first)
**Recommendation: slice it — do NOT hand Lovable the whole core at once.** Same discipline the backend pass used: build the security boundary, prove it, then build UI on top of a *proven* boundary. Three Lovable prompts:

- **Prompt 1 — the write boundary (no UI):** `src/lib/tickets/authz.ts` (`isAdmin`/`isMemberOf`) + the **5 write-fns** + `notify.server.ts`. Then run **Validation §10 steps 1–5** (admin-only lockout, sender-side authority, reopen rule, per-kind status rules, attachment Findings D/E + Decision 5) at the fn/SQL level. **Gate: do not proceed until green.** (Zero migrations — §0.)
- **Prompt 2 — client PWA:** the nav restructure (Stats=Home, 3 tabs, ☰, back-arrow; relocate Dashboard→`index`, Conversations→`inbox`) + read-only **Account** + **Edit**/**Support** tabs + client-side `client-assets` upload + the **payment-gate shell** + the `open_ticket` Alerts action. Run **§10 steps 6, 8**.
- **Prompt 3 — admin per-client surfaces:** `admin.edit-requests` + `admin.support` (+ history filter) calling `postAgencyReply`/`setTicketStatus`. Run the **end-to-end §10 step 7** (client opens+uploads → agency replies/approves → client sees resolution + Alerts + owner-email stub → reply reopens).

Then record a build-log validation + hand the `mobile-app`/`admin-view`/`scratch-foundation` mirror-lines (§8). Baseline stays **`golden-master-v1.7`** throughout (app-layer; no re-tag). **Config prereq before Prompt 2's upload is exercised live:** the `client-assets` 25 MB / MIME caps (§7).

---
**Spec-only. Frozen backend untouched. No migration, no re-tag. §6 decisions LOCKED — ready for Lovable (slice per §11).**
