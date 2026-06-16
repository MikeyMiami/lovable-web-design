# 1f-Prep Review — TextGrid provider swap + Reactivation number pool

> Claude Code review of the 3 draft outputs (textgrid-provider SKILL, textgrid-swap impact map, reactivation-number-pool spec) against the real frozen `cloud-spark-setup` repo (cloned, golden-master-v1 @ 1266804) + the planning repo. 2026-06-16. Drafts NOT yet committed as specs — these are the flags to fold in first.

## A. TextGrid swap — 3 isolation points VERIFIED in the real code
1. **Single send primitive ✓** — `src/lib/sms/send.server.ts` is SEND-ONLY (no supabase/db imports — whole file is the stub + 2× retry). `sendStubSmsWithRetry` has exactly 2 callers: `runner.server.ts:490` + `reply.functions.ts:41`. No other outbound path exists (no `api.twilio.com`/`Messages.json` anywhere — all "twilio" hits are comments/labels).
2. **`twilio_number` single-source ✓** — written once (`admin.settings.tsx`), read via that single field; no hardcoding.
3. **Webhooks under `/api/public/*` ✓** — all public routes are there (chat, cron, discount, intake, r/*). **BUT see Correction 1.**

## B. Code touch-points — confirmed
- **Send primitive SEND-ONLY ✓** (3a guard intact).
- **Status-swap point ✓** — code: `runner.server.ts:~532` ("status='stub' → real Twilio delivery status; no new logic") + `reply.functions.ts:~55`; doc: spec line 738. Matches the impact map.
- **A2P columns purely additive ✓** — the runner reads only `twilio_number` for `from`; the proposed `provider_*`/`a2p_*` columns don't exist yet, nullable+additive, runner ignores them. Clean.

## C. 🔴 Correction 1 — inbound webhooks + signature are NET-NEW, not a "swap"
The skill (§0/§3) + impact map (B.2) say "swap `X-Twilio-Signature` → `X-TextGrid-Signature`" and "verify where the current Twilio-signature check lives." **There is NO current signature check and NO inbound/voice/webhook route in the repo** — `/api/public/*` has no inbound-SMS or voice route, and `grep` finds zero signature-verification code. So §3 (inbound SMS reply-exits + missed-call voice + STOP-at-webhook + signature verification) is **entirely NET-NEW 1f code**, built from scratch — not a one-line swap. Reframe skill §0 ("the ONE genuine code difference") + §3 + impact-map B.2 accordingly. *(The reply-exit/missed-call business logic partly exists as the pre-step stub fallback; the webhook INGESTION layer + signature is new.)*

## D. 🔴 Correction 2 — spec §9 "Inbound SMS → CRM [built]" is INACCURATE
The frozen spec/memory says inbound SMS→CRM (conversation/message create + STOP/pass) is "[built]". The repo has no inbound route — it was never built; it's 1f. Correct spec §9 (and any echo) to "1f — net-new inbound webhook," consistent with the deferred-1f list.

## E. 🟡 from-resolution — make explicit (a shared seam)
The send primitive takes `{clientId, contactId, body}` — **no `from`**. At 1f the real send needs `from` (= `clients.twilio_number`) + per-client auth (subaccount). To keep the primitive SEND-ONLY (no DB reads inside it), the **CALLER must resolve + pass `from` + auth** (the runner already loads the client; the reply path too). Skill §2 shows `from` in the payload but should state explicitly: *caller-passed, primitive stays SEND-ONLY.* **This same seam is what the reactivation pool reuses** (it passes a pool number as `from`). Minor: `admin.settings.tsx` UI labels "Messaging (Twilio)" / "Twilio number (E.164)" → provider-neutral (1f admin-surface nicety).

**Sign-off: the TextGrid swap is genuinely isolated (the 3 points hold) — APPROVED as a 1f spec AFTER folding Corrections 1+2 + the from-resolution note.** The swap touches only: send-primitive internals, the (net-new) inbound webhook layer, the status-swap, and additive A2P columns — nothing else in the frozen master.

## F. Reactivation number pool — PLACEMENT + RLS + runner DECISION
**Decision: (a) separate agency-ops layer.** Grounded in the real code:
- `claim_due_enrollments` (frozen) claims **all** active enrollments for active clients with **NO sequence/campaign filter**. So if pool enrollments lived in the frozen `enrollments` table, the **per-client runner would claim them and send from `clients.twilio_number`** — wrong number + entanglement. ✗
- The frozen master ALSO already has a **per-client reactivation drip** (`enroll.server.ts` `enrollReactivation`, `sequence_key='reactivation'`, caps 50/day + 2/20min, dedup) that sends from the client's own number. The pool feature is a DIFFERENT model (agency numbers). See the flag below.

**So:**
- **Tables (net-new, agency-scoped):** `reactivation_numbers`, `reactivation_campaigns`, **+ a separate `reactivation_campaign_enrollments` queue** — do NOT reuse the frozen `enrollments` table. All **platform-scoped (RLS read = `is_admin()`, like `audit_log`/export-client), NOT tenant-RLS'd.**
- **RLS coexistence answer:** these are **agency** rows, not tenant rows — they never traverse the per-client tenant-RLS path. The `client_id` on a campaign is a **label** ("for whom"), gated by `is_admin`, not a tenant boundary. So there's no tenant-RLS conflict *because the pool data isn't tenant data* — it's agency-owned campaign infrastructure on agency-owned numbers.
- **Runner: SEPARATE finite-campaign runner** over `reactivation_campaign_enrollments`. It **reuses the send primitive** (calls it with `from` = the campaign's pool number + the agency PierceWorks subaccount auth — the §E seam), but the **frozen per-client runner + `claim_due_enrollments` stay untouched.** Reusing the per-client runner would force a campaign-exclusion filter in the frozen claim fn + from-branching in the frozen runner = modifying frozen code. Don't.
- **Release-condition logic — fits.** "All 3 true" reduces to **"zero enrollments for this campaign with a future `next_run_at`"** — sound: click-exited enrollments are `status≠active` (no next_run_at), completed ones have none, mid-drip ones hold a future next_run_at (number stays `in_use` until the LAST follow-up). Applied to the SEPARATE campaign queue, checked after each finite-campaign tick. ✓

## G. 🔴 Frozen-master risk flags (reactivation)
1. **Do NOT put pool enrollments in the frozen `enrollments` table** (the frozen claim fn would grab them + send from the wrong number). Separate queue table.
2. **Do NOT add from-branching/campaign-exclusion to the frozen runner or `claim_due_enrollments`.** Separate finite-campaign runner instead.
3. **Shared dependency:** the pool feature needs the 1f send-primitive arg-shape (`from`+auth caller-passed). That's a 1f primitive change (re-validated) anyway — design it once so both the per-client runner and the pool runner pass `from`. The pool feature adds NO further frozen change beyond consuming that primitive.
4. **Duplication flag (product decision):** the frozen master already has a **per-client reactivation drip from `clients.twilio_number`**; the locked decision moves reactivation to **agency pool numbers**. So the frozen per-client reactivation path is **superseded** for real reactivation traffic. Decide: retire/deprecate the per-client reactivation (admin "Upload Customers" → client-number drip) in favor of the pool model, or keep both. The new feature does NOT need to modify the frozen one — but the duplication should be a conscious call, not an accident.

**Net:** the reactivation pool is **fully buildable as net-new agency infrastructure with ZERO modification to the frozen master** — its only frozen-master dependency is *calling* the 1f send primitive (which gains `from`+auth args as a shared 1f change). Placement (a) + separate runner + agency-scoped tables keeps tenant isolation pristine.

## H. Doc reconciles (provider-neutral wording) — proposed, see turn response for verbatim
spec §12 (1f bullets + line 738 + line 604 + line 71), LAUNCH.md freeze deferred-1f list, launch-check §B/§D, onboard-from-form (A2P Brand fields), new-client-site (add A2P registration step). Reword "Twilio"/"real-Twilio" → "messaging provider (TextGrid)"; fold Corrections 1+2 (inbound = net-new). Applied on confirmation.
