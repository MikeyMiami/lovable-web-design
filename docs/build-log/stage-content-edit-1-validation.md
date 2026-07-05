# Stage CONTENT-EDIT-1 — Settings editors for AI/SEO content fields — validation

> Point-in-time validation record, 2026-07-05. **App-layer; ZERO schema.** Verified against `cloud-spark-setup` `origin/main` @ `54dba6d` (`git diff 4e644e0..origin/main -- supabase/migrations` = empty). Build spec: `docs/phase-content-edit-1-build-spec.md`. Scope: `docs/phase-template-vars-editors-scope.md`.

## What shipped
Friendly editors for the AI/SEO-feeding `template_vars` fields (`differentiators`, `about_us`, `services`, `segment`) — previously raw-JSON-only:
- **`updateClientContent`** (`seo.functions.ts:337`) — server-side-merge fn (`requireSupabaseAuth` + `assertAgencyAdmin`, re-reads `template_vars`, overlays only the provided keys, `statusCode`-on-throw).
- **"Business & SEO Content"** section in `admin.settings.tsx` (`:578`) — imports + calls `updateClientContent` (`:13/:323`).
- **"AI writes from this"** read-only preview in `admin.seo` (differentiators + About + "Edit in Settings" link).

## Validation (PASS)
- **No-clobber confirmed** — edited `differentiators` via the new section → re-read row: `differentiators` updated AND `discount__*` / `seo` / `site_assets` all intact (server-side merge works). ✅
- **SEO-panel preview** shows `differentiators` + an Edit-in-Settings link (single source = Settings; preview read-only). ✅
- **Drift:** `seo.functions.ts` (+`updateClientContent`) + `admin.settings.tsx` (+section) + `admin.seo.tsx` (+preview). **No schema/migration**; admin-gated; `audit_tenant_rls()` unaffected. ✅

## Roadmap
**CONTENT-EDIT-1 → DONE.** Next: the structured-services arc (SVC-1 = `services_structured` shape + `updateClientServices` merge fn + `proposeSeoMap` prefer-structured-else-string + derived flat string).
