# Production-Readiness Audit — Full Platform (2026-07-29)

**Scope:** every live system read end-to-end at true HEAD — `cloud-spark-setup` @ `6f87c3f` (app), `professional-landscpaing-template` @ `origin/main 31232b4` (local clone was **203 commits stale**; audited via read-only worktree), `pro-style-shell` @ `e14ce22` (pulled 39 commits), `lovable-web-design` @ `56f487a` (docs/skills). Method: verify-against-reality — every claim below cites file:line. What could not be verified from the repos (live DB contents, Telnyx portal settings) is listed in the **Verification SQL appendix** with the exact query to run.

**Files read in full:** `runner.server.ts` (1,242 ln), `enroll.server.ts`, `send.server.ts`, `telnyx-send.server.ts`, `resolve.server.ts`, `missed-call.server.ts`, `business-hours.server.ts`, `cron/sequences.ts`, `intake.ts`, `chat/optin.ts`, `discount.ts` (contact path), `r/$token.ts`, `r/rate.ts`, `_shared/core.ts` (all 176 ln), `telnyx-sms-inbound/index.ts`, `pow.server.ts`, `tenant-resolver.server.ts`, `write.server.ts` (vars), `reply.functions.ts` (guards), `review.functions.ts`, `health.functions.ts`, all 5 claim/infra migrations, the foundation schema migration (constraints + indexes + RLS), `get_client_public` (newest def), both templates' `CallNowBar` / `client-data` / `bot-shield` / `site-url`.

---

## 1. Executive sign-off

