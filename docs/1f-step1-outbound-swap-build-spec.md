# 1f Step 1 — Outbound TextGrid Swap — Lovable Build Spec

> The exact change-set for the FIRST 1f hardening step: swap the stub send for a real TextGrid outbound send. Audited against the real frozen code @ `golden-master-v1.1` (`cloud-spark-setup@5e41f41`). Decisions locked 2026-06-16. Hand this verbatim to Lovable; validate the build report against real code before re-tag.

## Scope
**IN:** real outbound SMS via TextGrid; a pure-transport send primitive (`{to, from, body, sendingAccountSid, auth}` — ZERO DB access); caller-side from/to/auth resolution; render-completeness guard at the send boundary; one additive column (`provider_subaccount_sid`); a `SMS_MODE=stub|live` switch; real SID + initial status written by both callers.

**OUT (separate 1f items — do NOT build here):** the net-new inbound + voice + **delivery-status (StatusCallback) webhook layer**; Turnstile/rate-limit; the reactivation number pool; the `a2p_*` / `provider_webhook_secret` columns. (Delivery `delivered`/`failed`/`undelivered` arrives via the StatusCallback webhook built in the webhook-layer item — this step writes only the *synchronous* send result.)

## Locked decisions (recorded)
1. **Send boundary = pure transport.** The primitive does zero DB access; the caller resolves `to`, `from`, `sendingAccountSid`, and `auth` and passes them in. This is the from-resolution seam: the future reactivation pool reuses the SAME primitive by passing a pool number as `from` + agency creds — no branch, no second primitive.
2. **Auth is a caller-passed param.** Build for **Option 1** (one agency MASTER token acting on the per-client subaccount; no per-client secret storage). The primitive stays agnostic about whose account it sends from; flipping to Option 2 (per-client subaccount token on the row) is a pure caller-resolution change. **Path `sendingAccountSid` is decoupled from the Bearer `auth` pair** so the parent-on-subaccount confirm (below) is also a caller-only change.
3. Delivery status deferred to the webhook layer (above).
4. **Retryable mapping:** TextGrid 5xx → `retryable:true` (existing 2× loop); 4xx → `retryable:false` → `failed`; `400` opted-out → terminal non-retryable; `401` → auth error, non-retryable, alert.
5. **Render-completeness guard at the send boundary** (LIVE only — a literal `{key}` stays a legal stub-mode diagnostic).
6. Additive migration only → re-validate → re-tag `golden-master-v1.2`.

## TextGrid API (from `textgrid-provider` skill §1/§2)
- Base: `https://api.textgrid.com/2010-04-01`
- Auth header: `Authorization: Bearer <base64(AccountSid:AuthToken)>` — **Bearer + base64, NOT HTTP Basic** (the one format difference from Twilio).
- Endpoint: `POST /Accounts/{accountSid}/Messages.json`
- Request body (JSON): `{ "body", "from", "to", "statusCallback"? }`
- Response: `sid`, `status` (`queued`/`sent`/`failed`), `error_code`, `error_message`.
- Char note: ≤160 GSM-7 = 1 segment (cost); 2048 hard max.

---

## 0. Secrets / config (`src/lib/config.server.ts`)
Add runtime secrets (NOT on any DB row):
- `TEXTGRID_MASTER_ACCOUNT_SID`, `TEXTGRID_MASTER_AUTH_TOKEN` — agency master creds (Option 1).
- `TEXTGRID_BASE_URL` — default `https://api.textgrid.com/2010-04-01`.
- `SMS_MODE` — `stub` | `live`, default `stub`.

Add a per-request getter (read inside the function — Workers bind env at request time):
```ts
export function getTextGridConfig() {
  return {
    mode: (process.env.SMS_MODE ?? "stub") as "stub" | "live",
    baseUrl: process.env.TEXTGRID_BASE_URL ?? "https://api.textgrid.com/2010-04-01",
    masterAccountSid: process.env.TEXTGRID_MASTER_ACCOUNT_SID,
    masterAuthToken: process.env.TEXTGRID_MASTER_AUTH_TOKEN,
  };
}
```

## 1. Additive migration
```sql
ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS provider_subaccount_sid text;
```
(Only this column for outbound. `provider_webhook_secret` / `a2p_*` are deferred to the webhook/registration steps.) Run `SELECT * FROM public.audit_tenant_rls();` after → must stay 0 rows.

## 2. The send primitive (`src/lib/sms/send.server.ts`) — pure transport
Rename `sendStubSms*` → `sendSms`/`sendSmsWithRetry` (it is no longer a stub; update the 2 importers). Signature becomes fully caller-resolved, ZERO DB:

