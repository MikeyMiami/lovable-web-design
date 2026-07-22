# Telnyx as a Second Provider (Dual-Provider Switch) — Project Scope

> ⚠️ SUPERSEDED (2026-07-20) — the current authority is `skills/telnyx-provider` (SINGLE Telnyx account, no Managed Accounts; the as-built column is `clients.provider`; AMD lives on the TeXML `<Number>` noun). Retained as historical record.

**Written 2026-07-15.** Scopes adding **Telnyx** SMS + voice *alongside* the existing **TextGrid** integration, switchable per-client, with **zero removal** of TextGrid. Grounded in a full map of the `cloud-spark-setup` codebase's provider surface + Telnyx's documented capabilities.

---

## Verdict

**Feasible, well-bounded, and strategically right.** Two reasons:

1. **Telnyx solves the actual problem by default.** The entire "no caller-side ringback" saga is a TextGrid defect. Telnyx's carrier network **replies with SIP `183 Session Progress` + early media carrying a US ringback tone to the caller, and passes through the called party's real ringback when it arrives** ([Telnyx SIP settings](https://support.telnyx.com/en/articles/4404448-sip-connection-inbound-outbound-settings)), and TeXML `<Dial>` generates `180 Ringing` for local ringback. That's exactly the behavior TextGrid refuses to do. On Telnyx there is nothing to fix — ringback works out of the box.
2. **The provider-specific surface is small and already isolated.** ~90% of the system (enrollment, sequencing, throttle, send-window, daily caps, events, contacts, templates, tracked links, notifications, opt-out) is **provider-agnostic** and needs no change. Only a handful of seams are provider-specific.

You can also **self-serve the entire thing** — Telnyx has full public docs and APIs, so you build and test without waiting on anyone.

---

## The provider-specific surface (everything that must be abstracted)

| Seam | TextGrid today | Telnyx |
|---|---|---|
| **Outbound send** | `src/lib/sms/send.server.ts` → `POST {base}/Accounts/{sid}/Messages.json`, form-encoded `To/From/Body/StatusCallback`, auth `Bearer base64("SID:AuthToken")`, Twilio JSON response (`sid`/`status`) | `POST https://api.telnyx.com/v2/messages`, **JSON** body (`from`/`to`/`text`/`messaging_profile_id`), auth `Bearer <API_KEY>`, JSON response (`data.id`/`data.to[].status`) |
| **Config** | `src/lib/config.server.ts` → `getTextGridConfig` (`SMS_MODE`, `TEXTGRID_BASE_URL`, master SID + token) | `TELNYX_API_KEY`, `TELNYX_PUBLIC_KEY`, `TELNYX_MESSAGING_PROFILE_ID` (no "account SID / subaccount" concept) |
| **Signature verify** | HMAC-SHA1 over `(url + rawBody)`, header `x-textgrid-signature`, per-client shared secret `clients.provider_webhook_secret` — 1 shared util + inlined 4× in edge fns | **Ed25519 public-key** signature over `({timestamp}\|{rawBody})`, headers `telnyx-signature-ed25519` + `telnyx-timestamp`, one **account-level public key** ([docs](https://developers.telnyx.com/docs/messaging/messages/receiving-webhooks)) — *completely different algorithm; the single biggest abstraction point* |
| **Inbound/status webhook parse** | form-encoded Twilio params (`MessageSid`, `MessageStatus`, `CallSid`, `DialCallStatus`) via `URLSearchParams` | **JSON** `data.event_type` + `data.payload.*` |
| **Voice response** | TwiML (`<Response><Dial>…`) | **TeXML** (near-identical XML — low-friction) or JSON Call Control |
| **Number / A2P provisioning** | 100% manual (console + typed into admin.settings.tsx) | Full APIs: number order, messaging profile, 10DLC brand/campaign, webhook config — **automatable** |

**Provider-agnostic (untouched):** the cron runner's enrollment/sequencing/throttle/caps/idempotency, `reactivation/runner`, template resolution + merge + tracked links, `messages/insert.server.ts`, events, notifications, STOP/opt-out, missed-call enroll+throttle, tenant resolution, cron trigger routes.

---

## The switch mechanism (how "flip a switch" works)

**Add `clients.messaging_provider text not null default 'textgrid'`** (`'textgrid' | 'telnyx'`). Every provider seam dispatches on this column:

> ⚠️ **As-built (2026-07-20):** the column shipped as **`clients.provider`** (this doc's `messaging_provider` is wrong); the Telnyx messaging profile is a **per-client `clients.telnyx_messaging_profile_id` column — NOT a global `TELNYX_MESSAGING_PROFILE_ID` secret** (single account, one account-wide `TELNYX_API_KEY`). See `skills/telnyx-provider`.
- Existing clients stay `'textgrid'` → **completely unaffected**.
- Migrate **one client at a time** by flipping their value to `'telnyx'` — you can pilot Telnyx on a single test client while everyone else stays on TextGrid. This is the safest possible rollout.
- (Optionally also a global `MESSAGING_PROVIDER` env as a master default for new clients.)

This composes with the existing `SMS_MODE` (stub|live) switch — orthogonal axes.

**Reused provider-neutral columns (no migration churn):**
- `clients.twilio_number` — just holds a Telnyx E.164 number for Telnyx clients (the name is cosmetic; it's the routing key everywhere).
- `messages.twilio_sid` — holds any provider's message ID (Telnyx `data.id` lands here; dedup indexes still work).
- `clients.provider_subaccount_sid` / `provider_subaccount_auth_token` — **repurposed for Telnyx** as `messaging_profile_id` / (unused; API key is global), or left null.
- `clients.provider_webhook_secret` — for Telnyx, signature is verified against the **global** `TELNYX_PUBLIC_KEY`, so this per-client secret is unused for Telnyx clients.
- `a2p_brand_id` / `a2p_campaign_id` / `a2p_status` — hold Telnyx's brand/campaign IDs (currently display-only; no send-gating reads them).

---

## Prerequisite decision: which webhook surface is canonical

The codebase currently has the SMS/voice webhooks in **TWO parallel copies**: the **Supabase Edge Functions** (`supabase/functions/sms-inbound|sms-status|voice-inbound|voice-status`) and **app routes** (`src/routes/api/public/*`). The **edge functions are the LIVE/canonical ones** (they're what the TextGrid number's webhooks are actually wired to — `/functions/v1/…`); the app-route copies are **legacy/superseded**. 

**⇒ Build Telnyx into the edge functions only; treat the app-route duplicates as dead (delete or ignore).** Adding Telnyx to both would double the work for no benefit. Consolidating first (or at least confirming the edge fns are the only wired surface) is a cheap prerequisite.

---

## Phased build plan

**Phase 0 — Seam + config (small).** Add `clients.messaging_provider` column + admin toggle; add `TELNYX_API_KEY` / `TELNYX_PUBLIC_KEY` / `TELNYX_MESSAGING_PROFILE_ID` secrets; introduce a `MessagingProvider` dispatch (`send`, `verifySignature`, `parseInbound`, `parseStatus`, `renderVoiceForward`) selected by the column. Rename `getTextGridConfig`→`getMessagingConfig` etc. (cosmetic).

**Phase 1 — Telnyx SMS (clean, high value, low risk).** Telnyx outbound (`/v2/messages`), inbound + status edge-fn branches (JSON parse + Ed25519 verify). **Test end-to-end on ONE Telnyx-flagged client** while all TextGrid clients keep running. This is the bulk of the value and the easiest part.

**Phase 2 — Telnyx voice (the payoff).** TeXML `voice-inbound` returning `<Dial>` to the owner's cell — **ringback works by default**, so the whole TextGrid voice saga (dead air, attribute isolation, provider ticket) simply doesn't exist here. `voice-status` via Telnyx's call webhooks. Miss detection is also cleaner (Telnyx call-event webhooks give explicit `hangup`/`no-answer` semantics + `call_leg_id`).

**Phase 3 — Provisioning automation (optional; Telnyx makes it easy).** The thing that was impossible on TextGrid (manual console wiring) is API-driven on Telnyx: order number → attach to messaging profile → set webhook URL → 10DLC brand/campaign. Automate it in the onboarding number-attach step so new Telnyx clients need zero console work. (This also closes the Find-6 provisioning gap — but on the Telnyx side.)

---

## Real-world costs / risks (not code)

- **10DLC re-registration.** TextGrid brand/campaign registrations **do not transfer** to Telnyx — a Telnyx client needs its own Telnyx 10DLC brand + campaign (API-driven, but still a TCR vet: days + fees). Same reality as TextGrid's A2P, just on a better-documented rail.
- **New numbers vs porting.** Simplest cutover = **new Telnyx numbers** per migrated client (update `twilio_number`, re-place on site/GBP/cards). Keeping the existing number requires **number porting** (LOA, ~days–weeks). New-number is faster; port preserves continuity.
- **Two signature schemes coexisting.** Edge fns must branch on `messaging_provider` (or on which signature header is present) — HMAC-SHA1 for TextGrid clients, Ed25519 for Telnyx. Straightforward but must be exact (this project has been bitten by silent-401s before).
- **Cosmetic naming debt.** `twilio_number` / `twilio_sid` / `getTextGridConfig` / "Messaging (TextGrid)" UI labels stay Twilio/TextGrid-flavored unless renamed; functionally harmless.

---

## Recommendation

**Do it — phased, Telnyx-first for new work, TextGrid as the untouched default.** Concretely:
1. **Phase 0 + Phase 1 (Telnyx SMS) on one pilot client first.** Clean, self-serve, low-risk, proves the seam.
2. **Phase 2 (Telnyx voice) next** — this is where you win; ringback is free, and it ends the TextGrid voice dependency you're currently blocked on.
3. Keep flipping clients to Telnyx one at a time as their 10DLC + number are ready. TextGrid clients keep running until you choose to migrate them.
4. Phase 3 provisioning automation whenever you want to scale onboarding.

The only hard costs are the ones inherent to *any* new carrier (10DLC registration + numbers) — the code surface is small and already isolated, and you stop waiting on TextGrid's support entirely.

---

*Source: full provider-touchpoint map of `cloud-spark-setup` (see the touchpoint table in the build notes), `src/lib/config.server.ts`, `src/lib/sms/send.server.ts`, the 8 webhook files, `admin.settings.tsx`, and Telnyx docs (messaging webhooks / SIP early-media / 10DLC APIs). Companion: `VOICE-NO-RING-HANDOFF.md`, `VOICE-RINGBACK-TEST-RESULTS.md`.*
