# Phase C — C-3d-1: token model + generate-link + public mode-aware wizard shell (the schema slice)

> First C-3d slice. **One additive schema object (`onboarding_tokens`); everything else app-layer.** Held for review. Verified against `cloud-spark-setup` `origin/main` @ `807618d`.

## Scope
- **`onboarding_tokens`** table (additive migration) + single-use/expire model.
- **`generateOnboardingLink`** admin server fn → a token + 14-day expiry.
- **/agency Onboarding** gains a "New Client → Generate onboarding link" action (copyable URL).
- **Public `/onboard/$token`** route (NOT `_authenticated`) → validate token → render the wizard in **client mode**; friendly errors for invalid/expired/claimed.
- **`OnboardWizard` made mode-aware** (`agency` | `client`) and reusable by both routes.
- **Client-mode uploads + submit are GATED** in C-3d-1 (uploads = C-3d-2; submit + mode-aware success = C-3d-3). Agency self-fill unchanged.

## Verified facts / decisions
- `createClientFull` (admin-gated, `status:"pending"` at insert) is **untouched in C-3d-1**. **F3 (extract a shared `insertClientFull` helper) is deferred to C-3d-3** — that's when the public submit becomes the second caller. **Regression owed in C-3d-3:** after the insert logic moves into the shared helper, the authed self-fill `/onboard` must still create a **pending** client correctly.
- **G1 guardrail [IMPORTANT]:** `audit_tenant_rls()` + `export_client_bundle` derive tenant tables by the **exact column `client_id`** (only `user_roles` excluded). So the token table's nullable created-client FK is named **`created_client_id`** (NOT `client_id`) → the table stays OUT of the tenant scan → service-role-only RLS (no policies) passes the audit, like `rate_limit_hits`. No guardrail-function edits.
- `OnboardWizard` is currently the route component in `src/routes/_authenticated/onboard.tsx` (component at ~`:188`, create→`createClientFull` at `:318`, success screen `:341`). C-3d-1 extracts/exports it with a `mode` prop; **agency mode behavior must be identical (regression).**
- Public-route + service-role pattern reused from `intake.ts`. Token reads/writes go through server fns using `supabaseAdmin` (table is service-role-only).

## Schema flag (the one touch)
**`onboarding_tokens` — additive migration.** No other schema/contract change in C-3d-1. (Turnstile + rate-limit land on the **write** paths: upload proxy C-3d-2, public submit C-3d-3.)

---

# PROMPT C-3d-1 — paste into Lovable

> **One additive migration (`onboarding_tokens`) + app-layer code. NO other schema, NO fn-contract change to existing fns** (`createClientFull` untouched). Report files changed + the migration.

## 1. Migration (additive) — `onboarding_tokens`
```sql
create table if not exists public.onboarding_tokens (
  token             text primary key,
  draft_id          text not null,                 -- storage namespace for pre-submit uploads (reuses the wizard draftId pattern)
  status            text not null default 'active', -- 'active' | 'claimed' (free text)
  claimed_at        timestamptz,
  expires_at        timestamptz not null,
  created_client_id uuid references public.clients(id) on delete set null,  -- set on submit (C-3d-3). NAMED created_client_id (NOT client_id) so the table stays out of the tenant-table catalog scan used by audit_tenant_rls()/export_client_bundle.
  created_by        uuid,                           -- agency user who generated the link
  prefill           jsonb,
  created_at        timestamptz not null default now()
);
alter table public.onboarding_tokens enable row level security;
-- Service-role only: NO policies. All access via server fns using supabaseAdmin.
revoke all on public.onboarding_tokens from anon, authenticated;
create index if not exists idx_onboarding_tokens_active on public.onboarding_tokens(status) where status = 'active';
```
**Single-use enforcement** (claim happens at submit, C-3d-3): `update public.onboarding_tokens set status='claimed', claimed_at=now() where token=$1 and status='active'` — idempotent (0 rows ⇒ already claimed).

