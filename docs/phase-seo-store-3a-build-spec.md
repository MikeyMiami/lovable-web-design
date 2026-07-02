# SEO-STORE-3a — SEO map capture (admin.seo panel + template_vars.seo) — build spec [HELD, commits held]

> App-layer on `golden-master-v1.7` in `cloud-spark-setup` (drift-checkable). **ZERO schema** — the map is additive JSON at `template_vars.seo`. One new admin route + one new server-fn file. Reads via RLS; AI-seed + save via service-role server fns (`assertAgencyAdmin`). Grounded on `origin/main` @ `330d9ad`. Awaiting build.

## Read-only-verify findings (against 330d9ad)
- **Route pattern:** `createFileRoute("/_authenticated/admin/review")({ head, component })` in `src/routes/_authenticated/admin.review.tsx`. New panel = `src/routes/_authenticated/admin.seo.tsx` → `createFileRoute("/_authenticated/admin/seo")`. Admin tab nav lives in `admin.tsx` (add a link there).
- **Active client:** `useActiveClient()` from `@/lib/admin-context` → `activeClientId` (global admin selector; reuse — no picker needed).
- **RLS read:** the panel reads the client via the RLS browser client `supabase` (`@/integrations/supabase/client`) + `useQuery` (admins can read `clients` incl. `template_vars`).
- **Read-merge-write (the discount/social pattern, `admin.settings.tsx`):** `const base = { ...(client.template_vars ?? {}) }` → overlay the key → `saveClient.mutate({ template_vars: base })` → re-seed local state. `saveClient` calls **`updateClientSettings`** (`lib/clients/onboarding.functions.ts`), which maps `fields.templateVars` → a **wholesale** `template_vars` replace — so the merged `base` (all existing keys + `seo`) is what preserves the other keys. **Verified `updateClientSettings` clobbers `template_vars` wholesale → the merge MUST happen client-side before calling it.**
- **Server-fn shape:** `createServerFn({ method: "POST" }).middleware([requireSupabaseAuth]).inputValidator((d)=>Schema.parse(d)).handler(async ({ data, context }) => { const { supabaseAdmin } = await import("@/integrations/supabase/client.server"); await assertAgencyAdmin(supabaseAdmin, context.userId as string); … })`. `assertAgencyAdmin` checks `user_roles` for `admin`/`agency_owner`.
- **Reusable AI:** `createLovableAiGatewayProvider(process.env.LOVABLE_API_KEY)` (`lib/ai-gateway.server.ts`), OpenAI-compatible; call `gateway("google/gemini-3-flash-preview")` with the `ai` SDK (stream.ts uses `streamText`; a one-shot structured call uses `generateObject`). `LOVABLE_API_KEY` = ambient server env.
- **Services source:** `template_vars.services` = free-text comma string (from OnboardWizard); `template_vars.segment` = industry label; `business_name` on the row. **No structured categories exist** — the AI-seed creates the first proposal.
- **Slug convention:** client slug regex `^[a-z0-9-]+$` (`CreateClientFullInput`); reuse for category/service slugs.

## Decisions locked (from the user)
Map at `template_vars.seo` (read-merge-write). AI-seed via light AI. **Geo DEFERRED** (topical Core-30 only — home + categories + services; no location pages, per seo-content §7). Seed state = draft (3b). Re-seed idempotent by `(client_id, slug)`, no overwrite (3b). Reserved-slug guard at write time. Slices 3a → 3b → 3c.

---

# PROMPT SEO-STORE-3a — paste into Lovable (cloud-spark-setup)

> **App-layer on `golden-master-v1.7`. ZERO schema change** — no migration, no new table/column/policy/RPC. The map is additive JSON stored at `clients.template_vars.seo`. Build ONE new admin route + ONE new server-fn file. Reads via RLS; the AI-seed + save run through service-role server fns gated by `assertAgencyAdmin`. Report the files changed + confirm no DB/migration change.

