---
name: textgrid-provider
description: Use when implementing the Stage-1f messaging-provider swap (Twilio → TextGrid) on the frozen golden master, OR when onboarding a client's per-tenant A2P 10DLC registration. Defines the TextGrid send-path swap (outbound SMS), inbound webhook config (reply-driven exits + missed-call textback), voice call-forwarding, and the per-client subaccount→Brand→Campaign→number ISV registration flow. NOT for message copy/timing (automation-config), the client marketing site's opt-in form/privacy content (a separate A2P-site-compliance concern — see §6 handoff), or admin UI (admin-view). This is a 1f IMPLEMENTATION skill: it changes the provider TARGET, not the frozen architecture.
---

# TextGrid Provider — the 1f messaging swap + per-client A2P/ISV registration

TextGrid is a deliberate Twilio API clone (base path is literally `2010-04-01` — Twilio's API version). The golden master was built provider-agnostic without naming it: a single send primitive, `twilio_number` single-sourced per client, all webhooks under `/api/public/*`. So this swap changes the provider TARGET and adds a registration flow — it is NOT a re-architecture. Everything above the send primitive (the runner, resolveTemplate, drip logic, materialization) is untouched.

**Source of truth for capability claims:** TextGrid's three API docs (10DLC, Breeze, Breeze Voice). Confirmed feature-complete against the frozen master 2026-06-16.

---

## §0 — What stays frozen / what changes in 1f / what's net-new

**STAYS FROZEN (do NOT touch):**
- The cron runner control logic (claim-lease, window-gating, caps, reschedule-without-advance, advance-on-success, 2× retry).
- `resolveTemplate` (override→global) + dripMergeVars + the tracked review_link.
- The materialization helper `insertOutboundMessage{Admin,Rls}` and the messages/conversations/events writes.
- All RLS, the §A `get_client_public` RPC, the 4 isolation guardrails, the audit_log.
- The schema, including the column NAMES `twilio_number` / `twilio_messaging_service_sid` / `call_forwarding_number` (see §5 — leave names, document meaning).

**CHANGES IN 1f (provider-target only — the OUTBOUND swap):**
- The send primitive internals (`src/lib/sms/send.server.ts` `sendStubSmsWithRetry`): stub → real TextGrid `Messages.json`. Base URL + auth header + response mapping. (Verified: the primitive is genuinely SEND-ONLY, no DB imports, exactly 2 callers — runner + reply.)
- The status-swap: stub status → real TextGrid `sid` + delivery/failure status (already spec'd at spec line 738 as the 1f swap point — for BOTH runner and reply outbound writes; no new insert logic).
- `from`-resolution at the caller (see §2): the primitive takes `{clientId, contactId, body}` with NO `from`. At 1f the CALLER resolves + passes `from` (= `clients.twilio_number`) + per-client auth, so the primitive STAYS SEND-ONLY (no DB reads inside it). This is the exact seam the reactivation pool reuses (it calls the same primitive with `from` = a pool number).

**NET-NEW (built from scratch at 1f — NOT a swap):**
- **Inbound webhooks + signature verification (§3).** VERIFIED against the repo: there is NO inbound route, NO voice route, and NO signature-verification code in the frozen master today. So inbound reply-exits, missed-call voice handling, STOP-at-webhook, AND the `X-TextGrid-Signature` (HMAC-SHA1) verification are ALL built fresh at 1f. (Earlier drafts wrongly called the signature a "swap" — corrected: it's net-new because nothing inbound exists yet.)
- The per-client A2P registration flow (§4): subaccount → Brand → Campaign → attach-number. New onboarding/admin server flow, OUTSIDE the runner — it provisions the per-client sending identity the (unchanged) runner then uses.
- Per-number webhook wiring (§2, §3) at provision time.

---

## §1 — Base config & auth (the "one line")

- **Base URL:** `https://api.textgrid.com/2010-04-01` (replaces `https://api.twilio.com/2010-04-01`).
- **Auth header:** `Authorization: Bearer <base64({AccountSid}:{AuthToken})>`. (Twilio uses HTTP Basic with the same SID:token; TextGrid wants it base64'd as a Bearer token. Trivial mapping — one helper.)
- **For per-client sends, auth with the CLIENT'S SUBACCOUNT** SID + auth_token (each subaccount has its own — see §4), OR send from the master with the client's `from` number. Default: subaccount-scoped (cleaner isolation, mirrors tenant model).
- **Billing:** master account rolls up all subaccount charges (confirmed). You pay TextGrid once, rebill clients with markup.

---

## §2 — Outbound SMS (drop-in)

**Endpoint:** `POST /Accounts/{accountSid}/Messages.json` — Twilio-identical.
```
{ "body": "<resolved+merged template>", "from": "<clients.twilio_number>", "to": "<contact phone E.164>", "statusCallback": "<.../api/public/sms-status>" }
```
**Response:** `sid`, `status` (queued/sent/failed), `error_code`, `error_message`. Map exactly as the stub did:
- `status` `queued`/`sent` + `sid` present → success → materialize with real `sid` (replaces `STUB-%`).
- `status` `failed` / `error_code` set → failure → the runner's existing 2× retry + failure-status path.
- 400 on opted-out recipient → treat as terminal non-retryable (do NOT retry; mirrors Twilio 4xx).
- 401 → auth/config error (alert, don't retry).

> **⚠️ FIRST THING TO CHECK IF LIVE SENDS 401/auth-fail (UNRESOLVED as of 2026-06-16):** the parent-on-subaccount auth model (§7 open-item) was NOT confirmed by TextGrid before build — we built for Option 1 (master AuthToken authenticates against the subaccount's AccountSid) on the Twilio-clone assumption, awaiting TextGrid support reply. If every per-client LIVE send 401s, this is the prime suspect: TextGrid likely requires Option 2 (each subaccount's OWN AuthToken). Fix = caller-side only (resolve the per-client subaccount token instead of the master token; the `auth` param is decoupled from `sendingAccountSid` precisely so this is NOT a primitive re-architecture). Do not chase other causes before confirming which auth model TextGrid requires.

**Send primitive contract (UNCHANGED — stays SEND-ONLY):** `sendStubSmsWithRetry` → `sendSmsWithRetry` stays SEND-ONLY. No DB writes / no event-logging / NO DB reads in the primitive (the 3a regression guard). Materialization stays in the callers (runner + reply path) via `insertOutboundMessage`.

**`from`-resolution [the reusable seam]:** the primitive today takes `{clientId, contactId, body}` — NO `from` argument. At 1f, change the arg-shape so the CALLER resolves and passes `from` (= `clients.twilio_number` for per-client sends) + per-client auth. This keeps the primitive SEND-ONLY (it does not read the DB to find the number). **This is the exact seam the reactivation pool reuses:** the pool's separate finite-campaign runner calls the SAME primitive but passes `from` = an agency pool number + agency subaccount auth. Design the `from`+auth arg-shape ONCE so both the per-client runner and the pool runner pass it — no further frozen change needed.

**Char limits:** single SMS up to 2048 chars (TextGrid splits/segments). Keep templates ≤160 GSM-7 to stay 1 segment (cost). Bulk endpoint (`POST /BulkMessages.json`) exists (special-permission) — NOT needed for the drip runner (per-send is fine); note for future burst use.

**Render-completeness guard (LIVE-only, in the primitive).** Before the real fetch, if the rendered body still contains a residual `{…}` token, the primitive returns `{ok:false, retryable:false, error:"unrendered_token"}` and does NOT transmit. STUB mode allows a literal `{token}` (visible diagnostic) — guard is LIVE-only. Stays SEND-ONLY (pure body-text inspection, no DB). The CALLER owns the fate: the runner treats `unrendered_token` as a SELF-HEAL — reschedule WITHOUT advancing + emit `render_incomplete`, enrollment stays active (identical to `template_missing`/`send_config_missing`), NEVER terminal-fail. A transient bad merge-var must never silently drop a customer from their drip.

---

## §3 — Inbound webhooks (reply exits + missed-call textback) — NET-NEW at 1f

**VERIFIED against the frozen repo: there is NO inbound route, NO voice route, and NO signature-verification code today.** This entire section is built from scratch at 1f (NOT a swap). New `/api/public/*` routes for inbound SMS + voice + status callbacks.

**Universal pre-send opt-out guard (caller-side, mode-AGNOSTIC).** Before any SMS send — every drip type AND the reply box — check `contacts.opted_out_at`. If set: the runner EXITS the enrollment (`exited_opted_out`; no send, no advance); the reply box blocks + throws `contact_opted_out`. NOT in the pure-transport primitive (needs a DB read + enrollment-exit fate, and must fire in STUB). Generalizes the frozen runner's one_year-only opt-out exit to ALL sequences. Compliance-critical (TCPA): once opt-out capture (net-new inbound webhook, below) is live, no drip may text an opted-out contact. Validated under SMS_MODE=stub.

Webhooks are configured PER NUMBER at provision time via `IncomingPhoneNumbers` (`smsUrl`, `voiceUrl`, `statusCallback`, each with a method). Point them at the new `/api/public/*` routes.

**Webhook signature verification [NET-NEW — build fresh]:** every TextGrid webhook carries `X-TextGrid-Signature` = Base64(HMAC-SHA1(webhookURL + rawRequestBody, key=subaccount Webhook Secret)). The 1f inbound handlers verify THIS. Each subaccount has its own `webhook_secret` (returned on subaccount create) — store it per-client to verify that client's inbound calls. (No existing signature code to "swap" — nothing inbound exists yet.)

**3a — Inbound SMS (reply-driven exits, 1f).** `smsUrl` → POST, `application/x-www-form-urlencoded`. Params are Twilio-identical: `From`, `To`, `Body`, `MessageSid`, `SmsStatus=received`, `NumSegments`, `NumMedia` (+ `MediaUrl0..` for MMS). Maps directly to the one-year reply-exit + general inbound handling already spec'd. Respond `<Response></Response>` (empty TwiML) to ack, or `<Response><Message>…</Message></Response>` to auto-reply.

**3b — Missed-call detection (missed-call textback, 1f).** Two payloads:
- `voiceUrl` (incoming call) → POST params `CallSid`, `From`, `To`, `CallStatus=ringing`, `Direction=inbound`. Respond with TwiML (see §3c for the forward; if not forwarding, the call routing decides answer/no-answer).
- **Call Status Callback** → `CallStatus = completed/busy/no-answer/failed` + `CallDuration`. **`no-answer` (or `busy`) = the missed-call signal** → fire the textback via the runner's existing missed-call feature. This is the exact trigger the frozen master's missed-call-textback was designed for.

**3c — STOP/opt-out:** TextGrid handles STOP/QUIT/END/UNSUBSCRIBE + START/YES/UNSTOP + HELP natively (auto-replies, suppression). The app's own opt-out keyword (`pass`) + exit logic still runs via the inbound-SMS webhook. Opt-in/out can also be set via API (`/optin/...`).

---

## §4 — Per-client A2P 10DLC / ISV registration (subaccount-per-client)

**Confirmed structure (native ISV):** one **subaccount per client** → **Brand** (client's EIN) attached to that subaccount → **Campaign** under the Brand → client's **number(s)** attached. Each subaccount vets independently (per-client 2–4 day cadence — register at signing, vets during site build).

**Flow (Stage-5 onboarding, per client):**
1. **Create subaccount:** `POST /Accounts.json` `{friendlyName: "<client slug>"}` → store `sid`, `auth_token`, `webhook_secret` on the client record (new per-client provider columns — see §5).
2. **Create Brand (non-blocking):** `POST /campaigns/brand/nonblocking` with `subAccountSID = <client subaccount sid>`, `entityType: "PRIVATE_PROFIT"` (typical local business; SOLE_PROPRIETOR path needs SMS OTP — see below), client's `companyName`/`ein`/`einIssuingCountry`/address/`phone`/`email`/`website`/`vertical`/`brandRelationship`. Returns `brandId` (B-prefixed), `identityStatus: PENDING`. Callback `BRAND_IDENTITY_STATUS_UPDATE` → VERIFIED/UNVERIFIED.
   - **EIN ≥ 15 days old** (TCR rule) — gate at onboarding.
   - Sole-Prop only: trigger SMS OTP (`/brand/{brandId}/smsOtp`), verify (`PUT`), before campaign.
3. **Check use-case qualification:** `GET /campaigns/brand/{brandId}/usecase/{usecase}` → confirms MNO support, required `minMsgSamples`, opt-in/out/help requirements, embedded-link rules, T-Mobile daily cap, AT&T TPM. Use-case for your traffic ≈ `CUSTOMER_CARE` / `ACCOUNT_NOTIFICATION` / `MARKETING` (or `LOW_VOLUME` mixed). Pick per the client's actual messaging.
4. **Create Campaign:** `POST /campaigns/campaign` with `brandId`, `usecase`, `description` (must include "message frequency may vary"), `subscriberOptin/Optout/Help: true`, `sample1..5` (real sample drip messages), `messageFlow` (the opt-in flow text), `helpKeywords/helpMessage`, `optinKeywords/optinMessage`, `optoutKeywords/optoutMessage`, `termsAndConditionsLink`, `privacyPolicyLink`, `embeddedLink: true` (your review links). Returns `campaignId` (C-prefixed). Optional `expediteCampaign: true` (+$27). Note the DCA2 $15 manual-vet per submission.
   - **TCR Nov-2024 content rules (campaign WILL be rejected without these):** privacy policy must state mobile opt-in is NOT shared with third parties for marketing; ToS must carry the SMS disclosure (message types, cadence, msg&data-rates, privacy link, opt-out); opt-in CTA must show brand + msg-frequency + fees + HELP/STOP; the phone field on the opt-in site must be OPTIONAL (a required phone = "forced opt-in" = rejection). **These are satisfied by the client's marketing site — see §6 handoff to the A2P-site-compliance skill.**
5. **Attach number to campaign:** `POST /campaigns/number/{campaignId}` `{phoneNumberSids: ["<sid>"]}`. (Number must belong to your account; if shared via TCR, `Import Campaign` first.)
6. **Provision number webhooks** (§3): set `smsUrl`/`voiceUrl`/`statusCallback` on the number → `/api/public/*`.
7. **Write `clients.twilio_number`** = the provisioned number → the (unchanged) runner picks it up automatically (single-source rule). Optionally set call-forwarding (§5/§3c).

**Buying numbers:** `GET /AvailablePhoneNumbers/{US|CA}/Local.json?areaCode=` → `POST /IncomingPhoneNumbers.json` (can set webhooks at purchase). Local area-code match to client market.

**Status tracking:** `GET /campaigns/campaign/{campaignId}` exposes `SecondaryDcaSharingStatus` (PENDING/ACCEPTED/DECLINED) + `SecondaryDcaDeclineReason` — surface in admin to know when a client is live / why a campaign was rejected.

---

## §5 — Voice call-forwarding + column naming

**Call forwarding to owner's cell:** dedicated endpoint `POST /IncomingPhoneNumbers/{phoneNumberSid}/forward.json` `{forwardEnabled, forwardTo: <clients.call_forwarding_number>, forwardRecord}`. (Or TwiML `<Dial>` from the voiceUrl.) **Billed as two legs** (inbound + outbound) per the docs — matches the cost model (~$0.012/min est., ~$10/mo typical contractor). For missed-call-textback WITHOUT forwarding, the unanswered call → `no-answer` status → textback (§3b), near-zero cost.

**TwiML verbs supported:** `<Say>`, `<Dial>`, `<Gather>`, `<Play>`, `<Pause>`, `<Redirect>`. Covers missed-call + forwarding + IVR. (No `<Conference>`/`<Enqueue>` — not needed by the master.) Voices: `man`/`female`/`Polly.*`. Outbound call origination: `POST /Accounts/{sid}/Calls.json` with `url` (TwiML) + `statusCallback`; AMD available via `machineDetection`.

**Column naming [DECISION: LEAVE + DOCUMENT].** The frozen schema has `twilio_number`, `twilio_messaging_service_sid`, `call_forwarding_number`. Do NOT rename for cosmetics (a rename = post-freeze schema migration + re-tag for zero functional gain). These columns hold the PROVIDER's values regardless of name: `twilio_number` = the TextGrid From number, `twilio_messaging_service_sid` = unused/null under TextGrid (or a TextGrid messaging-service equivalent if used). **Net-new per-client provider columns to ADD** (post-freeze, re-validated migration): `provider_subaccount_sid`, `provider_subaccount_auth_token` (server-only secret store), `provider_webhook_secret`, `a2p_brand_id`, `a2p_campaign_id`, `a2p_status`. These are additive (new nullable columns) — they don't alter frozen logic; the runner ignores them, the onboarding/admin flow uses them.

---

## §6 — Handoff to A2P-site-compliance (skill #13, separate)

The Campaign creation (§4 step 4) CONSUMES the client's marketing site: `privacyPolicyLink`, `termsAndConditionsLink`, the opt-in URL/screenshot (`messageFlow`/CTA media via `/campaigns/{campaignId}/cta`), and sample messages. Those artifacts are PRODUCED by the client's marketing template (Stage-5 template-builder world), not by this provider skill. The A2P-site-compliance skill (#13) owns: the privacy-policy page (with the "mobile opt-in not shared with 3rd parties" clause), the ToS SMS disclosure, and the opt-in form (unchecked + OPTIONAL checkbox, all CTA disclosures). **This skill assumes those exist and are live at registration time; #13 guarantees they do.** Documented handoff, two skills, one approval requirement.

**Possible frozen-funnel concern to flag in review:** if the frozen funnel's opt-in (chat-widget + lead-form) does NOT already present SMS consent as unchecked + optional + fully-disclosed, that's a frozen-backend funnel adjustment (1f/bug-fix), not pure template work. Claude Code should confirm against the real funnel code.

---

## §7 — Open items to confirm with TextGrid before go-live (non-blocking)
- Exact outbound voice per-minute rate (est. ~$0.008; for the forwarding cost model).
- Per-second vs per-minute voice billing (affects short missed-call rings).
- Any per-CSP cap on number of client brands registered under the master (ecosystem brand-validation limits).
- Whether `twilio_messaging_service_sid` has a TextGrid analog you want to use, or leave null.
- **[GATES LIVE — not STUB] Parent-on-subaccount auth:** confirm with TextGrid whether the parent/master AuthToken can authenticate `Messages.json` calls made against a subaccount's AccountSid (Option 1 — one master secret, no per-client token storage), OR whether each subaccount's own AuthToken is required (Option 2 — per-client encrypted token on the row). Twilio supports Option 1; TextGrid is a clone so it's likely, but the docs don't explicitly confirm it. The 1f send primitive is built for Option 1 with the `auth` param decoupled from `sendingAccountSid`, so switching to Option 2 if required is a CALLER-resolution change only (no primitive re-architecture). Verify during the STUB phase, before flipping SMS_MODE=live. (1f-step1 build spec @ 33b583b.)

---

## §8 — Implementation order (1f)
1. Add the provider config (base URL, auth helper, master creds via direct API — TextGrid is reached by direct `fetch`, NOT a Lovable connector gateway; the old Twilio-via-Lovable-gateway path does not apply).
2. Swap the send primitive internals (§2) — keep SEND-ONLY; re-run the 2e regression (the 3a guard) to prove control logic intact on a runner_version-confirmed bundle.
3. Wire inbound webhooks + `X-TextGrid-Signature` verification (§3) — reply-exits + missed-call textback.
4. Status-swap: stub status → real sid/delivery/failure for BOTH runner + reply writes (spec line 738).
5. Add the net-new per-client columns (§5) via a re-validated additive migration; re-tag.
6. Build the A2P registration flow (§4) as an onboarding/admin server flow (outside the runner).
7. Call-forwarding wiring (§5).
8. Each backend change re-validated + re-tagged per the post-freeze contract. The A2P registration flow + webhook verification are net-new (validate fresh); the send/status swap is a re-validation of existing logic against a new target.
