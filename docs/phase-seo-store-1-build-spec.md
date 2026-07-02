# SEO-STORE-1 — content_pages content store (migration) — build spec [BUILT + VALIDATED 2026-07-02]

> ONE additive migration on `golden-master-v1.7`; no existing table/column/fn touched. Shipped as `cloud-spark-setup` migration `20260702203549` (+ `20260702203923` = test-row cleanup). Validation: `docs/build-log/stage-seo-store-1-content-store-validation.md`. Scope: `docs/phase-seo-content-store-scope.md`.

## The prompt that shipped (verbatim)

> **ONE additive migration on `golden-master-v1.7`. NO existing table/column/fn is touched.** Creates the `content_pages` table + indexes + ONE authenticated tenant READ policy + 2 SECURITY DEFINER anon-read RPCs. Writes are **service-role only** (no write policy). Anon reads **only** via the RPCs (no anon table policy — a direct anon policy would fail the tenant audit). Report the migration + confirm `audit_tenant_rls()` returns **0 rows**.

```sql
create table if not exists public.content_pages (
  id               uuid primary key default gen_random_uuid(),
  client_id        uuid not null references public.clients(id) on delete cascade,
  slug             text not null,
  type             text not null,                 -- 'home'|'category'|'service'|'supporting'|'geo'
  title            text,
  meta_description text,
  h1               text,
  body             text,
  schema_jsonld    jsonb,
  target_keyword   text,
  internal_links   jsonb,
  external_link    text,
  og_image         text,
  status           text not null default 'draft', -- 'draft'|'published'
  published_at     timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create unique index if not exists uq_content_pages_client_slug    on public.content_pages(client_id, slug);
create index        if not exists idx_content_pages_client_status on public.content_pages(client_id, status);
create index        if not exists idx_content_pages_client_type   on public.content_pages(client_id, type);

grant all    on public.content_pages to service_role;
grant select on public.content_pages to authenticated;
revoke all   on public.content_pages from anon;

alter table public.content_pages enable row level security;

create policy content_pages_tenant_read on public.content_pages
  for select to authenticated
  using (
    public.is_admin((select auth.uid()))
    or client_id in (select public.user_client_ids((select auth.uid())))
  );

create or replace function public.get_client_page(_slug text, _page_slug text)
returns setof public.content_pages
language sql stable security definer set search_path = public as $$
  select cp.* from public.content_pages cp
  join public.clients c on c.id = cp.client_id
  where c.slug = _slug and c.status = 'active' and c.deleted_at is null
    and cp.slug = _page_slug and cp.status = 'published';
$$;

create or replace function public.get_client_pages(_slug text)
returns setof public.content_pages
language sql stable security definer set search_path = public as $$
  select cp.* from public.content_pages cp
  join public.clients c on c.id = cp.client_id
  where c.slug = _slug and c.status = 'active' and c.deleted_at is null
    and cp.status = 'published';
$$;

revoke all     on function public.get_client_page(text, text) from public;
revoke all     on function public.get_client_pages(text)      from public;
grant execute  on function public.get_client_page(text, text) to anon, authenticated;
grant execute  on function public.get_client_pages(text)      to anon, authenticated;
```

## Validation (as run — PASS)
- `select * from public.audit_tenant_rls();` → **0 rows** (load-bearing).
- `get_client_pages('test-landscaping')` → published-only; `get_client_page(...,'test-published')` → 1 row; `...,'test-draft'` → 0 rows.
- Drift clean: one additive migration; no existing schema touched; writes service-role only; anon reads only via the RPCs. Additive-no-retag.
