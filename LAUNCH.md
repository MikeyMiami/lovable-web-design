# LAUNCH.md — Master Build Document

The operating manual for building the golden-master backend and launching clients. Read this first. It points at the skills + spec as the authoritative source — **the skills win; if a skill is wrong, fix the skill (single-source), don't patch around it.**

Source of truth: `docs/platform-spec-source-of-truth.md` (the spec) + `skills/*/SKILL.md` (the 11 skills). This doc is the *process*; the skills are the *content*.

---

## 0. Architecture in one paragraph
ONE shared multi-tenant backend (the "golden master"), built once and frozen — all clients live in it, scoped by `client_id` + RLS. Per-client launch = a client row + config on the shared backend, plus a Remixed marketing site (frontend-only) pointed at the shared backend. Business logic is never regenerated per client (that's the anti-drift core). See spec §0.

## 1. Project structure (set up once)
- **Project 1** — shared backend + agency/admin dashboard + per-client tenant app (`app.theirdomain.com`). Owns the database. Once it generates code, have Lovable **create its own GitHub repo** (+ menu → GitHub → Create Repository) so the golden-master CODE is owned + version-controlled. NOTE: Lovable cannot connect to a pre-existing repo — the planning repo (`MikeyMiami/lovable-web-design`, holding spec + skills + these docs) stays SEPARATE as the source-of-truth library; Lovable's new repo holds the built app code. (Optionally copy `skills/`+`docs/` into the Lovable repo later so they ride alongside the code.)
- **Project 2** — lean marketing-site template (presentational only; no admin/backend code).
- **Per-client marketing sites** — Remix Project 2, customize design, point `.env` (`VITE_SUPABASE_URL` + anon key + `project_id`) at Project 1's Supabase.
- **Subdomain routing (locked):** tenant app `app.theirdomain.com`, marketing root `theirdomain.com`.

## 2. How to feed the build to Lovable (the workflow)
Confirmed with Lovable:
- **Skills are imported as Lovable Skills** (one-time snapshots, surfaced through the skills system). Lovable CANNOT live-read files from an external repo by path. So: **re-upload (delete + re-import) a skill right before you build with it**, to ensure Lovable has the current version. Just-in-time, one skill at a time — not all 11 constantly. The spec goes in **Workspace Knowledge** (always-on).
- **Feed ONE layer at a time** — build → validate → next. Never paste all skills at once. Migrations approve one-at-a-time and `types.ts` regenerates after each, so building against unapproved schema produces stale types.
- **Keep each pasted/feed chunk focused.** If a skill is large, split by sub-layer (schema → RLS → server fns → cron), exactly as the Stage 0–1 runbook does.
- **Plan then Build:** a short Plan-mode confirm before each non-trivial Build turn (schema/RLS/cron); skip planning for pure code edits.

## 3. The report-back + validation loop (every step)
After each build step, get Lovable to report what it built, then validate it here + with Claude Code BEFORE the next step.

**Ask Lovable explicitly** (this is the standard report-back request — also baked into each skill's footer):
> "After building, list every table/column/policy/index/route/server-fn you created or changed, and quote the SQL of any new RLS policies."

**Validation artifacts, highest→lowest trust** (validate against these, not the prose):
1. **Migration file** `supabase/migrations/<ts>_*.sql` — source of truth for schema/RLS/functions. Diff against the skill.
2. **Live DB query** — ask Lovable to run `information_schema` / `pg_policies` / `pg_indexes` reads. Highest-trust confirmation of what Postgres actually accepted.
3. **`src/integrations/supabase/types.ts`** — regenerated post-migration.
4. **Route / server-fn files** — read directly.
5. **Lovable's prose summary** — lowest trust; verify against 1–4.

**The loop:** Lovable builds a step → produces the report-back + migration/query → paste it here + to Claude Code → validate against the skill → **approve, or request a targeted correction** ("only change X, don't touch Y/Z"; migrations are append-only — corrections are new migrations, never edits to approved ones) → next step.

## 4. Build order (the stages)
Detailed sub-steps for Stage 0–1 are in `docs/phase2-build-guide-stage0-1.md`. High-level sequence:

**Stage 0 — Wiring** (setup, not skill-feeds): stable backend domain; enable pg_cron + pg_net; create the two storage buckets; set runtime secrets (CRON_SECRET, parent Twilio auth token, Turnstile secret). Resolve the two ❓ confirm-in-Lovable items (email from-domain/ESP; native-AI invocation) before those specific build steps.

**Stage 1 — Foundation** (`/scratch-foundation`, in sub-steps 1a–1f): schema + enum ALTER TYPEs + migrations → helpers + RLS + indexes + the RLS-audit gate → three Supabase clients + auth/roles → server-fn + CORS skeleton (+ CORS resolver) → cron drip-runner (+ per-client fairness) → Twilio Option 1. Gate: `/launch-check` A + B + D green (covers all 4 isolation guardrails).

**Stage 2 — Feature/automation layer** (in dependency order): `/features` → `/automation-config` (seed templates + sequences) → `/opt-in-forms` → `/chat-widget`. Gate: `/launch-check` C per feature. (Operative build order is **infrastructure-first** — `/automation-config` *seeding* precedes `/features` *wiring*, since drips can't run until sequences/templates are seeded; see `docs/phase2-build-guide-stage2.md` for the sub-step sequence.)

**Stage 3 — Client-facing surfaces:** `/admin-view` + `/mobile-app` (both shared-backend, authed). Includes the **3c Conversations-materialization** sub-step (runner → `messages`/`conversations` + shared `insertOutboundMessage` helper, stub status) that completes the inbox.

**Stage 3.5 — Pre-freeze cleanup** (after the Stage-3 tabs, before the freeze): batch the deferred non-Twilio items so the frozen master is complete — **audit_log** table (role-mutation audit), **export-client** server fn (isolation guardrail 3), and the **3a send-primitive regression re-test** (re-run 2e TEST1–TEST5 + confirm the primitive is send-only). All gated within `/launch-check` A–D.

**Stage 4 — Freeze the golden master:** `/launch-check` A–D green **for the frozen-LOGIC rows** → the backend is the proven, frozen master. **Freeze = the automation LOGIC + schema + surfaces (the drift-prone stuff) are locked.** **The carve-out is the FULL 1f scope (deferred to 1f, post-freeze — NOT freeze blockers), not just the §A Turnstile row:** §A Turnstile/rate-limit + parent Twilio auth token; §B real-Twilio 5xx/4xx branch (the 2× retry loop IS frozen); §C one-year real-time reply-exit + missed-call voice-webhook trigger + owner-email actual send (the drip *logic* is frozen — these triggers/sends are 1f); §D **nearly all** — real Twilio account/From/SID, status-swap, render-completeness guard, inbound+voice webhooks, real-time reply-driven exits, per-client number/forwarding/GBP (§D is the 1f/launch stage, not a freeze gate). Confirm the GitHub repo holds the built code; tag `golden-master-v1` on both repos.

**Stage 1f — Final pre-launch hardening (AFTER freeze):** the genuinely Twilio-dependent items only — real Twilio swap + message testing, LIVE Turnstile/rate-limit, real-time reply-driven drip exits (inbound webhook), and the outbound-message status-swap (stub status → real Twilio SID/delivery; the materialization + helper already exist from 3c). The ONLY changes permitted to touch the frozen backend; gated by `/launch-check` §E before any client goes live.

**Stage 5+ — Per-client launch** (repeatable, per client): see §5.

## 5. Per-client launch (after the master is frozen) — `/new-client-site`
Per client, NOT a backend rebuild:
1. Provision on the shared backend: client row + `send_settings` + sequences (or inherit globals) + `user_roles` + `allowed_origins` + Twilio number/SID (`/onboard-from-form` captures §9b data).
2. Telephony: provision the number under the parent Twilio account; forward to `call_forwarding_number`; place on site/GBP.
3. Remix Project 2 (marketing template) for the client's domain; point `.env` at the shared backend; customize design (`/website-structure`).
4. Verify: `/launch-check` section E (per-client go-live) + an end-to-end smoke test (submit a live lead → contact created → drip enrolls → SMS sends → owner notified).

## 6. Discipline (non-negotiable)
- **Single-source:** the spec + skills are authoritative. If Lovable proposes something that contradicts a skill, the skill wins. If the skill is actually wrong, fix the skill first (and mirror it in the repo), then re-feed.
- **Build then test in separate turns** — never combine a big migration + its verification in one prompt.
- **Patience on the master:** it's built once and every client rides on it. Let each verify-gate actually pass before moving on.
- **Additive migrations only:** never drop columns; deprecate with nullable+default. A bad additive migration is reversible in minutes.
- **The validation loop is the safety net** — every step validated against migration/DB artifacts before the next. This is the same three-way loop (spec author ↔ Claude Code ↔ Lovable) that produced the spec, now applied to the build.
