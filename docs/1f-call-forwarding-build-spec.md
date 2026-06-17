# 1f — Call-Forwarding — Audit + Build Spec

> Routes an inbound call to the client's real phone (`clients.call_forwarding_number`) so the owner receives calls AND the missed-call textback (built at step 2 / v1.3) has something to detect. Audited against the real frozen code @ `golden-master-v1.4` (`cloud-spark-setup@ac37b56`). Per `textgrid-provider` §5. Audit + spec only.

## Audit findings (real code @ ac37b56)

**A. `clients.call_forwarding_number` — stored-but-unused (exactly like `twilio_number` pre-step-1).** Exists on `clients` (`types.ts:50`), **editable + saved in admin** (`admin.settings.tsx:437-439` Input "Call forwarding number (rings owner's real phone)", persisted at `:426`). **Read by NOTHING in the backend** — only the type + the admin UI. So this step is what finally *wires* it. **No migration needed** (column already present).

**B. The incoming-call `voiceUrl` route is NET-NEW.** The only voice route is `voice-status.ts` (the call **status callback** → missed-call detection on `CallStatus ∈ {no-answer, busy, failed}`). There is **no `voiceUrl` (call-arrival) route, no `<Dial>`, no forward code** anywhere. These are two different webhooks: **`voiceUrl`** fires when a call ARRIVES (we respond with TwiML), **`statusCallback`** fires when a call ENDS. Step 2 built the latter; this step builds the former.

**C. The signature/resolve seam is reusable.** `voice-status.ts` already does the canonical pattern: `rawBody → parse → resolveTenantByNumber(To) → no-tenant 200 → no-secret 401 → verifyTextGridSignature → 401 → process`. The new `voiceUrl` route reuses `verifyTextGridSignature` + `resolveTenantByNumber` verbatim. `resolveTenantByNumber` currently returns `{clientId, slug, providerWebhookSecret, allowedOrigin}` — **extend it to also return `call_forwarding_number`** (one extra column in its SELECT; harmless to the other callers).

**D. 🔴 The interaction finding — forwarding CHANGES how a missed call is detected.** Step 2's `voice-status` keys on the **parent call's `CallStatus`**. But once the `voiceUrl` route answers the call to run `<Dial>` TwiML, the **parent call becomes `in-progress` → `completed`** (it was answered, to forward) — it will **NOT** report `no-answer`. The "owner didn't pick up" signal instead surfaces as the **`<Dial action>` callback's `DialCallStatus`** (`no-answer`/`busy`/`failed`). So:
  - **No-forward case** (number unset): call rings the line, never answered → the existing `CallStatus`-based path *could* fire — but if we answer to play a message it's `completed`. → handle inline (below).
  - **Forward case** (`<Dial>`): the miss is on the **dial leg** (`DialCallStatus`), not the parent. → point `<Dial action>` at `voice-status`, **extended to read `DialCallStatus ?? CallStatus`**.
  - **No double-fire:** forward-answered → parent `completed` + dial `completed` → both ignored. Forward-unanswered → dial-action `no-answer` → **one** textback (parent `completed` ignored). ✓

## Recommendation — TwiML `<Dial>` (dynamic), NOT `forward.json` (static)
| | TwiML `<Dial>` from `voiceUrl` | `POST /IncomingPhoneNumbers/{sid}/forward.json` |
|---|---|---|
| Reads `call_forwarding_number` | **per-call, dynamic** — admin edit propagates instantly | set-once at provisioning; admin edit needs a re-call |
| Missed-call detection | `<Dial action>` → `DialCallStatus` (clean) | relies on number-level status callback |
| Coupling | route exists + responds; `voiceUrl` wired at provisioning | extra provisioning API call per number |
**→ TwiML `<Dial>` wins** — `call_forwarding_number` is admin-editable over time, so the per-call dynamic read is the right fit (no re-provisioning when the owner changes their cell). Matches `textgrid-provider` §5.

## Scope
**IN:** a net-new `voiceUrl` incoming-call route (`/api/public/voice/inbound`) that signature-verifies + responds `<Dial>` to `call_forwarding_number` (or an inline-textback fallback when unset); a small extension to `voice-status` to also accept `DialCallStatus`; extend `resolveTenantByNumber` to return `call_forwarding_number`; `RUNNER_VERSION` bump. **OUT:** per-number `voiceUrl` wiring (A2P provisioning, step 5/6 — the route exists/verifies/responds; provisioning points the number at it); the frozen send primitive + steps 1–3. **No migration** (`call_forwarding_number` exists).

