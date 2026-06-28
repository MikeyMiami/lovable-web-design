# Phase C — C-3d (client-facing onboarding) + C-3c (finalize/invite) — READ-ONLY SCOPE

> Scope/plan only — **no code, no skill edits, no build prompts.** Grounded on live `cloud-spark-setup` `origin/main` @ `9319873` (verified via 3 read-only code investigations 2026-06-28). Design decisions locked this session are folded in. Awaiting sign-off on the open questions before any build.

## 0. The lifecycle we're building
```
C-3d (client-facing CAPTURE)                         C-3c (agency FINALIZE/INVITE)
agency "New Client" → one-time tokenized link  ─┐
   (or agency self-fills in the agency view)    │
client opens link → mode-aware wizard           │
client uploads logo/photos (via upload PROXY)   │
client submits (token consumed, single-use)     ▼
   → client row AUTO-CREATED status='pending'  ──►  agency notified (pending queue + badge)
                                                     agency reviews (pre-gen console + submission viewer)
                                                     agency clicks Finalize & Invite:
                                                        provisionClientOwner(Business Email)
                                                        status pending → active
                                                        Remix handoff checklist (slug / VITE_CLIENT_SLUG /
                                                          allowed_origins / site_style)
```
**Confirmed:** C-3c = "agency reviews a pending submission and invites"; C-3d = "client-facing capture that produces the pending submission." C-3c is the endpoint C-3d feeds.

---

## 1. Findings (verified against live code)

### 1a. One-time token (NET-NEW — there is no reusable one-time-submission token)
- Existing token = `tracked_links` (`token` PK, `client_id`, `contact_id`, `clicked_at`) — review-link tracking, **idempotent first-click only, NO single-use submission semantics**, and it's contact-scoped (wrong shape for onboarding). Migration `20260609163654…`; route `src/routes/api/public/r/$token.ts:28-46`.
- Chat token = stateless signed JWT (`src/lib/chat/token.server.ts`) — not DB-backed, not single-use.
- **Public-route pattern to reuse** (`src/routes/api/public/intake.ts`, `discount.ts`): `createFileRoute` + server handlers, **no auth middleware**, Turnstile (`src/lib/security/turnstile.server.ts` — fail-closed on explicit fail, fail-open on infra), DB rate-limit (`check_rate_limit` RPC, `src/lib/security/rate-limit.server.ts`), and **service-role writes via `supabaseAdmin`** (`src/integrations/supabase/client.server.ts`).
- **Tenant resolution difference:** intake/discount resolve `client_id` from `Origin`→`allowed_origins` (`src/lib/tenant-resolver.server.ts`). The onboarding submit has **no client yet** (created at submit) → identity/authorization comes from **the TOKEN itself**, not origin. The onboarding page is served by the app's own domain (same-origin), so cross-origin CORS isn't the concern it is for marketing-site intake.

### 1b. Pending-status model — reuse `clients.status` (NO new column; one verify-flag)
- `clients.status` = **text, values `'active'` | `'archived'`, default `'active'`** (migration `20260609034341…:65`). Filtered in exactly **3 allowlist places**, all `= 'active'`: `claim_due_enrollments` RPC, `get_client_public` RPC, `clients_anon_select` RLS policy.
- A new value `'pending'` is **automatically excluded** by all three (they allowlist `'active'`) → pending clients run **no automations** and are **invisible to anon/public**. Exactly what we want. **No filter changes required for safety** (just confirm none should *include* pending).
- `access_suspended` (payment gate — PWA shell only), `a2p_status` (SMS carrier brand state, unused), `deleted_at` (archival) — **none fit** "pending review/not invited." Confirmed.
- **`provisionClientOwner` works on a pending client** (it only checks existence + `deleted_at`, not status) — so invite-then-activate is clean.

### 1c. createClientFull is admin-gated → public submit needs its own creation path
- `createClientFull` (`src/lib/clients/onboarding.functions.ts:84`): `.middleware([requireSupabaseAuth])` + `assertAgencyAdmin`. **A public/unauthenticated caller CANNOT invoke it.** (Same for `updateClientSettings`, `provisionClientOwner`.)
- So the client submit path must be a **public route that does the creation itself via `supabaseAdmin`** (insert `clients` status='pending' + upsert `send_settings` + write the submission JSON) — i.e. replicate createClientFull's body. **Recommend extracting a shared `insertClientFull(core, { status })` helper** used by BOTH the admin `createClientFull` and the new public submit route (DRY; createClientFull's external contract unchanged).

