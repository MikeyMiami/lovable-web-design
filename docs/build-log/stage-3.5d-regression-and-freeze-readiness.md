# Build Log — Stage 3.5 item 3 (runner regression) + Freeze-Readiness Pass

> Validation of the runner regression re-test (the last Stage-3.5 item) + an independent `/launch-check` A–D pass to assess Stage-4 freeze readiness. Source: Lovable regression report (5 proofs, live on `runner_version=v20260615-2`). 2026-06-15 (Claude Code).
> **Verdict: item 3 CLOSED — PASS → Stage 3.5 COMPLETE. Freeze: CONDITIONAL GO** — the frozen-LOGIC rows are green, but "all §A–D green except §E" is INACCURATE: the freeze carve-out is the **full 1f scope** (predominantly **all of §D**), not just the §A Turnstile row; and **2 foundation guardrail confirms (G2 fairness, G4 CORS-resolver) lack explicit evidence**. Close those + reframe the gate → GO. No secret values.

## ✅ Item 3 — runner regression (all 5, live on `v20260615-2`)
Tick: `claimed 16/17` (archived TD excluded), processed 16, sent 13, blocked 2, rescheduled 3, clients 3, failed 0.
1. **Control logic intact** — claim-lease (`FOR UPDATE SKIP LOCKED` in `claim_due_enrollments`); window-gating (TB → `blocked-window`, `current_step=0`, `next_run_at`→tomorrow's window); caps (TC → `blocked-cap`, step unchanged); **reschedule-WITHOUT-advancing** (TB/TC/TM all `current_step=0` + active, zero consumed); advance-on-success (13 advanced exactly one step; MC2+DC → completed); 2× send-retry (`SEND_MAX_ATTEMPTS=2` loop, distinct from template_missing). ✓
2. **Archived-skip** — TD (archived) due-now → never leased; `clients=3`; TD row untouched. ✓
3. **Send-primitive SEND-ONLY** — `send.server.ts` imports nothing from supabase/events/messages; no writes/logging; materialization is the separate `insertOutboundMessageAdmin` AFTER send. ✓
4. **Full drip set renders real (13 keys)** — review 1–4, one_year 1–5, missed_call 1–2, lead_form, discount: all real bodies, merge vars resolved (`{first_name}`→Alice/Olive/…, `{company_name}`→TestCo A, `{discount__on_referral}`→10%), real tracked `/api/public/r/<token>` links, ZERO `[stub]`, ZERO literal `{…}`. (3f proved 1 key; this proves all 13.) ✓
5. **`template_missing` self-heal** — forced missing template → `template_missing` event (payload `template_key`, `rv=v20260615-2`), `status=active`, `current_step=0` (not consumed), `next_run_at +15min`, zero messages, isolated, not in 2× retry. ✓

## 🔎 Independent `/launch-check` A–D pass (the real freeze question)
**Frozen-LOGIC rows = GREEN** (validated across stages): §A (RLS, no-anon-write, server-fn writes, CORS/allowlist/OPTIONS *structure*, enrollments UNIQUE, indexes, enums, net-new schema, storage buckets+policies, template_vars single-source, G1 RLS-audit=0, G3 export-client); §B (pg_cron, runner batch/claim/advance, materialization, real-body render, deploy-verification stamp, archived-skip, send-primitive regression, window/cap/pacing, enrollment caps, cron-decision logging); §C (review drip+funnel, one-year, lead-form, discount, reactivation, chat-widget — feature LOGIC).

### ⚠️ The framing correction — the carve-out is the WHOLE 1f scope, not just §E/§A-Turnstile
"All §A–D pass except the §E 1f row" is wrong. **§D (Telephony) is almost ENTIRELY 1f** — and other 1f-tagged rows live in §A/§B/§C. The accurate freeze model (per the locked freeze decision: *freeze = logic; 1f = Twilio-dependent hardening*): these are **deferred to 1f, post-freeze**, NOT green at freeze:
- §A: Turnstile/rate-limit (row 19); **parent Twilio auth token** (row 26 — real Twilio).
- §B: real-Twilio **5xx/4xx handling** (the 2× retry loop is green; the Twilio-response branch is 1f).
- §C: one-year **real-time reply-exit**, missed-call **voice-webhook trigger**, owner-**email actual send** (email layer) — the drip *logic* is green; these triggers/sends are 1f.
- §D (nearly all): real Twilio account/From/SID, **status-swap**, **render-completeness guard**, **inbound+voice webhooks** (route-by-To, X-Twilio-Signature), **real-time reply-driven exits**, per-client number/forwarding/GBP. *(The inbound-SMS→CRM + STOP/HELP/pass handler logic was built at foundation, but it's exercised by real Twilio inbound = 1f.)*
  > **[ANNOTATION 2026-06-16 — SUPERSEDED, original line left intact for history]** Two stale claims above: (1) provider is **TextGrid**, not Twilio (signature is **`X-TextGrid-Signature` HMAC-SHA1**, not `X-Twilio-Signature`); (2) the **inbound-SMS→CRM + STOP/HELP/"pass" opt-out handler was NOT built at foundation** — it is **net-new at 1f** (verified against the frozen repo: no inbound/voice route under `src/routes/api/public/`, no signature code). Superseded by the 1f-prep review **Correction 2** (`docs/build-log/1f-prep-textgrid-reactivation-review.md`) and **HANDOFF.md §2**. Authoritative docs (spec/launch-check/HANDOFF) carry the corrected model; this build-log is point-in-time history.
→ **Freeze gate should read: "the frozen-logic rows (A/B/C + non-Twilio §A) are green; the entire 1f scope (above, predominantly §D) is deferred to 1f."** Not "A–D green except one row." This corrects LAUNCH.md Stage 4 / spec §12 step 4, which both say "A–D green (except the §A Turnstile/rate-limit launch-gate row)."

### 🟥 2 genuine pre-freeze confirms (no explicit evidence on hand)
- **G4 — CORS resolver adversarial test (§A row 29):** confirm a **forged `client_id` in the request body is IGNORED** (client_id resolved server-side from Origin/Host→allowed_origins only). Built at foundation; the adversarial test isn't in my records. Run it before freeze.
- **G2 — per-client cron fairness (§B row 44):** confirm the runner **round-robins** so one large client can't starve others within a tick. The regression had 3 small clients (no starvation scenario exercised). Confirm the round-robin is implemented + tested with one big client.

### 🟡 2 doc-nits (fixed launch-check this turn)
- §A row 16 said "anon SELECT limited to `clients` public columns" — superseded by the §A **RPC-only** model (anon has NO clients SELECT; reads via `get_client_public`). Reconciled.
- §A row 23 net-new columns omitted **`clients.notification_email`** (added at 3g/F-pii). Added.

## Status
- **Item 3 CLOSED → Stage 3.5 COMPLETE** (§A security ✓, audit_log ✓, export-client ✓, regression ✓; all 4 isolation guardrails done).
- **Freeze = CONDITIONAL GO.** Before pulling the trigger: (1) run **G4** + **G2** confirms; (2) reframe the freeze gate (LAUNCH.md / spec §12 step 4) to "frozen-logic green; full 1f scope deferred" — not "except §A Turnstile". On those → GO for Stage 4 freeze.
- Freeze procedure documented in the turn response (tag + lock + post-freeze allowed-changes = 1f + bug-fixes only).
