# Stage C-3c-1 — Finalize & Invite + Remix handoff checklist — validation

> Point-in-time validation record, 2026-06-28. **App-layer / UI only — no schema, no migration, no fn-contract change** (`provisionClientOwner` reused as-is). Verified against `cloud-spark-setup` `origin/main`. Build spec: `docs/phase-c-3c1-build-spec.md`.

## What shipped
A **Finalize & Invite** section on the per-client `/admin` Settings page (`src/routes/_authenticated/admin.settings.tsx`):
- **Remix handoff checklist** (read-only, from the loaded client row): `slug`, `VITE_CLIENT_SLUG` (= slug), matched `site_style`, `allowed_origins`.
- **Finalize & Invite** button → calls the existing `provisionClientOwner({ clientId, email, reason })` with the **Business notification email** (`notification_email ?? email`); `window.confirm` guard (sends a real email). Idempotent.

## Validation (PASS)
- **Drift:** `admin.settings.tsx` only; no migration / schema / fn-contract change; `tsc` passes.
- **SQL** on client `574e8c6a-72d8-4fc5-be9a-cfd4e3120ce3` / `mansionsmax@gmail.com`:
  - `user_roles.role = 'client_owner'` for that client ✅
  - `audit_log`: `action=grant`, `role=client_owner`, `actor_source=fn`, `reason="C-3c finalize/invite"` ✅
- **Idempotency** confirmed (re-run grants without error). **No service-role** key used in the page (reads/writes via authed browser supabase; the invite goes through the admin-gated server fn).

## Logged (non-blocking — batch later, do NOT fix now)
- **[UX] Success feedback not visible** — after the confirm dialog there was no visible success confirmation; the success toast may not render reliably on this page. The invite genuinely succeeded (SQL proves it). Polish later: a persistent "Invited ✓" / inline success state so real-client invites give obvious feedback.

## Carried config prereqs (not code; do not block testing)
- `VITE_INVITE_REDIRECT_URL` → the client-PWA set-password route (until set, the invite magic-link uses the default redirect).
- Custom SMTP on Supabase Auth (default invite lands in spam).
The invite still creates the auth user + grants the role without these.

## Skills brought to parity (mirror lines handed)
- `admin-view` — Settings tab gains the **Finalize & Invite** section (handoff checklist + `provisionClientOwner` invite; the UX-toast backlog note; the C-3c-2 pending→active forward pointer).
- `new-client-site` — step 1 records the per-client `/admin` Finalize & Invite as the concrete invite + Remix-handoff surface.

## Next
**C-3c-2** — pending-status model (`status='pending'`) + pre-gen console / immutable submission viewer + agency pending-review queue; the `status` pending→active flip folds into this Finalize & Invite action.
