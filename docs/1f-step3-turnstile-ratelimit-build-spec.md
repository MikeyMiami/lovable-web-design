# 1f Step 3 — LIVE Turnstile + Rate-Limiting — Audit + Build Spec

> The §A launch-gate: bot protection + rate-limiting on public lead-intake routes. Provider-independent (does NOT wait on the TextGrid auth confirm). Audited against the real frozen code @ `golden-master-v1.3` (`cloud-spark-setup@761aa19`). Audit + spec only — no build code yet.

## Audit findings (real code @ 761aa19)

**A. Public-route inventory + current protection.** Every `/api/public/*` route:

| Route | Method(s) | Kind | Current gate | Turnstile? | Rate-limit? |
|---|---|---|---|---|---|
| `intake` | POST | **bare lead form** (anon→contact) | CORS+Zod+resolveTenant | **YES** | **YES** |
| `discount` | POST | **bare lead form** | CORS+Zod+resolveTenant | **YES** | **YES** |
| `chat/optin` | POST | **bare lead form** (chat entry) | CORS+Zod+resolveTenant | **YES** | **YES** |
| `chat/request` | POST | token-gated (`chat_token` from optin) | CORS+Zod+`verifyChatToken` | NO (optin already gated) | **YES** (replay defense) |
| `chat/stream` | POST | token-gated (`chat_token`) | `verifyChatToken` | NO | optional (AI cost) |
| `r/rate`, `r/feedback` | GET+POST | token-gated funnel (`tracked_links`, ~22-char token) | token only (same-origin, no CORS) | NO (token-gated, friction-sensitive) | optional light per-IP |
| `r/$token` | GET | tracked-link click→redirect | token only | NO | optional |
| `cron/sequences` | POST | **server-to-server** | `x-cron-secret` | **EXCLUDED** | **EXCLUDED** |
| `sms/inbound`, `sms-status`, `voice-status` | POST | **server-to-server** (provider) | `X-TextGrid-Signature` HMAC | **EXCLUDED** | **EXCLUDED** |

→ **Turnstile scope = the 3 bare lead forms: `intake`, `discount`, `chat/optin`.** `chat/request` gets rate-limit only (it's token-gated; optin is the Turnstile entry). The webhook + cron routes are **explicitly EXCLUDED** — Turnstile is for browser-origin human submissions; these are signature/secret-gated server-to-server (a provider can't solve a CAPTCHA). The review-funnel (`r/*`) is token-gated (high-entropy minted token) → exclude Turnstile (would add friction to an SMS-click flow); optional light per-IP rate-limit only.

