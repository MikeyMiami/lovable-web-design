# SEO — `content_pages` content store + template render routes — READ-ONLY SCOPE

> Scope/plan only — **no code, no build prompts.** The CMS-backed endpoint behind `/seo-build` §4: pages are DATA the site renders; the build + the content-automation tool WRITE rows, never edit the frontend. Grounded on `cloud-spark-setup` `origin/main` @ `91a90d3`. Awaiting sign-off.

## 0. The one net-new decision that drove everything — RLS (verified against the live audit)
`audit_tenant_rls()` (current) derives every **base table with a `client_id` column (except `clients`)** as a tenant table and then **flags any policy whose `USING`/`WITH CHECK` lacks `(user_client_ids|is_admin)\s*\(`** — for **SELECT, INSERT, UPDATE, DELETE**. So:
- **A direct anon SELECT policy `USING (status='published')` FAILS the audit** (no tenant membership check). → **Anon public read must go through a `SECURITY DEFINER` RPC**, exactly like `get_client_public` (the `clients` table already does this + the audit even forbids anon policies on `clients`).
- This is the **opposite** of the `onboarding_tokens` call: there we named the column `created_client_id` to keep the table OUT of the tenant scan. Here `client_id` is intentional — `content_pages` IS a tenant table, so it must **carry a tenant-scoped policy + PASS `audit_tenant_rls()=0`**, and expose anon reads via an RPC (never a direct anon policy).

## 1. `content_pages` table shape (per `/seo-build` §4)
```sql
create table public.content_pages (
  id               uuid primary key default gen_random_uuid(),
  client_id        uuid not null references public.clients(id) on delete cascade,
  slug             text not null,                 -- unique per client
  type             text not null,                 -- 'home'|'category'|'service'|'supporting'|'geo' (free text; check optional)
  title            text,                          -- <title> (seo-build §3 formula)
  meta_description text,
  h1               text,
  body             text,                          -- markdown/html
  schema_jsonld    jsonb,                         -- LocalBusiness/Service/FAQPage/... (seo-build §3)
  target_keyword   text,
  internal_links   jsonb,                         -- editorial in-content links (seo-build §2)
  external_link    text,                          -- the "not-AI-slop" outbound slot (seo-content §6)
  og_image         text,
  status           text not null default 'draft', -- 'draft'|'published'
  published_at     timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create unique index uq_content_pages_client_slug on public.content_pages(client_id, slug);
create index idx_content_pages_client_status on public.content_pages(client_id, status);
create index idx_content_pages_client_type   on public.content_pages(client_id, type);
```

## 2. RLS design [LOCKED to the get_client_public posture — passes the audit]
```sql
alter table public.content_pages enable row level security;

-- Authenticated tenant READ (admins across all; client_owner their own). Satisfies the audit
-- (qual references BOTH is_admin and user_client_ids).
create policy content_pages_tenant_read on public.content_pages
  for select to authenticated
  using ( public.is_admin((select auth.uid()))
          or client_id in (select public.user_client_ids((select auth.uid()))) );

-- WRITES: service-role ONLY (no authenticated write policy). The per-client build, the
-- content tool, and the admin publish action all go through service-role server fns
-- (supabaseAdmin bypasses RLS) — same pattern as the ticket write fns. NO anon policy.
revoke all on public.content_pages from anon;   -- anon reads via the RPC below, never the table
```
```sql
-- ANON public read = SECURITY DEFINER RPCs (mirror get_client_public; NO anon table policy).
-- One page (by client slug + page slug), published only:
create or replace function public.get_client_page(_slug text, _page_slug text)
returns setof public.content_pages
language sql stable security definer set search_path = public as $$
  select cp.* from public.content_pages cp
  join public.clients c on c.id = cp.client_id
  where c.slug = _slug and c.status = 'active' and c.deleted_at is null
    and cp.slug = _page_slug and cp.status = 'published';
$$;
-- All published pages for a client (sitemap + Locations index + nav):
create or replace function public.get_client_pages(_slug text)
returns setof public.content_pages
language sql stable security definer set search_path = public as $$
  select cp.* from public.content_pages cp
  join public.clients c on c.id = cp.client_id
  where c.slug = _slug and c.status = 'active' and c.deleted_at is null
    and cp.status = 'published';
$$;
revoke all on function public.get_client_page(text,text)  from public;
revoke all on function public.get_client_pages(text)      from public;
grant execute on function public.get_client_page(text,text) to anon, authenticated;
grant execute on function public.get_client_pages(text)     to anon, authenticated;
```
*(RPCs filter `status='published'` + gate on the client being active — so anon only ever sees live pages of live clients. `body` etc. are public site content — no PII to strip, unlike `clients`.)*

