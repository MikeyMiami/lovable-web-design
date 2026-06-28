# Stage C-3c-2c — agency Pending-onboarding queue + badge — validation (closes C-3c)

> Point-in-time validation record, 2026-06-28. **App-layer / UI only — no schema, no migration, no fn-contract change, no service-role.** Verified against `cloud-spark-setup` `origin/main`. Build spec: `docs/phase-c-3c2c-build-spec.md`.

## What shipped
- `agency.tsx` — `UserPlus` icon import + an `onboardingCount` query (`clients` count `status='pending'`, 15s poll) + a new **Onboarding** tab with that badge.
- NEW `agency.onboarding.tsx` — cross-tenant queue of `clients WHERE status='pending'` (not deleted), newest by `created_at`, client-labelled; **"Open"** → `localStorage["admin.activeClientId"]` → `/admin/review`.

## Validation (PASS — full agency-side loop)
- Wizard create lands `pending` → appears in `/agency` **Onboarding** queue + badge. ✅
- **Open** routes to `/admin/review` (pending pill, submission viewer, missing-vars panel, Finalize & Invite). ✅
- **Finalize & Invite** activates + grants `client_owner` → the client **drops off** the queue + badge **decrements** within ~15s. ✅
- Only `pending` clients show; active clients never appear. ✅
- Authz holds (a `client_owner` hitting `/agency` is denied). ✅
- **Drift:** `agency.tsx` (UserPlus + onboardingCount + Onboarding tab) + NEW `agency.onboarding.tsx`; browser `is_admin` RLS reads, **no service-role**; no migration/schema/fn change; `tsc` passes. ✅

## Skills brought to parity (mirror handed verbatim from the commit)
- `agency-view` — 3-tab shell (Pending · Onboarding · Payment Access); new **Onboarding queue** bullet (`clients status='pending'`, 15s poll + badge, "Open" → `/admin/review`).

## Milestone
**C-3c is COMPLETE** — the full agency-side lifecycle for pending clients: wizard/self-fill create → `status='pending'` (dormant) → agency Onboarding queue → `/admin/review` (submission viewer + handoff + missing-vars) → Finalize & Invite (`provisionClientOwner` + pending→active) → live. All app-layer on `golden-master-v1.7`, no schema.

## Next
**C-3d** — the client-facing capture that FEEDS this queue: one-time tokenized `/onboard/$token` link (generated from agency "New Client"), the mode-aware wizard, the server-fn upload proxy (`public-assets` is admin-write), the public submit → pending-create → notify path, and the mode-aware success screen. The one schema touch is the additive `onboarding_tokens` table (see `docs/phase-c-3cd-scope.md` F2).
