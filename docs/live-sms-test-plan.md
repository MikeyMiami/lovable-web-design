# LIVE SMS + Drip — End-to-End Test Plan (tracked checklist)

> 2026-07-09. A2P approved + live number in hand. This is the dependency-ordered checklist to validate the entire SMS/drip surface for real. Grounded in the TextGrid docs (textgrid-provider skill, 1f-step1/2/6 specs) + verified in `cloud-spark-setup` code. **Check off each # as it passes.** Do the live-flip only after the two enablers are built + the client is wired + TextGrid webhooks are pointed.

## Two LIVE-flip risk gates (watch on the FIRST send)
- **Gate #1 — auth Option-1-vs-2:** built on Option 1 (master token authenticates the subaccount SID); docs may require Option 2 (subaccount's OWN auth token). **A LIVE `401` = this.** Fix ready: add `provider_subaccount_auth_token` + have the send use it.
- **Gate #2 — form-encoding:** we POST `application/x-www-form-urlencoded` + PascalCase; a TextGrid doc shows `application/json` + lowercase. **A `415`/`400` = this.**

## Prerequisites (in order)
- [ ] **P0** Deployment env: `TEXTGRID_MASTER_ACCOUNT_SID`, `TEXTGRID_MASTER_AUTH_TOKEN`, `TEXTGRID_BASE_URL` — keep `SMS_MODE=stub` for now.
- [ ] **P1** Wire the test client (via the new TextGrid credential UI once built): `twilio_number`, `provider_subaccount_sid`, `provider_webhook_secret`.
- [ ] **P2** On TextGrid, point the number's `smsUrl` → `/api/public/sms/inbound` and `statusCallback` → `/api/public/sms-status` (exact deployed URLs — HMAC gate #3). (+ `voiceUrl` → `/api/public/voice/inbound` for voice tests.)
- [ ] **P3** Verify config: `GET /api/public/cron/sequences?ping=1` echoes runner_version; a stub enrollment tick shows NO `send_config_missing` for the test client.
- [ ] **P4** Temp **"run drip tick now"** admin button built (pg_cron stays UNSCHEDULED until last).

## Test order (🟢 your phone · 👨‍👩‍👧 you + 5 family · ⚪ synthetic)
- [ ] **1. Flip `SMS_MODE=live` + config live** — `getTextGridConfig().mode='live'`, test client fully wired.
- [ ] **2. Single outbound (CANARY) 🟢** — reply-box or 1-step drip to your phone → you receive it; `messages.sid` real (not `STUB-`), `status=sent/queued`. *(Watch gates #1/#2.)*
- [ ] **3. Delivery status callback 🟢** — `messages.status → delivered` after the send. *(Needs P2 statusCallback.)*
- [ ] **4. Inbound reply + threading 🟢** — your reply lands in the conversation, `direction=inbound`, HMAC verified. *(Gates #3/#4.)*
- [ ] **5. Opt-out STOP / START 🟢** — `STOP` → `opted_out_at` set + enrollments exit; next tick blocks send; `START` clears. *(Needs P4 tick.)*
- [ ] **6. Drip — single step (live via runner) 🟢** — one live text via the tick, enrollment advances.
- [ ] **7. Drip — multi-step 🟢** — 2-step seq: tick sends step 0 → advances → after offset, step 1.
- [ ] **8. Window-gating ⚪ (+1 🟢 confirm)** — outside 9–7 → reschedule, no send; inside → sends.
- [ ] **9. Daily cap + slice under LIVE 👨‍👩‍👧** — cap=3, 6 enrolled → exactly 3 real texts (reserve-before-send holds live).
- [ ] **10. Concurrent multi-enrollment 👨‍👩‍👧** — all 6 in one tick → one text each, no double-send, `runner_ticks` logs.
- [ ] **11. Reply-box (manual operator reply) 🟢** — operator reply from the inbox → your phone receives.
- [ ] **12. Review-request flow 🟢** — review SMS + link → rating → high→Google / low→feedback + `one_year_followup` enroll.
- [ ] **13. Lead-form intake → drip 🟢** — form submit (Turnstile) → contact + `lead_form_*` enroll → response text. *(Needs Turnstile live.)*
- [ ] **14. Missed-call textback 🟢(call)** — call the number → auto-SMS textback (+ forward).
- [ ] **15. Call forwarding 🟢(call)** — call rings through to `call_forwarding_number`. *(Needs `voiceUrl`.)*
- [ ] **16. Customer reactivation (pool) 👨‍👩‍👧** — upload family as a reactivation campaign → pool number sends the drip. *(Needs the agency PierceWorks campaign + `reactivation_numbers` provisioned.)*
- [ ] **LAST. Schedule pg_cron** (`/cron/sequences` + `/cron/reactivation` to `* * * * *`) — only after all manual-tick tests pass. Remove the temp tick button.

## Open dependencies to confirm
1. **Reactivation pool** (#16): is the agency PierceWorks campaign + pool numbers provisioned? (build spec deferred — if not, #16 waits).
2. **Turnstile live** (#13): widget + secret on the lead forms?
3. **statusCallback + smsUrl** on the number (#3/#4): confirm settable to the deployed routes.
4. **`provider_webhook_secret`**: subaccount webhook secret in hand to store on the client?

## Enablers being built for this (2026-07-09)
- **TextGrid credential UI (PERMANENT):** `provider_subaccount_sid` + `provider_webhook_secret` (+ `a2p_*` display) inputs on the Messaging settings form; "Twilio"→"TextGrid" labels.
- **"Run drip tick now" button (TEMP):** agency-admin, calls `runDripTick()` once — removed before pg_cron goes live.
