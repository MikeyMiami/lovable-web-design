# SEO-STORE-3c-2 — per-page aiWritePage + saveSeoMap title-case normalization — build spec [HELD]

> The last SEO slice. App-layer on `golden-master-v1.7` in `cloud-spark-setup`. **ZERO schema.** (A) `aiWritePage(pageId)` — real single-page content via the AI gateway (one call/page = Worker-safe; the seed of the content pipeline). (B) fold **title-case normalization** into `saveSeoMap`. Grounded on `origin/main` @ `b40c84e`. Scope: `docs/phase-seo-store-3c-scope.md`. Awaiting user review.

## Read-only-verify findings (against b40c84e)
- **AI-call pattern to mirror (already in this file, `proposeSeoMap`):** `const key = process.env.LOVABLE_API_KEY; if (!key) propagateError(...); const [{ createLovableAiGatewayProvider }, { generateText }] = await Promise.all([import("@/lib/ai-gateway.server"), import("ai")]); const gateway = createLovableAiGatewayProvider(key); const model = gateway("google/gemini-3-flash-preview"); const r = await generateText({ model, prompt });`. `propagateError` (top of file) attaches `statusCode` to bypass `errorMiddleware`. **Use `generateText`** (body = prose HTML, not structured — avoids the strict-schema gotcha).
- **Page context readable via `supabaseAdmin`:** the `content_pages` row (`slug, type, title, h1, target_keyword, internal_links, client_id`) + the client (`business_name, address, service_area, template_vars` → `about_us`, `differentiators`, `seo.city`). City resolves exactly like `seedCoreThirty` (`seo.city ?? service_area[0] ?? address`-segment).
- **`saveSeoMap` normalization insertion point:** after the uniqueness + reserved-slug guards (`seo.functions.ts:267`), before building `merged` (`:278`). Normalize `primary_category` + every category/service `name`; **leave slugs untouched.**
- **One-H1 rule:** the page's `h1` is a separate column the template renders; the AI `body` must **start at `<h2>`** and contain **no `<h1>`** (`/seo-build` §3).
- **Editorial links:** the row's `internal_links` `[{href,anchor}]` must be **re-embedded as inline in-content `<a href>`** in the regenerated body (preserve the STORE-2 editorial-link mechanism, `/seo-build` §2).

---

# PROMPT SEO-STORE-3c-2 — paste into Lovable (cloud-spark-setup)

> **App-layer on `golden-master-v1.7`. ZERO schema change** — no migration/table/column/policy. (A) add `aiWritePage` to `src/lib/seo/seo.functions.ts` + a per-row "AI-write" action on the Pages list; (B) fold title-case normalization into `saveSeoMap`. Report files changed + confirm no DB/migration change.

## A. `aiWritePage` — per-page real content (one AI call = Worker-safe)
Add to `src/lib/seo/seo.functions.ts`, mirroring `proposeSeoMap`'s gateway call + `updatePage`'s try/`statusCode` shape:
- Input `{ pageId: z.string().uuid() }`; `requireSupabaseAuth` + `assertAgencyAdmin(supabaseAdmin, context.userId)`; wrap in try/catch that rethrows with `statusCode` (use `propagateError`).
- **Read** via `supabaseAdmin`: the `content_pages` row (`id, client_id, slug, type, title, h1, target_keyword, internal_links`) → if missing, `propagateError("Page not found")`. Then the client (`business_name, address, service_area, template_vars`).
- **Resolve `city`** = `template_vars.seo?.city ?? service_area?.[0] ?? first-comma-segment(address)`.
- **AI call:** `const key = process.env.LOVABLE_API_KEY; if (!key) propagateError("LOVABLE_API_KEY is not configured on the server."); const [{ createLovableAiGatewayProvider }, { generateText }] = await Promise.all([import("@/lib/ai-gateway.server"), import("ai")]); const model = createLovableAiGatewayProvider(key)("google/gemini-3-flash-preview"); const { text } = await generateText({ model, prompt });`
- **Prompt intent (encode `/seo-content` quality bar):** *"Write the on-page BODY (HTML) for this local-business page. Business: {business_name} in {city}. Page type: {type}. Target keyword: {target_keyword}. H1 (already on the page, do NOT repeat as h1): {h1}. Context: {about_us}; {differentiators}. Write genuinely useful, locally-specific content for {city} — what's included, why it matters here, what to expect — NOT generic filler. Rules: output HTML only; start at `<h2>` (NO `<h1>`); ~300–600 words; natural, specific, no keyword-stuffing. You MUST weave each of these editorial links inline as `<a href=\"HREF\">ANCHOR</a>` inside sentences (not a list): {internal_links as HREF/ANCHOR pairs}."*
- **Write:** `supabaseAdmin.from('content_pages').update({ body: text, updated_at: now }).eq('id', pageId)`. Leave `title/h1/slug/type/target_keyword/internal_links/status` untouched. Return `{ ok: true, pageId }`.
- **Do NOT** regenerate title/h1/meta here (deterministic SEO formula stays; the agency edits meta in 3c-1). One `generateText` call only — no loops, no per-service fan-out (Worker 30s).

