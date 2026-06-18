# Pathway to Completion — reconciled game plan

> **Status:** planning artifact, approved 2026-06-18. Repo `main` @ `c3b18ba`; frozen backend `cloud-spark-setup` @ `golden-master-v1.6` (`c491623`). Milestone reached: the first style template (**Professional Modern**, Landscaping demo) is BUILT in Lovable + audited clean (compliance verbatim + straight quotes, exact wire payloads, asymmetric consent, allowed-set labels, no niche/token leaks, demo renders + forms no-op; wiring isolated to ~8 `[LOCKED]`-commented files).
>
> This doc holds the ENTIRE remaining roadmap to launch + post-launch testing, reconciled against the skills, `docs/platform-spec-source-of-truth.md`, the frozen backend, and the held backlog. Work the phases against it.

---

## 0. The three framing facts (read first)

1. **The long pole is TextGrid verification — START IT NOW, in parallel.** A2P registration, pg_cron scheduling, the live flip, AND real SMS testing (Phase D + most of E) are ALL gated on TextGrid account verification. It's external and can't be rushed (+ each per-client A2P Brand/Campaign vets independently, ~2–4 days). **Everything else — templates, mobile app, admin/agency UI, the onboarding wizard, the v1.7 backend — builds while it clears.** If you serialize TextGrid last, that becomes weeks of idle gate.
2. **The backend opens ONCE, additively → `golden-master-v1.7`. This is NOT a destructive unfreeze.** It's the identical additive + re-validate + re-tag contract 1f used five times (`v1.2→v1.6`): new tables/columns/RLS/storage/routes, zero ALTER of existing object logic. See §3.
3. **AUTH IS DO-FIRST.** Client auth/login provisioning + the `audit_log` table come *before* the mobile-app features are meaningfully buildable/testable — there's no point shipping a client-facing PWA + ticketing + payment-gate if no client can log in to exercise them. See §1 Phase B-0.

**Critical path:** `TextGrid verification → per-client A2P approval (~2–4 days) → live flip`. Build A, B, C, and the onboarding wizard in parallel so they're *done and waiting* when TextGrid clears.

---

## 1. Reconciled phases (dependencies in **bold**)

### Phase A — Style-template library *(frontend-only; no backend; run now, fully parallel)*
- Polish + freeze **Professional Modern** as the remixable master (GitHub-connect = its backup/rollback).
- Build the other 5 by re-filling `docs/template-build-prompt-TEMPLATE.md` per style: **Corporate, Modern Tech, Artistic Unique, Family Owned / Local Business, Owner Operated / Local Business**.
- Close **D-3** (full required-`template_vars` enumeration in the master demo bullet) + **E-1** (seeded-segment fill note) **before styles 2–6** — tiny, but they stop each new build re-guessing the contract.
- Add the **Landscaping niche-library row** to `a2p-site-compliance` only when onboarding a real landscaper (the demo correctly used DEFAULT).
- **Dependency:** none. This is the keep-momentum-while-TextGrid-verifies track.

### Phase B-0 — AUTH + audit (DO-FIRST launch-readiness) *(precedes the mobile-app features)*
- **Client auth/login provisioning flow.** Mechanism is specced (`user_roles` enum `app_role`: admin|client|agency_owner|client_owner|client_staff; write the role on signup/invite with the right `client_id`; helpers gate the app/admin) but **the invite/credential flow is not built**. Build: create the auth user + grant `client_owner` (+ `client_staff`) for their `client_id`, and how the client receives credentials. You (agency) = `admin`/`agency_owner`; the client = `client_owner`/`client_staff`.
- **`audit_log` table** — `[BUILD — TODO]` in the spec; must land **before any real `admin` OR `agency_owner` is granted** (i.e. before you or any real client gets a role). `user_roles` AFTER-trigger is the sole writer (catches direct-SQL grants too). Built in the **v1.7 pass** (§3) but *gating-wise it's do-first*.
- **Dependency:** Supabase Auth (exists). **This gates Phase B's testability.**

