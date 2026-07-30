# Demo Clients — Build Spec v2 (respecced 2026-07-29)

> **Supersedes** the 2026-07-24 D1–D4 spec in memory (`project_backlog_template_demo_showroom_state`). That version was written before the CFL remix, the Call-Now pill / hero CTA, the two new copy slots, `VITE_SITE_URL`, single-tier, and the production-readiness audit. Every claim below was re-verified against `cloud-spark-setup@8b33707` and `pro-style-shell` / `professional-landscpaing-template` at `origin/main` on 2026-07-29.

**Goal:** fill out a few basics about a prospect → get a shareable link that renders a complete, branded marketing site for *their* business, using the existing published template. No remix, no republish, no onboarding, no A2P, zero risk to live client sending.

**Demo link shape:** `https://<published-template-url>/?demo=<slug>` — one published template serves unlimited prospects. Pick which style they see by choosing which template's URL you send.

---

## What the scope pass CHANGED from the v1 spec

| v1 spec said | Reality (verified) | Resolution |
|---|---|---|
| "ALL existing surfaces filter out `is_demo`" | ~100 `.from("clients")` read sites. Almost all are **by-id / by-slug / by-number** lookups — harmless. Only **3** enumerate clients. | Filter exactly **3** surfaces (§3). Do NOT touch the other ~97. |
| "NO `allowed_origins` → CORS rejects all form posts → zero contacts/drips" | **FALSE — this was the safety model and it has a hole.** `resolveTenant()` falls back to `resolveTenantBySlug()`, which matches on `slug` + `status='active'` and **never checks `allowed_origins`**. All three template forms post `slug` in the body (`LeadForm.tsx:59`, `DiscountForm.tsx:47`, `ChatWidget.tsx:84`). | **Two-layer fix (§4).** Template: `?demo=` must not enable live posting. App: hard `is_demo` guard in the resolver. |
| Collect a "niche" | The template hardcodes `site_style: "professional_modern"` in `mapPublicRowToClient`, and hero/gallery images come from the template's own `NICHE_DEFAULTS` static imports. Niche is not a data field the template reads. | **DROP niche.** Each template *is* a niche. |
| Logo → public-assets | Correct — `site-image-upload.ts` uses the `public-assets` bucket. | Keep. Logo stays **optional**. |
| Fallback to Evergreen demo | **Already free:** `fetchClient()` returns `demoClient` on any non-ok response or throw. | No work needed; just don't break it. |
| Auto-purge "joins the cron re-enable batch" | **pg_cron went live 2026-07-29.** | Manual button ships in v1 (spec'd); optional cron SQL provided in §7. |

### Also verified (so the demo renders correctly)
- **No images required.** Fallback chain is `galleryUrls` → `template_vars.site_assets.work_examples` → `NICHE_DEFAULTS`. A demo with zero images shows the template's stock niche photos.
- **No `content_pages` rows required.** `routes/index.tsx` (home) is a static route off client data. `content_pages` drives only the SEO page tree, which a demo doesn't need.
- **Services must be seeded to `template_vars.services_structured`**, NOT `template_vars.services` — `mapPublicRowToClient` reads `services_structured` and maps `{name, slug, description}`.
- **Email displays from `template_vars.support_email`**, not `clients.email`.
- `brand_color` already falls back to the demo client's colour if blank.
- `get_client_public` filters `status='active' AND deleted_at IS NULL` → a demo **must** be `status='active'` to be readable. It is. **No RPC change needed.**

### Not polluted — deliberately leave alone
- `agency.tsx` "Pending" badge → counts **tickets**, not clients.
- `agency.tsx` onboardingCount + `agency.onboarding.tsx` → `status='pending'`; demos are `'active'`.
- `admin.review.tsx` → by-id.
- **The drip runner** → a demo has zero enrollments (§4 guarantees it), so `claim_due_enrollments` finds nothing. No runner change, ever.

---

## §1 — Schema (additive)

```
clients.is_demo          boolean NOT NULL DEFAULT false
clients.demo_expires_at  timestamptz NULL
```
Partial index: `CREATE INDEX ix_clients_is_demo ON clients(demo_expires_at) WHERE is_demo;`
Columns only — no RLS change (admin already sees all clients via `is_admin()`).

## §2 — Creation (`createDemoClient`)

A **dedicated** server fn — do NOT reuse `insertClientFull` (it writes immutable submission JSON and moves EIN letters; neither applies).

Agency-admin gated. Inputs (only business name is required):

| Field | Lands in |
|---|---|
| Business name **(required)** | `business_name`; slug = `demo-{slugify(name)}-{4 rand chars}` |
| Address | `address` |
| Phone | `phone_display` (E.164-normalized server-side, same normalizer as `twilio_number`) |
| Tagline | `tagline` |
| City / service area | `service_area[]` + `template_vars.seo.city` |
| Logo | `public-assets` → `logo_url` |
| Brand colour | `brand_color` |
| Secondary / tertiary | `template_vars.brand_secondary` / `brand_tertiary` |
| Services (names) | `template_vars.services_structured` = `[{name, slug: slugify(name), description: ""}]` |

Fixed on insert: `status='active'`, `is_demo=true`, `demo_expires_at = now() + 14 days`, `allowed_origins = '{}'`, `chat_widget_enabled = true`, no telnyx/twilio config, no `send_settings` row (`loadSendSettings` defaults), no `content_pages`.

Seed defaults for anything left blank so the site never renders half-empty: `about_us`, `differentiators`, `support_email`, `lead_form_headline/subhead/cta`, `chat_widget_greeting/confirmation`, `hours`, and 3 generic services if none given.

## §3 — Filter demos out of exactly THREE surfaces

1. `src/routes/_authenticated/agency.access.tsx` — Payment Access list → add `.eq("is_demo", false)`
2. `src/routes/_authenticated/admin.tsx` — admin client switcher → add `.eq("is_demo", false)` (demos are managed only from the Demo Clients tab)
3. `src/lib/seo/seo.functions.ts` → `listSeoStatus` — SEO cadence worklist → add `.eq("is_demo", false)` **(otherwise every demo shows up as SEO-review-due)**

## §4 — Safety: writes must be impossible (BOTH layers)

**Layer 1 — template (primary).** `?demo=` changes **only the displayed data**. It must NOT alter `isDemoMode()` or `getClientSlug()`. Consequence chain: `isDemoMode()` stays `true` → forms keep their existing no-op-with-toast behavior → `getClientSlug()` stays `""` → `if (slug) payload.slug = slug` never fires → nothing is ever POSTed. Zero write-path code changes.

**Layer 2 — app (defense in depth, closes the specced hole).** In `tenant-resolver.server.ts`, both `resolveTenantByOrigin` and `resolveTenantBySlug` select `is_demo` and **return null when true**. A hand-crafted POST carrying a demo slug then resolves to no tenant → 403. This is the actual guarantee; Layer 1 is what makes it never come up.

Net effect: a demo can never create a contact, an enrollment, a message, or a send — so it can never reach the runner, a cap, or Telnyx.

## §5 — Agency tab: "Demo Clients"

New route `agency.demos.tsx`; nav entry in `agency.tsx` after "Payment Access" (`tabs` array, ~line 91). Create form (§2) + list showing business name, slug, **days left**, a copy-link control per published template URL, and Delete. Plus a **"Purge expired"** button.

## §6 — Purge (`purgeDemoClient`)

Agency-admin gated. **Hard-guarded: re-read the row and abort unless `is_demo === true`** (never allow an id-only delete path to touch a real client). Hard-deletes the client row (FK CASCADE clears any stray events) and best-effort removes the logo object from `public-assets`. Expired demo link → `get_client_public` returns nothing → `fetchClient()` falls back to the Evergreen demo. Graceful by construction.

## §7 — Optional auto-purge (SQL editor, after §6 ships)

```sql
SELECT cron.schedule('purge-expired-demos','41 5 * * *', $$
  DELETE FROM public.clients
  WHERE is_demo = true AND demo_expires_at < now()
$$);
```
Guarded on `is_demo = true`. Storage objects are not reclaimed by this — run the manual button periodically, or leave the tiny logo files.

## §8 — Template change (`?demo=<slug>`) — apply to BOTH templates

In `src/lib/client-data.tsx`:
- Add a runtime demo-slug resolver: read `?demo=` from the URL, persist to `sessionStorage` (so internal navigation keeps it), **and only honor it when the baked `VITE_CLIENT_SLUG` is blank** — a real client remix has a slug baked in and is therefore completely immune.
- `fetchClient()` uses `demoSlug ?? SLUG` for the `get_client_public` call. Everything else unchanged; the existing failure fallback to `demoClient` covers expired/bad slugs.
- **`isDemoMode()` and `getClientSlug()` must keep returning exactly what they return today** (see §4 Layer 1). This is the load-bearing invariant of the whole feature.

## §9 — Validation

1. Create a demo → open `template-url/?demo=<slug>` → name/logo/colours/services/address render; navigate away and back (sessionStorage holds).
2. Bad slug `?demo=nope` → Evergreen demo renders (no crash, no blank).
3. **Submit the lead form on the demo → nothing is written.** Verify: `SELECT count(*) FROM contacts WHERE client_id='<demo>'` = 0, same for `enrollments`, `messages`.
4. `?demo=` on a REAL client remix → **ignored** (baked slug wins).
5. Demo absent from: admin client switcher, Payment Access, SEO Status worklist.
6. Purge → row gone; the demo link now shows Evergreen.
7. Live-client regression: one real client's site still renders and its lead form still posts.