### UI — Pages list (in `admin.seo.tsx`)
- A per-row **"AI-write"** button → `window.confirm("This replaces the page body with AI-generated content.")` → `aiWritePage({ data: { pageId } })` → pending spinner (the call takes a few seconds) → on success invalidate the pages query + toast `Rewrote {title}`; `onError` toast. (Also fine to add the button inside the edit dialog.)

## B. `saveSeoMap` — title-case normalization
In `saveSeoMap` (`seo.functions.ts`), **after** the uniqueness + reserved-slug guards and **before** building `merged`, normalize names (slugs unchanged):
- A `titleCase(s)` helper: split on whitespace; for each word, **if the word is all-lowercase, capitalize its first letter; otherwise leave it as-is** (preserves acronyms like `HVAC`, `AC`, `LLC`).
- Apply to `data.seo.primary_category` and every `category.name` + `service.name`; keep all `slug`s exactly as-is.
- Use the normalized object as `seo:` in `merged` and in the returned `seo`.
- Effect: `"lawn care"` → `"Lawn Care"` (so `seedCoreThirty` titles/H1 read "Lawn Care {city}"); `"HVAC"` stays `"HVAC"`. Existing rows are fixed by re-Generate or 3c-1 edit.

## Guardrails
- **ZERO schema/migration.** Only: `aiWritePage` + `titleCase` in `seo.functions.ts`, a button in `admin.seo.tsx`.
- `aiWritePage` = **exactly one `generateText` call** (Worker-safe); rewrites **`body` only**; preserves one-H1 (no `<h1>` in body) + re-embeds the editorial `<a>` links.
- Writes via service-role (`assertAgencyAdmin`, `statusCode`-on-throw). No new grant/policy.

## Drift check (report back)
1. Files: `seo.functions.ts` (+`aiWritePage`, +`titleCase` in `saveSeoMap`), `admin.seo.tsx` (+AI-write button). No migration.
2. `aiWritePage` = one `generateText` call; updates `body` only; body has no `<h1>` and contains the `internal_links` as inline `<a>`.
3. `saveSeoMap` title-cases names, leaves slugs unchanged, preserves acronyms.

## VALIDATION
1. On a **service** page, click **AI-write** → body becomes locally-specific `{city}` prose, **starts at `<h2>` (no `<h1>`)**, and contains the row's editorial `<a href="/services/...">` inline in sentences.
2. Publish that page → the **STORE-2** route renders the new body with the editorial links in-content.
3. **`internal_links`/title/h1/slug/type unchanged** after AI-write (only `body` + `updated_at` changed).
4. Add a category **"lawn care"** + a service **"HVAC repair"** in the map → **Save** → stored as **"Lawn Care"** + **"HVAC Repair"** (acronym preserved); slugs still `lawn-care`/`hvac-repair`. Re-run **Generate Core-30** (on a fresh slug) → title/H1 are Title-Cased.
5. Missing `LOVABLE_API_KEY` → clear toast (not a silent failure). Non-admin blocked.
6. `audit_tenant_rls()` unaffected; no migration in the diff.

## Status
**HELD — awaiting review.** Completes the SEO content-store arc (STORE-1 store → 2 render routes → 3a map → 3b seed → 3c-1 manage → 3c-2 write). After this: the content-automation tool (ongoing supporting/geo + rank-map) is a separate future module.