| System | Verdict | Confidence | Notes |
|---|---|---|---|
| **Drip runner core** (claim → throttle → send → advance) | ✅ SOLID | **95%** | Better than its own docs: leased SKIP-LOCKED claim, reservation/refund cap math, `send_attempts` idempotency, DST-correct Intl tz math, 25s budget < 30s pg_net timeout, per-row self-heals |
| **Enrollment guards & caps** | ✅ SOLID (first-touch) / ⚠ by-design gap (repeat-touch) | **90% / 60%** | All caps enforced + evented. F-1: one-drip-per-lifetime is DB-enforced — see findings |
| **Tenant isolation** (RLS, resolver, service-role split) | ✅ SOLID | **90%** | Origin→allowlist server-side, body never trusted, RLS everywhere, infra tables deny-all. One blemish: F-4 hardcoded fallback tenant in edge fns |
| **Send transport** (dual provider) | ✅ SOLID with one hole | **85%** | F-2: 429 → permanent enrollment failure |
| **Opt-out / compliance path** | ⚠ CONDITIONAL | **70%** | Strict where it works (owner can't even reply to opted-out). F-5 duplicate-contact STOP hole + F-6 HELP unhandled; Telnyx auto-opt-out is deliberately OFF, so the app is the only enforcement |
| **Bot shield + rate limiting** | ✅ SOLID | **95%** | HMAC-signed, timing-safe, single-use both sides (client fix live on BOTH templates), DB-backed limiter, honeypot, fail-closed |
| **Review funnel + tracked links** | ✅ SOLID | **90%** | Idempotent first-click, audited, threshold flow correct. Token reuse interlocks with F-1 |
| **Templates (marketing sites)** | ✅ SOLID | **90%** | Kill-switch present, PoW single-use + pre-warm, converged pill/CTA. `phone_e164` is DERIVED from `phone_display` (docs corrected) |
| **Data hygiene at scale** | ⚠ NEEDS ATTENTION | **60%** | F-3 duplicate contacts; F-8 four unbounded tables with zero retention; F-4 pre-auth event writes |
| **Observability** | ⚠ PARTIAL | **65%** | `runner_ticks` + `failed24h` exist; stall-loop states (template_missing / render_incomplete / send_config_missing) invisible to the operator (F-9) |
| **Scale ceiling** | ✅ ~100–200 clients comfortable | **80%** | Soft ceiling ~300 active clients (9am drain); ops ceiling (manual remix/A2P) arrives first at ~50–100. §4 |

**Overall: production-ready for the first real clients**, with three compliance/correctness items (F-2, F-5, F-4) recommended as Lovable prompts **before** scale-up, and one design-level gap (F-1) accepted-and-monitored.

---

## 2. Findings (severity-ranked)

### F-1 · HIGH (design) — One drip per sequence per contact, per lifetime
`enrollments UNIQUE (client_id, contact_id, sequence_key)` is a **full** constraint (foundation migration ln 401), while the guard checks only `status='active'` (`enroll.server.ts:104-119`). A completed/exited/failed row → INSERT 23505 → `already_enrolled`. Consequences:
- **2nd-ever missed call from the same number → no textback, silently** (both providers: `missed-call.server.ts:90` and `_shared/core.ts fireMissedCall`; the event records `enroll_ok:false, enroll_reason:"already_enrolled"`; owner notification still fires — partial mitigation).
- Repeat review request impossible (visible to the operator as already-enrolled, but unfixable in-app).
- Repeat chat-widget/discount submitters (deduped contacts) → no drip.
- Lead form escapes this **accidentally** via F-3 (every submit = new contact row).
- Interlock: even if re-enrollment were enabled, `tracked_links` keeps `clicked_at` per (client, contact, sequence) forever → a re-enrolled review drip **insta-exits at step 0** for anyone who ever clicked (`runner.server.ts:403-416`, `contactClickedTrackedLink` is not enrollment-scoped). And resetting a completed enrollment row in place would trip `send_attempts` idempotency into skip-advancing every step. A correct fix touches 3 tables' semantics.
**Why not discovered before:** all validation was first-touch — fresh contacts/numbers per test, CFL purges between runs; no longitudinal repeat-customer scenario ever ran.
**Detection until fixed:** SQL A-2 (appendix) counts `already_enrolled` misses per sequence; run weekly.

### F-2 · HIGH (small fix) — Provider 429 → permanent enrollment failure
`telnyx-send.server.ts:55` and `send.server.ts:116-120`: any non-auth 4xx (including **429 rate-limit**) → `retryable:false` → runner sets `status='failed', next_run_at=null` (`runner.server.ts:736-745`). A transient burst condition permanently kills enrollments; nothing resurrects them. **Why missed:** live tests never hit provider rate limits. **Fix:** prompt P-1 below (treat 429 as retryable). Resurrect SQL A-5 for any existing rows.

### F-3 · MED-HIGH (design) — Duplicate contacts per phone; dedupe asymmetry
`intake.ts:150-162` inserts a NEW contact on EVERY lead-form submit (no phone dedupe); chat/optin + discount DO dedupe — but with `.maybeSingle()` and **no `.limit(1)` and no error check** (`chat/optin.ts:100-106`, `discount.ts:114-119`): once duplicates exist, multi-row match → PostgREST error → read as "no match" → **creates another duplicate**. Inbound threading picks `limit(1)` with **no ORDER BY** (`_shared/core.ts:126`) → replies attach to an arbitrary duplicate → `skipIfReplied`/one-year reply-exit can miss real replies.

### F-4 · HIGH (security/hygiene) — Edge fns: pre-auth DB writes to a hardcoded tenant
All 4 `telnyx-*` edge fns + legacy voice fns write a debug `events` row **before signature verification**, capturing the raw body, attributed to hardcoded `FALLBACK_CLIENT = 3c987f92-…` (`telnyx-sms-inbound/index.ts:4,11`). Since `events.client_id` FKs to `clients` **ON DELETE CASCADE** with a tenant-scoped SELECT policy: (a) if that UUID is a **live tenant**, its authenticated users can read raw webhook payloads of EVERY client's inbound (cross-tenant PII); (b) if it was **CFL (purged)**, every diagnostic insert now silently fails and the inbound observability layer is dead. Also an unauthenticated spam-write vector (any POST → row). Identify the UUID with SQL A-1; fix with prompt P-3.

### F-5 · HIGH (compliance) — STOP scoped to one contact row
`_shared/core.ts:164-166`: STOP updates `opted_out_at` and exits enrollments **by contact id only**. With F-3 duplicates, an active drip on a sibling row **keeps texting the same phone after STOP**. No provider backstop — Telnyx auto-opt-out is deliberately DISABLED (admin-view skill). The runner's D13 `optout_blocked` sync only helps if the provider blocks, which it won't. TCPA/carrier exposure. **Fix:** prompt P-2 (opt out by client+phone, not row) — closes the hole without touching the F-3 design question.

### F-6 · MED (compliance/docs) — HELP is not app-handled
`parseIntent` handles STOP synonyms/START/PASS only (`_shared/core.ts:14-26`); HELP routes as a plain reply, nothing responds. Docs claimed "STOP/HELP/START" — corrected 2026-07-29 (launch-check, features, project-app knowledge). **Action:** verify a HELP auto-response is enabled on the Telnyx messaging profile, or add an app-side responder (prompt sketch in P-4) before a real client goes live. 10DLC reviewers test HELP.

### F-8 · LOW-MED (ops) — Four unbounded tables, zero retention
`rate_limit_hits` (no purge anywhere), `send_attempts`, `runner_ticks` (**correction 2026-07-30: NOT 720 rows/day** — only ticks that CLAIM work write a row, so an idle platform writes ~0/day; see §11), `events` (the dominant grower: ~10-14 rows per send + every webhook + funnel + decisions). Growth estimate at 100 moderately active clients: ~60-70k events/day ≈ **25M rows/yr (~10-15 GB)**. Nothing breaks (the hot queries are index-covered), but storage + query drift accumulate. **Fix:** retention SQL A-6 (pg_cron purge jobs) — safe to run now; `events` retention is an operator decision (audit value), monitor with A-7.

### F-9 · MED (observability) — Stall-loops are invisible
`template_missing`, `render_incomplete`, `send_config_missing` reschedule +15 min forever by design (correct — never terminal), but `health.functions.ts` surfaces only `failed24h` + tick stats. A typo'd template var = a drip silently stalling for weeks, emitting 96 events/day. **Fix now:** monitoring SQL A-3 (run weekly / after any template edit). **Recommend:** add these counts to the admin health tile (small additive change, post-launch fine).

### Design notes (no action queued)
- `get_client_public` strips template_vars PII by **blacklist** (`- 'notification_email'`) — any future PII key added to template_vars is anon-exposed by default. A whitelist projection is the safer long-term shape (foundation for the next RPC change, not a change now).
- Inbound/enroll/missed-call logic is **duplicated** app-side vs edge-side and has already drifted once (edge `fireMissedCall` has an atomic CAS the app version lacks). The edge version is live for the Telnyx path — the good one. Consolidation is a post-launch refactor.
- Daily send cap counts all `sms_sent` events including 24/7 missed-call textbacks — a client at cap also stops textbacks. Cap default 500/day makes this theoretical; noting the interaction.
- `reply.functions.ts:63` throws on opted-out contacts — the owner cannot manually text an opted-out contact even from the inbox. Strict + compliant; be aware it will surface as a support question one day.
- Punch-list closure: `{your_message}` ← `contacts.notes` mapping EXISTS (`write.server.ts:180` + intake alias `intake.ts:158`) — the "mismatch" item was stale; memory updated.

---

## 3. Drip/enrollment deep-dive — verified mechanics

**States:** `active → completed | exited | failed`. Every terminal transition is evented. **No logical dead ends in the state machine itself** — the only unreachable-progress states are the deliberate F-1/F-2 cases above. Specifically verified:
- **Claim:** `claim_due_enrollments` v4 — per-client rank ≤25, batch ≤500, `FOR UPDATE SKIP LOCKED`, **+5-min lease written inside the claim txn**, archived/deleted clients excluded. Overlapping ticks are safe; a crashed tick's rows resurface in 5 min.
- **Idempotency:** `send_attempts` PK (enrollment_id, step) inserted BEFORE send; `'sent'` marked before advance; re-claim after crash → skip-and-advance; `'sending'` → resend with same idempotency key + `uq_messages_twilio_sid` backstop. **Double-send is engineered out.**
- **Caps:** reservation pre-incremented before dispatch, refunded on every non-send outcome — overshoot impossible under concurrency. Daily count from **client-tz midnight** (not UTC).
- **Windows:** `zonedWallTimeToUtc` converges over DST transitions; window block reschedules to the next window-open without advancing; order preserved.
- **Token population (the alignment you asked about):** SMS bodies render from `dripMergeVars` = `clients.template_vars` (+ `company_name` ← business_name) + contact fields (first_name/full_name/phone/email) + `quote_form_link` fallback ← company_website_link + per-(client,contact,sequence) minted `review_link`. Notifications layer `{your_message}` ← notes + `{request_time}` (client tz) + per-call vars (e.g. `caller_phone`). Unresolvable tokens are left as `{token}` and the LIVE transport **refuses to transmit** (`unrendered_token` → reschedule + event). **A wrong value can't ship silently; a missing value can't ship at all.** Final proof against live copy = SQL A-4 (extracts every `{token}` in `templates` and diffs against the known-populated set).

---

## 4. Scale ceiling analysis

**Runner throughput.** 720 ticks/day × (≤500 claims, ≤25/client). Per-enrollment processing ≈ 12-18 sequential DB round-trips (~0.5-1.1s), batched ≤25-concurrent per client; **client batches run sequentially** → ~15-25 client-batches per 25s tick. The stress case is the 9:00 AM window-open pile-up (overnight deferrals all due at once):
- 100 clients with due work → drained in ~5-7 ticks ≈ **10-14 min** ✅
- 300 clients → ~30-45 min ⚠ (morning sends slip toward 9:45)
- 500 clients → 1h+ ✖ (soft ceiling)

**Levers when needed (in order):** (1) cache `sequences`/contact reads per tick (cuts round-trips ~40%); (2) run 2-3 parallel cron jobs — **already safe** thanks to SKIP LOCKED + lease; (3) raise `PER_CLIENT_SLICE`/`TICK_TIME_BUDGET` (needs pg_net `timeout_milliseconds` raised in step). None require redesign.

**Data layer.** Enrollments/messages/contacts are trivially indexed for 10⁶-10⁷ rows. `events` is the grower (§F-8): ~25M rows/yr at 100 clients — fine on Supabase with `idx_events_client_type_created`, needs a retention decision by month ~6. `rate_limit_hits` ~5M/yr — purge job A-6.

**Provider layer.** Per-client 10DLC brand/campaign caps (~1-6k segs/day per client at standard trust tiers) scale **per client** — never platform-binding. Single shared Telnyx API key: burst-limited (F-2 fix removes the dead-end); per-number ~1 MPS long-code default far exceeds per-client need. A2P registration (3-7 days, manual per client) is a **throughput limit on onboarding**, not on operation.

**Hosting layer.** Marketing sites are per-client Lovable remixes — no technical ceiling before thousands, but **every template improvement is a manual N-fold propagation**. At 20 clients a template fix = 20 remix edits.

**The binding constraint is operational, not technical:** manual remix propagation + manual A2P + manual onboarding ≈ **50-100 clients per operator** before tooling (the parked MCP/edit-channels + one-click-client-build backlog items) becomes mandatory. The software itself signs off to ~200 clients as-built, ~300-500 with the listed levers.

---

## 5. Second-wave evaluation of queued changes

| # | Change | Necessary? Why | Why not found earlier | Risk of change | Verdict |
|---|---|---|---|---|---|
| P-1 | 429 → retryable (both transports) | Yes — converts permanent send-failure into a deferred retry; prerequisite for any volume | No test ever hit a provider rate limit | **~5%** — behavior changes only on 429s, which today hard-fail; bounded by caps + jitter + events | **FIRE** (prompt below) |
| P-2 | STOP by (client_id, phone) + `.limit(1)` hardening | Yes — closes the only path where a STOP doesn't stop; app is the sole STOP enforcement | Dupes never accumulated in single-pass tests | **~5-10%** — widens opt-out scope to same-phone rows (that IS the intent); worst case = over-opt-out of a duplicate row | **FIRE** (prompt below) |
| P-3 | Edge-fn debug writes: post-verification only, resolved-tenant only | Yes — removes unauthenticated write vector + cross-tenant PII risk + un-breaks diagnostics if the UUID is dead | Debug lines were added mid-crisis (July inbound saga) and never removed | **~5-10%** — logging-only change but touches the live inbound path; validate with one inbound text after deploy | **FIRE after SQL A-1** identifies the UUID |
| P-4 | App-side HELP responder | Compliance-dependent — carriers/reviewers test HELP | Docs claimed it existed; nobody texted HELP in a test | ~10% + needs copy decision | **HOLD** — first check the Telnyx profile setting (may already answer HELP); add only if not |
| A-6 | Retention purge jobs (SQL, additive) | Yes — unbounded tables | Growth is invisible at test volume | **~2-5%** — deletes only closed windows / sent attempts / old ticks | **RUN** in SQL editor |
| F-1 | Re-enrollment redesign (partial unique + enrollment-scoped clicks + attempt-key strategy) | Eventually — repeat customers are the business norm | First-touch-only testing | **~30-40%** — three interacting tables on the live send path | **DEFER** — designed change post-launch; monitor with A-2 |
| F-3 | Canonical contact-per-phone dedupe at intake | Eventually — data quality | Same | **~25-35%** — changes CRM semantics (update-vs-new-lead) | **DEFER** — pair with F-1 design pass |
| F-9 | Health tile: stall-loop counts | Nice-to-have | Health tile predates the self-heal states | ~5% | **DEFER** (post-launch); SQL A-3 covers the gap |

Applied this session (zero-risk, docs repo only): HELP wording corrected in launch-check/features/project-app knowledge; `phone_e164` derivation precision in project-template knowledge; stale punch-list item closed in memory.

---

## 6. Ready-to-fire Lovable prompts (APP project)

### P-1 — 429s must not kill enrollments (risk ~5%)
```
In src/lib/sms/telnyx-send.server.ts and src/lib/sms/send.server.ts (sendViaTextGrid), change ONLY the HTTP-status classification: when the provider responds with status 429, return { ok:false, retryable:true, error:"rate_limited_429" } instead of falling through to the non-retryable 4xx branch. Everything else in both files stays byte-identical. Do not touch the runner. Why: today a transient 429 marks the enrollment status='failed' with next_run_at=null — a permanent dead end from a burst; retryable:true makes the runner reschedule with jitter, which is the designed behavior for transient provider errors. Change nothing else.
```

### P-2 — STOP must stop every row on that phone (risk ~5-10%)
```
In supabase/functions/_shared/core.ts, inside handleInboundSmsCore's intent==="stop" branch only: (1) replace the contacts update .eq("id", contactId) with .eq("client_id", clientId).eq("phone_e164", from).is("deleted_at", null) so EVERY contact row sharing the inbound phone is opted out; (2) after it, select the ids of all matching contact rows and call exitActiveEnrollments for EACH id (not just contactId). Also, as pure hardening in src/routes/api/public/chat/optin.ts and src/routes/api/public/discount.ts, add .limit(1) immediately before .maybeSingle() on the contact-dedupe lookups (multi-row matches currently error and silently create another duplicate). The intent==="start" branch, threading, message insert, and everything else stay byte-identical. Why: contacts can share a phone (lead form inserts a new row per submit); STOP currently opts out only the row the reply threaded to, so an active drip on a sibling row keeps texting after STOP — a compliance hole, and the app is the only STOP enforcement because Telnyx auto-opt-out is disabled. Change nothing else.
```

### P-3 — Edge-fn debug writes: authenticated-only, resolved-tenant-only (risk ~5-10%; run SQL A-1 first)
```
In supabase/functions/telnyx-sms-inbound/index.ts, telnyx-sms-status/index.ts, telnyx-voice-inbound/index.ts, telnyx-voice-status/index.ts (and the legacy voice-inbound/voice-status if trivially co-editable): remove the FALLBACK_CLIENT constant and every events insert that fires BEFORE verifyTelnyxSignature succeeds or that writes client_id: FALLBACK_CLIENT — replace each with console.log/console.error carrying the same payload (Supabase edge logs capture these). Branch/outcome events that fire AFTER the client row is resolved keep being written, but with the RESOLVED client.id. Signature verification, envelope parsing, handleInboundSmsCore, and all response codes stay byte-identical. Why: the pre-verification insert is an unauthenticated write path that captures raw webhook bodies under a hardcoded tenant — either polluting a live tenant's RLS-visible events with other clients' message content, or silently failing against a deleted client id. After publish, send one inbound test text and confirm a telnyx_sms_inbound_branch event appears under the correct client. Change nothing else.
```

---

## 7. Verification SQL appendix (run in the APP project's SQL editor)

```sql
-- A-1 · Whose UUID is the edge-fn fallback tenant?
SELECT id, business_name, slug, status, deleted_at FROM clients
WHERE id = '3c987f92-5537-4c7f-8954-bacbea248578';
-- 0 rows → it was purged (CFL): debug inserts silently fail today (P-3 also un-breaks this).
-- 1 live row → cross-tenant PII exposure is real; fire P-3 promptly.

-- A-2 · F-1 detector: blocked re-enrollments by sequence (run weekly)
SELECT payload->>'sequence_key' AS seq, count(*)
FROM events
WHERE type = 'missed_call' AND payload->>'enroll_reason' = 'already_enrolled'
GROUP BY 1
UNION ALL
SELECT 'enrollment_blocked:' || (payload->>'reason'), count(*)
FROM events WHERE type = 'enrollment_blocked' GROUP BY 1;

-- A-3 · Stall-loop monitor (run weekly / after template edits): active enrollments stuck in self-heal
SELECT e.type, count(DISTINCT e.payload->>'enrollment_id') AS stuck_enrollments, max(e.created_at) AS latest
FROM events e
WHERE e.type IN ('template_missing','render_incomplete','send_config_missing')
  AND e.created_at > now() - interval '24 hours'
GROUP BY 1;

-- A-4 · Token alignment proof: every {token} used in live templates vs the populated set
WITH toks AS (
  SELECT key, client_id, (regexp_matches(body, '\{([a-zA-Z0-9_.]+)\}', 'g'))[1] AS tok
  FROM templates
)
SELECT tok, count(*) AS uses, array_agg(DISTINCT key) AS in_templates
FROM toks
WHERE tok NOT IN (
  -- populated by dripMergeVars/write.server.ts (verified in code 2026-07-29):
  'first_name','full_name','phone','email','company_name','review_link','quote_form_link',
  'company_website_link','company_owner_first_name','discount__on_referral','discount_amount',
  'review_request_link','about_us','services','differentiators','your_message','request_time',
  'caller_phone','business_name'
)
GROUP BY tok ORDER BY uses DESC;
-- Any row here = a token in live copy with NO populator → that template stalls (unrendered_token) when it fires.

-- A-5 · Resurrect any 429-killed enrollments (after P-1 ships; review before running)
SELECT e.id, e.client_id, e.sequence_key, e.current_step, ev.payload->>'reason' AS fail_reason
FROM enrollments e
JOIN LATERAL (
  SELECT payload FROM events
  WHERE payload->>'enrollment_id' = e.id::text AND type='cron_decision' AND payload->>'decision'='failed'
  ORDER BY created_at DESC LIMIT 1
) ev ON true
WHERE e.status = 'failed';
-- then, for rows whose fail_reason is transient (429/network):
-- UPDATE enrollments SET status='active', next_run_at=now() WHERE id IN (...);

-- A-6 · Retention purge jobs (additive ops; safe windows)
SELECT cron.schedule('purge-rate-limit-hits','17 * * * *',
  $$DELETE FROM public.rate_limit_hits WHERE window_start < now() - interval '2 days'$$);
SELECT cron.schedule('purge-send-attempts','23 4 * * *',
  $$DELETE FROM public.send_attempts WHERE status='sent' AND created_at < now() - interval '180 days'$$);
SELECT cron.schedule('purge-runner-ticks','29 4 * * *',
  $$DELETE FROM public.runner_ticks WHERE started_at < now() - interval '90 days'$$);

-- A-7 · Growth watch (monthly): table sizes + events/day rate
SELECT relname, pg_size_pretty(pg_total_relation_size(c.oid)) AS total
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND relkind='r'
ORDER BY pg_total_relation_size(c.oid) DESC LIMIT 12;
SELECT date_trunc('day', created_at) d, count(*) FROM events
WHERE created_at > now() - interval '14 days' GROUP BY 1 ORDER BY 1 DESC;

-- A-8 · Cron inventory sanity (drip-runner present + firing; content-jobs scheduled or not is a decision)
SELECT jobid, jobname, schedule, active FROM cron.job ORDER BY jobid;
SELECT jobid, status, return_message, start_time FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;
SELECT status_code, (content::jsonb)->>'ok' AS ok, created FROM net._http_response ORDER BY created DESC LIMIT 5;

-- A-9 · Duplicate-contact census (F-3 scope check)
SELECT client_id, phone_e164, count(*) AS rows
FROM contacts WHERE phone_e164 IS NOT NULL AND deleted_at IS NULL
GROUP BY 1,2 HAVING count(*) > 1 ORDER BY rows DESC LIMIT 25;
```

**Portal checks (no repo/SQL equivalent):** Telnyx messaging profile → confirm HELP auto-response behavior (F-6) and Number Pooling OFF; both already-documented invariants.

---

## 8. Monitoring runbook (until the health tile grows)

Weekly: A-2 (blocked re-enrollments), A-3 (stall loops), A-8 (cron firing + net responses 200). Monthly: A-7 (growth), A-9 (dupes). After any template copy edit: A-4 (token alignment). After any backend publish: `?ping=1` version gate (POST-only).

---

## 9. ADDENDUM — second-wave outcomes after operator review (2026-07-29, same day)

The operator challenged P-2 and P-3. Re-audited against Telnyx's own documentation (help-center 1270091 + developers advanced-opt-in-out). Results:

### P-2 — WITHDRAWN from the fire list (operator was right)
The original F-5 severity rested on our docs' claim that Telnyx auto-opt-out was DISABLED (decision D10). **Telnyx docs prove D10 was never achievable:** auto opt-out is default account behavior and **cannot be fully disabled** (only keywords/auto-responses customize). So the provider layer ALWAYS enforces STOP: the sender is added to Telnyx's opt-out list, Telnyx auto-confirms ("You have successfully been unsubscribed…"), and any later send to that phone fails **40300 "Blocked due to STOP message"** — which the runner's D13 `OPTOUT_HINT_RE` (`/blocked.*stop/i`) matches → contact synced + enrollment exited. The duplicate-contact STOP hole therefore **cannot deliver a message after STOP**; its residue is one blocked attempt + data cleanup, i.e. hygiene, not compliance. F-5 severity: HIGH → **LOW**. The `.limit(1)` dedupe-lookup hardening folds into the F-1/F-3 post-launch design pass.
**Root-cause of the false HIGH:** trusting our own doc's provider-behavior claim (D10) without provider-doc verification — the same doc-vs-reality failure mode this audit exists to catch, one layer up.

### NEW FINDING (from the same research) — F-11 · MED (architecture): Telnyx opt-out blocks are PROFILE-WIDE
"If a user opts out from one number on your profile, they're opted out from all numbers on that profile." On the ONE shared platform profile: **STOP to any client's number blocks that phone for EVERY client** — a shared customer of two platform clients who stops one silently stops both (second client's sends → 40300 → D13 marks their contact copy opted-out). Compliance-conservative (over-blocking, never under), but silent cross-client coupling. Rare until client density overlaps in one metro. **Option when it matters:** per-client messaging profiles at onboarding (one API call; webhook URL identical; voice/TeXML + runtime routing unaffected — nothing reads the profile id at send/inbound time). Operator decision, parked. Skills updated (/telnyx-provider §3 Opt-out ownership; D10/J5/Q7 marked superseded/resolved).

