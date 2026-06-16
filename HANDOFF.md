# HANDOFF — session context for a fresh Claude Code instance

> **Point a new instance here:** "Read `HANDOFF.md` to know what we're doing." This is the single go-to context file. Last updated **2026-06-16**.

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
- **Freeze model:** the automation **LOGIC + schema + surfaces** (drift-prone) are locked. The carve-out is the **FULL Stage-1f scope** (post-freeze, NOT freeze blockers).
- **Stage 1f = the deliberate FINAL pre-launch hardening** — the ONLY changes allowed to touch the frozen backend:
  1. **Real messaging-provider swap** (provider = **TextGrid**, a Twilio-API clone) — send-primitive internals + status-swap (`stub` → real SID/delivery).
  2. **NET-NEW inbound webhook layer** (`X-TextGrid-Signature` HMAC-SHA1) — inbound SMS→CRM, real-time reply-driven drip exits, missed-call. **This does NOT exist in the frozen master — built fresh at 1f** (verified against the repo; the old spec's "Inbound SMS→CRM [built]" was inaccurate).
  3. **LIVE Turnstile + rate-limiting** on public lead-intake routes.
  4. Additive per-client provider columns: `provider_subaccount_sid`, `provider_webhook_secret`, `a2p_brand_id`, `a2p_campaign_id`, `a2p_status`.
- **1f has NOT started yet.** "On to 1f when Mikey starts it."

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

**Commits this session (planning repo `lovable-web-design`):**
- `8394680` — the 1f-prep review record.
- `02b02e6` — provider-neutral reconciles + reactivation deprecation across spec, LAUNCH.md, launch-check, onboard-from-form, new-client-site, features.
- `fffb21f` — **self-review fix:** §9.D had residual stale items (header/auth/webhooks/A2P bullets) still in the old "Twilio Option 1 / one shared A2P campaign / parent-level webhooks" model, contradicting the per-client model written above them. Reconciled.

All mirror lines for `02b02e6` + `fffb21f` were handed to the user (they've mirrored `02b02e6`; **`fffb21f` §9.D mirror lines were the most recent hand-off**).

---

## 4. OPEN ITEMS / next steps
1. **`fffb21f` mirror lines** — confirm the user has mirrored the §9.D fix (5 items: header line 604, secrets/outbound/inbound bullets 606–608, A2P bullet 611).
2. **Remaining stale "Twilio"/"X-Twilio-Signature"/"Twilio Option 1" references** found on the repo-wide sweep — decide per-file:
   - **ACTIVE authoritative docs (SHOULD reconcile — was outside the agreed batch, ask the user):**
     - `skills/scratch-foundation/SKILL.md:99` — inbound route names `/api/public/twilio/...` + `X-Twilio-Signature` + parent-level webhooks.
     - `docs/workspace-knowledge-condensed.md:47` — "Twilio Option 1 … X-Twilio-Signature" (this feeds Lovable Workspace Knowledge, always-on — high impact).
     - `docs/platform-spec-source-of-truth.md` §12 net-state lines **690, 694, 707, 709** — "Twilio Option 1", "real Twilio swap".
     - `LAUNCH.md:45` — Stage-1 build-order says "→ Twilio Option 1".
     - `docs/phase2-build-guide-stage0-1.md:61,63` — "1f. Twilio Option 1 wiring", X-Twilio-Signature.
   - **HISTORICAL build-logs / build-guides (LEAVE AS-IS — point-in-time record; rewriting = falsifying history, against the keep-records rule):** `docs/build-log/stage-4-freeze.md`, `stage-3.5d-*`, `stage-3c-*`, `stage-1e-*`, `docs/phase2-build-guide-stage2.md`, `stage3.md`. These correctly say "real Twilio is 1f" for when they were written. At most add a forward-note; do not rewrite.
3. **A2P `vertical`/industry field GAP** — per-client Brand registration needs a `vertical`; no explicit onboarding field exists. Derive from the client's niche/`search_term` or add a field. Flagged in `onboard-from-form` build-notes.
4. **3 user-draft files (in the user's "outputs", NOT in this repo — I provide text, I don't edit them):**
   - `textgrid-provider` SKILL + TextGrid impact map — fold Corrections 1+2 (inbound = NET-NEW) + state `from` is caller-passed / primitive stays SEND-ONLY.
   - `reactivation-number-pool-spec` — add the "supersedes the deprecated per-client reactivation" header note.
5. **When 1f starts:** build the 1f scope (§2) + the reactivation pool as net-new agency layer (§3). Re-validate + **re-tag** the frozen master after each backend-touching 1f change (post-freeze contract: only 1f hardening + re-validated bug-fixes may touch it).

---

## 5. Key facts about the real frozen code (`C:\Users\Pierc\Desktop\cloud-spark-setup`)
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