**Post-migration gate:** `select * from public.audit_tenant_rls()` → **must return 0 rows** (the tenant read policy is the only `content_pages` policy; it's tenant-scoped; anon has no table policy).

## 3. Dynamic render routes (the marketing template builds these ONCE)
The per-client Remix knows its `VITE_CLIENT_SLUG`; it calls `get_client_pages(slug)` (nav/sitemap/Locations) + `get_client_page(slug, pageSlug)` (a page) via anon, then renders + applies **`/seo-build` §1/§3** (schema, meta, one-H1, semantic HTML, canonical, OG, breadcrumbs, editorial internal links).
| Route | Renders |
|---|---|
| `/` | the `type='home'` row (+ the 8 GBP-consistency signals, `/seo-build` §1) |
| `/services` | **generated index** (from `get_client_pages`) listing category → service pages |
| `/services/$slug` | a `type='category'` OR `type='service'` row (resolved by slug) |
| `/service-area/$slug` | a `type='geo'` row |
| `/$slug` | a `type='supporting'` row *(**lowest routing precedence** — must not shadow `/about`,`/contact`,`/gallery`, compliance, or the funnel routes; only match known supporting slugs)* |
| Locations index (`/locations` or `/service-area`) | **generated list** of all `type='geo'` pages |
| `/sitemap.xml` | **generated** from all published rows |
| `/robots.txt` | static (allow crawl + sitemap ref) |

**Precedence flag [must-decide]:** `/$slug` is a catch-all — it must sit BELOW all fixed routes (about/contact/gallery/discount/review/thank-you/terms/privacy/sms-program) so those win; a supporting page whose slug collides with a fixed route is rejected at write time.

## 4. Write path [LOCKED — write rows only, never edit the frontend]
- **Per-client build (at launch/finalize):** a service-role server fn (`seedCoreThirty(clientId)`) reads the client's **categories + services-by-category** (from the admin SEO panel / `template_vars`) → generates first-pass Core-30 copy (the lighter `/seo-content` pass) → **inserts** `home` + `category` + `service` rows (`status='published'` or `'draft'`).
- **Content-automation tool (ongoing):** writes `supporting`/`geo` rows (draft → agency reviews → publish) via service-role.
- **Admin publish/edit:** a service-role fn (draft↔published, edit body) — the admin SEO panel calls it (ticket-fn pattern: read via RLS, write via service-role).
- **All three only INSERT/UPDATE rows.** The template is a **generic renderer** — it never changes per page. **Publishing = inserting a row / flipping `status` to `published`.** No frontend edit, ever.

## 5. Net-new schema vs reused
- **NET-NEW (this migration only):** the `content_pages` table + its indexes + the 1 tenant read policy + the 2 anon-read RPCs (`get_client_page`, `get_client_pages`). That's the entire schema footprint.
- **REUSED (no changes):** `is_admin()` / `user_client_ids()` RLS helpers; the `audit_tenant_rls()` gate; the **`get_client_public` SECURITY-DEFINER anon-read pattern**; the service-role write pattern (`supabaseAdmin`); the marketing-site anon-read + `VITE_CLIENT_SLUG` resolution. **No existing table/column/fn is modified.**

## 6. MIGRATION FLAG [explicit]
- **ONE additive migration** = the `content_pages` table + indexes + the tenant read policy + the 2 anon RPCs. **Additive on `golden-master-v1.7`** (like `onboarding_tokens` was — additive, app-layer-on-v1.7). It is a **genuine schema add** (a real tenant table), so it MUST: enable RLS, carry the tenant read policy, expose anon reads via the RPCs (NOT a direct anon policy), and **preserve `audit_tenant_rls()=0`**. Re-tag optional (recommend recording it in the build-log like `onboarding_tokens`; no re-tag needed unless you want a `v1.x` marker).

## 7. Slicing recommendation
- **SEO-STORE-1 — the store (schema).** The migration (§1/§2): table + tenant policy + anon RPCs + indexes. Validate: table shape, `audit_tenant_rls()=0`, anon `get_client_page`/`get_client_pages` return only published/active, direct anon table SELECT denied. **The schema slice — do first.**
- **SEO-STORE-2 — the render routes (template/frontend, Phase A).** The dynamic routes (§3) baked into the style template(s) via `/template-builder`, reading via the RPCs + applying `/seo-build`. Validate with a **manually-seeded published row** → the page renders with correct title/schema/canonical/links; sitemap lists it.
- **SEO-STORE-3 — the write path.** `seedCoreThirty` (first-pass Core-30 writer) + the **admin SEO panel** (categories / services-by-category / geo input that feeds it). Validate: finalize a client → Core-30 rows exist → the site renders them.
- **(Later) content-automation tool** — the ongoing writer (`supporting`/`geo` + the rank-map loop). Its own module.

**Sequence:** SEO-STORE-1 (store) → SEO-STORE-2 (routes, test with a seeded row) → SEO-STORE-3 (seeder + admin panel) → tool.

## 8. Open questions to settle (before SEO-STORE-1)
1. **Anon read shape** — the 2 RPCs (`get_client_page` + `get_client_pages`) as specced, returning full rows? (vs a narrower projection — but there's no PII to hide, so full rows are fine.) *(Rec: as specced.)*
2. **`/$slug` supporting route precedence** — confirm supporting pages live at `/$slug` (lowest precedence, collision-rejected at write) vs a prefixed namespace like `/guides/$slug` (zero collision risk, slightly less clean URLs). *(Rec: `/$slug` with write-time collision guard; fall back to a prefix if routing precedence is fragile in TanStack.)*
3. **First-pass Core-30 at build = `published` or `draft`?** Publish immediately, or land as draft for agency review in the SEO panel before going live? *(Rec: `draft` → agency publishes from the panel; but a "publish all" is one click.)*
4. **Migration marker** — record additive-no-retag (like `onboarding_tokens`), or cut a `v1.8`-style tag? *(Rec: additive-no-retag + build-log record.)*

---
**Read-only scope. ZERO existing-schema change; ONE additive table + 2 anon RPCs (the whole footprint). Anon read = the get_client_public RPC posture (a direct anon policy WOULD fail `audit_tenant_rls()`). Slices: store → render routes → seeder/panel → tool.**