### P-3 — RE-TIMED, not fired (operator context changed the call)
The FALLBACK_CLIENT UUID is the **agency's own client row** (operator-confirmed) — so debug events land in the agency's own tenant, not a customer's; the cross-tenant-PII branch of F-4 collapses. Capture-first is also a DOCUMENTED decision (D9: "stripped only at steady-state"), and **SMS Day-0 still needs it** (Q8/Q9 resolve by capture). Verdict: **keep capture-first through SMS Day-0; strip the pre-verification raw-body debug inserts at steady-state** (the planned retirement), leaving post-verification branch events. Residual until then: unauthenticated POSTs can write ~1 events row each (spam/growth vector, agency-visible only) — accepted short-term. Run A-1 once anyway to confirm the row's id/status matches expectations.

### P-1 — unchanged, operator-approved, ready to fire (§6).
### Day-0 canary spec corrected: the STOP canary now EXPECTS Telnyx's confirmation + a 40300 on the follow-up send + a HELP auto-reply check (/telnyx-provider §8 step 7).

---

## §11 — 2026-07-30 — `runner_ticks` is NOT a heartbeat (false-alarm post-mortem)

**A false "the drip runner has been dead 27 hours" alarm was raised during routine verification. The runner was healthy the entire time.** Recording the mechanism so it never recurs.

