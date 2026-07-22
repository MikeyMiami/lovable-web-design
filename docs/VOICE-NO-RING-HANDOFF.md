# Voice "No-Ring" Issue — Third-Party Diagnostic Handoff

**Prepared 2026-07-14.** Self-contained package for an external AI/engineer to diagnose the inbound-call "no ring / dead air" problem. All code below is the ACTUAL deployed source (Supabase repo `cloud-spark-setup` @ commit `c551a56`, 2026-07-13 "Simplified TwiML in voice-inbound"). No file access needed — everything is inline.

---

## ROLE & ASK (read this first)

You are a senior VoIP / telephony engineer with deep **Twilio TwiML**, **SIP** (RFC 3960 early media; `180 Ringing` vs `183 Session Progress`), and **FreeSWITCH** expertise. Below is a real, reproduced production problem with the exact deployed code, the confirmed symptom, and everything we've already tried. Diagnose it and give concrete, actionable answers to:

1. **Root cause:** Given the exact code in §5, do you agree the provider (TextGrid) is **early-answering the caller's inbound leg and injecting no ringback** — or is there another explanation?
2. **Is there ANY fix on OUR side?** A TwiML verb/attribute/ordering change, a `<Play>` ringback-loop strategy, a whisper/`<Number url>` screen, a different `<Dial>` option — anything that restores **caller-side ringback** on a Twilio-compatible provider running **FreeSWITCH** that (in our tests) **ignores `answerOnBridge` and `ringTone`**? Or is this **definitively provider-side only**?
3. **If provider-side:** name the exact **FreeSWITCH/SIP setting or behavior** we should demand from TextGrid support (channel var, early-media policy, etc.).

Assume we can freely edit + redeploy the TwiML / Supabase edge functions, but we **cannot** change TextGrid's switch config ourselves. Be specific and cite the mechanism, not just "contact support."

---

## ⚠️ CORRECTED LEAD DIAGNOSIS (2026-07-14, after an external review pass — READ BEFORE §7's history)

An independent review found a flaw in the original "provider-side ringback defect on the app-`<Dial>` path" conclusion: **the app-`<Dial>` has almost certainly never executed.** In `voice-inbound` (§5.1) the client lookup `.eq("twilio_number", to)` runs on the RAW `To` **before** the signature check and **before** the `<Dial>` branch, and returns `<Response></Response>` (empty = hang up) on a miss. TextGrid sends `To` **without** the leading `+` (and in `x-www-form-urlencoded` a literal `+` decodes to a space), so the lookup fails on every call → the `<Dial>` is never served. Since the owner's phone still rings, **the active forward is TextGrid's native number-level forward** (the "sticky greyed number" is a real provisioned forward, not UI residue; the unchecked checkbox is the display bug). Therefore the "`answerOnBridge`/`ringTone` are ignored" rule-out below is **invalid** — those attributes lived in TwiML that never ran. **Only the *native*-forward path has actually been tested for ringback.** Fix = normalize `To`+`From` to E.164 before any DB use in both functions, add branch-level instrumentation, have TextGrid remove the native forward, then confirm the `<Dial>` branch fires on a real call before drawing any ringback conclusion. Everything in §7/§8 below is preserved for history but should be read through this correction.

## 0. TL;DR for the vetter

We route an inbound phone call to a small-business owner's real cell phone through a **TextGrid** number (a Twilio-API-compatible SMS/voice provider that runs on FreeSWITCH). **Problem: the CALLER hears silence / dead air instead of a ringback ("ring… ring…") tone while waiting for the owner to pick up.** It reproduces on BOTH implementations we've tried (app-generated `<Dial>` TwiML forwarding AND TextGrid's native dashboard call-forwarding). Our current leading theory (~90% internal confidence) is a **TextGrid provider-side defect** (it answers the caller's leg early and injects no ringback, and ignores the two TwiML levers — `answerOnBridge` and `ringTone` — that would fix it). We've opened a TextGrid support ticket. **We want a fresh, independent diagnosis: is this truly unfixable on our side, or are we missing something?**