```ts
export type SendAuth = { accountSid: string; authToken: string };

export type SendArgs = {
  to: string;                 // E.164, caller-resolved (contact phone)
  from: string;               // E.164, caller-resolved (clients.twilio_number, or a pool number)
  body: string;               // already rendered
  sendingAccountSid: string;  // path: /Accounts/{sendingAccountSid}/Messages.json (subaccount for per-client)
  auth: SendAuth;             // Bearer base64(auth.accountSid:auth.authToken)
  statusCallback?: string;    // omitted in step 1 (added with the status-webhook layer)
  mode: "stub" | "live";
};

export type SendResult =
  | { ok: true; sid: string; status: string }
  | { ok: false; retryable: boolean; error: string; errorCode?: string };

const SEND_MAX_ATTEMPTS = 2;
const UNRENDERED = /\{[a-zA-Z0-9_.]+\}/;   // residual merge token

async function sendOnce(args: SendArgs): Promise<SendResult> {
  // STUB mode: preserve current behavior so the whole resolve/refactor path
  // validates without real creds. No guard (a literal {key} is a stub diagnostic).
  if (args.mode === "stub") {
    return { ok: true, sid: `STUB-${crypto.randomUUID()}`, status: "stub" };
  }
  // LIVE: render-completeness guard at the boundary — never transmit a residual token.
  if (UNRENDERED.test(args.body)) {
    return { ok: false, retryable: false, error: "unrendered_token" };
  }
  const base = process.env.TEXTGRID_BASE_URL ?? "https://api.textgrid.com/2010-04-01";
  const cred = btoa(`${args.auth.accountSid}:${args.auth.authToken}`);
  let resp: Response;
  try {
    resp = await fetch(`${base}/Accounts/${args.sendingAccountSid}/Messages.json`, {
      method: "POST",
      headers: { Authorization: `Bearer ${cred}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        body: args.body, from: args.from, to: args.to,
        ...(args.statusCallback ? { statusCallback: args.statusCallback } : {}),
      }),
    });
  } catch (e) {
    return { ok: false, retryable: true, error: `network:${(e as Error).message}` };
  }
  if (resp.status >= 500) return { ok: false, retryable: true, error: `http_${resp.status}` };
  if (resp.status === 401) return { ok: false, retryable: false, error: "auth_401" };
  const json = await resp.json().catch(() => ({} as any));
  if (resp.status >= 400 || json?.status === "failed" || json?.error_code) {
    return { ok: false, retryable: false, error: json?.error_message ?? `http_${resp.status}`, errorCode: String(json?.error_code ?? resp.status) };
  }
  return { ok: true, sid: json.sid, status: json.status ?? "sent" };
}

export async function sendSms(args: SendArgs): Promise<SendResult> {
  return sendOnce(args);
}