**What was observed:** latest `runner_ticks` row was `2026-07-29 16:08`, ~27h stale, and the latest `cron_decision` event matched it. Inferred: cron active but not executing.

**What was actually true:** `drip-runner` was firing every 2 minutes without a miss — `cron.job_run_details` showed `succeeded` at `03:40, 03:42 … 04:26`, and `net._http_response` showed matching `200 {"ok":true,"claimed":0,...}` for each. pg_net request ids `188→369` spanned exactly 6 hours = 181 two-minute ticks (pg_net prunes responses after ~6h, which made `max_id` look deceptively low).

**Root cause of the wrong inference:** `runDripTick()` early-returns at `runner.server.ts:253` (`if (due.length === 0) return summary;`) **before** the `runner_ticks` insert at ~832. **A tick that claims zero enrollments writes no `runner_ticks` row and no events.** With no active enrollments due, the table is frozen at the last tick that had work. **An idle runner is indistinguishable from a dead one in that table.** The file's header comment ("Every tick writes one `runner_ticks` row") is FALSE and is the trap.

**Process failure, not a code defect.** This audit's own **A-8** already prescribes the correct three-layer check (`cron.job` + `cron.job_run_details` + `net._http_response`) and the app knowledge doc says "Verify BOTH `cron.job_run_details` AND `net._http_response`." The alarm came from substituting an ad-hoc `runner_ticks` query for the documented method. **Follow A-8; never treat `runner_ticks` as liveness.**

