# Phase C — C-3c-2 — pending model + pre-gen console / submission viewer + agency pending queue — READ-ONLY SCOPE

> Scope/plan only — **no code, no skill edits, no build prompts.** Grounded on live `cloud-spark-setup` `origin/main` @ `0015450` (read-only verify 2026-06-28). Awaiting review before any build.

## Verified facts (the four checks)
1. **`clients.status` is free text — `status text NOT NULL DEFAULT 'active'`, NO CHECK, NO enum** (clients migration `20260609034320:65`). → **`'pending'` is ZERO-SCHEMA.** The `status='active'` allowlist filters auto-exclude pending: `clients_anon_select` RLS (`:166`), `get_client_public` RPC, the enrollment-claim fn, the anon safe-column policy. So a pending client runs **no automations** and is **invisible to anon/public** — exactly what we want; **no filter edits needed.**
2. **Admin/agency reads pending rows.** `clients_select` (authenticated) = `is_admin(uid) OR id IN user_client_ids(uid)` (`:158-163`) — **not status-filtered.** `clients_update` is likewise `is_admin`-gated (`:170-179`) → the agency can flip `status`.
3. **Submission JSON has NO reader.** `{clientId}/onboarding-submission.json` (private `client-assets`) is only **written** (`onboarding.functions.ts:108`). The viewer is **net-new**; `client-assets` RLS permits `is_admin` reads, so it reads via the **authed admin** (signed URL / download) — **no new server fn, no service-role, no policy change.**
4. **No pre-gen console / submission viewer route exists.** `/admin` = `admin.tsx` shell + 10 sub-routes. Net-new surface. Agency queue routes in via C-1's `localStorage["admin.activeClientId"]` + navigate.

## Schema / fn-contract flags
| # | Item | Schema? | Notes |
|---|---|---|---|
| F1 | `clients.status = 'pending'` | **NONE** (free text). | The gotcha — confirmed zero-schema. Allowlist filters already exclude it; no filter changes. |
| F2 | `createClientFull` inserts `status='pending'` | **No schema; app-layer fn BEHAVIOR change** (insert default 'active' → explicit 'pending'). Signature/contract unchanged. | Unified lifecycle (Q1): every wizard-created client starts pending → activated by Finalize & Invite. The ONLY fn touch in C-3c-2. |
| F3 | pending→active flip | **No schema, no new fn.** | Extends the EXISTING C-3c-1 Finalize & Invite mutation: after the invite, a direct-RLS `clients.update({status:'active'})` (admin `clients_update` RLS allows it). **No duplicate logic** — same button/component. |
| F4 | Submission viewer | **No schema, no new fn, no service-role.** | Authed-admin read of the private JSON (`is_admin` storage RLS → signed URL/download). |
| F5 | Agency pending queue | **No schema, no service-role.** | Browser `is_admin` RLS read of `clients WHERE status='pending'` (per the agency-view LOCKED contract: authed supabase only). |

**Net: zero schema. One app-layer fn-behavior change (F2). Everything else is UI + existing-pattern reuse.**

## Lifecycle (after C-3c-2)
```
wizard create (self-fill OR client-submit) → createClientFull → status='pending'
   → pending client: NO automations, NOT anon-visible, but admin/agency-readable
   → agency Pending-onboarding queue (badge) → routes into per-client /admin review surface
   → review: immutable submission viewer (raw answers) + editable Settings (prefilled)
   → Finalize & Invite (C-3c-1, extended): provisionClientOwner + status pending→active
   → active: automations eligible, anon-visible
```

## Slicing recommendation (matches your expectation)
- **C-3c-2a — pending model + flip.** `createClientFull` sets `status='pending'` (F2); **extend the existing Finalize & Invite mutation** to flip `pending→active` on successful invite (F3 — no new button, no duplicate logic). Smallest slice; validates the whole lifecycle on a wizard-created client. *(No new route — touches `onboarding.functions.ts` + the C-3c-1 mutation in `admin.settings.tsx`.)*
- **C-3c-2b — pre-gen console + immutable submission viewer.** A net-new per-client `/admin` review route (active-client scoped) that renders the **read-only raw submission** (download `{clientId}/onboarding-submission.json` via authed-admin) + a pointer to the editable Settings + **embeds the same Finalize & Invite component** (single source — extract it from Settings into a shared component so it isn't duplicated). F4.
- **C-3c-2c — agency pending-onboarding queue + badge.** A new agency tab mirroring C-1's pending-tickets queue: reads `clients WHERE status='pending'` (browser `is_admin` RLS), client-labelled, count badge, 15s poll, **"Open" → `localStorage["admin.activeClientId"]=id` + navigate to the C-3c-2b review route.** F5.

Each slice = its own build prompt + validation + build-log, same discipline.

## Open design questions (decide before build)
1. **Finalize & Invite home once the console exists (C-3c-2b):** keep it in Settings, move it to the new review console, or **extract a shared `<FinalizeInvite/>` component embedded in both**? → *Rec: extract the shared component (single source); console is its primary home, Settings keeps it too. Avoids the duplicate-logic risk you flagged.*
2. **`createClientFull` → pending for ALL wizard creates (incl. agency self-fill), confirm (Q1 said unified):** every new client starts pending and needs Finalize & Invite to activate. → *Rec: yes (unified). Note: existing active clients are untouched; no backfill.*
3. **Pre-gen console scope for C-3c-2b — lean or rich?** → *Rec: LEAN v1 = the immutable submission viewer + link to Settings (editable, prefilled) + the Finalize & Invite action. The richer "congruence console" (assemble selections/branding/niche/A2P-prep side-by-side) = a later polish, not C-3c-2.*
4. **Backfill:** leave today's active test clients as `active` (no migration/backfill); only new wizard creates start pending. → *Rec: yes, no backfill.*
5. **Review-route placement/name:** new route e.g. `/admin/review` (or `/admin/finalize`)? → *Rec: `/admin/review` (active-client scoped, like the other admin sub-routes).*

## Files / skills touched (enumeration only)
**Code (`cloud-spark-setup`):**
- `src/lib/clients/onboarding.functions.ts` — `createClientFull` insert sets `status='pending'` (F2).
- `src/routes/_authenticated/admin.settings.tsx` — extend the Finalize & Invite mutation with the pending→active flip (F3); extract `<FinalizeInvite/>` if shared (Q1).
- NEW `src/routes/_authenticated/admin.review.tsx` (pre-gen console + submission viewer) — embeds the shared Finalize & Invite (C-3c-2b).
- Agency: `src/routes/_authenticated/agency.tsx` (add a Pending-onboarding tab + badge) + NEW `src/routes/_authenticated/agency.onboarding.tsx` (the queue) (C-3c-2c).

**Skills (`lovable-web-design`):**
- `admin-view` — the pre-gen console + immutable submission viewer become BUILT (existing `[BUILD]` items); Finalize & Invite flips pending→active.
- `agency-view` — new Pending-onboarding queue + badge + route-in.
- `scratch-foundation` — record the `status='pending'` lifecycle (createClientFull default + the active-on-invite flip).
- `onboard-from-form` — note wizard creates land as `status='pending'`.

---
**Read-only scope. No code/skills edited, no build prompts, nothing committed. Zero schema (F1 confirmed). One app-layer fn-behavior change (F2 — createClientFull sets pending). Slices: 2a pending+flip → 2b console/viewer → 2c agency queue.**
