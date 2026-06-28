# Stage C-3 — Google review link → agency-set; capture GBP link at onboarding — validation

> Point-in-time validation record, 2026-06-28. App-layer / UI only — **no schema, no migration, no fn-contract change.** Verified against `cloud-spark-setup` `origin/main` (live built code + SQL on a full test client). Build spec: `docs/phase-c-review-link-to-admin-build-spec.md`.

## What shipped
The precise Google review URL is **agency-set** (it must be formatted correctly to work); onboarding instead collects the easy-to-find **Google Business Profile link**.
- **Wizard (Prompt A):** Step-6 field replaced — `reviewLink` state → `googleBusinessProfileLink`; field relabeled "Google Business Profile link" (private, not site-shown). Assembly: removed `templateVars.review_request_link` and `fields.reviewLink`; added `templateVars.google_business_profile_link` (submission carries it via `...s`). `ReviewSummary.tsx` Reviews row shows the GBP link. The wizard now sets **nothing** review-related except `google_business_profile_link`.
- **Admin (Prompt B + shipped refinement):** Review Config syncs `template_vars.review_request_link` to the `review_link` column on save (merge-safe, full object, textarea re-seed). The **GBP link shipped EDITABLE** (not read-only): `review` state gained `google_business_profile_link` (seeded from `client.template_vars` directly — TDZ-safe, since `initialVars` is declared after `review`), an editable `<Input>`, and the `onSave` overlays `google_business_profile_link` into the same merge-safe `base`. Direct-RLS `saveClient` (not `updateClientSettings`).

## Consumer map (verified)
- `clients.review_link` (column) — funnel redirects (`r/$token.ts`, `r/rate.ts`), PWA account view. Formatted Google URL → agency-set.
- `template_vars.review_request_link` — static message merge value (`runner.server.ts`). Distinct from the per-contact tracked `{review_link}` (`trackedLinkUrl(token)`). → kept in sync with the column on save.
- `template_vars.google_business_profile_link` — agency reference (anon-readable public URL; also iterated into the chat knowledge prompt — harmless). Not rendered on-site.

## Validation (SQL, PASS)
- **Wizard create** (slug `test-landscaping`): `google_business_profile_link` saved; `review_link` NULL; `review_request_link` absent. Deferred R-1 checks also cleared: `call_forwarding_number = +12424242424` (E.164); `clients.hours` == `send_settings.business_hours` (same structured object — derive + `{raw}` fix, weekends present, Sunday omitted); defaults held (place_id NULL, star_threshold 4, toggle gated, allowed_origins []); send_settings caps/window at DB defaults. Staff manifest carries BOTH typed entries: individual `{name:"Jeff", position:"CEO", type:"individual"}` + group `{label:"The Team", type:"group"}` (resolves the prior pending-SQL caveat in `website-structure`).
- **Admin merge:** setting `review_link` → `review_link` and `review_request_link` synced to the same URL; `gbp` present; survived alongside the discount save; `keep_about`/`keep_services`/`keep_assets` ALL true (no clobber across both merges). GBP edit in admin saves merge-safe.

## Skills brought to parity (mirror lines handed)
- `onboard-from-form` — Reviews step collects the GBP link → `template_vars.google_business_profile_link`; wizard no longer sets `review_link`/`review_request_link`; field→destination rows added (GBP owner-filled; review link agency-set).
- `admin-view` — Review Config: `review_link` agency-set, `review_request_link` synced on save, GBP link shown EDITABLE (pre-filled, merge-safe).

## Note
The staff individual/group manifest data-shape (previously "pending SQL confirmation" in `website-structure` and `stage-c3-r3-validation.md`) is now **SQL-confirmed** via this test client.
