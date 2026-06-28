# Stage C-3c-2b — /admin/review console + submission viewer + shared FinalizeInvite — validation

> Point-in-time validation record, 2026-06-28. **App-layer / UI only — no schema, no migration, no fn-contract change, no service-role.** Verified against `cloud-spark-setup` `origin/main` @ `53aba32`. Build spec: `docs/phase-c-3c2b-build-spec.md`.

## What shipped (incl. 4 refinements beyond the base prompt)
- **Shared `<FinalizeInvite/>`** (`src/components/admin/FinalizeInvite.tsx`) — single source for the handoff checklist + invite + pending→active flip.
- **`/admin/review` console** (`admin.review.tsx`, active-client scoped) — Review & Finalize tab: status pill, immutable submission viewer, missing-vars reminder, Settings link, embedded `<FinalizeInvite/>`.
- **Review tab** added to the `/admin` nav.
- **Refinement 1 — status pills** render amber (pending) / green (active) via inline styles.
- **Refinement 2 — Finalize & Invite REMOVED from Settings** — it now lives ONLY on Review & Finalize (a deliberate change from the base prompt, which embedded it in both; single-source kept, one surface).
- **Refinement 3 — missing-required-`template_vars` panel** on the Review tab, above `<FinalizeInvite/>` (pre-invite gap reminder).
- **Refinement 4 — shared `src/lib/clients/required-template-vars.ts`** — the required-keys list extracted to a single module; Settings + Review both import it (agree, no drift).

## Validation (PASS — visual)
- Status pills: amber pending / green active (inline styles). ✅
- Finalize & Invite present ONLY on Review (removed from Settings); still the single shared component. ✅
- Missing-required-`template_vars` panel shows on Review above FinalizeInvite; agrees with Settings (shared lib). ✅
- Finalize from the Review console flips `status` pending→active + grants `client_owner` (C-3c-2a behavior intact). ✅
- **Drift:** NEW `required-template-vars.ts`; `admin.settings.tsx` (FinalizeInvite removed); `admin.review.tsx` (pill + missing-vars panel); `FinalizeInvite.tsx` (unchanged from build); no migration/schema/fn/service-role; `tsc` passes. ✅

## Skills brought to parity (mirror handed verbatim from the commit)
- `admin-view` — Pre-generation console / Review & Finalize tab + immutable submission viewer now **BUILT (C-3c-2b)**; Finalize & Invite moved out of Settings to the Review console (shared `<FinalizeInvite/>`); missing-required-`template_vars` pre-invite reminder + shared `required-template-vars.ts`.

## Next
**C-3c-2c** — agency Pending-onboarding queue + badge (`clients WHERE status='pending'`, mirror C-1, "Open" → `/admin/review`). Closes out C-3c-2.