**Consequences accepted (deliberately NOT fixed):** the admin health tile (`health.functions.ts:102`) reads the newest `runner_ticks` row as `lastTick`, so it shows a stale timestamp on any quiet day. A prompt to make the runner write idle ticks was drafted and **REJECTED** at second-wave review: it edits the most critical file in the system for observability convenience, and would add ~263k idle rows/yr. Correct fix if ever wanted: derive cron liveness in the health tile from `cron.job_run_details` (read-only admin surface, never the send path) — post-launch, ~5%. Also worth folding into any future runner-touching prompt: correct the false header comment.

**Also confirmed 2026-07-30:** the A-6 retention purges are live and working — `purge-rate-limit-hits` first run `DELETE 172`; `purge-send-attempts` `DELETE 0` (correct, nothing 180d old). And `?ping=1` returned `runner_version v20260729-1`, proving the 429-retryable fix is deployed.

### §11b — Second-audit correction to the §11 reading rule (2026-07-30)

The rule first written in §11 ("`backlogDue > 0` + stale `lastTick` = genuinely broken") was **incomplete and would have produced the same class of false alarm one layer up.** Found on a deliberate re-audit.

**Why:** `backlogDue` = `headCount("enrollments", status='active' AND next_run_at <= now)` (`health.functions.ts:83`) — **no client join.** But `claim_due_enrollments` JOINs `clients` on `status='active' AND deleted_at IS NULL` (migration `20260615211906`, comment: "skip enrollments belonging to archived/deleted clients"), and `archive_client` only runs `UPDATE public.clients` — it never deletes enrollments (CASCADE fires on DELETE, not UPDATE). Note the asymmetry is visible in the same function: `activeClients` filters client status, `backlogDue` does not.

**Consequence:** archive a client holding active enrollments and `backlogDue` stays elevated **forever** while the runner is perfectly healthy and correctly skipping them.

**Corrected rule (now in `/launch-check` + `software-constraints-at-scale.md` §6):** `backlogDue > 0` + stale tick = **investigate**, and disambiguate with a client-joined query — only due enrollments belonging to an ACTIVE, non-soft-deleted client mean the runner is actually broken.

**Meta-lesson (the reason this keeps recurring):** every metric here is a *proxy*, and each proxy has a scope that differs subtly from the thing it is proxying. `runner_ticks` proxies "runner ran" but scopes to "runner had work." `backlogDue` proxies "work the runner owes" but scopes to "work rows exist, regardless of whether the runner is allowed to touch them." **Before treating any counter as an alarm, check what it EXCLUDES versus what the consuming code excludes.**
