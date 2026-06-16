# 1f Step 2 — Net-New Inbound Webhook Layer — Audit + Build Spec

> The second 1f hardening step: build the inbound/voice/status webhook layer from scratch. Audited against the real frozen code @ `golden-master-v1.2` (`cloud-spark-setup@73ca26e`). Audit + spec only — no build code yet. Same discipline as step 1: validate against real code, hand verbatim mirror lines, additive migrations, re-validate + re-tag.

## Audit findings (real-code-grounded @ 73ca26e)

**A. The inbound seam — confirmed NET-NEW.** Public routes today: `chat/{optin,request,stream}`, `discount`, `intake`, `r/{$token,feedback,rate}`, `cron/sequences`. **No inbound-SMS route, no voice route, no sms-status route. No signature-verification code** (the only HMAC is `chat/token.server.ts` — HMAC-**SHA256** for chat tokens, unrelated; webhooks need HMAC-**SHA1**). Two route patterns exist to model on: `intake.ts` = CORS public-write (resolve tenant by Origin); `cron/sequences.ts` = **server-to-server, no CORS, secret-gated**. **Webhooks follow the cron pattern** (server-to-server, no CORS) but swap the secret check for **signature verification**, and resolve the tenant by **`To` → `clients.twilio_number`** (a resolver that does NOT exist yet — see change-set).

**B. The reply-exit machinery is BUILT but DORMANT — step 2 is the writer that activates it.** The runner already has: one-year reply-exit (`runner.server.ts:375-395` via `inboundReplyState`/`hasInboundSince`), missed-call `skipIfReplied` (sms2, `:397-405`), and D1's `opted_out_at` enforcement (`:340-350`). **All of them READ inbound state that NOTHING currently WRITES:** `hasInboundSince` queries `messages WHERE direction='inbound'`, but the only message-writer (`insert.server.ts`) writes `direction:"outbound"` — **no code writes inbound messages**, so `hasInboundSince` is always false today. Likewise `opted_out_at` is **read in 4 places but written nowhere**. So the entire reply-driven machinery is inert until step 2 supplies the inbound data. The reusable EXIT pattern already exists and is exported: **`exitOneYearOnDiscountClaim(clientId, contactId)`** (`enroll.server.ts:341`) — direct `UPDATE status='exited', next_run_at=null` + a `drip_exit` event. Generalize it into a shared `exitActiveEnrollments(clientId, contactId, sequenceKey, reason)`.

**C. Opt-out capture is net-new (the SETTER).** `opted_out_at` is read by: `enroll.server.ts:189` (enroll guard), `runner.server.ts:343/822` (D1 + one_year), `reply.functions.ts:63` (D1 reply guard). **Written nowhere.** Step 2's inbound-SMS handler is the writer: STOP/"pass" → `UPDATE contacts SET opted_out_at=now()`; START/UNSTOP → clear it. (D1's enforcement already consumes it — step 2 just turns it on.)

**D. Missed-call textback — machinery exists, TRIGGER is net-new.** Present: the `missed_call_textback` sequence (`enroll({sequenceKey:"missed_call_textback"})`), the `missed_call` notification type (`write.server.ts:48`, `open_conversation:true`, "can fire pre-upsert"), the per-contact throttle column **`contacts.last_missed_call_textback_at`** (written NOWHERE today), and the admin "Open conversation" deep-link. **There is NO trigger** — nothing enrolls `missed_call_textback` today (no voice webhook). Step 2's voice **status-callback** handler is the trigger: `CallStatus ∈ {no-answer, busy, failed}` → find-or-create contact → `enroll(missed_call_textback)` (throttled via `last_missed_call_textback_at`) → `missed_call` owner notification.

