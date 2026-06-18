# Phase B-0 Build Spec — client login provisioning (`provisionClientOwner`)

> **Status:** APPROVED 2026-06-18 (spec). The implementation below is for sign-off **before it goes live**. From `main` @ this commit; target backend = `cloud-spark-setup` @ `golden-master-v1.6` (the fn is app-layer; **no migration**). Part of `docs/pathway-to-completion.md` Phase B-0 (do-first; gates all client access).

## 1. What's already built vs. what this builds
- **Already BUILT (live in `v1.6`), nothing to build:** `audit_log` table + append-only triggers (`audit_log_immutable`) + `user_roles_audit()` sole-writer trigger + `assign_user_role_audited`/`revoke_user_role_audited` RPCs + the test-admin backfill (migrations `20260615210212` + `20260615211022`, to the locked spec §730 design); `app_role` enum + `user_roles`; helpers `has_role`/`is_admin`/`is_agency_owner`/`user_client_ids`; `assignUserRole`/`revokeUserRole` server fns (verified authz matrix).
- **This spec builds ONLY:** the **auth-user provisioning flow** — `provisionClientOwner`. **Migration-free** (Supabase Auth admin API + the existing audited RPC). **B-0 opens NO backend; `golden-master-v1.7` stays the single later additive batch** (ticketing + consent persistence + payment-access flag + A2P columns).

## 2. Locked decisions
1. **Invite mechanism = `auth.admin.inviteUserByEmail`** — client clicks the magic link, sets their own password. (Supabase Auth SMTP dependency → §6 validation must-check.)
2. **`client_staff` = owner-invites-staff** — build only the `client_owner` path for v1 (the authz matrix already permits owner→staff within-tenant; UI later).
3. **Standalone now → wizard later** — `provisionClientOwner` is a standalone `admin`/`agency_owner`-gated server fn now; the Phase-C onboarding wizard calls the SAME fn at its final step. No rework.
4. **Client surface = PWA-only** — the client logs in as `client_owner`/`client_staff` on the mobile PWA only. The operator surfaces (agency account + per-client admin view) are agency-scoped (`admin`/`agency_owner`) and are NEVER payment-gated.

## 3. The fn — signature + 5-step behavior
`provisionClientOwner({ email, clientId, reason? })` (`createServerFn` POST + `requireSupabaseAuth`):
1. **Caller authz** (reuse the `assignUserRole` lookup): require the caller to be `admin` OR `agency_owner`; else `Forbidden`.
2. **(defensive) validate `clientId`** exists (and not archived).
3. **Create the auth user** via `supabaseAdmin.auth.admin.inviteUserByEmail(email, { redirectTo, data:{ client_id } })` → new `userId`. **Already-registered handling:** if invite errors because the email exists, resolve the existing `userId` (admin user lookup) and continue — the grant is idempotent.
4. **Audited grant:** `supabaseAdmin.rpc("assign_user_role_audited", { _actor: callerId, _reason, _user_id: userId, _role: "client_owner", _client_id: clientId })` → the `user_roles_audit()` trigger writes the `grant` row (`actor_source='fn'`).
5. **Return** `{ ok: true, userId, invited: <bool> }`.

**Baked-in notes:**
- `client_owner` only (v1). `redirectTo` points at a **temporary page for B-0** (the real client-PWA set-password route lands in Phase B). Audit is automatic (trigger). SMTP delivery is a validation must-check (§6).

