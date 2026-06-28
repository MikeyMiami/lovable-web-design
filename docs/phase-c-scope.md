# Phase C Scope — Onboarding Wizard + Agency-View (for approval)

> **Status:** SCOPE FOR APPROVAL — read-only, 2026-06-20. **Build nothing.** Against `golden-master-v1.7` (current frozen baseline). Two pieces: (1) the **onboarding wizard** (the linchpin), (2) the cross-tenant **agency-view** (NEW skill). Strategy confirmed: Phase C is **config-UI + dashboard work with ZERO live-SMS/A2P dependency** → fully buildable now; it's what lets you onboard a real client and leaves only live testing for after A2P clears.

## 0. ⚠️ Grounding accuracy note (read first)
The **local clone `C:\Users\Pierc\Desktop\cloud-spark-setup` is STALE at v1.6** (handoff §5). v1.7 objects this scope depends on — **`provisionClientOwner`** (`src/lib/auth/provisioning.functions.ts`, B-0 validated 2026-06-18), **`setClientAccessSuspended`** (`src/lib/clients/access.functions.ts`), **`clients.access_suspended`**, **`a2p_brand_id`/`a2p_campaign_id`/`a2p_status`**, and the **5 Slice-1 ticket fns** — all **exist in live v1.7** but are **absent from the clone**. A read of the clone will falsely report them missing. **Before building, verify exact signatures against the LIVE v1.7 repo** (`git fetch origin && checkout golden-master-v1.7`, or read in Lovable) — never off the stale clone. Everything below is grounded on the true v1.7 state + the `onboard-from-form` field→destination mapping (the wizard's contract).

## 1. Schema impact — **NONE (app-layer on v1.7; no re-tag)** — one deferral flag
Both pieces **read/write existing destinations + call existing validated fns**. Confirmed app-layer:
- Wizard destinations all exist: `clients` columns, `template_vars` (jsonb), `send_settings` (timezone / `sms_send_window` / `business_hours` / `daily_send_cap` / `daily_enrollment_cap` / `sequence_overrides`), `public-assets`/`client-assets` buckets. The immutable submission record is a **storage JSON** (`{client_id}/onboarding-submission.json`), not a table.
- Agency-view reads existing `tickets`/`clients` (via `is_admin()` RLS, cross-tenant) + calls `setClientAccessSuspended` (exists).
- **The ONE schema temptation = the EXTENDED A2P columns** (`entityType`/`brandRelationship`/`vertical`/`termsLink`/`privacyLink`). **Recommend DEFER to Phase D** (when actual Brand/Campaign *registration* is built). The wizard **captures** A2P-prep into `template_vars` (anon-safe ones) + the immutable submission JSON (PII ones like EIN) and sets `a2p_status='not_started'` — standing columns aren't needed until registration. **Keep C app-layer.**
- *(Optional perf only: a cross-tenant pending-tickets index. Volumes are tiny pre-launch → defer.)*

**→ Confirmed: Phase C is app-layer on v1.7, no migration, no re-tag.**

---

## 2. PIECE 1 — The Onboarding Wizard (linchpin)

### 2a. What it is — **CONFIRMED: the orchestration wrapper**
It takes a business from nothing → a fully-configured, launchable client. It **wraps** (does not replace) the validated pieces: client-row creation + full config capture + `send_settings` + the immutable submission record + **`provisionClientOwner`** (login) + the **Remix handoff**. *(Reality check from the clone: there is no real `onboard-from-form` code today — only a doc reference — and client creation today is ad-hoc RLS inserts in `admin.settings.tsx`. The wizard is the first real capture surface; `createClient` is currently thin/4-field, so the wizard introduces a proper orchestration fn — see 2d.)*

### 2b. What it captures, step by step (grounded in the `onboard-from-form` mapping)
| Step | Captures | Destination |
|---|---|---|
| 1 · Identity | Owner full name; official business name; business phone; display address; website | `template_vars.company_owner_first_name` (first token); `business_name` + `template_vars.company_name`; `call_forwarding_number` (seed); `clients.address`; `template_vars.company_website_link`. *(Shipping address = agency-ops/submission-JSON only, not a feature column.)* |
| 2 · Content (AI-knowledge) | About Us; all services; differentiators; service areas (≤14); hours | `template_vars.about_us` / `.services` / `.differentiators`; `clients.service_area[]`; `send_settings.business_hours` (+ site). *(These 3 `template_vars` keys feed the chat-widget knowledge bundle automatically.)* |
| 3 · Branding | Logo (upload or "need one" flag); brand colors (primary/secondary/tertiary) | upload→`public-assets`→`clients.logo_url`; `clients.brand_color` (hex) + `template_vars.brand_secondary`/`brand_tertiary`. |
| 4 · Niche + style | Niche/segment; site style (1 of 4) | `template_vars.segment` (keys the a2p niche library); `clients.site_style`. |
| 5 · Photos | 25–60 categorized: work-examples / per-service / staff | structured paths in `public-assets`/`client-assets` + a `template_vars.site_assets` manifest; missing categories fall back to niche defaults. *(See D6 — phased.)* |
| 6 · Review config (agency) | Google review link + Place ID; star threshold; review toggle | `clients.review_link`, `review_place_id`, `star_threshold` (def 4), `google_review_toggle` (def gated). **+ `template_vars.review_request_link`** = the business's own direct Google review URL used in messages (distinct from the per-contact tracked `review_link`). *(See 2e.)* |
| 7 · Offers | Return/referral discount + amount | `template_vars.discount__on_referral` / `.discount_amount`. |
| 8 · Config (agency) | Timezone; SMS send window; business hours; caps; marketing domains; quote-form + terms links | `send_settings.timezone`/`sms_send_window`/`business_hours`/`daily_send_cap`/`daily_enrollment_cap`; `clients.allowed_origins[]`; `template_vars.quote_form_link`/`website_terms_page_link`. |
| 9 · A2P-prep (PREPARES, does not submit) | EIN; legal name/DBA; entity type; vertical; contact email (domain-match); TCPA attestation; logo ≤400px | the immutable **submission JSON** (PII) + `template_vars` (anon-safe) + sets `a2p_status='not_started'`. Standing extended-A2P columns = **Phase D**. |
| 10 · Finalize | Consent (terms + SMS opt-in); review & confirm | write the immutable `{client_id}/onboarding-submission.json`; then **call `provisionClientOwner`** (mint login); then emit the **Remix handoff** (2f). |

### 2c. Buildable NOW vs A2P/live-gated
- **Buildable now (all of it):** every capture step, full config, `send_settings`, the immutable submission record, login provisioning, **review-link capture/storage**, the **pre-generation console**, and the **A2P-prep COPY generation** (`a2p-site-compliance`).
- **Gated (Phase D/E, the wizard PREPARES but does NOT activate):** actual A2P Brand/Campaign **submission + approval**; the real per-client messaging number/SID assignment (subaccount→Brand→Campaign→number); live SMS; and **testing** the live review flow / menus / drips. The messaging columns (`twilio_number`/`messaging_service_sid`) exist and stay empty/placeholder until A2P. `a2p_status` starts `not_started`; the wizard never flips it to submitted/approved.

### 2d. Where it calls existing validated pieces (orchestration — no rework)
- **Client creation:** a NEW server fn **`createClientFull`** (orchestrator) — inserts the `clients` row + **upserts `send_settings`** (NOT auto-created on client insert — confirmed) + writes the submission JSON. *(Wraps/extends today's thin createClient + the `admin.settings` insert pattern; service-role + Zod + completeness validation.)*
- **Config editing afterward:** extend the existing `admin.settings` editors / **`updateClientSettings` to cover ALL §9b fields** (today it covers identity/brand/timing/caps; the wizard writes everything at creation, Settings edits it after).
- **Login:** **`provisionClientOwner`** (B-0, v1.7) called at the FINAL step — invite email (`redirectTo` = the PWA set-password route) + audited `client_owner` grant. **No rework — it's standalone + the wizard is its caller, exactly as B-0 designed** ("the Phase-C onboarding wizard calls the SAME fn at its final step").
- **Storage:** logo/photos via the proven `ticket-upload.ts`-style upload (to `public-assets`/`client-assets`).
- **A2P-prep copy:** `a2p-site-compliance` generation (already specced).

**→ Confirmed: the wizard is the wrapper orchestrating `createClientFull` (client + config + send_settings) → submission record → `provisionClientOwner` → Remix handoff.**

### 2e. Review-link handling (capture/storage now; live test = A2P-gated)
Two distinct, both captured now: **`clients.review_link`** + **`clients.review_place_id`** (agency grabs from the Google Business Profile; the review funnel reads these) and **`template_vars.review_request_link`** (the business's own direct Google review URL merged into messages). Stored at onboarding; the review-request flow already consumes them. **Testing the live flow (link resolves to the real GBP URL, menus work) is A2P-gated** (needs live SMS) — capture + storage is fully buildable now.

### 2f. The Remix handoff (open decision D8)
The per-client marketing site is a **manual Remix** of the style template (set `VITE_CLIENT_SLUG`, connect domain, set `allowed_origins`, real Turnstile keys) per `new-client-site`. The wizard **finalizes the backend client + emits the handoff checklist** (slug, env vars, allowed-origins, the matched `site_style` template); it does **not** auto-remix. Confirm (D8).

### 2g. Surfaces (net-new vs reuse)
- **Net-new:** the wizard route + stepper UI; `createClientFull` orchestrator; the submission-JSON write; logo/photo **upload UX**; the **pre-generation console** (review/approve/edit-before-remix — assembles selections + branding + niche + A2P-prep for a congruence check); the **immutable submission viewer** (read-only); extend `updateClientSettings`.
- **Reuse:** `provisionClientOwner`, `send_settings` upsert, the `admin.settings` field editors, storage buckets + upload helper, `a2p-site-compliance` copy gen, the `template_vars` contract.

---

## 3. PIECE 2 — Agency-View (cross-tenant) — NEW skill
### 3a. What it is
The agency-wide layer above the per-client admin: see what needs attention **across ALL clients** without drilling in, and control payment access from one place. It now has clean consumers — the 5 ticket fns + `setClientAccessSuspended`.

### 3b. Surfaces
- **Cross-tenant pending queue:** all `open`/`in_progress` **edit-requests + support tickets across every client**, client-labelled, sorted by `last_message_at`, with new-request flagging (badge/count). Click → jump into that client's per-client admin Edit Requests/Support thread (set active client + navigate). *(Reading all clients' tickets works today: the admin's `is_admin()` RLS branch returns cross-tenant rows; `fetchAdminBootstrap` already lists all clients.)*
- **Payment-access control:** all clients with their `access_suspended` status + a per-client toggle → **`setClientAccessSuspended`** (exists; logs to `events`). One place to suspend/restore.
- *(Optional: a clients overview — status, suspended, pending counts per client.)*

### 3c. Net-new vs reuse
- **Net-new:** the agency-view route/shell (cross-tenant — no single "active client"); the cross-tenant queries; the **new `agency-view` skill**.
- **Reuse:** `fetchAdminBootstrap`/`admin-context` client list; the `tickets` tables (read via `is_admin()` RLS); `setClientAccessSuspended`; the per-client admin thread UI (the queue routes INTO it — agency-view is read+route+toggle, **not** a reply surface in v1, D2).

---

## 4. Build sequence + slicing (same discipline as B-design)
Recommend three validated slices:
- **C-1 — Agency-view** (small, self-contained, reuses everything; immediately useful for managing the tickets you just shipped). Validate: agency sees cross-tenant pending queue; payment toggle suspends/restores + logs; a `client_owner` cannot reach `/agency` (authz).
- **C-2 — Wizard orchestration fns** (`createClientFull` + extend `updateClientSettings` + submission-JSON write + wire `provisionClientOwner`). Validate fn-level: one call produces a complete `clients` row + `send_settings` + submission JSON + a minted login (invite sent), à la the B-0 green path.
- **C-3 — Wizard UI** (stepper + capture steps + logo/photo upload + pre-gen console + submission viewer). Validate end-to-end: onboard a test client start→finish → the client can log into the PWA → the Remix handoff checklist is correct.

**Order options:** *(A — recommended)* C-1 → C-2 → C-3 (agency-view as the low-risk warm-up, then the linchpin in fn→UI slices). *(B)* C-2 → C-3 → C-1 if you'd rather hit the onboarding linchpin first. Either is fine; the slices don't depend on each other.

## 5. Open decisions (settle on approval)
| # | Decision | Recommendation |
|---|---|---|
| D1 | Agency-view location | **Separate `/agency` shell** (cross-tenant; the `/admin` shell is single-active-client) — not an `/admin` tab. |
| D2 | Agency-view: inline reply vs route-to-client-admin | **Route-only v1** — the queue jumps into the per-client thread UI; no duplicate reply surface. |
| D3 | Wizard form: one long form vs multi-step stepper | **Stepper** with a final review; **draft-save optional** for v1. |
| D4 | Client creation: new `createClientFull` server fn vs extend the `admin.settings` RLS pattern | **New server fn** (orchestration + the provisioning call must be server-side; Zod + completeness validation). |
| D5 | A2P-prep storage | **Submission JSON + `template_vars` now; extended `a2p_*` columns DEFERRED to Phase D.** Confirm we are NOT batching A2P columns into C. |
| D6 | Photos (25–60 categorized) | **Phase it:** logo + work-examples uploads in C-3; full per-service/staff categorization can be a fast follow-on (heavy UI, not launch-blocking). |
| D7 | Pre-gen console placement | Wizard's **final review step = the pre-gen console**; the per-client admin gets the **read-only submission viewer** + the editable Settings. |
| D8 | Remix handoff | Wizard **finalizes the backend client + emits the remix checklist**; the actual Remix is **manual** (per `new-client-site`), not auto-triggered. |

## 6. Skills touched
- **`agency-view`** — **NEW skill** (cross-tenant pending queue + new-request flagging + routing + payment toggle).
- **`onboard-from-form`** — the wizard is now BUILT; correct the "Stage 3 built" overstatement; the field→destination table becomes the implemented contract.
- **`admin-view`** — build/mark the pre-gen console + immutable submission viewer + logo-upload UX (existing BUILD items).
- **`new-client-site`** — the wizard→Remix handoff (orchestration).
- **`scratch-foundation`** (minor pointer) — `createClientFull` orchestrator + the `send_settings`-not-auto-created note.
- **`platform-spec-source-of-truth`** — reflect the onboarding wizard built.
- Mirror lines handed **after** each slice builds + validates (discipline).

## 7. Work-time estimate (our iterate-and-validate cadence)
| Slice | Work | Rough effort |
|---|---|---|
| C-1 Agency-view | cross-tenant queue + payment toggle + authz validate | **~0.5–1 day** |
| C-2 Wizard fns | `createClientFull` + `updateClientSettings` extension + submission JSON + provisioning wire + fn validate | **~0.5–1 day** |
| C-3 Wizard UI | stepper + capture + uploads + pre-gen console + submission viewer + e2e onboard test | **~2–3 days** (the bulk) |
| **Total** | | **~4–5 days elapsed** |

Bigger than B-design; the **wizard UI is the heavy part** (many capture fields + uploads + the pre-gen review). The backend/orchestration is small and reuses the validated B-0/v1.7 fns.

---
**Scope-only. App-layer on `golden-master-v1.7` — no schema, no re-tag (extended A2P columns explicitly deferred to Phase D). Approve + settle D1–D8, then we sequence + slice.**
