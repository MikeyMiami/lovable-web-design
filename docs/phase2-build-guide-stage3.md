# Phase 2 Build Guide — Stage 3 (Client-Facing Surfaces)

How to build the read/interaction surfaces — the agency admin tabs and the client mobile PWA — over the proven Stage-1/2 spine. **Surfaces-over-data:** Stage 2 built the logic that WRITES (enrollments, notifications, conversations, events); Stage 3 builds the UIs that READ and lightly interact with them. The data contracts are already proven, so most sub-steps are "render what exists" + a few write-back actions that reuse Stage-2 server functions.

> Lessons carried from Stages 1–2, baked in:
> - **One verifiable sub-step per turn**; build → validate (here + Claude Code) → next. Never "build all the tabs."
> - **Name the skill explicitly** each sub-step; reload (delete + re-import) the skill right before its sub-step.
> - **Reuse, don't rebuild:** write-back actions (enroll, send SMS, edit settings) must call the EXISTING Stage-2 server fns / enrollment paths — not new parallel logic. (The 2f chat widget proved this pattern: reuse `enroll()`, single dispatcher.)
> - **Public reachability ≠ registered route** (the 2b/2f lesson): admin + mobile are AUTH-GATED surfaces (logged-in agency/client users), the OPPOSITE of the public funnel — so verify they're correctly behind auth, and that RLS scopes every read to the active client (a logged-in client must see ONLY their own data).
> - **Validate against high-trust artifacts** (live DB rows the UI reads, the RLS that scopes them) not just "the page renders."
> - **Mobile-app reference was 'table/spec only' in Stage 2** (2c) — now it's the real UI build.

---

## Prerequisites
- Stage 1 (foundation) + Stage 2 (feature/automation layer) complete + validated. ✓
- Skills current in Lovable: re-import `admin-view` + `mobile-app` right before their sub-steps (both edited during Stage 2 — path rename, sending_subdomain, etc.).
- Still STUB send (1f deferred) — Conversations "reply" + Review-Request enroll write through the same stub/enroll paths; real Twilio is 1f.

---

## THE CRITICAL CROSS-CUTTING REQUIREMENT — tenant data isolation on read surfaces

Every admin/mobile read MUST be scoped to the logged-in user's client_id via RLS (the foundation's `user_client_ids()`/`is_admin()` policies). This is the #1 thing to validate at EVERY sub-step: a logged-in client_owner sees ONLY their own contacts/conversations/notifications/events; a platform-admin can see across clients (admin context). The data layer enforces this (RLS), but the UI must query AS the authed user (browser/authed-server-fn clients from 1d), NEVER via service-role. **Any read surface that uses the admin/service-role client to fetch tenant data is a cross-tenant leak — flag immediately.**

---

## STAGE 3 ORDER (mobile PWA first — it consumes the most Stage-2 output, then admin)

Rationale: the mobile app is the client's daily surface and consumes the action-flag notifications (day-10 auto-enroll, missed-call open-conversation) + the conversations the chat widget feeds — building it first proves those Stage-2 outputs are consumable. Admin is the agency's heavier config surface, built second.

### 3a — Mobile PWA shell + auth + Conversations tab (`/mobile-app` Tab 1)
The app at `app.theirdomain.com`. Auth-gated (client_owner/client_staff). Build the PWA shell + the Conversations inbox.
- PWA shell: 4-tab nav (Conversations / Review Request / Notifications / Dashboard), mobile-first, installable.
- Auth: logged-in client user; RLS scopes everything to their client_id.
- **Conversations (Tab 1):** SMS threads across this client's contacts, iMessage-style, newest first, status badges + relative time. Reply box → sends an outbound SMS in the thread (reuse the Stage-1e/2e send path — STUB until 1f; writes a `message` row + the conversation updates).
- Validate: auth gates the app; a logged-in client sees ONLY their conversations (RLS); reply writes a message via the existing send path (not a new one); threads render newest-first.
- **Gate:** logged-in client sees their threads only; reply lands a message row through the stub send path.

### 3b — Review Request tab + Notifications tab (`/mobile-app` Tabs 2 + 3)
The two tabs that WRITE back into Stage-2 (enrollment + the action-flag notifications).
- **Review Request (Tab 2):** First/Last/Phone/Email form → enroll into review_request drip. MUST reuse the 2d mobile-review enroll path (daily enrollment cap 50, re-enrollment guard by client_id+phone). Not a new enroll path.
- **Notifications (Tab 3):** feed of `notifications` rows for this client (no read/unread tracking). Render each with stacked-line formatting + `tel:` click-to-call. The two ACTIONABLE ones:
  - day-10 lead reminder → **Auto-Enroll button** (enrolls into review_request via the same guard; suppressed if already in review — the 2e suppression). Reads the `{auto_enroll:true}` action flag.
  - missed-call → **Open-conversation deeplink** (opens the Tab-1 thread for `related_contact_id`). Reads the `{open_conversation:true}` action flag.