There is also **one unresolved ambiguity we need to confirm** (see §2) and **two separate confirmed bugs** in the missed-call detection path (see §8) that are independent of the ringback problem.

---

## 1. What we're trying to build (the goal)

A "missed-call text-back" feature for local-business clients:

1. A customer calls the client's **TextGrid business number**.
2. The call **forwards to the owner's real cell phone** (`clients.call_forwarding_number`). The owner's phone rings; they can answer normally.
3. **While the owner's phone is ringing, the CALLER should hear a normal ringback tone** (this is the broken part).
4. If the owner **doesn't answer**, we fire an automated **SMS text-back** to the caller ("Sorry I missed you…") + notify the owner in-app.

TextGrid is Twilio-API-compatible, so we respond to its `voiceUrl` webhook with **TwiML** (`<Response><Dial>…</Dial></Response>`), exactly as you would with Twilio.

---

## 2. The symptom ("no ring") — CONFIRMED (operator, 2026-07-14)

- **Voice/forwarding works 100%.** The **owner's cell phone rings normally**, the call connects, and audio is **clear both ways**. Calls are received and answerable.
- **The defect is caller-side ONLY:** from the moment the call connects, **the CALLER hears complete dead silence — no ringback "ring… ring…" tone at all** — until the owner picks up, at which point normal two-way audio begins.
- **TextGrid native dashboard forwarding is OFF** — the "Enable forwarding" checkbox is **UNCHECKED**, so the **app-generated `<Dial>` TwiML in `voice-inbound` (§5.1) is the active forwarding path.** *(Caveat: the owner's number stays auto-filled/greyed in TextGrid's native-forwarding text box and will not clear, but the checkbox is unchecked — we treat the sticky number as a TextGrid UI display residue, not an active forward. If in doubt, our `voice_inbound_debug` event row proves our function executed on the call.)*

**Conclusion:** this is unambiguously a **caller-side ringback (early-answer) defect on the app-`<Dial>` path** — not a forwarding failure, and not native-forwarding interception.

---

## 3. Environment / stack

- **Provider:** TextGrid (SMS + voice). Twilio-API-compatible surface; **runs on FreeSWITCH** (confirmed same engine as Plivo). **Zero public technical docs** — everything is reverse-engineered/live-tested. Support: support@textgrid.com, (786) 522-1559.
- **Webhook host:** Supabase **Edge Functions** (Deno runtime). Base: `https://onbhnkylzadyldpziapo.supabase.co/functions/v1/`.
- **Two voice webhooks** wired on the TextGrid number:
  - `voiceUrl` → `.../voice-inbound` — fires when a call **arrives**; we answer with TwiML.
  - `statusCallback` → `.../voice-status` — fires as call state **changes/ends**; used for missed-call detection.
- **Signature:** every webhook is HMAC-**SHA1** over `(exact webhook URL string + raw request body)`, base64, compared to the `x-textgrid-signature` header, keyed by a **per-client `provider_webhook_secret`**. (This scheme is live-validated and works for inbound SMS.)
- **Numbers stored E.164** (`+1…`) in `clients.twilio_number`; forward target in `clients.call_forwarding_number`.

---

## 4. Architecture & intended call flow

```
Caller ──dials──> [TextGrid business number]
                        │  (voiceUrl webhook, signed)
                        ▼
              supabase/functions/voice-inbound   ── responds TwiML ──>  TextGrid
                        │                                                   │
        if call_forwarding_number set:                                     │ executes <Dial>
          <Response><Dial timeout="20" callerId="{ourNumber}">             │
             {owner_cell}</Dial></Response>                                ▼
                        │                                      [Owner's cell phone rings]
        else (no forward target):                              caller SHOULD hear ringback  ← BROKEN (dead air)
          <Say>Sorry we missed your call…</Say>  + fire text-back
                        
              (separately) TextGrid ── statusCallback ──> supabase/functions/voice-status
                                       (CallStatus/DialCallStatus/CallDuration) → missed-call detection
```

---

## 5. EXACT deployed code (verbatim)

### 5.1 `supabase/functions/voice-inbound/index.ts` (the call-arrival handler → returns `<Dial>` TwiML)