## Recommended decisions (flag any to change)
1. **`<Dial>` dynamic forward** (not forward.json). [D above]
2. **No `call_forwarding_number` → fallback:** the `voiceUrl` route responds `<Response><Say>Sorry we missed your call — we'll text you shortly.</Say></Response>` **AND enrolls the missed-call textback inline** (no forward target = the call is definitionally missed; the caller still gets the courtesy text). *(Alt: `<Reject/>` + no text — rejected; I prefer the courtesy text.)*
3. **`callerId` on `<Dial>` = the client's TextGrid number (`To`), NOT the caller (`From`).** Providers reject spoofing un-owned numbers; the owner sees their business line ringing, and the caller's number is carried in the missed-call notification.
4. **Always forward** when a number is set (don't business-hours-gate v1). An owner who doesn't answer after-hours → `DialCallStatus=no-answer` → textback fires naturally. *(Business-hours-gated forwarding = backlog option.)*
5. **Missed-call detection routes to the extended `voice-status`** via `<Dial action="…/voice-status">` — one place for all missed-call logic (reuses the throttle + enroll + notify).

## Change-set
**1. `resolveTenantByNumber` (`tenant-resolver.server.ts`):** add `call_forwarding_number` to the SELECT + the returned object.

**2. NET-NEW `src/routes/api/public/voice/inbound.ts`** (server-to-server, signature-gated, returns TwiML):
- `rawBody = await request.text()` → parse `CallSid, From, To, CallStatus` (form-encoded; incoming = `CallStatus=ringing, Direction=inbound`).
- `resolveTenantByNumber(To)` → unknown → `<Response><Reject/></Response>` (or empty) 200; no `provider_webhook_secret` → 401; `verifyTextGridSignature(request.url, rawBody, secret, header)` → fail 401. *(4 invariants reused.)*
- If `call_forwarding_number` set → respond:
  `<Response><Dial timeout="20" callerId="{To}" action="{ABS_URL}/api/public/voice-status" method="POST">{call_forwarding_number}</Dial></Response>`
- If NOT set → respond `<Response><Say>Sorry we missed your call — we'll text you shortly.</Say></Response>` AND `enroll({sequenceKey:"missed_call_textback"})` + the `missed_call` notification + throttle (reuse `voice-status`'s missed-call block, or factor it into a shared `fireMissedCall(clientId, fromPhone, toPhone, callSid)` helper called by both routes).
- `Content-Type: application/xml`.

**3. EXTEND `voice-status.ts`:** `const status = params.get("DialCallStatus") ?? params.get("CallStatus");` and gate `MISSED_STATUSES.has(status)`. This makes it serve BOTH the number-level status callback (no-forward) AND the `<Dial action>` callback (forward-unanswered). *(Factor the missed-call block into `fireMissedCall(...)` so `voice/inbound`'s no-forward path reuses it — DRY.)*

**4. `RUNNER_VERSION`** bump (→ `v20260617-4`) — route bundle changes.

## Validation walk
**STUB-validatable (synthetic signed payloads; no real call):**
1. Deploy → `?ping=1` echoes `v20260617-4`.
2. **Forward TwiML:** signed `voiceUrl` POST (`CallStatus=ringing`) for a test client WITH `call_forwarding_number` set → 200, body is `<Response><Dial … callerId="<clientNum>" action="…/voice-status">+1…</Dial></Response>` (contains the forward number).
3. **No-forward fallback:** same with `call_forwarding_number` NULL → `<Say>` response AND a `missed_call_textback` enrollment + `missed_call` event.
4. **Dial-action missed:** signed POST to `voice-status` with `DialCallStatus=no-answer` → textback enrolled (throttle respected on a 2nd within-window).
5. **No double-fire:** `DialCallStatus=completed` (answered) → no textback.
6. **Signature:** bad/missing sig → 401; no secret → 401; unknown `To` → reject/200.
7. `audit_tenant_rls()=0` (no schema change, but confirm).
**LIVE-gated:** a real forwarded call (real phone rings), real `DialCallStatus` from the provider, the `callerId` display, two-leg billing, and **the `<Dial action>` callback's exact `From`/`To`/`DialCallStatus` field names + which field identifies the client** (confirm against Breeze Voice doc — see blockers).

## Blockers / edge cases (tagged)
- **🟠 [DECISION] No `call_forwarding_number` fallback** — decision 2 (`<Say>` + inline textback). Don't `<Dial>` to null (TextGrid would error / dead-air).
- **[FIX] `callerId` = client number (`To`), not caller (`From`)** — decision 3 (spoofing un-owned numbers is rejected).
- **🔵 [LIVE-confirm] `<Dial action>` callback fields.** Confirm against the Breeze Voice doc: the dial-action callback's `To`/`From` (the original called number vs the dialed forward number) and that `DialCallStatus` is the field name — so `resolveTenantByNumber(To)` resolves the *client*, not the forward number. STUB controls the payload; verify at LIVE. (If the dial-action `To` is the forward number, resolve by `From`-of-original or pass the client number through the `action` URL as a query param.)
- **🟠 [DECISION/BACKLOG] Business-hours gating of forwarding** — decision 4 (always-forward v1; BH-gated = backlog).
- **[FIX] Signature on the new route** — reuse `verifyTextGridSignature` + `resolveTenantByNumber` + the 4 invariants. Idempotency: voice has `CallSid` (no `MessageSid`); a duplicate `<Dial action>` is bounded by the enroll re-enrollment guard + the `last_missed_call_textback_at` throttle (no unique-index dedupe needed).
- **[BACKLOG] Two-leg billing** — forwarding bills inbound + outbound legs (`textgrid-provider` §5); cost note, not code.
- **[BACKLOG] `<Dial>` timeout** — `timeout="20"` (rings owner ~20s before falling to no-answer→textback); tunable.

## Open / confirm items
- The `voiceUrl` (and `<Dial action>`) URLs must be the canonical absolute prod URL (same URL-exactness HMAC concern as the other webhooks — carried LIVE gate).
- Provisioning (step 5/6) wires the number's `voiceUrl` → `/api/public/voice/inbound`.