## 2. `src/lib/clients/onboarding.functions.ts` — two new server fns (do NOT touch `createClientFull`)
```ts
// Admin: generate a one-time onboarding link (14-day expiry).
const GenerateOnboardingLinkInput = z.object({ prefill: z.record(z.any()).optional() });
export const generateOnboardingLink = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => GenerateOnboardingLinkInput.parse(d))
  .handler(async ({ data, context }) => {
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    await assertAgencyAdmin(supabaseAdmin, context.userId as string);
    const token = crypto.randomUUID();
    const draftId = crypto.randomUUID();
    const expiresAt = new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString();
    const { error } = await supabaseAdmin.from("onboarding_tokens").insert({
      token, draft_id: draftId, status: "active", expires_at: expiresAt,
      created_by: context.userId, prefill: data.prefill ?? null,
    });
    if (error) throw new Error(error.message);
    return { token, draftId, expiresAt };
  });

// Public (NO auth): validate a token for the public wizard. Service-role read; returns minimal state only.
const ValidateOnboardingTokenInput = z.object({ token: z.string().min(1).max(200) });
export const validateOnboardingToken = createServerFn({ method: "POST" })
  .inputValidator((d: unknown) => ValidateOnboardingTokenInput.parse(d))
  .handler(async ({ data }) => {
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const { data: row, error } = await supabaseAdmin
      .from("onboarding_tokens")
      .select("token, draft_id, status, expires_at, prefill")
      .eq("token", data.token)
      .maybeSingle();
    if (error) throw new Error(error.message);
    if (!row) return { state: "not_found" as const };
    if (row.status === "claimed") return { state: "claimed" as const };
    if (new Date(row.expires_at).getTime() <= Date.now()) return { state: "expired" as const };
    return { state: "valid" as const, draftId: row.draft_id as string, prefill: (row.prefill ?? null) as unknown };
  });
```
(`assertAgencyAdmin`, `requireSupabaseAuth`, `createServerFn`, `z` are already imported/defined in this file. `createClientFull` is unchanged.)

## 3. `OnboardWizard` → mode-aware + reusable
Extract the wizard into a shared component **`src/components/onboard/OnboardWizard.tsx`** (move it out of `admin.settings`-style inline) exporting:
```tsx
export function OnboardWizard({ mode, draftId, prefill }: {
  mode: "agency" | "client";
  draftId?: string;       // client mode: the token's draft_id namespace
  prefill?: any;          // client mode: optional prefilled values
}) { /* … */ }
```
- **Agency mode (`mode="agency"`)** — current behavior **unchanged**: the admin-authz check, the create flow via `createClientFull`, the existing success screen. `src/routes/_authenticated/onboard.tsx` now just renders `<OnboardWizard mode="agency" />`.
- **Client mode (`mode="client"`)** — **no** admin-authz check (public); seed `draftId` from the prop (instead of generating one); apply `prefill` if present. **Gate the not-yet-built paths in C-3d-1:**
  - **Uploads** (logo + photos) — disabled with an inline note "Uploads enable shortly" (wired in C-3d-2).
  - **Final submit** — disabled with an inline note "Submitting enables shortly" (wired in C-3d-3); do NOT call `createClientFull` in client mode.
  - The mode-aware success screen is C-3d-3.

## 4. `src/routes/onboard.$token.tsx` (NEW, PUBLIC — not under `_authenticated`)
```tsx
import { createFileRoute, useParams } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { validateOnboardingToken } from "@/lib/clients/onboarding.functions";
import { OnboardWizard } from "@/components/onboard/OnboardWizard";

export const Route = createFileRoute("/onboard/$token")({
  head: () => ({ meta: [{ title: "Onboarding" }] }),
  component: PublicOnboard,
});

function PublicOnboard() {
  const { token } = useParams({ from: "/onboard/$token" });
  const { data, isLoading, error } = useQuery({
    queryKey: ["onboard-token", token],
    queryFn: () => validateOnboardingToken({ data: { token } }),
    retry: false,
  });

  if (isLoading) return <Centered>Loading…</Centered>;
  if (error) return <Centered>Something went wrong. Please ask your agency for a new link.</Centered>;
  if (!data) return <Centered>Invalid link.</Centered>;
  if (data.state === "not_found") return <Centered>This onboarding link is invalid.</Centered>;
  if (data.state === "claimed") return <Centered>This link has already been used. Ask your agency for a new one.</Centered>;
  if (data.state === "expired") return <Centered>This link has expired. Ask your agency for a new one.</Centered>;

  return (
    <div className="min-h-screen bg-background">
      <OnboardWizard mode="client" draftId={data.draftId} prefill={data.prefill} />
    </div>
  );
}

function Centered({ children }: { children: React.ReactNode }) {
  return <div className="min-h-screen grid place-items-center p-8 text-center text-sm text-muted-foreground max-w-md mx-auto">{children}</div>;
}
```