> Note the current `<Dial>` is **bare** — `timeout="20"` + `callerId` only. Earlier we probed extra attributes (`answerOnBridge`, `ringTone`, `dialMusic`) here; the latest commit **"Simplified TwiML in voice-inbound"** removed them. There is **no `action` attribute** on this `<Dial>` (see §8). The `voice_inbound_debug` event insert (hardcoded to a test client id) is a temporary probe to confirm the function fires.

```ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const WEBHOOK_URL = "https://onbhnkylzadyldpziapo.supabase.co/functions/v1/voice-inbound";
const VOICE_STATUS_URL = "https://onbhnkylzadyldpziapo.supabase.co/functions/v1/voice-status";
const MISSED_CALL_WINDOW_MIN = 60;

const enc = new TextEncoder();
function b64(buf: ArrayBuffer): string {
  let s = "";
  for (const byte of new Uint8Array(buf)) s += String.fromCharCode(byte);
  return btoa(s);
}
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
async function verifySignature(secret: string, header: string | null, rawBody: string): Promise<boolean> {
  if (!secret || !header) return false;
  const key = await crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-1" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(WEBHOOK_URL + rawBody));
  return timingSafeEqual(b64(sig), header);
}
function xml(body: string, status = 200): Response {
  return new Response(body, { status, headers: { "Content-Type": "application/xml; charset=utf-8" } });
}
function esc(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&apos;");
}
async function enroll(admin: any, clientId: string, contactId: string, sequenceKey: string): Promise<{ ok: boolean; reason?: string }> {
  const { data: contact } = await admin.from("contacts").select("id, opted_out_at").eq("id", contactId).eq("client_id", clientId).maybeSingle();
  if (!contact) return { ok: false, reason: "contact_not_found" };
  if (contact.opted_out_at) return { ok: false, reason: "contact_opted_out" };
  const { data: active } = await admin.from("enrollments").select("id").eq("client_id", clientId).eq("contact_id", contactId).eq("sequence_key", sequenceKey).eq("status", "active").maybeSingle();
  if (active?.id) return { ok: false, reason: "already_enrolled" };
  const { data: seqs } = await admin.from("sequences").select("steps_json, client_id, start_delay_minutes").or(`client_id.eq.${clientId},client_id.is.null`).eq("key", sequenceKey);
  if (!seqs?.length) return { ok: false, reason: "sequence_not_found" };
  const chosen = seqs.find((r: any) => r.client_id === clientId) ?? seqs[0];
  if (!((chosen.steps_json ?? []) as unknown[]).length) return { ok: false, reason: "sequence_not_found" };
  const startDelay = Number(chosen.start_delay_minutes ?? 0);
  const nextRunAt = new Date(Date.now() + startDelay * 60_000).toISOString();
  const { error } = await admin.from("enrollments").insert({ client_id: clientId, contact_id: contactId, sequence_key: sequenceKey, current_step: 0, next_run_at: nextRunAt, status: "active" }).select("id").single();
  if (error) {
    if (error.code === "23505" || /duplicate/i.test(error.message)) return { ok: false, reason: "already_enrolled" };
    return { ok: false, reason: error.message };
  }
  return { ok: true };
}
async function fireMissedCall(admin: any, clientId: string, from: string, to: string, callSid: string): Promise<void> {
  let contactId: string;
  let lastTextbackAt: string | null = null;
  const { data: existing } = await admin.from("contacts").select("id, last_missed_call_textback_at").eq("client_id", clientId).eq("phone_e164", from).is("deleted_at", null).limit(1).maybeSingle();
  if (existing?.id) {
    contactId = existing.id;
    lastTextbackAt = existing.last_missed_call_textback_at ?? null;
  } else {
    const { data: created, error } = await admin.from("contacts").insert({ client_id: clientId, phone_e164: from, source: "missed_call", status: "new" }).select("id").single();
    if (error || !created) { console.error(`[voice-inbound] contact upsert failed: ${error?.message}`); return; }
    contactId = created.id;
  }
  if (lastTextbackAt) {
    const ageMin = (Date.now() - new Date(lastTextbackAt).getTime()) / 60_000;
    if (ageMin < MISSED_CALL_WINDOW_MIN) {
      await admin.from("events").insert({ client_id: clientId, contact_id: contactId, type: "missed_call_throttled", payload: { call_sid: callSid, from, to, ageMin } });
      return;
    }
  }
  const result = await enroll(admin, clientId, contactId, "missed_call_textback");
  await admin.from("contacts").update({ last_missed_call_textback_at: new Date().toISOString() }).eq("id", contactId).eq("client_id", clientId);
  await admin.from("events").insert({ client_id: clientId, contact_id: contactId, type: "missed_call", payload: { call_sid: callSid, from, to, enroll_ok: result.ok, enroll_reason: result.reason ?? null } });
}

Deno.serve(async (req) => {
  const rawBody = await req.text();
  const params = new URLSearchParams(rawBody);

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
  await admin.from("events").insert({
    client_id: "3c987f92-5537-4c7f-8954-bacbea248578",
    type: "voice_inbound_debug",
    payload: Object.fromEntries(params.entries()),
  });

  const callSid = params.get("CallSid");
  const from = params.get("From");
  const to = params.get("To");
  if (!callSid || !from || !to) return new Response("bad request", { status: 400 });

  const { data: client } = await admin.from("clients").select("id, provider_webhook_secret, call_forwarding_number").eq("twilio_number", to).eq("status", "active").is("deleted_at", null).limit(1).maybeSingle();
  if (!client) return xml("<Response></Response>", 200);
  if (!client.provider_webhook_secret) { console.warn(`[voice-inbound] 401: no secret`); return new Response("unauthorized", { status: 401 }); }

  const sigOk = await verifySignature(client.provider_webhook_secret, req.headers.get("x-textgrid-signature"), rawBody);
  if (!sigOk) { console.warn(`[voice-inbound] 401: sig mismatch`); return new Response("unauthorized", { status: 401 }); }

  if (client.call_forwarding_number) {
    const callerId = to.replace(/^\+/, "");
    const twiml = `<Response><Dial timeout="20" callerId="${esc(callerId)}">` + esc(client.call_forwarding_number) + `</Dial></Response>`;
    return xml(twiml, 200);
  }
  await fireMissedCall(admin, client.id, from, to, callSid);
  return xml(`<Response><Say>Sorry we missed your call — we'll text you shortly.</Say></Response>`, 200);
});
```

### 5.2 `supabase/functions/voice-status/index.ts` (status callback → missed-call detection)

```ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const WEBHOOK_URL = "https://onbhnkylzadyldpziapo.supabase.co/functions/v1/voice-status";
const MISSED_CALL_WINDOW_MIN = 60;
const MISSED_STATUSES = new Set(["no-answer", "busy", "failed"]);

