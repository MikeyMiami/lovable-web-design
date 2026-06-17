# HANDOFF — session context for a fresh Claude Code instance

> **Point a new instance here:** "Read `HANDOFF.md` to know what we're doing." This is the single go-to context file. Last updated **2026-06-16**. Planning-repo head: **`029896d`** (all reconciles in; user's masters confirmed in full byte-parity).

---

## 1. What this project is (one paragraph)
A multi-tenant SMS-automation **"golden master" backend** built in **Lovable** (cloud app builder) on **Supabase** (Postgres + Auth + RLS + Storage) with **TanStack Start v1 / React 19** on **Cloudflare Workers**. The model: **ONE shared backend** is built/proven once, **frozen**, and **never regenerated per client**. A per-client launch = one `clients` row + config on the shared backend + a Remixed frontend marketing site pointed at it. Business logic is never per-client (that's the anti-drift core).

**Two repos (both `MikeyMiami`, `gh` is authed):**
- `lovable-web-design` — **planning repo** (this repo): spec + 11 skills + build-logs + these docs. The **source-of-truth library**. I (Claude) edit here.
- `cloud-spark-setup` — **the built app CODE** (Lovable owns it). **FROZEN** at `126680404a818fc5fee4ef92e87643f3f99f54de`, tag `golden-master-v1`. Cloned locally at `C:\Users\Pierc\Desktop\cloud-spark-setup` for code verification. **Do NOT modify frozen code.**

**My role:** validate Lovable's build reports against the spec/skills/real code, record durable build-log validations, and hand the user **verbatim mirror lines + exact placement** so their separate "masters" stay byte-identical. Discipline below (§6).

---

## 2. Current state — FROZEN, in 1f-prep
- **Stage 4 freeze EXECUTED** (2026-06-15). Golden master tagged `golden-master-v1` on **both** repos. Record: `docs/build-log/stage-4-freeze.md`.
- **Re-tag `golden-master-v1.1`** (2026-06-16, `cloud-spark-setup@5e41f41`): the cron route `/api/public/cron/sequences` gained a **`?ping=1`** deploy-promotion health-check (POST-only, early-returns `runner_version` before auth/tick — no secret, no send). This closed the owed deploy-lag root-cause (spec §12 INFRA): (2) no separate worker, (3) `cron.job` empty / no scheduled caller, (4) inherent Lovable edge-propagation lag. **The post-deploy "confirm-promoted" gate** — bump `RUNNER_VERSION` → publish → POST `…?ping=1` until it echoes the new version → then cross-check fresh `events.payload->>'runner_version'` — is now the required procedure after every backend-touching 1f deploy. Record: `docs/build-log/1f-prep-deploy-lag-rootcause.md`. **pg_cron is still UNSCHEDULED by design** (scheduled LAST in 1f, at the canonical prod URL, after swap + inbound validate on manual ticks — spec §12 / launch-check §E).
- **Freeze model:** the automation **LOGIC + schema + surfaces** (drift-prone) are locked. The carve-out is the **FULL Stage-1f scope** (post-freeze, NOT freeze blockers).
- **Stage 1f = the deliberate FINAL pre-launch hardening** — the ONLY changes allowed to touch the frozen backend:
  1. **Real messaging-provider swap** (provider = **TextGrid**, a Twilio-API clone) — send-primitive internals + status-swap (`stub` → real SID/delivery).
  2. **NET-NEW inbound webhook layer** (`X-TextGrid-Signature` HMAC-SHA1) — inbound SMS→CRM, real-time reply-driven drip exits, missed-call. **This does NOT exist in the frozen master — built fresh at 1f** (verified against the repo; the old spec's "Inbound SMS→CRM [built]" was inaccurate).
  3. **LIVE Turnstile + rate-limiting** on public lead-intake routes.
  4. Additive per-client provider columns: `provider_subaccount_sid`, `provider_webhook_secret`, `a2p_brand_id`, `a2p_campaign_id`, `a2p_status`.
- **1f STEP 1 (outbound TextGrid swap) — BUILT + STUB-VALIDATED, tagged `golden-master-v1.2`** (`cloud-spark-setup@73ca26e`, 2026-06-16). Spec: `docs/1f-step1-outbound-swap-build-spec.md`. Validation: **independent code review all-green (7/7)** — pure-transport SEND-ONLY `sendSms`/`sendSmsWithRetry`, D1 universal opt-out exit (all sequences) + reply `contact_opted_out` throw, D2 render self-heal (`render_incomplete`, never terminal-fail), LIVE-only `send_config_missing`, additive `provider_subaccount_sid`, `RUNNER_VERSION=v20260616-2` — **plus `audit_tenant_rls()=0`**. **`SMS_MODE=stub`, no TextGrid creds set, cron unscheduled.** Tick-level behavioral tests (2e regression, opt-out exits) are **DEFERRED to the LIVE smoke** (code verified; live exercise belongs at LIVE — and Lovable Cloud has no external-secret path to drive ticks anyway: `CRON_SECRET` write-only, service-role ambient-only). **LIVE flip is GATED on:** (a) the **TextGrid parent-on-subaccount auth confirm** — built on the Option-1 assumption, docs lean Option-2, `auth`/`sendingAccountSid` decoupled so the flip is caller-only; if a LIVE send 401s, that's the cause (`textgrid-provider` §2/§7); (b) the **form-encoding/content-type LIVE-path watch** — Lovable POSTs `application/x-www-form-urlencoded` + PascalCase `To/From/Body`, but the Breeze doc shows `application/json` + lowercase; confirm/switch before LIVE.
- **1f STEP 2 (net-new inbound webhook layer) — BUILT + validated, tagged `golden-master-v1.3`** (`cloud-spark-setup@761aa19`, 2026-06-16). Spec: `docs/1f-step2-inbound-webhook-build-spec.md`. Validation: **code review green** + **live opt-out proof green** (pass-tightening confirmed end-to-end on the live webhook). **Covered:** inbound SMS→CRM (conversation upsert + inbound `messages` + `inbound_sms` event); **`X-TextGrid-Signature` HMAC-SHA1** verify with the **4 hardening invariants** (fail-closed-no-secret → 401, resolve-secret-by-`To`-then-verify, raw-body HMAC, dedupe-by-`MessageSid`); real-time reply-exit (one_year → exit + interest notify); **STOP / sole-word `pass` / START opt-out capture that SETS `opted_out_at`** (D1's read-side from step 1 now has a writer — full TCPA chain live); missed-call textback off `voice-status` (`no-answer`/`busy`/`failed`, 60-min throttle); `sms-status` delivery callback. Additive migrations: `provider_webhook_secret`, `uq_messages_twilio_sid` (partial), `inbound_sms` enum; `audit_tenant_rls()=0`; `RUNNER_VERSION=v20260617-2`. **`pass` tightened to sole-word** (was `\bpass\b`-anywhere → false-positived "pass this along"; fixed `73ca26e`-era → `761aa19`). **Deferred to LIVE:** per-number webhook wiring (A2P provisioning, step ③/A2P), the **URL-exactness + non-ASCII `\uXXXX` HMAC watches**, and the D1 "subsequent-tick-exits-it" sub-step (needs a `CRON_SECRET` tick). **Cosmetic backlog (later doc sweep):** `parseIntent` docstring still says "whole-word `\bpass\b`"; runner/reply "Twilio STUBBED" doc-comments.
- **1f STEP 3 (Turnstile + rate-limiting) — BUILT + STUB-validated, tagged `golden-master-v1.4`** (`cloud-spark-setup@ac37b56`, 2026-06-16). Spec: `docs/1f-step3-turnstile-ratelimit-build-spec.md`. Validation: **code review green** + STUB evidence green (ping/pass/rate-limit/audit). **Covered:** Turnstile siteverify on the **3 bare lead forms** (`intake`/`discount`/`chat/optin`) — **fail-CLOSED** on `success:false`/missing-token, **fail-OPEN+alert** on call throw/timeout(5s)/non-2xx/missing-secret; `chat/request` = **rate-limit only** (token-gated); webhooks/cron/`r/*` EXCLUDED. **DB-backed rate limiter** (`rate_limit_hits` + atomic `check_rate_limit()` SECURITY-DEFINER/service-role-only RPC, RLS-on/no-policies — no KV/DO in the Lovable/Nitro runtime), **per-IP (10/10m) + per-client (60/10m)** from `CF-Connecting-IP`, 429+`Retry-After`. Order: `parse→Zod→resolveTenant→rate-limit→Turnstile→process`. `audit_tenant_rls()=0`; `RUNNER_VERSION=v20260617-3`; send primitive + step-2 untouched. **Deferred to LIVE:** the Turnstile **fail-probe** (secret-rebind infra issue, NOT code — fail branch code-verified), and (carried) the real widget + `TURNSTILE_SECRET_KEY` must be set before LIVE (missing secret = fail-OPEN = bot-protection off, alerted). **Backlog [FIX]:** `rate_limit_hits` old-window GC (slow growth).
- **NEXT: remaining 1f (ordering Mikey's call)** — **A2P registration flow** (per-client subaccount→Brand→Campaign→number; full field list in `docs/1f-step6-a2p-registration-field-requirements.md`; also wires the **per-number webhooks** step 2 deferred), **call-forwarding**, the **reactivation number pool** (net-new agency layer), and **pg_cron scheduling LAST**. **Frontend-widget launch prerequisite** recorded in `/website-structure` + `/launch-check` §E (Turnstile widget + public site key on all 3 forms before first launch — backend is fail-closed). **LIVE flip remains gated on** the TextGrid parent-on-subaccount auth confirm (`textgrid-provider` §2/§7) + the outbound form-encoding/content-type watch.

### Carried items — consolidated checklist (MUST-CLEAR before LIVE + backlog; nothing lost)
> Single source for everything deferred across steps 1–3. None of these block building the remaining STUB 1f steps; the 7 gates ALL block the real-provider / real-traffic LIVE flip.

**LIVE-flip gates (7):**
1. [ ] **TextGrid parent-on-subaccount auth confirm** — built on Option-1 (master token vs subaccount SID); docs lean Option-2; `auth`/`sendingAccountSid` decoupled so the flip is caller-only. A LIVE send 401 ⇒ this. (`textgrid-provider` §2/§7; step-1 spec.)
2. [ ] **Outbound form-encoding/content-type watch** — build POSTs `application/x-www-form-urlencoded` + PascalCase `To/From/Body`; Breeze doc shows `application/json` + lowercase. 415/400 at LIVE ⇒ switch to JSON. (step-1 validation.)
3. [ ] **Inbound URL-exactness (HMAC)** — signature = `HMAC-SHA1(request.url + rawBody)`; configured `smsUrl`/`statusCallback`/`voiceUrl` must EXACTLY equal `request.url` (scheme/host/slash/query/proxy) or every sig 401s. Pin canonical URL at provisioning. (step-2; `textgrid-provider` §3.)
4. [ ] **Inbound non-ASCII `\uXXXX` HMAC** — TextGrid re-encodes >127 chars before signing; form bodies are %-encoded ASCII so likely fine — confirm at LIVE with an emoji/accented inbound SMS. (step-2; `textgrid-provider` §3.)
5. [ ] **Turnstile live fail-probe** — STUB proved pass; the `success:false`→403 branch is code-verified; live fail-probe deferred (Lovable secret-rebind infra). Exercise with the real widget at LIVE. (step-3.)
6. [ ] **Real Turnstile widget + `TURNSTILE_SECRET_KEY` on forms** — backend fail-CLOSED on bad token but fail-OPEN (protection OFF, alerted) if secret unset; marketing Remixes must render widget + public site key on all 3 forms (else zero leads). (`/website-structure` + `/launch-check` §A/§E.)
7. [ ] **D1 "subsequent-tick-exits-it" sub-step** — opt-out→enforcement end-to-end (set `opted_out_at` → next runner tick exits `exited_opted_out`, no send) needs a `CRON_SECRET` tick (write-only on Lovable Cloud). Verify at LIVE; opt-out CAPTURE already proven on the live webhook. (step-2.)

**Backlog (non-blocking):**
- [ ] **[FIX] `rate_limit_hits` old-window GC** — periodic `DELETE … WHERE window_start < now() - interval '1 day'` (slow growth). (step-3.)
- [ ] **[COSMETIC] doc-comment sweep** — `parseIntent` docstring still says "whole-word `\bpass\b`" (now sole-word); runner/reply "Twilio (Stage 1f) is STUBBED" comments (now TextGrid). Non-functional. (steps 1–2.)

### Locked product decisions
- **Messaging provider = TextGrid** (no Twilio, no grey-area bridge). Per-client flow: **subaccount → Brand (client EIN, ≥15 days old) → Campaign → number**, each subaccount **vets INDEPENDENTLY per-client** (~2–4 days). NOT one shared agency campaign.
- **Reactivation = agency number-pool ONLY.** The frozen **per-client** reactivation drip (`enrollReactivation`, sends from `clients.twilio_number`) is **LOGICALLY DEPRECATED / superseded** — route zero traffic, leave frozen code physically intact (no re-tag). Verified it's **purely enrollment-driven, NO auto-trigger** (only admin Upload-Customers CSV → `reactivationUpload` → `enrollReactivation`).

---

## 3. What we just did this session (2026-06-16)
**1f-prep: reviewed 3 user-draft files against the real frozen code, then applied provider-neutral doc reconciles + the reactivation deprecation to the planning repo.**

Review record: `docs/build-log/1f-prep-textgrid-reactivation-review.md` (commit `8394680`). Key findings:
- TextGrid swap is genuinely isolated — the **3 isolation points hold** (single SEND-ONLY primitive `sendStubSmsWithRetry`, 2 callers only; `twilio_number` single-source; webhooks under `/api/public/*`). **APPROVED as a 1f spec.**
- **Correction 1:** inbound webhooks + signature are **NET-NEW**, not a "swap" (no inbound route/signature exists in the frozen repo).
- **Correction 2:** spec §9 "Inbound SMS→CRM [built]" was inaccurate → reframed to 1f net-new.
- **from-resolution seam:** the send primitive takes `{clientId, contactId, body}` — **no `from`**. At 1f the **CALLER** must resolve+pass `from` (= `clients.twilio_number`) + subaccount auth, keeping the primitive SEND-ONLY. The reactivation pool reuses this exact seam (passes a pool number as `from`).
- **Reactivation pool placement:** **separate agency-ops layer** — net-new agency-scoped tables (`reactivation_numbers`, `reactivation_campaigns`, **separate** `reactivation_campaign_enrollments` queue), RLS read = `is_admin()` (like `audit_log`/export-client), NOT tenant-RLS. **Separate finite-campaign runner** that reuses only the send primitive. **Do NOT** put pool enrollments in the frozen `enrollments` table (the frozen `claim_due_enrollments` would grab them + send from the wrong number) and **do NOT** add branching to the frozen runner. Buildable as net-new with **ZERO frozen-master modification**.

**Commits this session (planning repo `lovable-web-design`), in order:**
- `8394680` — the 1f-prep review record.
- `02b02e6` — provider-neutral reconciles + reactivation deprecation across spec, LAUNCH.md, launch-check, onboard-from-form, new-client-site, features.
- `fffb21f` — **self-review fix:** §9.D had residual stale items (header/auth/webhooks/A2P bullets) still in the old "Twilio Option 1 / one shared A2P campaign / parent-level webhooks" model, contradicting the per-client model above them. Reconciled.
- `8c9aae4` — added this `HANDOFF.md`.
- `42689fb` — **Bucket-1 provider-neutralize sweep** across all active authoritative docs (spec §0/§9/§9b.D/§10/§12, LAUNCH, scratch-foundation §8 full incl. connector-gateway→direct-API, workspace-knowledge-condensed:47, features, automation-config, admin-view, new-client-site, phase2-build-guide-stage0-1 §1f). Also recovered the silently-lost features:77 reactivation `[DEPRECATED]` header.
- `029896d` — two Stage-0 stragglers (phase2-build-guide-stage0-1 lines 10/13).

**PARITY CONFIRMED:** the user has mirrored EVERY hand-off byte-for-byte; their masters == planning repo @ `029896d`. The TextGrid provider-neutralize reconcile + reactivation deprecation are **COMPLETE**. No active-doc stale-model `Twilio` prose remains (verified by repo-wide grep both sides).

---

## 4. OPEN ITEMS / next steps (the reconcile work is DONE — these are what's LEFT)
1. ~~Provider-neutralize sweep + §9.D fix~~ **DONE & in full parity (`029896d`).** Nothing outstanding here.
2. **A2P registration field GAP — parked at 1f step 6 with the FULL field list** (`docs/1f-step6-a2p-registration-field-requirements.md`, recorded 2026-06-16 from the TextGrid 10DLC doc). The gap is **bigger than just `vertical`**: also `entityType` (sole-prop branch = NO EIN + SMS-OTP flow; many local businesses are sole props), `brandRelationship`, and Campaign-required `termsAndConditionsLink` + `privacyPolicyLink`. The "≥15-day-old EIN" assumption is NOT in the TextGrid docs (verify). Onboarding (`onboard-from-form`) must capture these; implied additive `clients` columns at step 6. Not a step-1 blocker.
3. **3 user-draft files (in the user's "outputs", NOT in this repo — I provide text, the user edits them).** Status: the user reports all three are now folded — `textgrid-provider` SKILL (direct API: `fetch` to `api.textgrid.com`, Bearer auth; Corrections 1+2 in; `from` caller-passed / primitive SEND-ONLY; the two stray "connector gateway" mentions fixed), TextGrid impact map, and `reactivation-number-pool-spec` (supersedes-header added). If revisited, these are the user's files — provide text, don't edit.
4. **When 1f starts (NOT started yet — the real next phase):** build the 1f scope (§2) + the reactivation pool as a net-new agency layer (§3 of "what we did"). Re-validate + **re-tag** the frozen master after each backend-touching 1f change (post-freeze contract: only 1f hardening + re-validated bug-fixes may touch it). Expect Lovable build reports to validate via the usual loop.

---

## 5. Key facts about the real frozen code (`C:\Users\Pierc\Desktop\cloud-spark-setup`)
> **A fresh instance does NOT have this code in context.** Before verifying ANYTHING against the real backend, read from the local clone at `C:\Users\Pierc\Desktop\cloud-spark-setup` (it's tag `golden-master-v1` @ `1266804`). If the clone is missing/stale, re-clone: `git clone https://github.com/MikeyMiami/cloud-spark-setup C:\Users\Pierc\Desktop\cloud-spark-setup` then `git -C ... checkout golden-master-v1`. The real code / live DB / migrations are the highest-trust source — never validate off Lovable's prose summaries (see §6). The facts below are a starting map, not a substitute for reading the code.
- `src/lib/sms/send.server.ts` — SEND-ONLY stub. `sendStubSms` / `sendStubSmsWithRetry({clientId, contactId, body})` — **NO `from` arg**; `SEND_MAX_ATTEMPTS=2`. **2 callers only:** `runner.server.ts:490`, `reply.functions.ts:41`. No `api.twilio.com`/`Messages.json` anywhere (all "twilio" hits are comments/labels).
- `src/lib/cron/runner.server.ts` — `RUNNER_VERSION = "v20260615-2"` (line 39); send call passes no `from` (line 490); status-swap comment ~532.
- `claim_due_enrollments` (migration `20260615211906_*.sql`) — round-robin per-client (`row_number() … PARTITION BY client_id`), `WHERE e.status='active' … AND c.status='active' AND c.deleted_at IS NULL` (archived filter), **NO sequence/campaign filter** (this is why pool enrollments must NOT live in the frozen `enrollments` table).
- `get_client_public(slug)` (migration `20260615202126_*.sql`) — `SECURITY DEFINER STABLE SET search_path=public`, 13-col projection, `template_vars - 'notification_email'` stripped, status filter in-body. **No `clients_public` view** (dropped in `20260614225655`). Anon has ZERO base grants on `clients` (direct anon SELECT = 42501).
- `enrollReactivation` / `reactivationUpload` (`src/lib/enroll/…`) — sequence_key="reactivation", caps 50/day + 2/20min; called ONLY by `admin.reactivation.tsx` (admin CSV upload). **No auto-trigger.**
- **NO inbound/voice route** under `src/routes/api/public/` (only chat/cron/discount/intake/r/*); **NO `X-Twilio-Signature` code anywhere.**
- `admin.settings.tsx` UI labels: "Messaging (Twilio)" / "Twilio number (E.164)" (cosmetic; 1f provider-neutral nicety).

### The 4 isolation guardrails (verified pre-freeze)
G1 RLS-audit gate (`audit_tenant_rls()` = 0). G2 per-client cron fairness (round-robin). G3 export-client (`export_client_bundle` + `archive_client`, in-RPC `is_admin` authz). G4 CORS resolver (client_id from Origin→allowed_origins, never request body).

---

## 6. Working discipline (non-negotiable — the user values these)
- **Validate against high-trust artifacts** (live DB introspection / real code / migration files), **NOT** Lovable's prose summaries. I've been burned twice marking things "RESOLVED" off summary checkmarks that didn't land.
- **Audit-first, measure before code** — surface spec-vs-reality with specifics/numbers before implementing.
- **Byte-parity mirror-line workflow** — for every doc edit, hand the user the **verbatim new text + exact placement** so they can byte-match their masters. Never just say "I updated X."
- **Keep verification scripts / build-log records** as regression artifacts; **build-logs are point-in-time history — don't rewrite them.**
- **Additive migrations only** on the backend; never modify the frozen master without re-validate + re-tag.
- **Catch doc drift** — surface contradictions; the spec/skills are single-source (fix the skill, don't patch around it).

### Environment notes
- `gh` CLI authed to MikeyMiami (full `repo` scope). Annotated tags need committer identity (`user.name=MikeyMiami`, `user.email=itsmikeymiami@gmail.com`).
- Intermittent classifier outage on the `Edit` tool this session (`claude-opus-4-8[1m] temporarily unavailable`) — retry the failed Edit individually; succeeds on retry.
- Memory index at `C:\Users\Pierc\.claude\projects\C--Windows-System32\memory\MEMORY.md` has related project facts.