/** 2× retry on retryable failures only. */
export async function sendSmsWithRetry(args: SendArgs): Promise<SendResult> {
  let last: SendResult = { ok: false, retryable: true, error: "no_attempt" };
  for (let attempt = 1; attempt <= SEND_MAX_ATTEMPTS; attempt++) {
    last = await sendOnce(args);
    if (last.ok || !last.retryable) return last;
  }
  return last;
}
```
**SEND-ONLY invariant:** this file imports no supabase client and performs no DB read/write. (Regression check.)

## 3. Caller A — cron runner (`src/lib/cron/runner.server.ts`)
Resolve send params caller-side, then call the renamed primitive.
- **Per-client provider cache (one load/tick):** extend the existing per-tick client cache (the `send_settings` load ~`:249`) to also load `clients.twilio_number` + `clients.provider_subaccount_sid`.
- **`to`:** the contact's `phone_e164` (already read in `loadContactVars`; expose/read it for the send).
- **Resolve `auth`** from `getTextGridConfig()` master creds; **`sendingAccountSid`** = the client's `provider_subaccount_sid`; **`mode`** = config mode. **No `statusCallback` in step 1.**
- **Config-missing guard (LIVE):** if `mode==='live'` and `from`/`to`/`sendingAccountSid` is missing → **reschedule WITHOUT advancing** + emit a distinct `send_config_missing` event (mirror the existing `template_missing` self-heal at `:460`); do NOT burn the step, do NOT funnel into the 2× retry.
- Replace the send call at `~:490`:
```ts
const result = await sendSmsWithRetry({
  to: contactPhoneE164, from: client.twilio_number,
  body, sendingAccountSid: client.provider_subaccount_sid,
  auth: { accountSid: cfg.masterAccountSid!, authToken: cfg.masterAuthToken! },
  mode: cfg.mode,
});
```
- **Status writes:** at the `sms_sent` event (`~:522`) drop `stub: true`; add `status: result.status`. At `insertOutboundMessageAdmin` (`~:533`) change `status: "stub"` → `status: result.status` and keep `sid: result.sid`.

## 4. Caller B — reply box (`src/lib/messages/reply.functions.ts`)
- After the RLS conversation lookup, resolve under the authed client: `clients.twilio_number` + `clients.provider_subaccount_sid` (by `convo.client_id`) and `contacts.phone_e164` (by `convo.contact_id`).
- Replace the send at `:41`:
```ts
const result = await sendSmsWithRetry({
  to: contactPhoneE164, from: client.twilio_number,
  body: data.body, sendingAccountSid: client.provider_subaccount_sid,
  auth: { accountSid: cfg.masterAccountSid!, authToken: cfg.masterAuthToken! },
  mode: cfg.mode,
});
if (!result.ok) throw new Error(`send_failed:${result.error}`);
```
- `insertOutboundMessageRls` (`:50`): `status: "stub"` → `status: result.status`. (Interactive path: a missing `from`/subaccount in LIVE → throw a clear error to the user, not a silent reschedule.)

## 5. Insert helper (`src/lib/messages/insert.server.ts`)
**No change.** It already accepts `status` + `sid` and writes `messages.twilio_sid`/`status`. Callers now pass the real values. (Confirm: no new insert logic — exactly as the §3c design promised.)

## 6. Version stamp
Bump `RUNNER_VERSION` `v20260616-1` → **`v20260616-2`** in the SAME commit (route + runner are one bundle).

---

## Validation walk (on a `?ping=1`-confirmed bundle)
1. **Deploy `SMS_MODE=stub`.** Confirm promotion: `POST …/cron/sequences?ping=1` → `runner_version="v20260616-2"` before interpreting anything (deploy-lag gate).
2. **2e regression (manual ticks), STUB:** re-run TEST1–TEST5 → claim-lease / window / caps / reschedule-without-advancing / advance-on-success / 2× retry all intact after the signature refactor; bodies rendered (no `[stub]` literal); `messages.status` + `twilio_sid` populated from the stub result; `sms_sent` event carries `status`.
3. **SEND-ONLY:** code-review + regression confirm `send.server.ts` does zero DB.
4. **Render guard:** a template with an unresolvable `{token}` under `mode=live` → `unrendered_token`, non-retryable, NO transmit (and `messages` not written). In `stub` the literal `{token}` still ships (diagnostic) — both behaviors asserted.
5. **Config-missing self-heal:** a LIVE client with null `provider_subaccount_sid` → `send_config_missing` event, step NOT advanced, no retry burn.
6. **LIVE smoke (AFTER the TextGrid auth confirm + a real subaccount):** one real send to a test number → real `sid`, `status` `queued`/`sent`, `messages` row updated.
7. **Re-validate + re-tag `golden-master-v1.2`** (`audit_tenant_rls()`=0; both repos).

## Open / confirm items (carry)
- **TextGrid parent-on-subaccount auth confirm** — "can the MASTER `AuthToken` authenticate `Messages.json` against a subaccount's `AccountSid`, or is subaccount-scoped auth required?" Gates **LIVE**, not STUB. Owner: user → TextGrid. Add to `textgrid-provider` skill §7 open-items. The decoupled `sendingAccountSid`/`auth` shape makes either answer a caller-only change.
  - **STATUS 2026-06-16 — UNCONFIRMED, building on the Option-1 ASSUMPTION.** Question sent to TextGrid support 2026-06-16 (~1–2 day reply). Building STUB now on **Option 1** (agency MASTER `AuthToken` authenticates against the subaccount's `AccountSid`); `auth`/`sendingAccountSid` are decoupled so a flip to **Option 2** (per-client subaccount `auth_token`, stored on the row) is a caller-only change — no primitive re-architecture. **The TextGrid docs LEAN Option 2** (audit C2: subaccount Create returns its own `auth_token`; parent-on-subaccount for Messages is undocumented — only Brand creation sanctions it via a `subAccountSID` body field), so treat Option 2 as the likely outcome. **If a LIVE send returns `401 auth_401`, this is the cause** — see `textgrid-provider` skill §2 (LIVE-failure insurance) + §7. Do NOT flip `SMS_MODE=live` before the confirm.
- **StatusCallback + delivery status** = the net-new webhook-layer 1f item (`/api/public/sms-status`). The `statusCallback` param is wired through the primitive now but left unset until that route exists.
- `a2p_*` + `provider_webhook_secret` columns = the A2P-registration / inbound steps.