### 1d. Agency pending queue + notify — reuse C-1, with one channel caveat
- Agency view (C-1): `src/routes/_authenticated/agency.tsx` (shell, 2-tab + count badge), `agency.index.tsx` (cross-tenant pending **tickets** via `is_admin()` RLS on the **authed browser client**, 15s poll), `agency.access.tsx` (payment toggle). **Security contract [LOCKED]: agency routes use the authed browser `supabase` (is_admin RLS), NEVER service-role.**
- A **pending-onboarding queue** = the same pattern: a new agency tab reading `clients WHERE status='pending'` via the admin's `is_admin` RLS branch + a count badge. (Verify the admin `clients` SELECT RLS isn't status-filtered so pending rows are readable by the agency — almost certainly is_admin-gated, not status-gated.)
- **Notify infra** (`src/lib/notifications/write.server.ts`, `src/lib/tickets/notify.server.ts`): in-app `notifications` row + an `events` `owner_email_stub` row; email recipient = `resolveOwnerEmail(clientId)` = the **client's** `notification_email`. **Caveat:** that infra notifies the CLIENT owner, not the AGENCY. For "notify ME (agency) of a pending submission," the in-app **agency pending-queue + badge** is the clean reuse; an email-to-agency would need a **platform/agency recipient** (not the client's email) — open question 3.

### 1e. Upload proxy — required; service-role server route (no policy change)
- `public-assets` storage policy: **read = anon+authenticated; write = authenticated AND `is_admin()`** (migration `20260614222357…:29-55`). A non-admin / unauthenticated client **cannot** write directly (`uploadSiteImage` in `src/lib/clients/site-image-upload.ts` would RLS-fail).
- **`supabaseAdmin` (service-role) bypasses RLS** → an upload proxy works with **no storage-policy change**. **No existing proxy** (the only service-role storage write is inside createClientFull).
- Design: a **token-gated public route** (e.g. `/api/public/onboarding/upload`) that validates the onboarding token, enforces MIME/size caps (10 MB images) + rate-limit, writes to `public-assets` under the token/draft namespace via `supabaseAdmin`, returns the public URL. The client wizard calls this **instead of** `uploadSiteImage` in client mode.

### 1f. Mode-aware wizard
- `onboard.tsx` lives at `/_authenticated/onboard` (admin-gated). Client-facing needs a **public route** rendering the SAME wizard in "client mode." → extract a shared `OnboardWizard` component used by two thin wrappers: the existing authed agency route (self-fill → `createClientFull`) and a NEW public `/onboard/$token` route (client mode → public submit route + upload proxy). Mode controls: success screen ("All Set! / email coming" vs agency confirmation), final button ("Submit" vs "Create Client"), the create path (authed fn vs token submit), and the upload path (direct vs proxy).

---

## 2. Schema / fn-contract flags (sign off before build)
| # | Item | Schema? | Notes |
|---|---|---|---|
| F1 | `clients.status = 'pending'` | **No new column.** ⚠️ VERIFY no CHECK/enum constraint on `status` (it reads as free text). If a CHECK/enum exists, adding the value is a 1-line additive migration. | The 3 `= 'active'` allowlist filters already exclude pending — no change needed for safety; confirm intent. |
| F2 | One-time onboarding token storage | **NEW TABLE (additive migration).** | Recommend `onboarding_tokens(token PK, draft_id, status, expires_at, claimed_at, client_id nullable, prefill jsonb?, created_by)`. **Not** contact-scoped (unlike tracked_links). `client_id` is NULL until submit (client created on claim). Single-use via idempotent `UPDATE … SET claimed_at=now() WHERE claimed_at IS NULL`. |
| F3 | Public submit creation path | **No schema; app-layer refactor.** | Extract `insertClientFull` helper shared by `createClientFull` (admin) + the new public submit route (service-role, forces `status='pending'`). createClientFull's external signature unchanged. |
| F4 | Upload proxy | **No schema, no storage-policy change.** | service-role write to `public-assets`; new public route. |
| F5 | Agency pending-onboarding notification type | **No schema** (notifications table exists). | New notification `type` key + template (`onboarding_pending_review`). Email-to-agency = open Q3. |
| F6 | provisionClientOwner at finalize | **No change** — reused as-is (takes email + clientId). | C-3c may add a thin wrapper that also flips `status` pending→active + records the handoff. |

**Net:** the only true schema touches are **F2 (new tokens table, additive)** and **possibly F1** (only if `status` has a constraint). Everything else is app-layer.

---

## 3. File / skill / doc impact (enumeration only — nothing edited)

### Code (`cloud-spark-setup`)
- `src/routes/_authenticated/onboard.tsx` — refactor to a shared wizard + agency-mode wrapper; mode-awareness.
- NEW `src/components/onboard/OnboardWizard.tsx` (if extracted) — the shared stepper.
- `src/components/onboard/ReviewSummary.tsx` — mode-aware intro/labels (Submit vs Create).
- NEW public route `src/routes/onboard.$token.tsx` — client-mode wizard wrapper (token-gated).
- NEW public API `src/routes/api/public/onboarding/submit.ts` — validate token → service-role create pending client (+ send_settings + submission JSON) → notify → consume token.
- NEW public API `src/routes/api/public/onboarding/upload.ts` — token-gated upload proxy → `public-assets` via service-role.
- `src/lib/clients/onboarding.functions.ts` — extract `insertClientFull` helper; NEW admin server-fn `generateOnboardingLink` (creates `onboarding_tokens` row, returns URL).
- `src/lib/auth/provisioning.functions.ts` — reused; optional finalize wrapper (invite + status flip).
- Agency view: `src/routes/_authenticated/agency.tsx` (add "New Client / generate link" + a Pending-onboarding tab + badge) + NEW `src/routes/_authenticated/agency.onboarding.tsx` (pending queue, routes into the per-client review).
- Per-client admin review: the existing `admin-view` [BUILD] **pre-gen console** + **immutable submission viewer** + a **Finalize & Invite** action + Remix handoff checklist (C-3c).
- `src/lib/notifications/…` — new `onboarding_pending_review` notification type + template.
- Migration(s): `onboarding_tokens` table (F2); status constraint only if F1 needs it.