## 5. `src/routes/_authenticated/agency.onboarding.tsx` — generate-link action
At the top of the Onboarding queue page, add a **"New Client → Generate onboarding link"** button. On click → `generateOnboardingLink({ data: {} })` → build `const url = \`${window.location.origin}/onboard/${token}\`` → show it in a read-only input + a **Copy** button + the 14-day expiry. (A `useMutation` + a small local state for the generated URL.)

## Drift check (report back)
1. Migration `onboarding_tokens` (additive, service-role-only RLS, `created_client_id` NOT `client_id`). `onboarding.functions.ts` (+`generateOnboardingLink`, +`validateOnboardingToken`; `createClientFull` untouched). NEW `OnboardWizard.tsx` (mode-aware) + `_authenticated/onboard.tsx` renders `mode="agency"`. NEW `onboard.$token.tsx`. `agency.onboarding.tsx` (+generate-link).
2. **No other schema change; no fn-contract change to existing fns.** `createClientFull` unchanged (F3 is C-3d-3).
3. **`select audit_tenant_rls('<any admin uuid>')` (or the canonical call) still returns clean / 0** — `onboarding_tokens` is NOT in the tenant scan (`created_client_id`).
4. `tsc` passes.

---

# VALIDATION — C-3d-1 (as `itsmikeymiami`)

1. **Migration + guardrail:**
   ```sql
   select column_name from information_schema.columns where table_name='onboarding_tokens' order by 1;
   -- EXPECT: claimed_at, created_at, created_by, created_client_id, draft_id, expires_at, prefill, status, token (NO 'client_id').
   ```
   Re-run the RLS audit (the canonical `audit_tenant_rls(...)` call used elsewhere) → **still clean / 0** (onboarding_tokens not treated as a tenant table).
2. **Generate link:** `/agency` → Onboarding → "Generate onboarding link" → a URL appears + Copy works. SQL:
   ```sql
   select token, status, expires_at > now() as not_expired, draft_id is not null as has_draft, created_by is not null as has_creator
   from public.onboarding_tokens order by created_at desc limit 1;
   -- EXPECT: status='active', not_expired=true, has_draft=true, has_creator=true; expires_at ≈ now()+14d.
   ```
3. **Public route — valid:** open the URL (in a logged-OUT browser/incognito) → the wizard renders in **client mode**, no login required; steps navigable; uploads + final submit show the "enables shortly" notes (gated).
4. **Public route — states:** 
   - `update public.onboarding_tokens set status='claimed' where token='<t>';` → reopen → "already used".
   - `update public.onboarding_tokens set expires_at=now()-interval '1 day', status='active' where token='<t>';` → reopen → "expired".
   - open `/onboard/some-random-uuid` → "invalid".
5. **Regression (agency self-fill):** `/onboard` (authed) still walks the wizard and **creates a pending client** end-to-end (the component move didn't change agency behavior). SQL: `select status from public.clients where slug='<new>';` → `pending`.

**Pass:** token table additive + audit clean; generate-link produces a working 14-day URL; public route renders client-mode wizard for valid tokens and the right error for claimed/expired/invalid; uploads+submit gated; agency self-fill unchanged (pending create). Cleanup: `delete from public.onboarding_tokens where created_by='<me>';` + delete any test client.

### After C-3d-1 is green
→ **C-3d-2** (upload proxy: token-gated service-role write to `public-assets` under `draft_id`; Turnstile + rate-limit; client mode uses it). Then **C-3d-3** (public submit → shared `insertClientFull` → `status='pending'` + token claim + mode-aware success; **F3 + the self-fill regression check land here**).

---
**One additive table (`onboarding_tokens`, `created_client_id` to dodge the tenant scan). `createClientFull` untouched (F3 = C-3d-3 + regression). Client-mode uploads/submit gated until C-3d-2/3.**