const enc = new TextEncoder();
function b64(buf: ArrayBuffer): string {
  let s = "";
  for (const byte of new Uint8Array(buf)) s += String.fromCharCode(byte);
  return btoa(s);
}
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
async function verifySignature(secret: string, header: string | null, rawBody: string): Promise<boolean> {
  if (!secret || !header) return false;
  const key = await crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-1" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(WEBHOOK_URL + rawBody));
  return timingSafeEqual(b64(sig), header);
}
async function enroll(admin: any, clientId: string, contactId: string, sequenceKey: string): Promise<{ ok: boolean; reason?: string }> {
  const { data: contact } = await admin.from("contacts").select("id, opted_out_at").eq("id", contactId).eq("client_id", clientId).maybeSingle();
  if (!contact) return { ok: false, reason: "contact_not_found" };
  if (contact.opted_out_at) return { ok: false, reason: "contact_opted_out" };
  const { data: active } = await admin.from("enrollments").select("id").eq("client_id", clientId).eq("contact_id", contactId).eq("sequence_key", sequenceKey).eq("status", "active").maybeSingle();
  if (active?.id) return { ok: false, reason: "already_enrolled" };
  const { data: seqs } = await admin.from("sequences").select("steps_json, client_id, start_delay_minutes").or(`client_id.eq.${clientId},client_id.is.null`).eq("key", sequenceKey);
  if (!seqs?.length) return { ok: false, reason: "sequence_not_found" };
  const chosen = seqs.find((r: any) => r.client_id === clientId) ?? seqs[0];
  if (!((chosen.steps_json ?? []) as unknown[]).length) return { ok: false, reason: "sequence_not_found" };
  const startDelay = Number(chosen.start_delay_minutes ?? 0);
  const nextRunAt = new Date(Date.now() + startDelay * 60_000).toISOString();
  const { error } = await admin.from("enrollments").insert({ client_id: clientId, contact_id: contactId, sequence_key: sequenceKey, current_step: 0, next_run_at: nextRunAt, status: "active" }).select("id").single();
  if (error) {
    if (error.code === "23505" || /duplicate/i.test(error.message)) return { ok: false, reason: "already_enrolled" };
    return { ok: false, reason: error.message };
  }
  return { ok: true };
}
async function fireMissedCall(admin: any, clientId: string, from: string, to: string, callSid: string): Promise<{ ok: boolean; reason?: string }> {
  let contactId: string;
  let lastTextbackAt: string | null = null;
  const { data: existing } = await admin.from("contacts").select("id, last_missed_call_textback_at").eq("client_id", clientId).eq("phone_e164", from).is("deleted_at", null).limit(1).maybeSingle();
  if (existing?.id) {
    contactId = existing.id;
    lastTextbackAt = existing.last_missed_call_textback_at ?? null;
  } else {
    const { data: created, error } = await admin.from("contacts").insert({ client_id: clientId, phone_e164: from, source: "missed_call", status: "new" }).select("id").single();
    if (error || !created) return { ok: false, reason: "contact_upsert_failed" };
    contactId = created.id;
  }
  if (lastTextbackAt) {
    const ageMin = (Date.now() - new Date(lastTextbackAt).getTime()) / 60_000;
    if (ageMin < MISSED_CALL_WINDOW_MIN) {
      await admin.from("events").insert({ client_id: clientId, contact_id: contactId, type: "missed_call_throttled", payload: { call_sid: callSid, from, to, ageMin } });
      return { ok: true };
    }
  }
  const result = await enroll(admin, clientId, contactId, "missed_call_textback");
  await admin.from("contacts").update({ last_missed_call_textback_at: new Date().toISOString() }).eq("id", contactId).eq("client_id", clientId);
  await admin.from("events").insert({ client_id: clientId, contact_id: contactId, type: "missed_call", payload: { call_sid: callSid, from, to, enroll_ok: result.ok, enroll_reason: result.reason ?? null } });
  return { ok: true };
}

