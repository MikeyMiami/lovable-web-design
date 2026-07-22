// Bot-shield live verification battery — app.pierceworks.co, slug x3-landscaping.
// Creates AT MOST 2 labeled test contacts (valid-submit + possibly legacy-turnstile).
import { createHash } from "node:crypto";

const BASE = "https://app.pierceworks.co";
const SLUG = "x3-landscaping";
const results = [];
function report(name, pass, detail) {
  results.push({ name, pass, detail });
  console.log(`${pass ? "PASS" : "FAIL"}  ${name}  ${detail}`);
}

async function post(path, body) {
  const res = await fetch(`${BASE}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  let json = null;
  try { json = await res.json(); } catch {}
  return { status: res.status, json };
}

function leadingZeroBits(buf) {
  let n = 0;
  for (const byte of buf) {
    if (byte === 0) { n += 8; continue; }
    for (let bit = 7; bit >= 0; bit--) { if ((byte >> bit) & 1) return n; n++; }
    return n;
  }
  return n;
}

function solve(challenge, bits) {
  const t0 = Date.now();
  for (let nonce = 0; ; nonce++) {
    const h = createHash("sha256").update(`${challenge}.${nonce}`).digest();
    if (leadingZeroBits(h) >= bits) {
      return { nonce: String(nonce), ms: Date.now() - t0, hashes: nonce + 1 };
    }
  }
}

async function mint(slug = SLUG) {
  return await post("/api/public/challenge", { slug });
}

// Fresh test number per run — a repeated phone on the same client hits the
// per-client uniqueness and returns 500 insert_failed on the valid-submit test.
const TEST_PHONE = "+1500555" + String(Math.floor(1000 + Math.random() * 9000));
const lead = (extra) => ({
  slug: SLUG,
  first_name: "PoW",
  last_name: "ShieldTest",
  phone_e164: TEST_PHONE,
  notes: "AUTOMATED bot-shield verification 2026-07-22 - safe to delete",
  ...extra,
});

// ── 1. Mint shape ─────────────────────────────────────────────
const m1 = await mint();
report("1 challenge mint", m1.status === 200 && !!m1.json?.challenge && !!m1.json?.sig && m1.json?.bits === 18,
  `status=${m1.status} bits=${m1.json?.bits} sig=${(m1.json?.sig ?? "").slice(0, 8)}…`);

// ── 2. Min-age gate: solve fast, submit immediately (<3s) ─────
const s1 = solve(m1.json.challenge, m1.json.bits);
const tok1 = `${m1.json.challenge}.${m1.json.sig}.${s1.nonce}`;
const fast = await post("/api/public/intake", lead({ pow_token: tok1 }));
report("2 min-age gate (<3s submit rejected)", fast.status === 403,
  `solve=${s1.ms}ms/${s1.hashes}h status=${fast.status} ${JSON.stringify(fast.json)}`);

// ── 3. Valid submit after 3s (same token — age failure didn't consume it) ──
await new Promise((r) => setTimeout(r, 3500));
const ok = await post("/api/public/intake", lead({ pow_token: tok1 }));
report("3 valid submit (>=3s)", ok.status === 200 && ok.json?.ok === true && !!ok.json?.enrollment,
  `status=${ok.status} id=${ok.json?.id} enrollment=${JSON.stringify(ok.json?.enrollment ?? null)}`);

// ── 4. Replay: same token again ───────────────────────────────
const replay = await post("/api/public/intake", lead({ pow_token: tok1 }));
report("4 replay rejected", replay.status === 403, `status=${replay.status} ${JSON.stringify(replay.json)}`);

// ── 5. Honeypot: filled website, no token → fake success ──────
const hp = await post("/api/public/intake", lead({ website: "https://spam.example.com" }));
report("5 honeypot fake-success", hp.status === 200 && hp.json?.ok === true && !hp.json?.enrollment,
  `status=${hp.status} id=${hp.json?.id} enrollmentAbsent=${!hp.json?.enrollment}`);

// ── 6. No token at all → 400 ──────────────────────────────────
const none = await post("/api/public/intake", lead({}));
report("6 no token -> 400 bot_check_required", none.status === 400 && none.json?.error === "bot_check_required",
  `status=${none.status} ${JSON.stringify(none.json)}`);

// ── 7. Garbage token → 403 ────────────────────────────────────
const garbage = await post("/api/public/intake", lead({ pow_token: "abc.def.123" }));
report("7 garbage token rejected", garbage.status === 403, `status=${garbage.status} ${JSON.stringify(garbage.json)}`);

// ── 8. Tampered challenge (bits→1, original sig) → 403 ────────
const m2 = await mint();
const payload = JSON.parse(Buffer.from(m2.json.challenge.replace(/-/g, "+").replace(/_/g, "/"), "base64").toString());
payload.bits = 1;
const tampered = Buffer.from(JSON.stringify(payload)).toString("base64url");
const s2 = solve(tampered, 1);
const tamperRes = await post("/api/public/intake", lead({ pow_token: `${tampered}.${m2.json.sig}.${s2.nonce}` }));
report("8 tampered challenge rejected (sig)", tamperRes.status === 403, `status=${tamperRes.status}`);

// ── 9. Unknown slug → 403 unknown_tenant ──────────────────────
const unk = await post("/api/public/challenge", { slug: "definitely-not-a-client-xyz" });
report("9 unknown tenant rejected", unk.status === 403, `status=${unk.status} ${JSON.stringify(unk.json)}`);

// ── 10. Legacy turnstile path still wired (dummy token) ───────
const legacy = await post("/api/public/intake", lead({ turnstile_token: "dummy-legacy-token" }));
report("10 legacy turnstile path wired", legacy.status === 403 || legacy.status === 200,
  `status=${legacy.status} (403=real secret rejecting dummy; 200=test/absent secret fail-open${legacy.status === 200 ? " — EXTRA test contact created id=" + legacy.json?.id : ""})`);

// ── 11/12. Gate wired on discount + chat/optin (no token → 400, no data created) ──
const disc = await post("/api/public/discount", { slug: SLUG, first_name: "PoW", phone_e164: "+15005550199", consent: true });
report("11 discount route gated", disc.status === 400 && disc.json?.error === "bot_check_required",
  `status=${disc.status} ${JSON.stringify(disc.json)}`);
const chat = await post("/api/public/chat/optin", { slug: SLUG, first_name: "PoW", last_name: "ShieldTest", phone_e164: "+15005550199", your_message: "test", consent: true });
report("12 chat/optin route gated", chat.status === 400 && chat.json?.error === "bot_check_required",
  `status=${chat.status} ${JSON.stringify(chat.json)}`);

const failed = results.filter((r) => !r.pass);
console.log(`\n${results.length - failed.length}/${results.length} passed${failed.length ? " — FAILURES: " + failed.map((f) => f.name).join("; ") : " — ALL GREEN"}`);
