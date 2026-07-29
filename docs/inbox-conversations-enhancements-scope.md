# Inbox / Conversations Enhancements — scope + build plan (for approval)

> **⚠ STATUS UPDATE 2026-07-28 — PARTIALLY SHIPPED. Read this before using anything below.** **#3 (archive)** and **#4 (archived view)** are BUILT AND LIVE (app `44d382e`, UI refined through `3bfa024`); **#6 (search by name/number)** was already live in `app.inbox.tsx`. Still open: **#1** (add name/email to a contact from a conversation), **#2** (recent/oldest/unread filter), **#5** (contact notes). **The schema delta below is now PARTLY OBSOLETE** — only `archived_at` was added, NOT `deleted_at` and NOT `last_read_at`, so #2's unread filter still needs a decision (add `last_read_at`, or keep reusing the per-device localStorage `msg_last_read` marker). **Delete was deliberately NOT implemented** — archive covers the real need without risking SMS history. The as-built contract (the `trg_unarchive_on_inbound` trigger, the SwipeRow rules, and the lead-type avatar) lives in `/mobile-app` Tab 1, which is the authority now.
>
> **Original status:** SCOPE FOR APPROVAL — read-only analysis, 2026-06-20. **Build nothing yet.** Mikey confirmed the full 6-feature set (no trimming). **Runs AFTER Phase B-design closes, as its own unit** — additive backend pass first (v1.8-style), then UI — mirroring how B-backend → B-design went. Grounded in the real frozen schema (`migrations/20260609034320…sql`).

## 0. Schema ground truth (verified, not assumed)
- **`contacts`** (`:229`): `first_name`, `last_name`, `email`, `notes`, `deleted_at` **already exist**; `contact_status`/`source` enums; `consent_*`, `opted_out_at`. **`contacts_all` FOR ALL RLS** (`:254-262`) + `GRANT SELECT,INSERT,UPDATE,DELETE TO authenticated` → a `client_owner` can already read/write their own contacts under RLS.
- **`conversations`** (`:268`): `id, client_id, contact_id, last_message_at, status text DEFAULT 'open', created_at`. **No `archived_at` / `deleted_at` / read column.** `conversations_all` FOR ALL RLS + full grants.
- **`messages`** (`:294`): `direction ('inbound'|'outbound')`, `body`, `twilio_sid`, `status`. `messages_all` FOR ALL. `ON DELETE CASCADE` from `conversations` → a hard-deleted conversation **destroys its SMS history**.
- **No read/unread state exists anywhere** (confirms the mobile-app skill).