## What 3a delivers
The **SEO map capture** panel: the agency defines/confirms the client's **topical Core-30 map** — a primary category + 3–4 categories, each with its services grouped — **AI-seeded** from the client's free-text services, then agency-edited and saved to `template_vars.seo`. **No geographic/location pages** in this map (deferred). **No `content_pages` writes here** (that's the next slice) — 3a only captures + saves the map.

## 1. New server-fn file — `src/lib/seo/seo.functions.ts`
Mirror the `onboarding.functions.ts` server-fn shape (`createServerFn` + `requireSupabaseAuth` middleware + `assertAgencyAdmin` + dynamic `supabaseAdmin` import).

**`proposeSeoMap`** — AI-seed a proposed map (does NOT save):
- Input: `{ clientId: string (uuid) }`.
- `assertAgencyAdmin(supabaseAdmin, context.userId)`.
- Read `business_name`, `template_vars` (for `services` + `segment`) from `clients` via `supabaseAdmin`.
- If `process.env.LOVABLE_API_KEY` is missing → throw a clear error.
- Call the Lovable AI gateway (reuse `createLovableAiGatewayProvider` from `@/lib/ai-gateway.server`; model `gateway("google/gemini-3-flash-preview")`) with **`generateObject`** (from `ai`) and this zod schema:
  ```ts
  z.object({
    primary_category: z.string(),
    categories: z.array(z.object({
      name: z.string(),
      slug: z.string().regex(/^[a-z0-9-]+$/),
      services: z.array(z.object({
        name: z.string(),
        slug: z.string().regex(/^[a-z0-9-]+$/),
      })),
    })).min(1),
  })
  ```
- Prompt intent: *"You are a local-SEO strategist. Given this business and its comma-separated services, produce the TOPICAL site map: one primary_category, then 3–4 categories, each grouping the relevant services. Slugs are lowercase-hyphen. Do NOT invent geographic/location/neighborhood pages — topical only. Use only services the business actually listed; group sensibly."* Include `business_name`, `segment`, and the raw `services` string.
- Return the parsed map object. **Never writes.**

**`saveSeoMap`** — persist the map with a **server-side** merge (the panel calls this, NOT a client-side merge):
- Input: `{ clientId: string (uuid), seo: <the map object> }` (validate `seo` = `{ primary_category, categories:[{name, slug, services:[{name, slug}]}] }` with the same slug regex).
- `assertAgencyAdmin(supabaseAdmin, context.userId)`.
- **Re-read the client's CURRENT `template_vars` server-side** (`supabaseAdmin.from("clients").select("template_vars").eq("id", clientId).single()`).
- Overlay **ONLY** the `seo` key: `const merged = { ...(current.template_vars ?? {}), seo: data.seo };`.
- Write the **full merged object** back: `supabaseAdmin.from("clients").update({ template_vars: merged }).eq("id", clientId)`.
- This eliminates stale-blob clobber entirely (two tabs / edit-racing-a-reseed / edit-during-AI-seed) — the freshest `template_vars` is read at write time and only `seo` changes.
- Return `{ ok: true, seo: data.seo }`.

## 2. New admin route — `src/routes/_authenticated/admin.seo.tsx`
- `createFileRoute("/_authenticated/admin/seo")({ head: () => ({ meta: [{ title: "Admin · SEO" }] }), component: AdminSeo })`.
- Add a nav link **"SEO"** alongside the existing admin tabs (see `admin.tsx`).
- `const { activeClientId } = useActiveClient();` — if none, render "Select a client."
- `useQuery` (RLS `supabase`) reads `id, slug, business_name, template_vars` for `activeClientId`.
- **Hydrate** editor state from `client.template_vars?.seo` (a `{ primary_category, categories:[...] }` object) if present; else empty.
- **Editor UI:**
  - `primary_category` text input.
  - Categories list: add / remove / rename; each category has an editable `slug` + a nested services list (add / remove / rename, editable `slug`).
  - Slugs auto-derive from names (slugify → lowercase, hyphens) but stay editable.
  - **"AI-seed from services"** button → calls `proposeSeoMap({ data: { clientId: activeClientId } })` → loads the proposal into the editor (agency then edits). Show a spinner + toast on error.
- **Validation before save** (block + toast on failure):
  - every slug matches `^[a-z0-9-]+$`;
  - slugs are **unique across the whole map** (categories + services share the `/services/$slug` namespace);
  - no slug is in the **reserved list**: `about, services, service-area, gallery, contact, get-your-discount, review, thank-you, terms, privacy, sms-program, locations, sitemap.xml, robots.txt`.
- **Save (server-side merge via `saveSeoMap`):**
  ```ts
  await saveSeoMap({ data: { clientId: activeClientId, seo: { primary_category, categories } } });
  ```
  The panel sends **only** the `seo` map — the server fn re-reads `template_vars` and merges. Then invalidate the query + re-seed local state from the returned/saved value (dual-writer guard). Import `saveSeoMap` from `@/lib/seo/seo.functions`. **Do NOT** do a client-side `template_vars` merge and **do NOT** call `updateClientSettings` for this.

## 3. Guardrails
- **ZERO schema / DB change** — no migration, no new table/column/policy/RPC. Only: 1 new route file, 1 new server-fn file (two fns: `proposeSeoMap` + `saveSeoMap`), 1 nav link.
- Writes go **only** to `clients.template_vars.seo` via `saveSeoMap` (service-role, admin-gated), which **re-reads `template_vars` server-side and overlays only the `seo` key** — preserving discount/social/site_assets/etc. The panel never sends a full `template_vars`.
- **No `content_pages` writes** in 3a.
- Admin-only: both the route (under `_authenticated`) and the server fn (`assertAgencyAdmin`).

## Drift check (report back)
1. Files: `src/routes/_authenticated/admin.seo.tsx` (new), `src/lib/seo/seo.functions.ts` (new, two fns), a nav link in `admin.tsx`. No other files touched.
2. **No migration / no schema change** — confirm.
3. `saveSeoMap` **re-reads `template_vars` server-side** and overlays **only** the `seo` key; other keys preserved.
4. `proposeSeoMap` returns topical-only (no geo) and **never writes**.

## VALIDATION
1. Open `/admin/seo` with an active client → panel loads; a non-admin cannot reach it or call the fns.
2. **AI-seed** → a plausible primary_category + categories + services-by-category appears; **no geographic/location categories**.
3. Edit + **Save** → re-read the `clients` row: `template_vars.seo` is present AND `discount__*` / `social_links` / `site_assets` / other `template_vars` keys are **still intact** (no clobber).
4. Reload `/admin/seo` → the saved map re-hydrates into the editor.
5. Slug validation rejects a reserved slug (e.g. `about`) and duplicate slugs.
6. `audit_tenant_rls()` unaffected (no DB change); no migration in the diff.

## Status
**HELD — awaiting the user's review of this prompt.** Next: 3b `seedCoreThirty` (reads `template_vars.seo` → draft `content_pages` rows), then 3c publish/edit panel.
