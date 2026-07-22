# 1f Inbound Webhook — LIVE Validation + Root-Cause (2026-07-11)

> First real end-to-end debug of TextGrid inbound SMS on the test client (number `+14194879124`, TextGrid master account `Kcip54bufdfWdoAnFINwWQ==`, campaign `C65WTYR`). Symptom: outbound sends worked, replies were received by TextGrid (visible in their UI) but **never appeared in the client's Conversations tab**. Resolved: the code/endpoint/config were correct all along — the failure was a **silent fail-closed 401** at the HMAC gate.
>
> **Identity note:** "Pierce Insurance Solutions LLC" (campaign `C65WTYR`) is the **A2P brand/campaign registrant** — the operator's own legal entity that owns the TextGrid master account — NOT a platform client. The client tenant owning `twilio_number = +14194879124` is separate (`x3-landscaping` per operator; confirm in-app). Don't infer client identity from the A2P registration name.

## Root cause
Inbound POSTs were being rejected `401` at the signature gate — almost certainly because `provider_webhook_secret` was **not stored on the client row** when the first replies arrived (fail-closed by design at `inbound.ts` — no secret → 401). With no logging on the reject path and TextGrid's error-log API returning 404, the rejection was completely invisible, which turned a config gap into a multi-hour hunt.

## What we proved (empirically, not theorized)
1. **Endpoint is live & correct.** Direct probes of `https://cloud-spark-setup.lovable.app/api/public/sms/inbound`: empty body → `400 bad request`; unknown `To` → `200 <Response></Response>`; real `To=+14194879124` → `401` (tenant RESOLVED, died at the secret/HMAC gate). Real Cloudflare deployment (`x-deployment-id`), not an SPA fallback. GET → SPA shell (so `SmsMethod` must be POST).
2. **TextGrid IS delivering webhooks** (killed the "carrier/campaign-inbound" theory). Repointed `smsUrl` to a webhook.site inspector; a real reply arrived in 0.001s with `user-agent: textgrid-api`, Twilio-identical params, and a valid `x-textgrid-signature`.
3. **Signature scheme reverse-engineered from the captured POST.** Brute-checked key×algorithm combos against the real signature:
   - **MATCH:** `Base64(HMAC-SHA1(request.url + rawBody, key = per-client provider_webhook_secret))`.
   - Key is the **webhook secret**, NOT the account AuthToken. Message is the **raw body verbatim**, NOT Twilio's sorted-params scheme. Our verifier `src/lib/webhooks/textgrid-signature.server.ts` was correct as written.
4. **URL-exactness holds.** Replicated TextGrid's signed request against the real endpoint: signing over the canonical URL (`https`, no trailing slash) → HMAC PASSED (200, materialized contact+message). Trailing-slash and `http` variants → 401. So `request.url` the handler sees == the configured `smsUrl` exactly on Lovable/Cloudflare.
5. **TextGrid REST READ APIs are unreliable.** `GET /Messages.json` returned empty even for messages known to exist in the UI (both outbound and inbound); `/Notifications.json` → 404; `/Accounts.json` (subaccounts) → 404 (no subaccounts exist). Not usable for diagnostics — the dashboard UI + a webhook.site redirect are the only reliable inspection tools.

## Config corrected on the number (via TextGrid API)
- `sms_url` → `/api/public/sms/inbound` (POST) ✅ (was already correct)
- `voice_url` → `/api/public/voice/inbound` (was empty)
- number-level `status_callback` → `/api/public/voice-status` (was wrongly `/api/public/sms/inbound`). Note: the number-level `statusCallback` is the **voice** call-status callback; SMS delivery-status is per-message on the send primitive, not settable here.

## Code change (observability — held commit)
`src/routes/api/public/sms/inbound.ts`: added **permanent `console.warn` logging** at the two 401 rejection points (no `provider_webhook_secret`; signature mismatch — logs `request.url`) and the unknown-`To` silent drop. Motivated directly by this incident — a fail-closed 401 must never be silent again. Needs deploy + (post-freeze contract) re-validate + re-tag.

## Resolved gates / checklist items
- HANDOFF LIVE-flip **Gate #3 (URL-exactness)** → RESOLVED (fact #4).
- `docs/live-sms-test-plan.md` **P2** (webhook wiring) → DONE with correction; **item 4** (inbound + HMAC) → validated via signed replica (real-reply confirmation pending); **open dep #4** (`provider_webhook_secret`) → resolved as the root cause.
- `1f-step2` spec URL-exactness LIVE-smoke watch → CONFIRMED. Non-ASCII `\uXXXX` watch (Gate #4) → still OPEN (not exercised).

## Follow-ups
- Delete the "DiagSig" test contact + message (From `+14197500242`) from the test client's Conversations (created by the validation POST; `.env` has only the anon key, so remove via app UI / Supabase dashboard).
- Deploy the observability logging + re-tag.
- Send one real reply to confirm end-to-end now that config is restored.