### Phase B — Mobile-app uniform design + two two-sided features + the payment gate
- **One multi-tenant PWA** at `app.theirdomain.com`, RLS-scoped per logged-in client. **One design for all clients; only branding is per-client** (logo + `brand_color`/`brand_secondary`/`brand_tertiary`), flowing dynamically. Promote the mobile-app **per-client-branding `[BACKLOG]` → `[BUILD]`**.
- **App icon = PWA dynamic per-host manifest:** each `app.theirdomain.com` serves a manifest with that client's logo/name/colors → per-client install branding from ONE codebase, **no app-store submissions**. **Native iOS/Android store apps = deferred decision** (only then does the per-client-build-vs-single-app question bite).
- **Feature A — "Request an Edit" tab:** client types a detailed change request + uploads assets (photos/docs/videos) → mirrors into that client's **admin view** (you see the request + download assets) → **agency view** flags a new request + lists PENDING edit-requests across ALL clients. Workflow: agency flag → open that client's admin view → edit-requests section → review + download → **approve or deny WITH a description** (returned to the client in-app). **No automated re-deploy** — "approve" = notification + status change + *you manually implement the edit in the remix*.
- **Feature B — "Support" tab:** client sends a support message → **agency view** lists pending support → you review → mark status (in progress / resolved) → reply delivered **in-app** → client can reply → threaded until you mark **resolved** (CLOSES the instance). Status reflects in that client's admin view; resolved instances stored in a **"support history"** section there.
  - **Ticket threads = polling** (reuse the existing 15s/10s cadence); **realtime = post-launch backlog**.
  - **Support notifications = in-app + owner-email on reply** (reuse the existing platform owner-email infra) — don't rely on the client happening to open the app.
- **Payment-access gate** — see §4 (the new feature).
- **Dependency:** **the v1.7 additive backend (§3)** for both ticketing features + the gate; **Phase B-0 auth** for testability.

