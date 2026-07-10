# Stage — P0.5 (per-client subaccount auth token, Option-2 support) — validation [DONE]

> 2026-07-09. Verified against `cloud-spark-setup` `origin/main` (`000abbc`). Additive column; `audit_tenant_rls()=0`. GOLDEN-MASTER change (send-path auth) → re-tagged **`golden-master-v1.9`**. **Null path byte-identical to v1.8.** Prereq for the live SMS test (`docs/live-sms-test-plan.md`).

## Why
Confirmed architecture: every client gets its OWN subaccount + A2P brand/campaign + number. The send path only had the master token (Option 1). If TextGrid requires per-subaccount auth (Option 2 — the unconfirmed LIVE-flip Gate #1), a real client's first send would 401. This adds per-client token support, backward-compatible.

## What shipped
- **Additive migration** `20260710005218` — `clients.provider_subaccount_auth_token text` (nullable). No RLS change (clients is the tenant-key table, outside the `audit_tenant_rls` scan). `audit_tenant_rls()=0`.
- **Credential UI** (`admin.settings.tsx`) — password-masked "Subaccount auth token" input next to subaccount SID + webhook secret; blank = use master token.
- **Send-path fallback** (`runner.server.ts:627-629`, `reply.functions.ts:72-74`):
  ```
  auth = subaccountToken ? `${subaccountSID}:${subaccountToken}` : `${masterAccountSID}:${masterAuthToken}`
  ```
  - **null token → master auth** (byte-identical to v1.8; main-account test + all current clients unchanged).
  - **set token → subaccount's own SID:token** (real per-client subaccount / Option 2).
- **`send.server.ts` UNTOUCHED** (still `Bearer base64(args.auth)`; the caller decides the token).

## Validation (PASS, code-level vs origin/main)
- Column present; `audit_tenant_rls()=0`. ✅
- Runner null path resolves to `masterAuth` (`:296`, unchanged) — **byte-identical** to v1.8's `auth: masterAuth`. ✅
- Reply null path resolves to `` `${masterAccountSid ?? ""}:${masterAuthToken ?? ""}` `` — **byte-identical** to v1.8's `:71`. ✅
- Set path builds `subaccountSID:token`. ✅ `send.server.ts` unchanged. ✅
- Runtime null-token proof deferred to the **main-account canary send (test #2, token blank)** — a landing send confirms the master-token path is unchanged.

## Credential surface — now COMPLETE for real clients
Per-client capturable in the UI: subaccount SID + subaccount auth token + webhook secret + A2P brand ID + campaign ID (+ a2p_status display) + number. `statusCallback`/`smsUrl` are set on TextGrid's number config (not our DB). **No remaining per-client credential gap.**

## Next
Gate #1 (Option 1 vs 2) resolves on the **first real-subaccount send**: sends fine → Option 1; 401 → set the subaccount token in the UI (no code change needed — the fallback is already built). Live test proceeds per the checklist starting at the canary send.