## 1. Per-feature: app-layer vs schema
| # | Feature (Mikey's priority order) | App-layer or schema? | Why |
|---|---|---|---|
| 1 | **Add name (+ email)** to a contact from inside the conversation | **App-layer** | `contacts.first_name/last_name/email` exist; write via a server fn. |
| 2 | **Filter list: recent / oldest / unread** | recent/oldest = **app-layer** (`order by last_message_at`); **unread = SCHEMA** | No read-state today → add `conversations.last_read_at`. |
| 3 | **Delete or archive** a conversation from the messages view | **SCHEMA** | Add `conversations.archived_at` + `conversations.deleted_at` (soft-delete — §2). |
| 4 | **Archived-conversations view** | **App-layer** (depends on #3) | Filter `archived_at IS NOT NULL`. |
| 5 | **Notes per conversation, linked to the contact** | **App-layer** | `contacts.notes` exists (1 conversation ↔ 1 contact). *(Open: single field vs multi-note table — §5 D5.)* |
| 6 | **Search by name or number** | **App-layer** (optional index) | Query `contacts` `first_name/last_name/phone_e164/email`. |

**Net: only #2 (unread) and #3 (archive/delete) need schema.** Everything else rides existing columns.

## 2. Delete — soft vs hard — **RECOMMEND SOFT** (`deleted_at`)
Strongly recommend **soft-delete** (`conversations.deleted_at timestamptz`, null = live):
- This is **client data in a multi-tenant CRM going live.** Hard-delete cascades (`messages ON DELETE CASCADE`) → **irreversible loss of SMS history** — a compliance / TCPA-record / audit risk.
- **Reversible** — a mis-tap is undoable; matches the platform's existing posture (`contacts.deleted_at`, `clients.deleted_at`, archive-via-status all soft).
- Hard purge, if ever needed, belongs in a separate admin-only tool — never the client's tap-to-delete.

## 3. Consolidated additive backend pass (v1.8-style — same contract as v1.7)
Additive-only; **no ALTER of existing logic; no policy changes** (so `audit_tenant_rls()` stays `0` — `conversations_all` already carries the `client_id` membership, and we add no tenant table without a policy). Exact delta:

**Columns (all on `conversations`, all `timestamptz` nullable):**
- `archived_at` — null = active; set = archived (browse in the Archived view).
- `deleted_at` — null = live; set = soft-deleted (hidden everywhere).
- `last_read_at` — null = never read; **unread ⇔ `last_message_at > coalesce(last_read_at, 'epoch')`**.

**Indexes (optional, perf — additive):**
- `idx_conversations_active` partial: `(client_id, last_message_at DESC) WHERE deleted_at IS NULL AND archived_at IS NULL` (the hot list query).
- `idx_contacts_client_name`: `(client_id, lower(first_name), lower(last_name))` (name search at scale).

**Tag:** the next golden-master tag — **`v1.8` if this lands before Phase D's A2P columns, else `v1.9`** (Phase D also reserved a "v1.8-style" A2P pass; whichever lands first takes `v1.8`). Coordinate the number at build time.

*(If multi-note history is chosen instead of the single `contacts.notes` field — D5 — this pass also adds a `contact_notes` table. Default = no new table.)*

## 4. Server fns (role-verified pattern — reuse `src/lib/tickets/authz.ts`)
All `createServerFn({method:"POST"}).middleware([requireSupabaseAuth])`, authz via `isMemberOf(caller, row.client_id)` (admins via `isAdmin`), writing field-scoped through `supabaseAdmin`:
- `updateContactIdentity({ contactId, firstName?, lastName?, email? })` — #1 (normalize email; never touches status/consent/opt-out).
- `updateContactNotes({ contactId, notes })` — #5.
- `setConversationArchived({ conversationId, archived })` — #3/#4.
- `setConversationDeleted({ conversationId, deleted })` — #3 (soft; reversible).
- `markConversationRead({ conversationId })` — #2 (sets `last_read_at = now()`; called on thread open / reply send).
- **Search (#6)** is read-only → no write fn; a client-side RLS-scoped query.

> **Why server fns when `contacts`/`conversations` are FOR ALL RLS** (clients *can* already write directly): the FOR ALL grant otherwise lets a client edit *any* column on their own rows — including `status`/`consent_*`/`opted_out_at`. Routing these edits through fns **field-scopes** them to exactly name/email/notes/archive/read, matching the ticket-fn security discipline. (Direct RLS-update is the lighter alternative for the trivial toggles if we ever want it.)

## 5. UI surfaces (built after the backend pass validates)
- **Inbox list** (`app.inbox.tsx`): a **filter control** (Recent [default] / Oldest / Unread) + a **search box** (name or number). Unread rows bold + a badge. Per-row **archive** + **delete** (swipe or kebab). Active list = `deleted_at IS NULL AND archived_at IS NULL`.
- **Messages / thread view:** header shows the contact name, or falls back to the bare number with an **"Add name"** affordance → inline edit (name + email) via `updateContactIdentity`; a **Notes** panel (edit → `updateContactNotes`); **archive** + **delete** actions; **`markConversationRead`** on open.
- **Archived view:** a route/segment (e.g. `/app/inbox/archived` or a toggle) listing `archived_at IS NOT NULL` with an **unarchive** action.
- **Search:** filters the list by contact name / number / email (ILIKE).

## 6. Open decisions (settle on approval)
| # | Decision | Recommendation |
|---|---|---|
| D1 | Soft vs hard delete | **Soft** (`deleted_at`) — §2. |
| D2 | Archive hides from main list, or just tags? | **Hide** from active list (active = not deleted, not archived); browse in Archived view. |
| D3 | Unread granularity | **Per-conversation** (`last_read_at`), not per-message read receipts. |
| D4 | New inbound on an archived/deleted conversation — resurface? | **Don't touch the frozen 1f inbound webhook.** v1: a new inbound bumps `last_message_at` but does NOT auto-unarchive/undelete; owner unarchives manually (optional "archived w/ new activity" badge later). Revisit if it annoys. |
| D5 | Notes: single field vs multi-note history | **Single `contacts.notes` field** (no schema). Multi-note table = future. |
| D6 | Delete scope | **Conversation-level soft-delete only** — the contact persists (may be in active drips/CRM); we hide the thread, not the person. |
| D7 | Who can edit | `client_owner` + `client_staff` (both `isMemberOf`) + `admin` (`isAdmin`). |

## 7. Sequencing + work-time estimate
**Sequenced AFTER B-design closes** — its own unit, NOT interleaved: additive backend pass → validate → UI (mirrors B-backend → B-design). Estimate at our Lovable iterate-and-validate cadence:

| Unit | Work | Rough effort |
|---|---|---|
| Backend pass | 1 migration (3 cols + 2 indexes) + 1 server-fn prompt (5 fns) + fn/SQL validation (write-scoping + tenant isolation, same harness style) | **~0.5 day** |
| UI | list filter + search + archive/delete actions + archived view + name & notes edit in thread + mark-read — ~2 prompts + manual verify | **~1–1.5 days** |
| **Total** | | **~2 days elapsed** (excludes review latency) |

The backend is genuinely small (3 nullable columns + 5 CRUD fns); **the UI is the bulk of the work.** This is a small-to-medium feature, lower-complexity than B-design's ticketing (no service-role-only write boundary to prove — these tables are already client-writable; the fns just field-scope).

---
**Scope-only. Build nothing until B-design closes + this is approved. Then: additive backend pass (v1.8-style) → validate → UI.**