**E. `provider_webhook_secret` — additive, confirmed safe.** `clients` already gained `provider_subaccount_sid` (step 1). Add `provider_webhook_secret text` (nullable). Additive → `audit_tenant_rls()=0` holds (the audit scans tenant tables' RLS + anon `clients` grants; a nullable column touches neither). Subaccount Create returns `webhook_secret` (TextGrid 10DLC doc) → stored per-client at A2P provision (step 5/6).

**F. Delivery-status callback — this is where step-1's deferral lands.** `messages` has `status text` + `twilio_sid text`. The send primitive left `statusCallback` **unset** (step 1). Step 2 builds `/api/public/sms-status`: on a status callback, find `messages WHERE twilio_sid = MessageSid` → `UPDATE status`. **Wiring decision (rec):** set the number's default `statusCallback` at **provision time** (per-number) rather than re-touching the step-1 send primitive — keeps the frozen primitive untouched.

**Reuse seams (don't rebuild):** `enroll()` (opt-out + re-enroll guards built in), `exitOneYearOnDiscountClaim` pattern (→ generalize), `toE164()` (normalize inbound `From`), the find-or-create-conversation logic in `insert.server.ts` (→ `insertInboundMessageAdmin`), `writeNotificationByTemplateKey` (one_year interest + missed_call owner notify), the `crypto.subtle` HMAC pattern in `chat/token.server.ts` (reference; change SHA-256→SHA-1).

---

## Scope
**IN:** new server-to-server webhook routes (inbound SMS, SMS delivery-status, voice status) + `X-TextGrid-Signature` (HMAC-SHA1) verification + a by-`To` tenant resolver + inbound-message CRM materialization + real-time reply-driven exits + STOP/HELP/"pass" opt-out capture + missed-call textback trigger + the additive `provider_webhook_secret` (and supporting additive bits). **OUT:** per-number webhook *wiring* (that's A2P provision, step 5/6 — step 2 builds routes that exist/verify/process; provisioning points the numbers at them later); the incoming-voice TwiML/forwarding call-flow (tightly coupled to the call-forwarding step §5 — step 2 builds the *status-callback* detection, the `<Dial>`/forward.json call-flow lands with §5); Turnstile/rate-limit; A2P registration; reactivation pool; pg_cron scheduling.

## Recommended decisions (flag if you disagree — none are 50/50)
1. **Signature verify order:** read **raw** body (`await request.text()`) → parse `To` (untrusted) → `resolveTenantByNumber(To)` → load that client's `provider_webhook_secret` → `HMAC-SHA1(webhookURL + rawBody, secret)` base64 == `X-TextGrid-Signature` → only then parse/process. (The `To` is only used to *look up* the secret; the signature proves authenticity. Forged `To` can't produce a valid sig.)
2. **No secret stored (bootstrapping) → FAIL CLOSED:** if a client has no `provider_webhook_secret`, reject `401` (do not process). Real webhooks can't arrive until a number is provisioned anyway; STUB-validate with a synthetic request signed by a test secret you set on a test client.
3. **Unknown `To` (no client match) → `200` empty TwiML, drop + no-op** (don't 500 / don't let the provider retry-storm). Nothing to log under (no client_id).
4. **Idempotency:** dedupe inbound by `MessageSid`. Add a **partial unique index** `messages(twilio_sid) WHERE twilio_sid IS NOT NULL` (additive) and treat a `23505` on insert as "already processed → ack 200". Status callbacks are naturally idempotent (set status).
5. **Inbound-created contact source:** find-or-create by `(client_id, phone_e164=From)`. **Confirmed enum:** `contact_source = web_form, review_enroll, missed_call, import, manual, chat_widget, mobile_enroll`. The **voice/missed-call path reuses the EXISTING `missed_call` source — no migration.** For an unknown inbound-**SMS** sender (rare — inbound is almost always a reply from a contact we already have): **[LOCKED] add `inbound_sms`** (additive `ALTER TYPE ADD VALUE`) for accurate provenance.
6. **STOP handling = belt-and-suspenders:** set `opted_out_at` **and** immediately `exitActiveEnrollments` for the contact (real-time), rather than waiting for the next runner tick. (D1 is the backstop.)
7. **`statusCallback` wiring [LOCKED]:** set per-number at provision (step 5/6); step 2 only builds the `/sms-status` route. **The frozen v1.2 send primitive is NOT re-touched.**

## TextGrid facts (from the Breeze/Voice/10DLC docs)
- Inbound SMS webhook: `application/x-www-form-urlencoded`, PascalCase `From, To, Body, MessageSid, SmsStatus=received, NumSegments, NumMedia` (+ `MediaUrl0..`). Respond TwiML (`<Response></Response>` to ack).
- Signature: `X-TextGrid-Signature` = `Base64(HMAC-SHA1(webhookURL + rawRequestBody, key=subaccount webhook_secret))`. **Construction differs from Twilio — do not reuse a Twilio validator.**
- SMS status callback: `MessageSid, MessageStatus={delivered|undelivered}, SmsStatus, SmsStatusDetail, ...` (`delivered`/`pending`/`undelivered` arrive here; `sent`/`failed` came on the send response).
- Voice: incoming → `voiceUrl` (`CallSid, From, To, CallStatus=ringing, Direction=inbound`), respond TwiML. **Missed call = inferred** from the call **status callback** `CallStatus ∈ {no-answer, busy, failed}` (no dedicated missed-call webhook).
- Webhooks are configured **per number** (`smsUrl`/`voiceUrl`/`statusCallback`) at provision time.

---

## Change-set

### 1. Additive migration(s) — `audit_tenant_rls()=0` after
```sql
-- (1) per-client webhook secret — additive
ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS provider_webhook_secret text;

-- (2) idempotency index. FIRST run the dup check; create the index ONLY if it returns 0 rows:
--       SELECT twilio_sid, count(*) FROM public.messages
--         WHERE twilio_sid IS NOT NULL GROUP BY 1 HAVING count(*) > 1;
--     → 0 rows: proceed.  → any rows: STOP + flag (do NOT force the index; resolve the dups first).
CREATE UNIQUE INDEX IF NOT EXISTS uq_messages_twilio_sid
  ON public.messages (twilio_sid) WHERE twilio_sid IS NOT NULL;   -- partial: NULL sids exempt

-- (3) inbound-SMS provenance [LOCKED add]. MUST be its OWN migration that fully COMMITS before the
--     inbound route (which inserts source='inbound_sms') is deployed/run: Postgres cannot use a
--     newly-ADDed enum value in the SAME transaction that adds it. Do NOT combine with route code,
--     and do NOT reference 'inbound_sms' in the same txn. (missed_call source already exists.)
ALTER TYPE public.contact_source ADD VALUE IF NOT EXISTS 'inbound_sms';
```
*(The partial index covers step-1's outbound `STUB-`/real sids too — the dup check above is the gate; STUB uuids are unique by construction.)*

### 2. Signature verifier — `src/lib/webhooks/textgrid-signature.server.ts` (net-new)
`verifyTextGridSignature({ url, rawBody, secret, header })` → `crypto.subtle` HMAC **SHA-1** over `url + rawBody`, base64, constant-time compare to `header`. Returns bool. (Model on `chat/token.server.ts`'s HMAC helper; SHA-1 not SHA-256.)

### 3. By-number tenant resolver — add to `src/lib/tenant-resolver.server.ts`
`resolveTenantByNumber(toE164)` → `clients` WHERE `twilio_number = toE164` AND `status='active'` AND `deleted_at IS NULL` → `{ clientId, slug, providerWebhookSecret }`. (No CORS/origin — server-to-server.)

### 4. Inbound message helper — `src/lib/messages/insert.server.ts` (extend)
`insertInboundMessageAdmin({ clientId, contactId, body, sid, status:"received" })` reusing the existing find-or-create-conversation + bump logic (generalize `insertOutboundMessageWith` to take `direction`). Dedupe via the unique `twilio_sid` index.

### 5. Shared exit helper — extract from `enroll.server.ts`
`exitActiveEnrollments(clientId, contactId, sequenceKey, reason)` (generalize `exitOneYearOnDiscountClaim`) → `UPDATE ... status='exited', next_run_at=null` + `drip_exit` event. Reused by the inbound handler.

### 6. Routes (net-new, server-to-server, signature-gated, no CORS)
- **`POST /api/public/sms/inbound`** — verify sig → resolve by `To` → find-or-create contact (`From`) → dedupe by `MessageSid` → `insertInboundMessageAdmin` + `inbound_sms` event → **keyword parse** (STOP/STOPALL/UNSUBSCRIBE/CANCEL/QUIT/END, START/YES/UNSTOP, HELP/INFO, and the app's **`pass`** — all **whole-word**, case-insensitive on trimmed body): STOP/`pass` → set `opted_out_at` + `exitActiveEnrollments`(all); START → clear `opted_out_at`. Else (a real reply) → **real-time exits**: one_year_followup active → `exitActiveEnrollments` + `writeNotificationByTemplateKey("one_year_reply_interest_internal")`. (missed-call sms2 reply-skip needs no special handling — the runner's `skipIfReplied` now works because the inbound message exists.) → respond `<Response></Response>`.
- **`POST /api/public/sms-status`** — verify sig → find `messages WHERE twilio_sid=MessageSid` → `UPDATE status=MessageStatus`. Idempotent. (Cross-client safe: match on the globally-unique sid.)
- **`POST /api/public/voice-status`** — verify sig → resolve by `To` → on `CallStatus ∈ {no-answer,busy,failed}`: find-or-create contact (`From`), check `last_missed_call_textback_at` throttle, `enroll({sequenceKey:"missed_call_textback"})`, set `last_missed_call_textback_at=now()`, `missed_call` owner notification. → `200`.
- *(Incoming-voice TwiML/forward route → deferred to §5 call-forwarding.)*

### 7. Version stamp
Bump `RUNNER_VERSION` (e.g. → `v20260617-1`) in the same commit — the cron route bundle changes (new routes), and the `?ping=1` gate must reflect the new bundle. (Step 2 may also touch `runner.server.ts` if the exit helper is extracted from it.)

---

## Validation walk

**STUB-validatable now (mode-agnostic — POST synthetic signed payloads; no provider needed):**
1. Deploy → `?ping=1` echoes the new version (deploy-lag gate).
2. **Signature verify:** a correctly-signed synthetic inbound passes; a bad/missing signature → `401`; a client with no `provider_webhook_secret` → `401` (fail-closed).
3. **Tenant resolution:** signed inbound with a known `To` resolves the right client; unknown `To` → `200` empty, no-op.
4. **Inbound CRM:** signed inbound creates/upserts the conversation + an inbound `messages` row (`direction='inbound'`, `status='received'`, `twilio_sid=MessageSid`) + `inbound_sms` event; a **duplicate** `MessageSid` is a no-op (idempotent).
5. **Opt-out capture — ⭐ HIGHEST-STAKES (end-to-end TCPA goes live here); exercise hardest:**
   - (a) signed inbound `Body="STOP"` → `contacts.opted_out_at` set **AND** `exitActiveEnrollments` runs in the SAME request (all active enrollments → `exited` + `drip_exit` event) — real-time, not next tick.
   - (b) `Body="pass"` (whole-word) → same as STOP. **`Body="passport"` / `"my password"` → does NOT opt out** (`\bpass\b`).
   - (c) `Body="START"` → `opted_out_at` cleared.
   - (d) **D1 end-to-end proof (the loop closes):** after (a), make a fresh enrollment due for that contact + run a runner tick → D1 EXITS it (`exited_opted_out`), **no `sms_sent`, no outbound `messages` row**. Proves the step-2 *write* + step-1 *read* are wired end-to-end.
   - (e) reply box to the opted-out contact → throws `contact_opted_out`, no message inserted.
   - Standard set: STOP/STOPALL/UNSUBSCRIBE/CANCEL/QUIT/END all opt out; START/YES/UNSTOP all clear.
6. **Real-time reply-exit:** an active `one_year_followup` contact sends a reply → enrollment `exited` (`exited_on_reply`/`drip_exit`) + the `one_year_reply_interest_internal` notification written.
7. **Missed-call trigger:** a signed `voice-status` with `CallStatus=no-answer` → contact found/created + `missed_call_textback` enrolled (throttle respected on a second within-window call) + `missed_call` notification.
8. `audit_tenant_rls()=0`.

**LIVE-gated (deferred to LIVE smoke / after provisioning):** real inbound from TextGrid, real `X-TextGrid-Signature` from the provider, real delivery-status callbacks updating `messages.status`, the actual per-number webhook wiring.

---

## Blockers / edge cases (tagged)
- **[FIX — in step 2] Idempotency / replay.** Duplicate webhooks (provider retries) → without the unique `twilio_sid` index, duplicate inbound rows + double exits/opt-outs. Decision 4: partial unique index + treat 23505 as already-processed.
- **[FIX — in step 2] Signature bootstrapping.** Webhook before a per-client secret is stored → fail-closed `401` (decision 2). STUB-test with a test-client secret.
- **[FIX — in step 2] Inbound from unknown `To`.** No client match → `200` empty, drop (decision 3).
- **[FIX — in step 2] Inbound-created contact source.** find-or-create by `(client_id, From)`; needs a `contact_source` enum value → additive `ADD VALUE 'inbound_sms'/'inbound_call'` (decision 5; confirm enum first).
- **[FIX — in step 2] STOP mid-drip.** Set `opted_out_at` + immediate `exitActiveEnrollments` (decision 6); D1 is the backstop next tick.
- **[FIX — in step 2] `pass` whole-word.** `\bpass\b` case-insensitive on trimmed body — must not match `passport`/`passion`. Standard STOP-keyword set handled too (TextGrid also auto-suppresses natively, but the app MUST still set `opted_out_at` so OUR runner stops).
- **[FIX — in step 2] Raw-body discipline.** Verify HMAC over the EXACT raw bytes (`await request.text()` once, before parsing) — re-serialized form params will not match the signature.
- **[BACKLOG] Delivery-status race.** A status callback could arrive before the outbound row's insert commits (unlikely with sync send). If `messages WHERE twilio_sid` finds nothing, no-op + ack (the row's terminal status just won't reflect the early callback) — acceptable; revisit if observed.
- **[BACKLOG] HELP auto-reply.** TextGrid answers HELP natively; the app need only record it. No app reply required unless we want a branded HELP.

## Open / confirm items
- ~~Confirm `contact_source` enum~~ DONE: `web_form, review_enroll, missed_call, import, manual, chat_widget, mobile_enroll`. `missed_call` exists (voice path needs no migration); only optional `inbound_sms` for unknown SMS senders.
- The exact route paths (`/api/public/sms/inbound`, `/sms-status`, `/voice-status`) must match what provisioning sets as `smsUrl`/`statusCallback`/`voiceUrl` at step 5/6 — lock the names here.
- Parent-on-subaccount auth confirm (carried from step 1) does not gate step 2, but the **per-subaccount `webhook_secret`** is what step 2 verifies against — confirm TextGrid returns it on subaccount create (10DLC doc says yes).
