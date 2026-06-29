# Stage C-3 — Friendly social-link editors in admin Settings — validation

> Point-in-time validation record, 2026-06-29. **App-layer / UI only — no schema, no migration, no fn-contract change.** Verified against `cloud-spark-setup` `origin/main`. Build spec: `docs/phase-c-social-links-admin-build-spec.md`.

## What shipped
Friendly **Instagram / Facebook / LinkedIn** URL inputs in admin Settings → **Brand & Site** (pre-filled from `clients.social_links`), alongside the existing "Social links (JSON)" textarea. The Brand & Site save **merges** the friendly fields into the full `social_links` object (overlay only those keys; blank field removes that key) and **re-seeds the JSON textarea** (dual-writer guard).

## Clobber/merge (the verified concern)
`social_links` is a dedicated jsonb COLUMN written wholesale (`UPDATE clients SET social_links = <obj>`). The existing Brand & Site save already round-tripped the full object (from the JSON textarea), so the merge pattern (parse base → overlay the 3 keys → write full object → re-seed textarea) preserves other keys — same proven no-clobber approach as the discount/GBP `template_vars` work.

## Validation (PASS)
- Friendly IG/FB/LinkedIn editors pre-filled from `social_links`; edits save; the JSON textarea re-seeds to match. Other keys preserved (no clobber); blank field removes its key.
- **Drift:** `admin.settings.tsx` only; no migration/schema/fn; `tsc` passes.

## Skill brought to parity (verbatim mirror handed)
- `admin-view` — Brand & Site gains friendly social-link editors (merge-safe into `social_links` + JSON-textarea re-seed).

## Status
This completes the social-links work (onboarding capture + admin friendly editors). The C-3c+C-3d onboarding arc + social-links are done.
