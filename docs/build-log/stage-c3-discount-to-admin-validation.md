# Stage C-3 — Returning Customer Discount: onboarding → agency-set — validation

> Point-in-time validation record, 2026-06-28. App-layer / UI only — **no schema, no migration, no fn-contract change.** Verified against `cloud-spark-setup` `origin/main` (live built code + SQL on a full test client). Build spec: `docs/phase-c-discount-to-admin-build-spec.md`.

## What shipped
The discount is now an **agency-set campaign offer**, removed from the onboarding wizard:
- **Wizard (Prompt A):** removed the "Returning Customer Discount" step (9 → 8 steps), its state (`discountOnReferral`/`discountAmount`), its step block (A2P renumbered 7→6, Review & Create 8→7), the `stepErrors` A2P guard (`i===7`→`i===6`), and the two assembly lines (`templateVars.discount__on_referral` / `.discount_amount`). Removed the discount Section from `ReviewSummary.tsx` (7 sections shown).
- **Admin (Prompt B):** a dedicated "Returning Customer Discount" Section in `admin.settings.tsx`, written via the page's existing **direct-RLS `saveClient`** with a **read-merge-write** (`base = { ...client.template_vars }`, overlay the two keys, write the FULL object) + JSON-textarea re-seed (dual-writer guard). Does NOT use `updateClientSettings` (which REPLACES `template_vars`).

## Key finding (the #4 merge question)
`updateClientSettings` → `clientPatch` does `p.template_vars = f.templateVars` → `UPDATE clients SET template_vars = …` = **wholesale jsonb REPLACE**. But the live admin editor uses **direct-RLS browser writes**, already round-trips the full `template_vars`, and `updateClientSettings` is only called by the throwaway test harness. → the discount editor uses the direct-RLS read-merge-write; no fn change.

## Validation (SQL, PASS)
- **Wizard create** (slug `test-landscaping`): discount keys **absent** at create (unset → agency sets later).
- **Admin merge:** discount set ($50-style) survived a subsequent review-link save; `keep_about`/`keep_services`/`keep_assets` ALL true (no clobber). Clearing the fields removes the keys; other `template_vars` intact.

## Skills brought to parity (mirror lines handed)
- `onboard-from-form` — 8-step wizard; discount removed → agency-set; field→destination discount row marked agency-set.
- `admin-view` — "Returning Customer Discount (agency-set)" dedicated Settings section (merge-safe) + the LOCKED note that any `template_vars` admin edit must read-merge-write (both `updateClientSettings` and a raw UPDATE replace the jsonb).