## 4. Proposed implementation (FOR REVIEW — not yet live)
```ts
// cloud-spark-setup: src/lib/auth/provisioning.functions.ts  (NEW FILE — app-layer, no migration)
import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

const ProvisionClientOwnerInput = z.object({
  email: z.string().email().max(254),
  clientId: z.string().uuid(),
  reason: z.string().max(500).optional(),
});

// B-0: temporary magic-link target. Phase B swaps this for the client PWA's
// set-password/callback route (app.theirdomain.com). Env-overridable.
const INVITE_REDIRECT =
  (import.meta.env.VITE_INVITE_REDIRECT_URL as string | undefined) ?? undefined;

export const provisionClientOwner = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input: unknown) => ProvisionClientOwnerInput.parse(input))
  .handler(async ({ data, context }) => {
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const callerId = context.userId;

    // 1. Caller authz — platform admin / agency_owner only (same pattern as assignUserRole).
    const { data: callerRoles, error: rolesErr } = await supabaseAdmin
      .from("user_roles")
      .select("role")
      .eq("user_id", callerId);
    if (rolesErr) throw new Error("Failed to verify caller");
    const isPlatformAdmin = (callerRoles ?? []).some(
      (r) => r.role === "admin" || r.role === "agency_owner",
    );
    if (!isPlatformAdmin) throw new Error("Forbidden");

    // 2. Defensive: the target client must exist (and not be archived).
    const { data: client, error: clientErr } = await supabaseAdmin
      .from("clients")
      .select("id, status, deleted_at")
      .eq("id", data.clientId)
      .maybeSingle();
    if (clientErr) throw new Error("Failed to verify client");
    if (!client || client.deleted_at) throw new Error("Client not found");

    // 3. Create/invite the auth user → userId. Idempotent on already-registered.
    let userId: string | undefined;
    let invited = false;
    const { data: inv, error: invErr } =
      await supabaseAdmin.auth.admin.inviteUserByEmail(data.email, {
        redirectTo: INVITE_REDIRECT,
        data: { client_id: data.clientId },
      });
    if (invErr) {
      // Most likely: the email already has an auth user. Resolve the existing id.
      userId = await findExistingUserId(supabaseAdmin, data.email);
      if (!userId) throw new Error(`Invite failed: ${invErr.message}`);
    } else {
      userId = inv?.user?.id;
      invited = true;
    }
    if (!userId) throw new Error("Could not resolve user id after invite");

    // 4. Audited grant of client_owner (trigger writes audit_log with actor_source='fn').
    const { error: rpcErr } = await supabaseAdmin.rpc("assign_user_role_audited", {
      _actor: callerId,
      _reason: data.reason ?? "provision client_owner",
      _user_id: userId,
      _role: "client_owner",
      _client_id: data.clientId,
    });
    if (rpcErr) throw new Error(rpcErr.message);

    return { ok: true, userId, invited };
  });

// Resolve an existing auth user's id by email (no direct getUserByEmail in the
// admin SDK; page through listUsers). Small client lists at our scale.
async function findExistingUserId(
  supabaseAdmin: { auth: { admin: { listUsers: (a: { page: number; perPage: number }) => Promise<{ data: { users: { id: string; email?: string }[] }; error: unknown }> } } },
  email: string,
): Promise<string | undefined> {
  const target = email.toLowerCase();
  for (let page = 1; page <= 20; page++) {
    const { data, error } = await supabaseAdmin.auth.admin.listUsers({ page, perPage: 200 });
    if (error) break;
    const hit = data.users.find((u) => (u.email ?? "").toLowerCase() === target);
    if (hit) return hit.id;
    if (data.users.length < 200) break; // last page
  }
  return undefined;
}
```
*(Review notes: `findExistingUserId` paginates `listUsers` — fine at our scale; if Supabase later exposes a direct email lookup, swap it in. `INVITE_REDIRECT` is env-overridable so Phase B points it at the real PWA route without code change. The grant uses the existing audited RPC verbatim.)*

## 5. Build + validation order (green path)
1. (audit_log already live — no build.)
2. **Build** `provisionClientOwner` (above) — no migration.
3. **Validate:**
   - a. Call `provisionClientOwner({ email: test@…, clientId: <test client> })`.
   - b. **Auth user created** — email in `auth.users` (`confirmed_at` null = invited, not yet accepted).
   - c. **Audit row** — `SELECT * FROM audit_log WHERE target_user_id=<userId>` → `action='grant'`, `payload->>'role'='client_owner'`, `payload->>'client_id'=<clientId>`, `payload->>'actor_source'='fn'`, `actor_user_id=<callerId>`.
   - d. **SMTP** — the invite email **actually arrives** (§6).
   - e. Accept invite → set password → sign in as the test user → query a tenant table (e.g. `contacts`) → **RLS returns ONLY that `client_id`'s rows** (`user_client_ids()` resolves correctly).
   - f. **`audit_tenant_rls() = 0`** sanity (no schema change; confirm clean).
4. **Defer** the PWA set-password route + UI gating to Phase B; the agency "provision a client" action UI to Phase C (agency-view).

## 6. SMTP delivery must-check
`inviteUserByEmail` sends via **Supabase Auth's SMTP** (separate from the platform owner-notification email infra). **Before relying on provisioning, verify invite/reset emails actually deliver** — configure custom SMTP in Supabase Auth or confirm the default works. Do not ship provisioning that silently never emails.

## 7. Skill / doc updates (in parity after build/validate)
- **`platform-spec` §730** → `audit_log` `[DONE]` — **APPLIED this pass** (migration refs added).
- **`pathway-to-completion.md` §4** → payment-gate wording = client PWA only; agency surfaces never gated — **APPLIED this pass**.
- **`scratch-foundation` §5** → add the provisioning flow (`provisionClientOwner`; `inviteUserByEmail`; `client_owner`-only v1; SMTP dependency; already-registered handling; standalone-now→wizard-later) — *pending build.*
- **`mobile-app` / `admin-view`** → role-model note (client = `client_owner` on the PWA; agency account + per-client admin view are agency-scoped, never payment-gated) — *pending build.*
- **`agency-view` (new, Phase C)** → will host the "provision a client" action (calls this fn) + the cross-client pending-request flagging.

## 8. Forward-compatibility
Same fn called standalone now + from the onboarding wizard (Phase C). `client_staff` invites layer on via the existing matrix. Forward-compatible with built billing later (unrelated).
