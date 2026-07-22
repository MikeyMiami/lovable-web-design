# Telnyx Parallel Build — Implementation Plan (for operator audit)

**Written 2026-07-15.** The concrete build plan for adding a complete **Telnyx SMS + voice provider path side-by-side with TextGrid**, per-client switchable, TextGrid untouched — designed so Telnyx can later become the sole provider with a small, bounded edit. Reconciles: (1) the external handoff spec (`docs/TELNYX PARALLEL BUILD — HANDOFF S.txt`), (2) the full TextGrid touchpoint audit of `cloud-spark-setup`, (3) the live code (send primitive, all 4 edge functions, admin settings card), (4) Telnyx platform research. Supersedes the earlier high-level `TELNYX-DUAL-PROVIDER-SCOPE.md`.

> **🔄 REVISION 2026-07-15 (post-Phase-A/B): SINGLE-ACCOUNT MODEL — NO Managed Accounts.** Telnyx Managed Accounts require a **$1,000/month commit plan** (not pay-as-you-go) and buy nothing we need (we control all code; clients never see Telnyx). Telnyx support confirmed: one PAYG account supports multiple 10DLC brands (different EINs) + campaigns + messaging profiles + 49 numbers/campaign. **Superseding changes:** D6 → ONE account-wide `TELNYX_API_KEY` (renamed from TELNYX_MASTER_API_KEY; no per-client keys; no MA-enablement dependency or fallback); D5 columns `telnyx_managed_account_id` + `telnyx_api_key` → REMOVED (drop migration); runbook §7 → 5 steps (MA steps deleted); Day-0 → no MA enablement; **NEW trust-boundary note:** with one shared key, client isolation = app logic — the outbound `from`-resolution + the inbound `telnyx_number` lookup are security-relevant and fixture-tested (unknown-number / cross-client). Authoritative correction spec: the operator's "Telnyx Build — Findings & Revision Spec" (2026-07-15); corrected model documented in `skills/telnyx-provider/SKILL.md`. Everything else in this plan stands.

**Status: ✅ AUDITED + APPROVED 2026-07-15 (operator audit via external reviewer). Rulings: J1–J6 ALL APPROVED as recommended (J3 "enthusiastically"; J5 confirmed). Green light: SHIP PHASE A.** Audit riders + gap fixes are folded into the sections below and marked ⟦AUDIT⟧. Binding conditions: (1) every prompt touching `_shared/` gets a post-publish grep acceptance check that Telnyx handlers literally `import` from `_shared/` — no inline copies (prior Lovable inline-duplication incident); (2) TextGrid freeze means freeze — any change during the dual window is an explicit, logged exception; bugs found in shared logic are fixed in `_shared/` only, divergence noted, never back-ported.

---

## 1. What I audited & found (current state)

### 1a. The provider boundary is exactly six surfaces (everything else is provider-agnostic)
| Surface | Where it lives today (TextGrid) | Verified detail |
|---|---|---|
| Outbound SMS | `src/lib/sms/send.server.ts` (`sendSms`/`sendSmsWithRetry`) | SEND-ONLY, zero DB access. Contract: `SendSmsArgs {to, from, body, sendingAccountSid, auth, mode, statusCallback?, idempotencyKey?}` → `SendResult {ok:true,sid,status} \| {ok:false,retryable,error}`. Stub mode returns `STUB-<uuid>` with no network. Unrendered-`{token}` guard (LIVE only). Hardcoded `SMS_STATUS_CALLBACK_URL` → sms-status edge fn. |
| Its 3 callers | `cron/runner.server.ts`, `messages/reply.functions.ts`, `admin/test-sms.functions.ts` | Each resolves `from` (=`clients.twilio_number`) + auth (`subaccount ?? master`) caller-side and passes them in. (The former 4th caller `reactivation/runner.server.ts` was DELETED 2026-07-21 with the number pool; reactivation now flows through the normal `cron/runner.server.ts` from `clients.telnyx_number`.) |
| Inbound SMS webhook | `supabase/functions/sms-inbound` | Form-encoded Twilio params; HMAC-SHA1(url+rawBody) vs `x-textgrid-signature`, keyed per-client `provider_webhook_secret`; contact upsert → conversation upsert → message insert (dedup on `twilio_sid` 23505) → `inbound_sms` event → intent parse (STOP/STOPALL/UNSUBSCRIBE/CANCEL/QUIT/END + whole-word `PASS` → opt-out; START/YES/UNSTOP → opt-in; else one_year reply-exit) → empty TwiML ack. |
| SMS status webhook | `supabase/functions/sms-status` | `MessageSid`+`MessageStatus` → `messages.status` update (terminal: delivered/failed/undelivered). |
| Voice inbound + status | `supabase/functions/voice-inbound`, `voice-status` | TwiML `<Dial timeout=20 callerId action=voice-status>`; normalizeE164 on To/From (just shipped); branch instrumentation (`voice_inbound_branch`); miss statuses {no-answer,busy,failed}; `fireMissedCall` (contact upsert → 60-min throttle → enroll `missed_call_textback` → `missed_call` event). |
| Config + admin | `config.server.ts` `getTextGridConfig` (SMS_MODE, TEXTGRID_BASE_URL, MASTER_SID, MASTER_TOKEN); `admin.settings.tsx` card **"Messaging (TextGrid)"** | Card fields (verified at lines 571–644): twilio_number, provider_subaccount_sid (required-flagged), provider_subaccount_auth_token (SecretInput), provider_webhook_secret (SecretInput + `configured` badge), a2p_brand_id, a2p_campaign_id, a2p_status (select), call_forwarding_number. Single-source rule: `twilio_number` lives ONCE on clients. |