Deno.serve(async (req) => {
  const rawBody = await req.text();
  const params = new URLSearchParams(rawBody);
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
  await admin.from("events").insert({
    client_id: "3c987f92-5537-4c7f-8954-bacbea248578",
    type: "voice_status_debug",
    payload: Object.fromEntries(params.entries()),
  });
  const callSid = params.get("CallSid");
  const from = params.get("From");
  const to = params.get("To");
  const status = params.get("DialCallStatus") ?? params.get("CallStatus");
  if (!callSid || !from || !to || !status) return new Response("bad request", { status: 400 });

  const { data: client } = await admin.from("clients").select("id, provider_webhook_secret").eq("twilio_number", to).eq("status", "active").is("deleted_at", null).limit(1).maybeSingle();
  if (!client) return new Response("ok", { status: 200 });
  if (!client.provider_webhook_secret) { console.warn(`[voice-status] 401: no secret`); return new Response("unauthorized", { status: 401 }); }

  const sigOk = await verifySignature(client.provider_webhook_secret, req.headers.get("x-textgrid-signature"), rawBody);
  if (!sigOk) { console.warn(`[voice-status] 401: sig mismatch`); return new Response("unauthorized", { status: 401 }); }

  const debugParams = Object.fromEntries(params.entries());
  await admin.from("events").insert({ client_id: client.id, type: "voice_status_debug", payload: debugParams });

  if (!MISSED_STATUSES.has(status)) return new Response("ok", { status: 200 });

  const result = await fireMissedCall(admin, client.id, from, to, callSid);
  if (!result.ok) return new Response(result.reason ?? "error", { status: 500 });
  return new Response("ok", { status: 200 });
});
```

---

## 6. Intended design (build spec) — for context

Our internal build spec (`docs/1f-call-forwarding-build-spec.md`) chose **TwiML `<Dial>` (dynamic per-call), NOT the provider's `forward.json` static forward**, so an admin edit to the owner's cell propagates instantly. Key design intents (some NOT reflected in current code — see §8):
- `<Dial callerId="{To}">` uses the **client's own TextGrid number** as caller ID (providers reject spoofing the original caller's number).
- Missed-call detection was designed to hang off the **`<Dial action>` callback's `DialCallStatus`** (the parent leg becomes `completed` once answered-to-forward, so the "owner didn't pick up" signal is on the dial leg). **The current deployed `<Dial>` has NO `action` attribute**, so this design intent is currently unwired.
- Signed webhooks must use the **canonical production URL** verbatim (HMAC signs the URL string).

---

## 7. Full issue timeline (what's been tried)

1. **Built app-`<Dial>` forwarding** per the build spec. Forwarding functionally worked (owner reachable) but **caller heard no ringback (dead air).**
2. **Operator decision (2026-07-13): switch to TextGrid NATIVE forwarding** (set the forward on the number in TextGrid's dashboard; app stops emitting `<Dial>`; `call_forwarding_number` becomes a reference field). **Still no ringback** on native forwarding either.
3. **Deep ringback root-cause analysis (3 research passes + Twilio docs/SDK source + our live call records), ~90% confidence:** TextGrid **answers the caller's inbound leg immediately** at `<Dial>` (sends SIP `200 OK` up front) instead of holding it in `180/183 Ringing` until the dialed leg connects. Once "answered," the caller's carrier stops generating ringback and TextGrid injects none → **dead air.** Call-record fingerprint = inbound leg `completed`/answered while the forward leg is still `in-progress` (early-answer signature).
   - The two Twilio levers that prevent this — **`answerOnBridge="true"`** (defer the 200, relay 180/183) and **`ringTone="us"`** (synthesize a tone) — **are BOTH ignored by TextGrid** in our tests → **no TwiML fix; provider-side defect.**
   - **Ruled out:** domain/endpoint mismatch (all URLs verified), auth handshake gating ringback (HMAC has no media role), webhook latency (fetching TwiML isn't an "answer" event). Verified `<Dial>` is the FIRST/only verb (no leading `<Say>`/`<Play>` that would force an early answer).
4. **Workaround probes (TextGrid = FreeSWITCH):** untested Dial attributes worth trying — `dialMusic="real"` (Plivo/FreeSWITCH early-media passthrough), `audioUrl` (Telnyx-style custom ringback), re-try `answerOnBridge`. Switch-level knobs only TextGrid can flip: `ignore_early_media=true`, `instant_ringback=true`, `transfer_ringback`, `generate_ringback_tone` (FreeSWITCH/SignalWire issue #2596: FS won't relay `180 Ringing` if `183 Session Progress` arrives first upstream). All named in the support ticket.
5. **Alternative research verdict:** rebuild as app-`<Dial>` + **press-to-accept "whisper" screening** (GoHighLevel "Call Connect" pattern): `<Dial><Number url="/whisper">…</Number></Dial>` where `/whisper` runs `<Gather numDigits=1>Press any key to accept</Gather><Hangup/>`. Deterministic miss detection (voicemail can't press a key). **Not implemented** — instead the TwiML was simplified back to a bare `<Dial>` (commit `c551a56`).
6. **Latest state:** bare `<Dial timeout="20" callerId="…">`; debug event inserts (`voice_inbound_debug` / `voice_status_debug`) left in to confirm the functions fire; **the definitive "does `voice-inbound` even run under native forwarding?" test is still pending** (needs someone to place a real call and read the debug rows).

---

## 8. Separate confirmed bugs in the missed-call path (independent of ringback)

These do NOT cause the no-ring symptom, but a vetter reviewing the whole feature should know:

1. **`To` is not `+`-normalized before client lookup.** TextGrid's **voice** callbacks send `To` **without** the leading `+` (e.g. `14194879124`), but `clients.twilio_number` is stored **with** `+` (`+14194879124`). Both `voice-inbound` (line: `.eq("twilio_number", to)`) and `voice-status` do an exact match on the raw `to`, so **client resolution fails → early return → no missed-call ever fires on these calls.** (Inbound SMS sends `To` *with* `+`, which is why SMS works.) **Fix:** normalize `to` to E.164 before the `.eq("twilio_number", …)` lookup. *(The `callerId` line in voice-inbound `to.replace(/^\+/, "")` is unrelated — that intentionally strips `+` for the caller-ID display.)*
2. **Status-only miss detection is inadequate.** `voice-status` only fires on `CallStatus/DialCallStatus ∈ {no-answer, busy, failed}`. But our live call records show those statuses **rarely appear** — a declined call goes to voicemail and reports `completed` (short duration), an early hang-up reports `in-progress`. So real misses are missed. Detection likely needs to be **duration-based** (short total duration ⇒ probably voicemail/no-answer), which is fuzzier. Also, under native forwarding there is **no `<Dial action>`**, so only the number-level status callback fires (parent leg = `completed`).
3. **Debug artifacts present:** both functions insert a `voice_*_debug` event **hardcoded to client id `3c987f92-…`** (a test client) on every call. Remove before production.

---

## 9. Config / values a vetter may need

- **Test client:** id `3c987f92-5537-4c7f-8954-bacbea248578` ("x3 landscaping"). Its TextGrid business number and `call_forwarding_number` (owner cell, e.g. `+14197500242`) are in the `clients` row. A test business number used in call logs: `+14194879124`.
- **Secrets (names only — values in Supabase):** `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` (function env); per-client `provider_webhook_secret` (on the `clients` row) = the HMAC-SHA1 key.
- **How to observe a call:** query the `events` table for `type in ('voice_inbound_debug','voice_status_debug','missed_call','missed_call_throttled')` filtered to the test client — the `payload` holds the verbatim webhook params (`CallStatus`, `CallDuration`, `DialCallStatus`, `SipResponseCode`, `From`, `To`, `CallSid`, etc.).
- **Provider:** TextGrid — support@textgrid.com, (786) 522-1559. No public API docs. Ticket already open requesting `answerOnBridge`/`ringTone`/early-media passthrough (and the FreeSWITCH ringback channel-vars).

---

## 10. Questions we want the vetter to answer

1. **Is the ringback truly unfixable from our side?** Do you agree TextGrid is early-answering the caller leg and injecting no ringback — or is there a TwiML/config approach (a verb order, an attribute, a `<Play>` loop strategy, an early-media trick) that works on a Twilio-compatible + FreeSWITCH stack that we haven't tried?
2. **Given TextGrid ignores `answerOnBridge` and `ringTone`,** is the **press-to-accept whisper** (`<Number url>` + `<Gather>`) pattern likely to (a) restore ringback for the caller and (b) give deterministic miss detection — or does whisper *also* force an early answer that kills ringback?
3. **Would a brief `<Play>` of a ringback audio loop before/around `<Dial>` help,** or does a leading media verb force the exact early-answer that breaks ringback (as we suspect)?
4. **Is the "native forwarding may be intercepting the call before our webhook runs" hypothesis plausible,** and what's the cleanest way to prove/disprove it without repeated live calls?
5. **Any TextGrid/FreeSWITCH-specific setting** (channel variable, number config) that forces `instant_ringback` / `ignore_early_media` from the customer side of a Twilio-compatible API?

---

*Companion internal docs (not needed to diagnose, but available): `docs/1f-call-forwarding-build-spec.md` (intended design), memory note "voice-native-forwarding" (decision history). Dead/superseded copies exist at `src/routes/api/public/voice-status.ts`, `src/routes/api/public/voice/inbound.ts`, `src/lib/voice/missed-call.server.ts` — the LIVE path is the two Supabase Edge Functions in §5.*
