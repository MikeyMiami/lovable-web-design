# Stage SEO-STORE-3a — SEO map capture (admin.seo panel + template_vars.seo) — validation

> Point-in-time validation record, 2026-07-02. **App-layer on `golden-master-v1.7`; ZERO schema/migration.** The map is additive JSON at `clients.template_vars.seo`. Verified against `cloud-spark-setup` `origin/main` @ `330d9ad` (pre-build). Build spec: `docs/phase-seo-store-3a-build-spec.md`. Scope: `docs/phase-seo-store-3-scope.md`.

## What shipped
The **SEO map capture** surface — the agency defines/confirms a client's **topical Core-30 map** (primary category + 3–4 categories, each with its services grouped), AI-seeded from the free-text `template_vars.services`, saved to `template_vars.seo`:
- **`admin.seo.tsx`** (new route `/_authenticated/admin/seo`) — reuses `useActiveClient()`; RLS read of the client; editor for primary_category + categories + services-by-category; **"AI-seed from services"** button; slug format/uniqueness/reserved-list validation; save via `saveSeoMap`.
- **`seo.functions.ts`** (new) — **`proposeSeoMap`** (AI-seed, **never writes**) + **`saveSeoMap`** (server-side merge: re-reads `template_vars`, overlays ONLY `seo`, writes the full merged object back). Both `requireSupabaseAuth` + `assertAgencyAdmin`.
- Nav link "SEO" in `admin.tsx`.

## Validation (PASS)
- **Panel loads** for an active client (`test-landscaping`); admin-gated. ✅
- **AI-seed** → sensible topical map: primary "Landscaping Services" + 3 categories grouping all 5 services, **NO geo/location pages**. ✅
- **Save (no-clobber)** → `template_vars.seo` saved AND `template_vars.services` intact. `social_links` being null is **pre-existing** (never set for this client), not a clobber — the server-side `saveSeoMap` re-read + overlay-only-`seo` works as designed. ✅
- **Drift:** `admin.seo.tsx` (new) + `seo.functions.ts` (new: `proposeSeoMap` + `saveSeoMap`) + nav link in `admin.tsx` + the two fixes below. **Zero schema/migration**; `audit_tenant_rls()` unaffected.

## Two real bugs found + fixed (learnings — will recur)
1. **`src/start.ts` `errorMiddleware` swallowed server-fn errors** → server fns failed **silently** (no toast, no useful log). **Fix:** `proposeSeoMap` now **attaches `statusCode`** to its thrown error so the real message propagates through the middleware to an `onError` toast + logs. **Learning [captured in `scratch-foundation` §6]:** any new `createServerFn` must attach `statusCode` (or otherwise mark the error) so it survives `errorMiddleware`; add an `onError` toast on the caller — otherwise failures are invisible.
2. **Gemini `generateObject` rejected the strict nested schema** ("No object generated") — the tightly-nested `{categories:[{services:[{name,slug}]}]}` with regex-constrained slugs was too strict for the model. **Fix:** **loosened the AI schema** to `{ primary_category, categories:[{ name, services:[string] }] }`; **slug derivation, strict shape, and uniqueness are computed server-side** after the AI call; added a **`generateText` + `JSON.parse` fallback** if `generateObject` still fails. **Learning [captured in `scratch-foundation` §6]:** keep AI output schemas LOOSE (names/strings only), derive strict shape/slugs/constraints in code, and always have a `generateText`+parse fallback.

## Skills brought to parity (verbatim mirrors handed)
- **`admin-view`** — new **SEO** tab (`/admin/seo`): the map-capture surface, AI-seed, `saveSeoMap` server-side merge (read-merge-write posture, no clobber).
- **`scratch-foundation` §6** — the two server-fn gotchas (errorMiddleware `statusCode` propagation; loose-AI-schema + server-side strict derivation + `generateText` fallback).

## Next
**SEO-STORE-3b** — `seedCoreThirty`: reads `template_vars.seo` → writes the Core-30 **draft** `content_pages` rows (home + category + service; deterministic slug/type/title/H1/meta + `internal_links` so STORE-2's editorial links render). Upsert by `(client_id, slug)`, no overwrite. Then 3c publish/edit panel.