### Phase C — Admin-view + agency-view + the onboarding wizard *(Project-1 admin builds)*
- **The onboarding wizard itself (the big missing build).** `createClient` accepts only slug/business_name/phone_display/email; `onboard-from-form` defines the field→destination mapping but **the capture UI does not exist** (the skill overstates it as "Stage 3 built"). This is the **linchpin of Phase E** — build the wizard + extend `updateClientSettings` to cover all §9b fields.
- **Existing admin `[BUILD]`:** logo upload UX + preview/download, brand-color editor, pre-gen console, A2P-prep panel, immutable submission record.
- **Agency-view — NEW skill** (cross-tenant dashboards are conceptually distinct from a single client's admin-view): pending-edit-requests across all clients, pending-support across all clients, new-request flagging, **payment-access toggle + suspension status across clients**, routing-to-client.
- **Admin-view additions:** edit-requests section + support section + support history (per client).
- **Hard prerequisites for onboarding a real client** (vs nice-to-have): the onboarding wizard (capture) + logo upload + `allowed_origins` editor + messaging/A2P config fields. Pre-gen console + A2P-prep panel are strongly wanted before A2P submission but data can be set via SQL/settings interim.
- **Dependency:** data destinations exist (clients/template_vars/buckets). Agency dashboards for the B features depend on the **v1.7 ticketing tables**.

### Phase D — 1f gated items *(blocked on TextGrid verification)*
- **Gated list:** (1) real outbound TextGrid swap → live SMS; (2) net-new inbound webhooks live; (3) **A2P registration flow** (subaccount→Brand→Campaign→number — the last build piece); (4) Turnstile/rate-limit **live keys**; (5) **pg_cron scheduling LAST** (schedules `/cron/sequences` + `/cron/reactivation`); (6) the **live flip** (`SMS_MODE=live`) + the **8-gate LIVE-flip checklist** (HANDOFF §2: parent-on-subaccount auth, form-encoding, HMAC URL-exactness, etc.).
- **Interaction with B:** the new ticketing tables/storage + the payment-gate flag are **authed surfaces, disjoint** from the A2P flow / scheduling / live flip — no interaction. **Only sequencing tie:** do the A2P additive columns in the **same v1.7 pass** as B-backend so you re-validate/re-tag once.
- **Dependency:** TextGrid verification. pg_cron + live flip are the *very last* steps before real traffic.

### Phase E — Real-world testing & onboarding validation *(the proof phase)*
- **Testing ORDER (what must be green before real traffic):**
  1. Auth/login provisioning works (you + a test client log into admin + the PWA).
  2. Onboarding wizard writes a complete `clients` row + `template_vars` + assets.
  3. Remix renders that client's real data (set `VITE_CLIENT_SLUG`, domain connected, `allowed_origins` set, **real Turnstile keys + hostname**).
  4. `?ping=1` confirms the live runner bundle is the validated one.
  5. One manual cron tick → drip renders **real templates** (not `[stub]`) → **real SMS send via TextGrid**.
  6. Inbound reply → opt-out capture → drip exit.
  7. Reactivation pool end-to-end.
  8. A2P **Brand+Campaign approved** for that client.
  9. Only then **schedule pg_cron + flip live**.
- **What stub/frontend testing did NOT catch (Phase E surfaces it):** live TextGrid auth (parent-on-subaccount 401 risk), form-encoding/content-type, inbound HMAC URL-exactness, **real Turnstile** (test key always-passes), CORS with the real domain, A2P carrier approval of the actual site, **consent persistence** actually writing records, owner-email deliverability, and **client login provisioning**.
- **Artifact:** a documented, repeatable **onboarding + remix + go-live test checklist** (new doc) = the per-client runbook.
- **Dependency:** Phase A (a template), C (onboarding wizard + admin), D (live SMS), B-0 (auth), + the non-code prereqs (§5).

---

## 2. Build-order summary (the parallelism)

```
NOW ──► TextGrid verification (external, long pole) ───────────────────────────────►  per-client A2P approval ─► LIVE FLIP
        │
        ├─ Phase A  (templates) ───────────────────────────────────────────────► done & frozen, waiting
        ├─ Phase B-0 (AUTH + audit_log)  ─► gates ─►  Phase B (mobile app + features + gate)
        ├─ Phase B-backend  (one additive pass → v1.7) ─► unblocks B features + gate + D's A2P columns
        ├─ Phase C  (admin + agency-view + ONBOARDING WIZARD) ──────────────────► done, waiting
        └─ Non-code prereqs (legal, domains, sender domain, billing-by-hand) ───► done, waiting
                                                                                    │
                                                                    Phase E (integration proof) ◄── needs A+B-0+C+D + prereqs
```

---

## 3. Backend-freeze decision — ADDITIVE-ONLY → `golden-master-v1.7` *(one batched pass)*

**Recommendation (approved): additive-only, one open/one tag. Not a destructive unfreeze.** Same contract as 1f (`v1.2→v1.6`): new objects only, zero ALTER of existing logic; re-run the **4 isolation guardrails** (esp. `audit_tenant_rls()=0`) → tag **`v1.7`**.

**Batch ALL pending additive backend into this single pass:**
| Item | New objects |
|---|---|
| Ticketing (Features A+B) | `edit_requests`, `support_tickets`, `ticket_messages`, `ticket_attachments` tables + RLS + status enums |
| Upload storage | dedicated `edit-request-uploads` bucket (RLS, `client_id`-scoped paths) |
| `audit_log` | table + `user_roles` AFTER-trigger (sole writer) — gates real role grants |
| Consent persistence | a consent-storage column/field so the Privacy Policy's "timestamped opt-in records" claim is true — **before first real A2P submission** |
| Payment-access gate | `clients.access_suspended boolean DEFAULT false` (§4) |
| 1f A2P additive columns | `a2p_brand_id`/`a2p_campaign_id`/`a2p_status` (+ any per-client provider cols not yet present) |

**Rejected:** touching existing objects (no reason; reintroduces drift) and a separate backend project (breaks single-shared-backend + RLS/auth sharing).

**Authed-surface note:** ticketing + gate are **authed + RLS-scoped per client**, not public — they don't ride the public `rate_limit_hits` limiter. They DO need upload size/type limits + an authed-surface abuse guard (design left open, §6).

---

## 4. NEW FEATURE — Payment-access gate *(built in v1.7 + agency-view + the app/admin shells)*

**Purpose:** revoke a client's access to their **mobile app AND admin view** when they haven't paid their monthly. An **access switch, not a billing system** — works with invoice-by-hand (you decide who's suspended) and is forward-compatible with built billing later (a future Stripe webhook can flip the same flag).

**Mechanism:**
- **(a) Flag + gating [v1.7 backend]:** `clients.access_suspended boolean DEFAULT false`. **NOT projected by `get_client_public`** (internal/agency field; the public site must not read or be gated by it). The authed app/admin read it from the RLS-scoped `clients` row.
- **(b) Gate UI [mobile-app shell + admin-view shell]:** when `access_suspended = true`, the shell **intercepts render** and shows a single full-screen message instead of all normal content/tabs:
  > "There was an issue with your payment method. Please correct to regain access to your mobile app."
  Flip it back to `false` → full access returns immediately.
- **(c) Agency control [agency-view]:** toggle a client's `access_suspended` (manual, since billing is by-hand) + see suspension status across all clients. **Log every toggle** (who suspended/restored whom) via `audit_log`/`events`.

**Confirmed behaviors [LOCKED in this plan]:**
- ✅ **Suspension does NOT stop backend automations.** The runner/drips/review/reactivation/A2P key off `status='active' AND deleted_at IS NULL` — NOT `access_suspended`. A suspended client's SMS automations keep running. (Reason: non-payment ≠ stop their customer-facing service mid-cycle; it gates *their* dashboard access, the lever that motivates payment, without harming their end customers or carrier standing.)
- ✅ **Suspension gates ONLY login-facing surfaces** (the authed PWA + admin). The **public marketing site is unaffected** (anon `get_client_public`, no flag read).
- ✅ **Distinct from `archive_client`:** suspension = temporary, reversible access hold, automations LIVE, `status` unchanged; archive (existing soft-offboard) = `status='archived'+deleted_at`, drips STOP, data persists (export bundle is the portability artifact). Two separate states — the doc names both.

**Design note (not a blocker):** the shell gate is a **UX access hold**, not a data-security boundary (the client's data is already RLS-theirs). If you later want hard server-side denial (so they can't `curl` their own data while suspended), add an `access_suspended` check in the authed data server-fns. v1 shell-gate is sufficient for "deny the app experience."

---

## 5. Skill-update surface (the documentation work, by phase)

| Phase | Skill / doc | What gets added |
|---|---|---|
| A | `docs/template-build-prompt-TEMPLATE.md` | D-3 (full template_vars enumeration), E-1 (seeded-segment note) |
| A | `a2p-site-compliance` | Landscaping niche-library row (at real-landscaper onboarding) |
| B-0 | `scratch-foundation`, a `1d`/auth doc | client login provisioning flow; `audit_log` table + trigger (already designed in spec — Option 3) |
| B | `mobile-app` | per-client branding `BACKLOG→BUILD`; **two new tabs** (Request an Edit, Support); dynamic per-host manifest; payment-gate shell; in-app + owner-email ticket notifications; polling cadence |
| B | `scratch-foundation` | ticketing tables + RLS + `edit-request-uploads` bucket + status enums + `access_suspended` (owns the data model) |
| B/C | **`agency-view` — NEW SKILL** | cross-tenant dashboards: pending edit-requests, pending support, new-request flagging, payment-access toggle + status, routing-to-client |
| C | `admin-view` | edit-requests section, support section + support history; logo-upload UX, brand-color editor, pre-gen console, A2P-prep panel, submission record; payment-gate shell intercept |
| C | `onboard-from-form` | the **wizard build** (capture UI) + extend `updateClientSettings`; correct the "Stage 3 built" overstatement |
| D | `textgrid-provider` §4, `launch-check` §E | A2P flow (specced) + gate rows |
| E | **new doc** (`docs/onboarding-runbook.md` or similar) | repeatable onboarding + remix + go-live test checklist |
| cross | `platform-spec-source-of-truth.md`, `HANDOFF.md` | keep in sync each pass; record v1.7 |

---

## 6. Open decisions — resolve per phase (NOT now)

- **Upload caps/quota numbers** (Feature A): exact per-file size cap (videos), per-client storage quota, resumable/TUS threshold. *(Standard: photos + docs direct; videos capped or TUS; dedicated `edit-request-uploads` bucket.)*
- **Support-history retention** specifics (keep-forever vs policy; append-only confirmed-intended).
- **Authed-surface abuse-guard design** (a client spamming tickets/uploads — it's RLS-scoped but still rate-worthy).
- **Payment-gate message text** — fixed string vs agency-configurable.
- **Native store apps** (vs PWA) — deferred decision.
- **Realtime** (vs polling) for ticket threads — post-launch.
- **Agency-view skill vs admin-view tabs** — resolved: **new agency-view skill** (decision 9).

---

## 7. What's MISSING from a launchable SaaS — named prereqs (folded in)

| Prereq | Status / where it lands | Severity |
|---|---|---|
| **Client auth/login provisioning** | **Phase B-0 (DO-FIRST)** — specced mechanism, unbuilt flow | BLOCKER for B + E |
| **`audit_log` table** | v1.7 pass; gates **before any real admin/agency_owner grant** | LAUNCH PREREQ |
| **Onboarding wizard (capture UI)** | **Phase C** — NOT built (skill overstates) | BLOCKER for E |
| **Billing / payments** | **DEFERRED — invoice-by-hand for v1**; no Stripe/plans/metering yet; revisit when manual invoicing is the bottleneck. The **payment-access gate IS built now** (§4) and works with manual invoicing + is Stripe-forward-compatible | deferred subsystem |
| **Agency's own legal** (client services agreement + acceptable-use policy) | **Parallel, NON-CODE** — must exist **before sending SMS on a real client's behalf** (your name is on the A2P filings) | non-code launch prereq |
| **Per-client domain/DNS + one-time agency sender domain** (NS-delegated, DKIM/SPF) | Phase-E runbook (domain connect, `allowed_origins`, Turnstile hostname, A2P site URL) + one-time agency email-domain setup | per-client + one-time |
| **Real Turnstile keys per client** | Phase E (template ships the always-pass test key; real site key + secret + per-client hostname at launch, or every legit lead is dropped) | per-client |
| **Error / cron-health / send-failure monitoring** | Lightweight ops view (you have `events`, `audit_log` pending, `?ping=1`, template `lovable-error-reporting.ts`; no consolidated alerting) | pre/post-launch |
| **Supabase backup / PITR policy** | Confirm a DB backup policy before real client data lands (backend rollback = `golden-master` tags; templates = GitHub) | pre-launch |
| **Per-client data export / offboarding** | **DONE** — `export_client_bundle` + `archive_client` (soft offboard, drips stop, data persists). Credit; no work | ✅ done |

---

## 8. Held-backlog slotting (nothing orphaned)

| Item | Phase | Note |
|---|---|---|
| D-3 (template_vars enumeration in master) | A (before styles 2–6) | tiny |
| E-1 (seeded-segment fill note) | A | tiny |
| Landscaping niche-library row | A/E | at real-landscaper onboarding; DEFAULT fine for demo |
| Consent persistence (A-3) | **v1.7 pass** | **must precede first real A2P submission** |
| Terms-token canonicalization (C-3/G-4) | A/C (skills) | `website_terms_page_link` vs `{terms_url}`/`{privacy_url}`/`{optin_url}` → on-site routes, before real onboarding |
| admin-view BUILD items (logo upload, pre-gen console, A2P panel, submission record) | C | onboarding-readiness UI |
| mobile-app per-client-branding BACKLOG | B | promote to BUILD |
| `audit_log` [BUILD — TODO] | **v1.7 pass** | before real role grants (do-first gating) |
| mobile-app realtime (vs polling) | post-launch | backlog |

---

## 9. TL;DR
- **Kick off TextGrid verification now** (long pole). Run **A (templates), B-0 (auth+audit), B-design, C (admin + agency-view + the missing onboarding wizard)** + the non-code prereqs in parallel.
- **One additive backend pass → `v1.7`** batches ticketing + `audit_log` + consent persistence + the payment-access flag + A2P columns. Same contract as 1f — not a real unfreeze.
- **Auth is do-first**; the onboarding wizard is the unbuilt linchpin; billing is invoice-by-hand (gate built, billing deferred); your client legal runs in parallel.
- **Payment-gate:** gates only the authed app + admin, automations keep running, public site untouched, distinct from `archive_client`.
- **D + E wait on TextGrid + per-client A2P approval** — the only thing you truly can't compress.