**B. Turnstile + rate-limit are FULLY NET-NEW.** Grep: zero Turnstile code, zero rate-limit code anywhere. The chat opt-in has **no stub** (the spec's guess was wrong — `chat/optin` is bare CORS+Zod+resolveTenant). Only marker is `intake.ts:4` "Stage 1f will add Turnstile + rate-limit." (`chat/stream`'s 429 handling is the *AI gateway's* 429, unrelated.)

**C. The CORS/resolver seam (`lib/cors.ts` + `tenant-resolver.server.ts`).** Current flow on the 3 bare routes: `OPTIONS`→`preflight(allowedOrigin)`; `POST`→ parse JSON → Zod `safeParse` → `resolveTenant({origin,host,slug})` → `!tenant` ? 403 : process → `jsonCors(body,status,allowedOrigin)`. The gate today is **resolveTenant** (unknown origin/slug → 403). CORS headers are echoed from `clients.allowed_origins`. The new checks slot **between resolveTenant and process**.

**D. 🔴 Rate-limiter storage — the environment forces the decision.** Grep for `KVNamespace`/`DurableObject`/`env.KV`/`cloudflare:`/`caches.`/wrangler bindings → **NONE.** No `wrangler.toml`, no KV/DO bindings; the runtime is Lovable-managed Nitro and everything is `process.env.*` (secrets) + Supabase. **There is no KV or Durable Object available** without new infra Lovable doesn't expose. → The only cross-isolate persistent store is **Postgres**. **Recommendation: DB-backed rate limiter** (additive table + atomic RPC). The spec §657 line ("DO / KV / DB-based — decision") resolves to **DB-based**. (KV/DO are future optimizations if volume ever demands; they'd need wrangler/Lovable support that doesn't exist today.)

**E. 🟡 Doc drift caught.** Spec §650 still names the webhook routes as `/api/public/twilio/inbound` + `/api/public/twilio/voice-status` (literal "twilio" paths) — but step 2 built `/api/public/sms/inbound`, `/api/public/sms-status`, `/api/public/voice-status`. Mirror-fix below.

## Scope
**IN:** Turnstile token verification on `intake` + `discount` + `chat/optin`; a DB-backed rate limiter on those 3 + `chat/request`; the additive rate-limit table + RPC; a `getTurnstileConfig()`; `RUNNER_VERSION` bump. **EXCLUDED:** all webhook + cron routes (server-to-server, signature/secret); `r/*` funnel (token-gated — optional light per-IP rate-limit only, low priority); the frontend Turnstile widget (marketing-template work — see coordination blocker). **Not re-touched:** the frozen send primitive, the step-2 webhook layer.

## Recommended decisions (flag any you'd change)
1. **Rate-limiter backing = Postgres** (no KV/DO exists). Additive `rate_limit_hits` table + a `SECURITY DEFINER` atomic check-and-increment RPC. [Forced by env — see D.]
2. **Granularity = per-IP AND per-client.** Per-IP catches one abuser hitting many clients; per-client catches a targeted flood. Two cheap checks (or one combined). 
3. **Order of checks:** `OPTIONS`=preflight; `POST`: parse → Zod → **resolveTenant** (need client_id) → **rate-limit** (per-IP + per-client; cheap, before the Turnstile network call) → **Turnstile siteverify** → process → `jsonCors`. *(Optional hardening: an early per-IP limit BEFORE resolveTenant to shield it from unknown-origin floods — surfaced, not default.)*
4. **Turnstile siteverify failure modes:** definitive `success:false` (invalid/expired/reused token) → **fail-CLOSED** (403). The siteverify **call itself** failing (network/timeout, ~3–5s budget) → **fail-OPEN + alert** (don't drop revenue leads to a Cloudflare blip). *(Your call — security-strict would fail-closed both; I lean fail-open on infra-failure for a revenue form.)*
5. **IP source = `CF-Connecting-IP`** header (Cloudflare), fallback first hop of `X-Forwarded-For`. NOT `request.ip` (unreliable on Workers).
6. **Limit defaults (tunable):** per-IP **10 / 10 min / route**; per-client **60 / 10 min / route** (generous for real lead volume — see burst edge case). Exceed → **429 + `Retry-After`**.

## Turnstile design
- **Frontend (marketing Remixes — NOT this repo):** render the Turnstile widget with the **PUBLIC site key**; the widget emits `cf-turnstile-response`, included in the POST body as `turnstile_token`. *(Coordination blocker below.)*
- **Backend (`config.server.ts`):** `getTurnstileConfig()` → `{ secretKey: process.env.TURNSTILE_SECRET_KEY, mode: process.env.TURNSTILE_MODE ?? "live" }` (read per-request, Workers).
- **Verify (shared lib `src/lib/security/turnstile.server.ts`):** `verifyTurnstile(token, ip)` → POST `https://challenges.cloudflare.com/turnstile/v0/siteverify` form `{secret, response:token, remoteip:ip}`, 5s timeout → returns `{ok, reason}`. `success:true`→ok; `success:false`→fail-closed; fetch throws/timeout→fail-open+alert (per decision 4).
- **Routes:** read `turnstile_token` from the parsed body (add to each route's Zod schema), call `verifyTurnstile` after the rate-limit check; `!ok && definitive` → `jsonCors({error:"captcha_failed"},403,allowedOrigin)`.
- **STUB/test:** Cloudflare publishes **test keys** — always-passes secret `1x0000000000000000000000000000000AA`, always-fails `2x0000000000000000000000000000000AA`, and the always-passing dummy response token. Set `TURNSTILE_SECRET_KEY` to the test secret for STUB validation (no real widget needed).

## Rate-limiter design (DB-backed)
**Additive migration:**
```sql
CREATE TABLE IF NOT EXISTS public.rate_limit_hits (
  bucket text NOT NULL,
  window_start timestamptz NOT NULL,
  count int NOT NULL DEFAULT 0,
  PRIMARY KEY (bucket, window_start)
);
ALTER TABLE public.rate_limit_hits ENABLE ROW LEVEL SECURITY;  -- no policies → service-role only (no client_id col → not in audit_tenant_rls scope)

CREATE OR REPLACE FUNCTION public.check_rate_limit(_bucket text, _window_seconds int, _limit int)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE _ws timestamptz; _c int;
BEGIN
  _ws := to_timestamp(floor(extract(epoch from now()) / _window_seconds) * _window_seconds);
  INSERT INTO public.rate_limit_hits(bucket, window_start, count) VALUES (_bucket, _ws, 1)
    ON CONFLICT (bucket, window_start) DO UPDATE SET count = rate_limit_hits.count + 1
    RETURNING count INTO _c;
  RETURN _c <= _limit;   -- true = allowed
END $$;
REVOKE ALL ON FUNCTION public.check_rate_limit(text,int,int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_rate_limit(text,int,int) TO service_role;
```
- **Atomic** (single `INSERT … ON CONFLICT … RETURNING`), works across isolates, one round-trip. Fixed-window (simple + sufficient; sliding-window is overkill for lead-intake).
- **Buckets:** `"intake:ip:<ip>"`, `"intake:client:<client_id>"`, etc.
- **Lib `src/lib/security/rate-limit.server.ts`:** `checkRateLimit(bucket, windowSec, limit)` → `supabaseAdmin.rpc("check_rate_limit", …)`. Route calls it for the IP bucket + the client bucket; either false → `jsonCors({error:"rate_limited"}, 429, allowedOrigin)` with `Retry-After`.
- **Cleanup:** old windows accumulate → a periodic `DELETE FROM rate_limit_hits WHERE window_start < now() - interval '1 day'` (cheap; run opportunistically or as a tiny scheduled job). **[FIX]**
- **`audit_tenant_rls()=0`:** `rate_limit_hits` has no `client_id` → not in the tenant-RLS audit scope (same as `audit_log`); RLS on + no anon/authenticated policy. Confirm 0 after.

## RUNNER_VERSION
Bump (e.g. → `v20260617-3`) — the 3 route files change → cron bundle changes → keep `?ping` meaningful.

## Validation walk
**STUB/test-validatable (no real widget):**
1. Deploy → `?ping=1` echoes the new version.
2. **Turnstile pass:** `TURNSTILE_SECRET_KEY`=test-always-pass + the dummy token → submit `intake`/`discount`/`chat/optin` → 200, contact created.
3. **Turnstile fail:** test-always-fail secret (or a missing/garbage token) → **403 `captcha_failed`**, no contact written.
4. **Rate-limit trip:** POST the same route past the per-IP limit → **429 + `Retry-After`**; under the limit → 200. Per-client limit trips independently.
5. **Order:** a rate-limited request does NOT spend a siteverify call; an unknown-origin request still 403s at resolveTenant.
6. `audit_tenant_rls()=0`.
**LIVE-gated:** real Turnstile widget tokens from the marketing forms (real site key + rendered widget + human challenge); per-client domain added as a Turnstile hostname.

## Blockers / edge cases (tagged)
- **🔴 [BLOCKER — frontend coordination, before first client launch] Marketing Remixes must inject the Turnstile widget + public site key on all 3 lead forms BEFORE backend enforcement goes live.** A form without the widget can't produce a token → backend (fail-closed) rejects → **zero leads**. No clients are live yet, so this is a "template must have it before the first launch" item, not mid-flight — but the marketing template (Project 2 / `website-structure` / `new-client-site`) MUST carry the widget. STUB-validate the backend with Cloudflare test keys meanwhile. Owner: frontend template.
- **🟠 [DECISION — fail-open vs fail-closed on siteverify infra-failure]** decision 4. Rec: fail-open + alert on the *call* failing; fail-closed on a definitive `success:false`.
- **🟠 [DECISION — per-IP vs per-client]** decision 2. Rec: both.
- **[FIX] Legit burst traffic.** A real high-volume client could trip a per-client limit → set the per-client default generously (60/10min) and treat it as configurable later (a `send_settings`-style override is a future knob). Don't block real lead volume. Per-IP stays tighter.
- **[FIX] IP extraction** = `CF-Connecting-IP` (decision 5). Wrong header → all requests share a bucket (proxy IP) → mass false-positive throttling.
- **[FIX] rate_limit_hits cleanup** (old-window GC).
- **[FIX] `r/*` funnel** = exclude Turnstile; optional light per-IP rate-limit only (high-entropy tokens make abuse low-value). Confirm we're NOT adding Turnstile friction to the SMS-click flow.
- **[FIX] `chat/request` rate-limit, no Turnstile** (token-gated via optin).
- **[BACKLOG] Turnstile token reuse/expiry** — Cloudflare's siteverify enforces single-use + ~300s expiry; our route just trusts the verdict. No app-side handling needed.

## Open / confirm items
- Lock the **fail-open/closed** + **per-IP/per-client** decisions (4, 2) before build.
- The frontend-widget coordination owner (which skill/template injects the site key).
- Whether to add the optional early per-IP shield before resolveTenant (decision 3).