- Validate: enroll reuses 2d path (caps/guard fire); notification feed renders all 12 types correctly; the two action buttons consume their action-jsonb flags + do the right thing; suppression holds.
- **Gate:** review enroll respects caps/guard; both action-flag notifications work end-to-end (auto-enroll enrolls, open-conversation deeplinks).

### 3c — Dashboard tab (`/mobile-app` Tab 4)
Read-only stat counters from `events`, client-tz.
- Four counters: New Website Leads (week/month) = contacts with source `web_form` in period; Review Link Clicks (week/month) = `review_clicked` events in period. Computed in client timezone.
- Validate: counts match a direct events query; week/month boundaries use client tz (the 1e tz-correctness lesson applies).
- **Gate:** counters match a hand-run events query for the period.

### 3d — Admin shell + Dashboard/Contacts/Conversations/Feedback tabs (`/admin-view`)
The agency surface (platform-admin / agency_owner context — can span clients via active-client selection). Read-heavy.
- Admin shell + active-client context. Dashboard (KPIs), Contacts (CRM list + detail), Conversations (full SMS inbox + threads), Feedback (low-star private submissions).
- Validate: admin can view the active client's data; switching active client re-scopes correctly; feedback shows review_feedback rows; no cross-client leakage beyond intended admin span.
- **Gate:** admin reads scope to active client; feedback/contacts/conversations render from the real tables.

### 3e — Admin Automations + Upload Customers tabs (`/admin-view`)
The two admin tabs that WRITE/configure.
- **Automations (`/admin/automations`):** edit message templates + sequence steps (the editable surface of automation-config content) — writes to `templates`/`sequences` (per-client overrides → client_id-scoped rows; never edits the global rows). Each drip shows a LIVE enrolled count (`enrollments WHERE status='active'` grouped by sequence_key). [BUILD — new]
- **Upload Customers (`/admin/reactivation`):** CSV/paste uploader feeding the reactivation drip — reuse the 2d reactivation enroll path (E.164 normalize → dedupe → enroll, caps 50/day + 2/20min). Shows reactivation enrollment count + queued-from-upload.
- Validate: template/sequence edits write client-scoped overrides (global rows untouched); enrolled counts are accurate; reactivation upload reuses the 2d path (caps/dedup fire). If any new tenant table/column → `audit_tenant_rls()`=0.
- **Gate:** per-client template override writes correctly (global seed untouched); reactivation upload reuses 2d path with caps.

### 3f — Settings tab (`/admin-view` Settings)
The per-client config surface — writes the `clients` row + `send_settings`.
- All the Settings fields: timezone, SMS send window, business hours (the separate lead-form window), daily send cap, daily enrollment cap, business identity, review config (place_id/link/threshold/google_review_toggle), template_vars (with missing-key surfacing), messaging config (twilio_number/messaging_service_sid/call_forwarding_number — non-secret per-client), notification recipient email, marketing domains/allowed_origins.
- **The single-source rule [LOCKED]:** twilio_number stored once on the clients row; everything reads from it. Changing it in Settings updates site + automations everywhere; never hardcoded.
- Validate: each field writes the right column; allowed_origins edits flow to the CORS allowlist; template_vars missing-key surfacing works; google_review_toggle modes (the 2-mode `review_gate_mode` enum: `gated` = use the funnel / `direct` = skip the rate page, straight to Google — there is NO "off"; suppress review prompts by not enrolling) wire to the funnel; editing twilio_number propagates (single-source).
- **Gate:** settings writes land on the right columns; allowed_origins drives CORS; single-source twilio_number holds.

---

## Stage 3 exit gate
All tabs render real data scoped correctly by RLS; all write-back actions reuse Stage-2 server fns (no parallel logic); tenant isolation verified on every read surface; action-flag notifications consumed correctly. Then **Stage 4 freezes the golden master = the automation LOGIC + schema + surfaces (the drift-prone stuff)** — that is what "frozen" protects. **1f (real Twilio swap + message testing + Turnstile/rate-limit) is the deliberate FINAL pre-launch hardening AFTER the freeze**, gated by `/launch-check` §E before any client goes live — NOT a freeze blocker. Post-freeze, the ONLY changes allowed to touch the backend are the 1f Twilio-swap + Turnstile/rate-limit (incl. the chat endpoints per F2); nothing else.

## Discipline reminders
- One sub-step per turn; build → validate → next.
- RLS-scoped reads via authed clients, NEVER service-role for tenant data on a read surface (cross-tenant leak check at every sub-step).
- Write-back actions REUSE Stage-2 paths (enroll, send, dispatcher) — never parallel logic.
- Stub send until 1f; Conversations reply + Review enroll use existing stub/enroll paths.
- `audit_tenant_rls()`=0 after any migration that adds a tenant table/column.
- Additive migrations only.
- Carry-forward flags land at their stages: F1 CHAT_TOKEN_SECRET (1f), F2 chat endpoints Turnstile/rate-limit (1f launch gate), F3 AI-chat email subject (email layer), F4/F5 byte-confirm + knowledge bundle (DB check / Stage 5 onboarding).