### Skills (`lovable-web-design`)
- `onboard-from-form` — add client-facing mode, one-time link, pending-create lifecycle, upload proxy; (+ the already-pending GBP-link & discount-move edits).
- `agency-view` — add "New Client / generate one-time link," the Pending-onboarding queue + badge + notify, and the route-into-review.
- `admin-view` — make the pre-gen console + immutable submission viewer + **Finalize & Invite** + Remix handoff checklist concrete (they're existing [BUILD] items).
- `new-client-site` — the wizard→Remix handoff checklist (C-3c) orchestration.
- `scratch-foundation` — record the `onboarding_tokens` model + the `status='pending'` lifecycle.
- `platform-spec-source-of-truth` — reflect client-facing onboarding + pending lifecycle.
- `website-structure` — likely NO change (the proxy produces the same `site_assets` URLs); note only.

### Docs
- Future: a C-3c build-spec + a C-3d build-spec (after sign-off). `pathway-to-completion.md` roadmap update. Build-log entries per slice.

---

## 4. Slicing recommendation

**Build C-3c FIRST, then C-3d** (C-3d feeds C-3c; C-3c can be validated immediately with agency-self-filled/seeded pending rows).

### C-3c — agency finalize/invite (smaller; builds on existing pieces)
- **C-3c-1 — Finalize & Invite + Remix handoff:** on the per-client review surface, a "Finalize & Invite" action → `provisionClientOwner(notification/business email, clientId)` + (if pending) flip `status`→`active` + show the Remix handoff checklist (slug / `VITE_CLIENT_SLUG` / `allowed_origins` / matched `site_style`). Works on TODAY's agency-created clients.
- **C-3c-2 — Pending model + review queue:** add `status='pending'` (F1), the pre-gen console + immutable submission viewer (admin-view [BUILD]), and the agency **Pending-onboarding queue + badge** (reuse C-1). Validate with a seeded pending row.

### C-3d — client-facing capture (bigger; net-new public surface)
- **C-3d-1 — Token + generate-link + public wizard shell:** `onboarding_tokens` (F2), admin `generateOnboardingLink`, public `/onboard/$token` route rendering the mode-aware wizard, token validate/expire/single-use.
- **C-3d-2 — Upload proxy:** the token-gated `public-assets` service-role upload route; wizard uses it in client mode.
- **C-3d-3 — Public submit → pending create → notify:** the public submit route (shared `insertClientFull`, status='pending'), token consume, agency notification; mode-aware success screen.

Each slice = its own build prompt + SQL/UI validation + build-log, same discipline as R-1/R-2/R-3.

---

## 5. Open design questions (decide before build)
1. **Unified lifecycle?** Should agency **self-fill** ALSO create `status='pending'` (then go through the same review→invite), or keep creating `active` directly (only client-submit creates pending)? *(Unifying = one lifecycle, cleaner; means createClientFull/self-fill sets pending too.)*
2. **Token model linkage** *(locked decision implies this — confirm):* client row is created **at submit** (token pre-creation = a draft namespace for uploads; `onboarding_tokens.client_id` NULL until claim). Confirm vs the alternative (create a pending row at link-generation time and the link fills it).
3. **Agency notification channel:** in-app Pending queue + badge only (recommended, reuses C-1), or **also** an email to the agency? Email needs a **platform/agency recipient** (the existing owner-email infra is client-scoped — it'd email the client, not you).
4. **Review surface location:** pending queue (agency) **routes into the per-client `/admin` pre-gen console + submission viewer** (like C-1 routes into admin tickets) — confirm that's where review+Finalize&Invite lives (vs a dedicated agency review screen).
5. **Button/label text** ("Create Client"→"Submit", "Review & Create"→"Review & Submit", ReviewSummary intro): fold into C-3d as **mode-aware** (recommended — agency mode may keep "Create"), or do as a trivial standalone now (would apply one wording to both modes).
6. **Self-fill invite timing:** confirm invite is **manual** (agency clicks Finalize & Invite in review), never auto on create — matches the locked "I review → I invite/activate."

---
**Read-only scope. No code/skills edited, no build prompts written, nothing committed. The only schema touches are the additive `onboarding_tokens` table (F2) and possibly a `status` constraint (F1) — flagged for sign-off. Discount + review-link skill mirrors + doc commits remain HELD pending your SQL validation results.**