Provider-AGNOSTIC (untouched by this build): cron runner control logic (claim/lease, window, caps, retries), resolveTemplate + merge vars + tracked links, `insertOutboundMessage*`, conversations/messages/events model, enrollments/sequences, notifications (in-app+email+push), review funnel, PWA, tenant model, RLS.

### 1b. Key facts that shape the build
- **The GitHub repo (`MikeyMiami/cloud-spark-setup`) is Lovable's live mirror** — Lovable auto-commits every change (origin/main already has yesterday's Dial-action fix). So "ship to repo" and "ship to Lovable" are the same pipeline; the question is only which direction (see J1).
- **Webhooks exist in two copies** — live edge functions + dead `src/routes/api/public/*` duplicates. Telnyx work targets **edge functions only**; the app-route copies stay dead.
- **Write-side E.164 normalization already shipped** (admin + onboarding) — the new Telnyx number fields must join it.
- **Reactivation** ~~pool sends from TextGrid master-account pool numbers — v1 keeps reactivation TextGrid-only (see J4)~~ **[SUPERSEDED 2026-07-21 — the number pool was REMOVED; reactivation now sends from the client's own Telnyx number via the normal per-client runner]**.
- **The handoff's ground rules are adopted**: TextGrid frozen, per-client switch, capture-first debug discipline, stub/fixture-first build (Telnyx account currently **blocked** at signup — support ticket pending), code is not the critical path (campaign approval + account unblock are).

---

## 2. Architecture decisions (D#) — adopted vs amended from the handoff

| # | Decision | Source |
|---|---|---|
| D1 | **Per-client switch: `clients.provider` text, default `'textgrid'`** (`'textgrid' \| 'telnyx'`, free-text + code guard per house style). All routing keys off it. | Handoff — adopted |
| D2 | **Separate NEW edge functions**: `telnyx-sms-inbound`, `telnyx-sms-status`, `telnyx-voice-inbound`, `telnyx-voice-status`. TextGrid's four stay byte-frozen. Telnyx numbers point at Telnyx URLs — no runtime provider-sniffing on inbound. | Handoff — adopted |
| D3 | **`send.server.ts` becomes a thin router preserving the exact `SendResult` contract**: `sendSms(args)` branches on a new optional `args.provider` (default `'textgrid'`) → existing TextGrid code (moved verbatim into `sendViaTextGrid`) or new `sendViaTelnyx` (`POST https://api.telnyx.com/v2/messages`, JSON, `Bearer <api key>`, `data.id`→`sid`, `errors[0].code/title/detail`→`error`, `webhook_url`=telnyx-sms-status + `use_profile_webhooks:false`). Stub mode identical for both. Callers (runner/reply/test-sms) select `provider` + resolve per-provider from/auth. | Handoff — adopted, concretized to the real contract |
| D4 | **Shared webhook core in `supabase/functions/_shared/`** (`core.ts`: normalizeE164, parseIntent, contact/conversation/message upsert + dedup, exitActiveEnrollments, fireMissedCall, event helpers; `telnyx.ts`: Ed25519 verify + envelope parse). **AMENDED (J2):** Telnyx handlers import it; **TextGrid functions stay byte-frozen and do NOT get refactored to import it** in v1 (handoff wanted extraction; I recommend not touching the working live path — see J2). | Amended — needs your ruling |
| D5 | **Parallel `telnyx_*` columns instead of overwriting shared columns** (**AMENDED — J3**): `telnyx_number`, `telnyx_managed_account_id`, `telnyx_api_key`, `telnyx_messaging_profile_id`, `telnyx_texml_app_id`, `telnyx_brand_id`, `telnyx_campaign_id`, `telnyx_a2p_status`. **⚠️ 2026-07-20: `telnyx_managed_account_id` + `telnyx_api_key` were DROPPED — single-account model (no Managed Accounts); see the REVISION banner + `skills/telnyx-provider`.** Handoff wanted to reuse `provider_subaccount_*`/`twilio_number`/`a2p_*`; I recommend parallel columns because: (a) flip becomes literally ONE field (`provider`) — instantly reversible both ways with zero data loss; (b) during a migration window the client's OLD TextGrid number keeps receiving inbound (replies/STOP on old threads) while new sends go out on Telnyx — impossible if `twilio_number` is overwritten; (c) brand/campaign are genuinely separate TCR registrations per provider — overwriting loses the TextGrid record. | Amended — needs your ruling |
| D6 | **Credentials**: global secrets `TELNYX_MASTER_API_KEY` (provisioning + send fallback) + `TELNYX_PUBLIC_KEY` (Ed25519 webhook verify — ONE per account; `provider_webhook_secret` unused on Telnyx). Per-client: Managed Account ID + MA API key (per-client isolation, mirrors subaccounts). **⚠️ 2026-07-20: ABANDONED — no Managed Accounts, no per-client MA keys; ONE account-wide `TELNYX_API_KEY` (renamed from `TELNYX_MASTER_API_KEY`), no MA-fallback. See REVISION banner + `skills/telnyx-provider`.** **Fallback designed in**: if Managed Accounts enablement lags, everything runs under the manager account (per-client MA fields null → master key used) — code identical. | Handoff — adopted |
| D7 | **Voice = TeXML Application** (webhooks arrive in Twilio format), response TeXML: `<Dial timeout="20" callerId="{telnyx_number}" action="{TELNYX_VOICE_STATUS_URL}" method="POST" machineDetection="Enable" amdStatusCallback="{TELNYX_VOICE_STATUS_URL}"><Number>{call_forwarding_number}</Number></Dial>`. **⚠️ 2026-07-20 (pre-correction recipe): live-validated AMD puts `machineDetection` on the `<Number>` noun — NOT on `<Dial>` (`<Dial machineDetection>`/`amdStatusCallback` are silently ignored); `timeout=45`. See `skills/telnyx-provider` §3.** Miss rule v1 with ⟦AUDIT⟧ **explicit precedence**: **AMD=human overrides everything (never fire missed); AMD=machine fires missed even on `completed`**; else `DialCallStatus ∈ {no-answer,busy,failed,canceled}` → missed. → shared `fireMissedCall` (same 60-min throttle). AMD solves the proven TextGrid blind spot (voicemail answers the forward → `completed`). ⟦AUDIT⟧ **Q11 decision branch:** if AMD turns out to gate/delay the bridge (owner answers to seconds of silence — bad on hot lead calls), re-evaluate: prefer async AMD mode if available, else consider dropping AMD from the forward leg and falling back to a duration heuristic. No `<Say>` bandage (Telnyx has real ringback — Day-0 listen test confirms). Exact attribute spellings verified against TeXML docs before coding (open Q4). | Handoff — adopted + audit riders |
| D8 | **Ed25519 verification**: WebCrypto-first (`crypto.subtle` supports Ed25519 in Deno/Supabase Edge), signed message `"{timestamp}\|{rawBody}"`, headers `telnyx-signature-ed25519` + `telnyx-timestamp`, 5-min replay window; `@noble/ed25519` esm.sh fallback if WebCrypto rejects. **TeXML voice webhooks: signing scheme UNKNOWN (Q1) → voice handlers run capture + soft-verify (log-only) until Day-0 confirms** — the silent-401 lesson, baked in. | Handoff — adopted + hardened |
| D9 | **Capture-first everywhere**: every Telnyx handler opens with an unconditional raw-capture debug event (`telnyx_*_debug`) + a branch event before every return (`telnyx_*_branch` with the served response) — the exact instrumentation that cracked the voice saga. Stripped only at steady-state. | Handoff — adopted |
| D10 | **Telnyx auto opt-out DISABLED on the messaging profile** — our in-app STOP/START/`pass` logic stays the single source of truth (no double STOP replies). Verified on the Day-0 STOP canary. | Handoff — adopted (confirm = J5) |
| D11 | **Idempotency**: Telnyx has no documented per-request idempotency header on `/v2/messages`; v1 relies on the runner's existing `send_attempts` app-level ledger (already the real guard). Noted as open Q10. | New |
| D13 | ⟦AUDIT⟧ **Suppression-list opt-out sync (J5 watch-item)**: if a Telnyx send hard-fails with the provider's "recipient has opted out / suppressed" error class, that error is authoritative. Mechanism (primitive stays SEND-ONLY): `sendViaTelnyx` maps that error class to the distinguishable string `optout_blocked:<code>`; the RUNNER (caller) on `optout_blocked` sets `contacts.opted_out_at` + exits active enrollments. Exact code class identified at Day-0 canary (watch error logs). | Audit rider |
| D12 | **Endgame ("built to replace")**: see §9 — final cutover is a bounded edit set, listed file-by-file now, so the code is written with that grain. | Your requirement |

---

## 3. DB migration (additive, one statement)

```sql
alter table public.clients
  add column if not exists provider text not null default 'textgrid',
  add column if not exists telnyx_number text,
  add column if not exists telnyx_managed_account_id text,   -- ⚠️ ABANDONED 2026-07-20: DROPPED (single-account model, no Managed Accounts)
  add column if not exists telnyx_api_key text,               -- ⚠️ ABANDONED 2026-07-20: DROPPED; key is now the account-wide TELNYX_API_KEY secret
  add column if not exists telnyx_messaging_profile_id text,
  add column if not exists telnyx_texml_app_id text,
  add column if not exists telnyx_brand_id text,
  add column if not exists telnyx_campaign_id text,
  add column if not exists telnyx_a2p_status public.a2p_status not null default 'not_started';
```
- All nullable/additive; zero effect on existing rows/logic (runner ignores them until a caller passes `provider:'telnyx'`).
- `telnyx_api_key` rides the same protections as `provider_subaccount_auth_token` today (admin-only RLS; NOT in the `get_client_public` anon projection — verify in validation).
- `messages.twilio_sid` holds Telnyx `data.id` unchanged (dedup indexes apply as-is). No renames anywhere (house rule).

## 4. File-by-file build manifest

**NEW files:**
| File | Contents |
|---|---|
| `supabase/functions/_shared/core.ts` | `normalizeE164`, `parseIntent` (STOP/START/`pass`), `upsertContact`, `upsertConversation`, `insertInboundMessage` (dedup), `exitActiveEnrollments`, `enroll`, `fireMissedCall` (60-min throttle), event helpers. **Written new to byte-match current TextGrid behavior** (source: the live fns) — imported by Telnyx handlers only (J2). |
| `supabase/functions/_shared/telnyx.ts` | `verifyTelnyxSignature(req, rawBody)` (Ed25519, WebCrypto-first, replay window), envelope parser (`data.event_type`/`data.payload`), TeXML response helper. |
| `supabase/functions/telnyx-sms-inbound/index.ts` | Raw-capture → Ed25519 verify → parse `message.received` → normalize both numbers → client lookup `.eq("telnyx_number", to)` [+ `provider='telnyx'` not required for lookup — the number IS Telnyx-unique] → shared core (contact/convo/message/intent/reply-exit) → branch event → 200 JSON. |
| `supabase/functions/telnyx-sms-status/index.ts` | Raw-capture → verify → parse `message.sent`/`message.finalized` per-recipient statuses → map to existing `messages.status` vocabulary (delivered/failed/undelivered) by `twilio_sid = data.payload.id` → branch event. (Completes the delivery-receipt feature properly.) ⟦AUDIT Gap 3⟧ **Terminal-wins ordering guard**: webhook events can arrive out of order (`message.sent` after `message.finalized` under retry) — never downgrade a terminal status (delivered/failed/undelivered) to a transient one; mirror the TextGrid status function's TERMINAL-set behavior. |
| `supabase/functions/telnyx-voice-inbound/index.ts` | Raw-capture (headers logged, values never) → **soft-verify until Q1 answered** → parse Twilio-style params → normalize → lookup by `telnyx_number` → TeXML `<Dial>` per D7 (or missed_say TeXML + fireMissedCall when no forwarding number) → branch events identical to the TextGrid voice fn pattern. |
| `supabase/functions/telnyx-voice-status/index.ts` | Handles BOTH the Dial action callback and the AMD callback (same URL): raw-capture → soft-verify → miss rule per D7 → shared `fireMissedCall` → branch event. |
| `src/lib/sms/telnyx-send.server.ts` | `sendViaTelnyx(args)` per D3 (fetch, JSON, error mapping, `parts` logging into the error/status string for cost visibility). SEND-ONLY, no DB. |
| `supabase/functions/_shared/fixtures/` (or tests co-located) | Documented-shape fixtures for all 4 webhook payloads + a fixture-runner note; reconciled against real captures at Day-0. |

**EDITED files (bounded):**
| File | Edit |
|---|---|
| `src/lib/sms/send.server.ts` | Existing live logic moved verbatim into `sendViaTextGrid()`; `sendSms` gains `provider?: "textgrid"\|"telnyx"` + `stub` branch stays on top; routes to the two transports. `SendResult`/retry semantics unchanged. |
| `src/lib/config.server.ts` | Add `getTelnyxConfig()` (`TELNYX_MASTER_API_KEY`, `TELNYX_PUBLIC_KEY`, base URL, same SMS_MODE). `getTextGridConfig` untouched. |
| `src/lib/cron/runner.server.ts` | Client-identity cache adds `provider`, `telnyx_number`, `telnyx_api_key` to its SELECT; per-send: `provider==='telnyx'` → `from=telnyx_number`, `auth=telnyx_api_key ?? master`, pass `provider`. Control logic untouched. |
| `src/lib/messages/reply.functions.ts` | Same per-provider from/auth resolution. |
| `src/lib/admin/test-sms.functions.ts` | Same + surface provider in the result. |
| `src/routes/_authenticated/admin.settings.tsx` | See §5. |
| `src/routes/_authenticated/admin.health.tsx` | Add `telnyxMasterKeySet` / `telnyxPublicKeySet` indicators. |
| `src/lib/clients/onboarding.functions.ts` | Accept/persist `provider` (default textgrid) — one field; normalize `telnyx_number` on write when present. |

**FROZEN (guaranteed untouched):** the four TextGrid edge functions, `getTextGridConfig`, TextGrid card fields/behavior, reactivation runner, all drip/runner control logic, sequences/templates/notifications, RLS, the dead app-route webhook copies.

## 5. Admin UI spec (mirrors the TextGrid card pattern exactly)

1. **Provider select** (top of the messaging area): `Messaging Provider — TextGrid (default) | Telnyx` → writes `clients.provider`. Helper copy: "Which provider this client's sends + webhooks run on. Flipping is instant and reversible; both configs are kept."
2. **Existing "Messaging (TextGrid)" card: unchanged.** Badge it "ACTIVE"/"standby" from `provider`.
3. **NEW "Messaging (Telnyx)" card** (same Card/Input/SecretInput components + save-payload pattern as the TextGrid card):
   - Telnyx number (`telnyx_number`) — placeholder `+15555550123`, **normalizeE164 on write**
   - Managed Account ID (`telnyx_managed_account_id`)
   - Managed Account API key (`telnyx_api_key`) — SecretInput + `configured` badge
   - Messaging Profile ID (`telnyx_messaging_profile_id`)
   - TeXML App ID (`telnyx_texml_app_id`)
   - 10DLC Brand ID (`telnyx_brand_id`) / Campaign ID (`telnyx_campaign_id`)
   - Telnyx A2P status (`telnyx_a2p_status`) — same select vocabulary as today
   - (call_forwarding_number stays in its current shared spot — provider-independent)
   - Card footer: the 7-step provisioning runbook (§7) as labeled helper text, one step per field group — so it's followable in-UI.
4. **Agency view: no changes** (messaging config is per-client `/admin` only; the onboarding wizard's A2P step already collects the provider-neutral EIN/legal/legal business address/vertical fields both registrations consume).

## 6. Feature coverage matrix (every feature → its Telnyx mechanism)

| Feature | Telnyx path | Change class |
|---|---|---|
| All drip sends (review, one-year, lead-form, discount, missed-call) | Runner → send router → `sendViaTelnyx` | Caller resolution only |
| Reply box | Same router | Same |
| Test-SMS canary | Same + provider surfaced | Same |
| Delivery-status receipts (v1.11) | `telnyx-sms-status` (`message.finalized`) → same `messages.status` — **more reliable than TextGrid's** | New fn, same table |
| Inbound STOP/STOPALL/…/`pass` opt-out + START opt-in | `telnyx-sms-inbound` → shared `parseIntent` (identical keywords) + Telnyx profile auto-opt-out DISABLED | New fn, same logic |
| One-year exit-on-reply; missed-call SMS#2 reply-skip | Same inbound fn writes the same `messages`/`enrollments` — downstream logic untouched | None |
| Conversation threading / inbox / unread | Same tables | None |
| Missed-call textback | TeXML `<Dial action>` + **AMD** → `fireMissedCall` — catches the voicemail-answers case TextGrid provably cannot | New fns, upgrade |
| Voice forwarding + **caller ringback** | Native on Telnyx (183/early media or 180) — the entire reason we're here; Day-0 listen test is the gate | Provider property |
| Owner notifications (in-app/email/push) | Fire from shared writes — untouched | None |
| Tracked review links/funnel; send window/caps/throttle; enrollment guards | Provider-agnostic | None |
| Reactivation | **[SUPERSEDED 2026-07-21 — number pool REMOVED; reactivation runs on the client's OWN Telnyx number via the normal runner, no pool].** ~~Stays TextGrid v1; pool migrates at full cutover with a `reactivation_numbers.provider` column. (J4)~~ | Removed |
| SMS_MODE stub validation | `stub` branch identical for both providers — full drip regression runnable on a telnyx-flagged client with zero network | None |

## 7. Per-client Telnyx provisioning runbook (manual v1 — mirrors textgrid-provider §4)

1. Manager account → create **Managed Account** (name = client slug) → `telnyx_managed_account_id`.
2. Mint an **API key** in that MA → `telnyx_api_key`.
3. Register **10DLC brand** (same EIN/legal/legal business address/vertical fields the wizard captures) → then **campaign** — reuse the `/a2p-site-compliance` generated pack VERBATIM (same TCR registry; samples/opt-in language that passed on TextGrid). ~3–7 business days. → `telnyx_brand_id`/`telnyx_campaign_id`/`telnyx_a2p_status`.
4. Buy a **local number** (~$1/mo; requires account **L2 verification**) → `telnyx_number`.
5. **Messaging Profile** (inbound webhook → `telnyx-sms-inbound`; **auto opt-out OFF** per D10) → `telnyx_messaging_profile_id`; assign number to profile **and campaign** (~2h propagation; no A2P traffic before it completes).
6. **TeXML app** (Voice URL → `telnyx-voice-inbound` POST; Status Callback → `telnyx-voice-status`) → `telnyx_texml_app_id`; assign number.
7. Flip `clients.provider = 'telnyx'`. Everything routes automatically. (Flip back = one field.)

⟦AUDIT Gap 5a⟧ **Pre-flip asymmetry note:** once steps 4–6 are done but `provider` is still `textgrid`, INBOUND on the Telnyx number already processes (the lookup is by `telnyx_number`, deliberately — enables pre-flip inbound canaries) while OUTBOUND still goes from the TextGrid number. Harmless as long as the Telnyx number is not published anywhere until flip.

Phase-2 (post-v1): steps 1–6 are all API-covered → automate in onboarding (the thing TextGrid never allowed). Closes the manual-wiring gap permanently on the Telnyx side.

## 8. Skills & docs plan

| Artifact | Action |
|---|---|
| `skills/telnyx-provider/SKILL.md` | **NEW** — mirrors textgrid-provider's structure: §0 dual-provider model + frozen list; §1 auth/env (master key, MA keys, Ed25519 public key, fallback-to-manager); §2 outbound `/v2/messages` contract + SendResult mapping + stub; §3 webhooks (JSON envelope, Ed25519, capture-first, the four `telnyx-*` fns, soft-verify rule for TeXML); §4 Managed-Account + 10DLC provisioning runbook (§7 above); §5 voice TeXML (`<Dial action>` + AMD + miss rule + ringback expectation); §6 handoff to a2p-site-compliance (same pack); §7 open questions Q1–Q10; §8 Day-0 protocol + implementation order; §9 endgame cutover edit-set. |
| `skills/textgrid-provider/SKILL.md` | UPDATE — banner: dual-provider era; `clients.provider` switch; TextGrid = default/fallback, **frozen**; any behavior change during the dual window must land in `_shared` AND here consciously; pointer to telnyx-provider. |
| `skills/admin-view/SKILL.md` | UPDATE — provider select + the Telnyx card fields (§5), same wiring style as the TextGrid card docs. |
| `skills/features/SKILL.md` | UPDATE — missed-call textback: provider-dependent detection note (TextGrid status/duration limits + voicemail blind spot vs Telnyx Dial-action + AMD). |
| `skills/new-client-site/SKILL.md` | UPDATE — launch step 2 becomes "provider registration (textgrid-provider §4 **or** telnyx-provider §4, per `clients.provider`)". |
| `docs/ONBOARDING-ORDER-OF-OPERATIONS.md` | UPDATE — Phase C gains the Telnyx alternative path + runbook pointer. |
| `skills/a2p-site-compliance/SKILL.md` | UPDATE — note: the generated registration pack feeds BOTH providers (same TCR); only the submission mechanics differ. |
| `skills/automation-config/SKILL.md` | NO CHANGE (verified — copy is provider-agnostic). |

## 9. Endgame — the "replace TextGrid entirely" edit-set (designed-in now)

When Telnyx is proven and you call the cutover, the FINITE change is exactly:
1. Data: flip remaining `clients.provider` rows → `'telnyx'`; change the column default to `'telnyx'`.
2. Delete `sendViaTextGrid` + collapse the router (sendSms = sendViaTelnyx + stub).
3. ⟦AUDIT Gap 1 — QUIET PERIOD⟧ **Do NOT delete TextGrid inbound immediately.** Real contacts received texts from TextGrid numbers (e.g. the Review Batch's 15 recipients) and can reply **STOP weeks later** — the old numbers must keep RECEIVING. Rule: **all four TextGrid edge functions + the TextGrid numbers stay alive as a unit until 60 days after the LAST TextGrid send to any real contact**; then delete the functions + `getTextGridConfig` + the `TEXTGRID_*` secrets and release the numbers together. (Functions and numbers retire as a unit — deleting the voice fns while numbers are live would point inbound calls at a dead webhook.)
4. Remove the "Messaging (TextGrid)" card + provider select (or leave the select for a future 3rd provider).
5. ~~Migrate the reactivation pool to Telnyx numbers (+ provider column or repoint).~~ **[OBSOLETE 2026-07-21 — pool REMOVED; reactivation already runs per-client from `clients.telnyx_number`.]**
6. Retire columns `provider_subaccount_*`, `provider_webhook_secret` (leave in place, null — house rule: no renames/drops needed).
7. Docs: textgrid-provider skill → ARCHIVED banner.
⟦AUDIT⟧ **Invariant (assert, don't assume):** opt-out is **contact-level and provider-agnostic** — a STOP arriving via the TextGrid inbound path (quiet period) suppresses Telnyx sends to that contact, because both paths write the same `contacts.opted_out_at` flag the runner checks pre-send regardless of provider. Asserted in the Phase-B validation checklist.
Nothing else changes — because no TextGrid-specific logic leaks into `_shared/`, the runner, or the schema semantics. This is the grain the v1 code is written along.

## 10. Phases & ship artifacts

| Phase | Contents | Gated on |
|---|---|---|
| **A — Scaffold** (start now) | Migration (§3) · `_shared/` modules · 4 Telnyx handler shells (capture-first, fixtures, soft-verify) · send router + `sendViaTelnyx` + 3 caller updates · admin provider select + Telnyx card · admin.health indicators · skills batch (§8) | Nothing — fixture/stub mode |
| **B — SMS validation (stub)** | Fixture-driven tests of inbound/status parsing + Ed25519 verify · flip a TEST client to `provider='telnyx'` under SMS_MODE=stub → full drip regression green (events/messages written, zero network) · validation SQL checklist. ⟦AUDIT riders⟧ PLUS: (a) **byte-match proof** — fixture → expected-writes tables derived from the frozen functions' SOURCE + the real captured events (`voice_inbound_debug`/`voice_inbound_branch`, SMS flow evidence), asserted against `_shared`'s writes (a live diff against the frozen fns isn't runnable without side effects — this is the executable equivalent); (b) ~~**reactivation stub regression** — prove the send-router change leaves the pool path byte-identical: `reactivation/runner.server.ts` needs ZERO edits, `provider` defaults preserve pool numbers + master auth exactly as today~~ **[OBSOLETE 2026-07-21 — the pool + `reactivation/runner.server.ts` were REMOVED; reactivation now runs through the normal runner from `clients.telnyx_number`, so there is no separate pool path to regress]**; (c) **provider-agnostic opt-out assertion** — STOP via the TextGrid inbound path suppresses a Telnyx-flagged contact's sends (same `contacts.opted_out_at` flag); (d) terminal-wins status-ordering fixtures (Gap 3). | Phase A |
| **C — Voice (stub/fixtures)** | TeXML handlers complete vs documented shapes · miss-rule fixture matrix (no-answer / busy / voicemail-AMD / answered) ⟦AUDIT Gap 2⟧ **+ the conflict case: answered + AMD-says-machine** (must resolve per D7 precedence: machine fires missed even on `completed` — a rare AMD false-positive texting someone the owner just spoke with is a KNOWN, tested behavior, not a surprise) **+ AMD=human + DialCallStatus=no-answer** (human overrides: no missed fire) | Phase A |
| **D — Onboarding wiring** | `provider` in onboarding create (default textgrid) · runbook copy in admin card | Phase A |
| **E — Day-0 live validation** | The handoff §8 protocol verbatim: L2 verify → Managed-Accounts enablement → pull Ed25519 key → secrets → submit Pierce brand+campaign (starts the only real clock) → test number → capture-only clone → **listen test (go/no-go: ringback audible?)** → SMS canaries + STOP (exactly one confirmation) → reconcile every parser against captures → live missed-call tests (incl. voicemail/AMD) → flip pilot client | **Telnyx account unblock** (support ticket pending) |

**Ship mechanics per phase:** I author the exact code → shipped as Lovable prompts carrying verbatim file contents (proven pipeline; Lovable auto-commits to GitHub so the repo mirrors every step) → I verify server-side after each publish (SQL/curl, as always). Skills/docs I edit directly in `lovable-web-design` (my repo). See J1 if you prefer I push code to GitHub directly instead.

## 11. Operator (you) task list — start in parallel today
1. **Chase the Telnyx signup unblock ticket** — it's the critical path; code isn't.
2. The moment the account opens: **L2 verification** → request **Managed Accounts enablement** → create the master **API key** → copy the **Ed25519 public key** (portal → Keys & Credentials).
3. Add secrets in Lovable Cloud: `TELNYX_MASTER_API_KEY`, `TELNYX_PUBLIC_KEY` (plain names, non-VITE — same as RESEND/VAPID pattern).
4. **Submit the pilot brand + campaign immediately** (3–7 day clock) — reuse the a2p pack verbatim.
5. Pick the **pilot client** (recommend the existing test client used for canaries — x3 — since its automations/data are already instrumented).
6. Budget note: number ~$1/mo, brand/campaign TCR fees (~$4–15/mo class), campaign vet possibly expedited.
7. ⟦AUDIT Gap 4⟧ When Telnyx enables Managed Accounts, **get in writing what verification each Managed Account needs for number ordering** (restrictions apply per account by verification status — each client MA may need its own verification before it can buy a number). That per-client friction number shapes the Phase-2 automation design.

## 12. Risks & mitigations
- **TeXML webhook signing unknown (Q1)** → voice handlers soft-verify (log-only) until Day-0 capture; never hard-401 on an assumption (the SMS-saga lesson, institutionalized).
- **Campaign approval is the schedule** — everything else is fixture-buildable now; don't let code sequencing delay the TCR submission.
- **Managed Accounts enablement lag** → designed fallback: run pilot under the manager account (MA fields null, master key) — zero code difference.
- **Telnyx content filtering vs the discount/review templates (Q9)** → observe on canary sends of the REAL templates before flipping a paying client.
- **Divergence during the dual window (if J2 = my recommendation)** → rule written into both provider skills: behavior changes land in `_shared` + consciously mirrored or explicitly skipped in the frozen TextGrid fns.
- **Two signature schemes coexisting** → they never meet (separate functions, separate headers); capture events prove which fired.

## 13. Open questions (answered by capture at Day-0, never assumed)
Q1 TeXML signing scheme **⟦AUDIT Gap 5b⟧ incl. the `telnyx-timestamp` UNIT (seconds vs ms) so the replay-window math is verified against reality** · Q2 TeXML param casing/`+` (normalize regardless) · Q3 Dial-action + AMD payload field names · Q4 AMD attribute spellings on `<Dial>` · Q5 TeXML apps per-MA vs shared · Q6 MA keys against TeXML endpoints · Q7 profile auto-opt-out default · Q8 `webhook_url`+`use_profile_webhooks:false` fully overrides profile status webhooks · Q9 content-filter strictness · Q10 idempotency on `/v2/messages` · ⟦AUDIT Gap 2⟧ **Q11 is `machineDetection` on TeXML `<Dial>` non-blocking (async result to `amdStatusCallback`) or does it delay the bridge?** (if it gates the bridge → D7 decision branch) · **Q12 the AMD result value vocabulary** (human/machine/not-sure/unknown — which values trigger the miss rule).
> **⟦RESOLVED 2026-07-20 at voice Day-0⟧** Q1–Q4/Q11/Q12 answered — see `skills/telnyx-provider` §3/§5: Ed25519 (`telnyx-timestamp` in **seconds**); form-encoded Twilio-CapitalCase params, E.164 with `+`; AMD lives on the **`<Number>` noun (NOT `<Dial>`)**, is **async/non-blocking** (result to the `<Number>` `statusCallback` with `statusCallbackEvent="...amd..."`), vocabulary `AnsweredBy` = `human|machine_start|machine_end_*|fax|unknown` (any `machine*` → miss). Q5/Q6 moot (single account).

---

## JUDGMENT CALLS — need your ruling before I start coding
- **J1 — Ship mechanics:** (recommended) I author code → Lovable prompts with verbatim contents → Lovable applies/deploys/auto-commits (repo syncs itself; no push races; edge fns definitely deploy). Alternative: I push directly to GitHub `main` and Lovable syncs — riskier for edge-function deploy timing and race with Lovable auto-commits.
- **J2 — Shared-core strategy:** (recommended) `_shared/` written NEW to byte-match; TextGrid fns stay frozen; unify at cutover. Handoff alternative: extract from TextGrid fns + refactor them to import shared — DRYer, but modifies the working live SMS/voice path during the dual window.
- **J3 — Column strategy:** (recommended) parallel `telnyx_*` columns — one-field flip, both configs preserved, old number keeps receiving during migration. Handoff alternative: reuse `twilio_number`/`provider_subaccount_*`/`a2p_*` — fewer columns, but flip = overwrite (lossy, not instantly reversible, kills old-number inbound).
- **J4 — Reactivation pool:** ~~v1 stays TextGrid-only; migrate the pool at full cutover. (Alternative: build pool provider-awareness now — more surface for zero pilot value.)~~ **[SUPERSEDED 2026-07-21 — J4 is OBSOLETE: the agency number pool was REMOVED entirely; reactivation now runs on the client's OWN Telnyx number via the normal per-client runner — no pool to keep TextGrid-only or migrate.]**
- **J5 — Opt-out ownership:** confirm D10 (disable Telnyx auto-opt-out; our app stays the single source of truth).
- **J6 — Pilot client:** x3 (recommended) or a fresh dedicated test client?
