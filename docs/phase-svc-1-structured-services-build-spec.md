# SVC-1 — structured services foundation (+ minimal Settings editor) — build spec [HELD]

> Structured per-service records (`template_vars.services_structured = [{name, slug, price_min?, price_max?}]`) + a server-side-merge `updateClientServices` fn + `proposeSeoMap` prefer-structured-else-flat + a derived back-compat `services` string, PLUS a minimal structured Services editor in the CONTENT-EDIT Settings section (so it's testable in-UI + operators can set per-service prices today). Grounded on `cloud-spark-setup` @ `54dba6d`. **ZERO schema.** Scope: `docs/phase-structured-services-scope.md`. Awaiting review.

## Read-only-verify findings
- `proposeSeoMap` reads the flat `tv.services` at `seo.functions.ts:106` (the fallback target). `slugify` (`:40`), `SLUG_RE` (`:38`), `RESERVED_SLUGS`, `assertAgencyAdmin`, `propagateError` all exist to reuse.
- CONTENT-EDIT-1 Settings: `saveContent`/`updateClientContent` (`admin.settings.tsx:316/323`) + the "Business & SEO Content" section (`:579`) with a "Services (comma-separated)" `<Textarea>` (`:610-616`). SVC-1 removes that textarea + splits `services` into a structured editor.

---

# PROMPT SVC-1 — paste into Lovable (cloud-spark-setup)

> **App-layer on `golden-master-v1.7`. ZERO schema change.** Structured per-service records in `template_vars` + a server-side-merge writer + a `proposeSeoMap` fallback + a derived back-compat string + a minimal structured Services editor in Settings. Existing clients unaffected. Report the diff + confirm no migration.

## 1. Backend — `src/lib/seo/seo.functions.ts`
**New fn `updateClientServices`** (mirror `saveSeoMap`: `requireSupabaseAuth` + `assertAgencyAdmin`; re-read `template_vars`; `propagateError`/`statusCode`):
- Input `{ clientId: uuid, services: [{ name: string (min 1), slug?: string, price_min?: string, price_max?: string }] }`.
- Normalize each record: `const slug = (s.slug?.trim() || slugify(s.name));` validate `SLUG_RE`; **dedupe** slugs across the list (append `-2`,`-3`… on collision); if a slug is in `RESERVED_SLUGS`, suffix it to avoid collision. Keep `price_min`/`price_max` as trimmed strings, **omit the key when empty**. → `services_structured = [{ name, slug, price_min?, price_max? }]`.
- Derived back-compat string: `const services = services_structured.map(s => s.name).join(", ");`
- Re-read the current `template_vars` server-side → `merged = { ...template_vars, services_structured, services }` → write back. Return `{ ok: true, services: services_structured }`. Only `services_structured` + `services` touched; all other keys preserved.

**`proposeSeoMap` fallback** (~`:106`) — replace `const services: string = String(tv.services ?? "").trim();` with:
```ts
const structured = Array.isArray(tv.services_structured) ? tv.services_structured : [];
const services: string = structured.length
  ? structured.map((s: any) => String(s?.name ?? "").trim()).filter(Boolean).join(", ")
  : String(tv.services ?? "").trim();
```
Rest of `proposeSeoMap` unchanged (feeds the `services` string to the AI seed; `if (!services)` guard stays).

## 2. Settings — `src/routes/_authenticated/admin.settings.tsx`
- **Remove** the "Services (comma-separated)" `<Field>` from the "Business & SEO Content" section, and **drop `services`** from the `saveContent.mutate({ … })` payload (services is now owned by the structured editor; `about_us`/`differentiators`/`segment` stay on `updateClientContent`).
- Import `updateClientServices` from `@/lib/seo/seo.functions`.
- **State** `servicesRows: Array<{ name: string; price_min: string; price_max: string }>`, seeded (and re-seeded on active-client change, like `content`): from `client.template_vars.services_structured` if a non-empty array (map each to a row), **else** parse the flat `client.template_vars.services` string (split on `,` → `{ name: trimmed, price_min: "", price_max: "" }`, drop blanks) for back-compat.
- **Mutation** `saveServices` → `updateClientServices({ data: { clientId, services } })`; `onSuccess` → toast + `onSaved()` (re-seeds); `onError` → toast.
- **New `<Section title="Services & Pricing">`** (near the Business & SEO Content section), `saving={saveServices.isPending}`, hint: *"Each service the business offers, with an optional price range (e.g. $150 – $500, $5k – $50k). Prices feed the SEO page writer (never invented); blank = no price shown. Names feed the SEO map."* `onSave`:
  ```ts
  saveServices.mutate(
    servicesRows
      .filter(r => r.name.trim())
      .map(r => ({
        name: r.name.trim(),
        price_min: r.price_min.trim() || undefined,
        price_max: r.price_max.trim() || undefined,
      }))
  )
  ```
  - **Rows UI:** for each row, a line with `<Input>` (name) + `<Input placeholder="$150">` (price_min) + a "–" separator + `<Input placeholder="$500">` (price_max) + a remove **×** button (drop that row). An **"+ Add service"** button appends a blank row `{ name:"", price_min:"", price_max:"" }`.
  - Works with prices blank (omitted, no error); an all-blank row is filtered out on save.

## Guardrails
- **ZERO schema/migration** — additive JSON in `template_vars` (`services_structured` + the derived `services`). New server fn (admin-gated, server-side merge, `statusCode`). No clobber (re-read + overlay only those two keys).
- **Back-compat:** existing clients (flat `services` only) → the editor parses to name-only rows; `proposeSeoMap` falls back to the flat string until re-saved. The flat `services` string stays in sync (derived) for anything reading it.
- `about_us`/`differentiators`/`segment` still save via `updateClientContent` (unchanged).

## Drift check (report back)
1. Files: `seo.functions.ts` (+`updateClientServices`, `proposeSeoMap` fallback), `admin.settings.tsx` (−Services textarea, +Services & Pricing structured section + `saveServices`). No migration.
2. `updateClientServices` re-reads `template_vars`, overlays only `services_structured` + `services`.
3. `proposeSeoMap` prefers structured names, falls back to the flat string.

## VALIDATION
1. Settings → **Services & Pricing** shows rows seeded from `services_structured` (or parsed from the flat `services` string for a back-compat client).
2. Add a service + set a price range → Save → re-read row: `template_vars.services_structured` has the rows (validated/deduped slugs + prices), `template_vars.services` = joined names, AND `differentiators`/`seo`/`site_assets`/other keys **intact**.
3. Blank prices → saved with no price (no error); an empty row is dropped.
4. `proposeSeoMap` (client now has `services_structured`) → AI-seed uses the structured names; a client with only the flat string still seeds (fallback).
5. Non-admin blocked; `audit_tenant_rls()` unaffected; no migration.

## Status
**HELD — awaiting review.** Next in the arc: SVC-2 (onboarding structured capture — pills + per-service photos), SVC-3 (pricing → `aiWritePage` PROVIDED CONTEXT), SVC-4 (Photo-Board pre-fill), SVC-5 (Assets tab).
