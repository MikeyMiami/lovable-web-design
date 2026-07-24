# Project 1 — Shared Backend + Admin + Client PWA (app.pierceworks.co)

This project IS the golden-master backend (workspace rules apply in full). It serves: the multi-tenant API + DB for ALL clients, the agency admin dashboard (`/admin`, `/agency`), and the white-label client PWA (`/app`, `/login`, `/set-password`, `/download`). Frozen infrastructure — changes are surgical, prompt-scoped, additive.

## Onboarding lifecycle
7-step wizard (authed `/onboard` or one-time tokenized client link; identity, content, discount, support/contact emails, A2P identity + optional CP 575 upload) → `clients.status='pending'` (dormant: no automations, not anon-visible) → `/admin/review` → **Finalize & Activate** (`provisionClientOwner`: SILENT `auth.admin.createUser` + audited `client_owner` grant + flip `active` — **NO email**) or **Decline** (pending-only guard; PERMANENT purge of row + storage). The client's ONE email = **Send Client Welcome** (same page, active-only): agency-editable intro (`template_vars.welcome_email_message`; Save button; layout preview) above 3 links — their website (requires `template_vars.company_website_link` set = site live) / set-password / app download. Set-password link built from `generateLink({type:'recovery'}).properties.hashed_token` → `{PUBLIC_APP_ORIGIN}/set-password?token_hash=…&type=recovery&c=…` (NEVER `action_link` — leaks the supabase.co URL). Sent via direct Resend fetch (`RESEND_WELCOME_FROM ?? RESEND_FROM`, `reply_to` from `RESEND_WELCOME_REPLY_TO`) — bypasses the notifications toggle, THROWS on failure. Re-send = the agency-side password reset (fresh single-use link). Stamps `welcome_email_sent_at` + an events row.

## Auth surfaces
`/login` = email+password only. `/set-password` = recovery-session page (hash tokens or `token_hash`→`verifyOtp`) → `updateUser({password})` → `/download`. `/download?c=<clientId>` = branded PWA install (per-client manifest `/api/public/manifest/$clientId`; requires sign-in). No self-serve password reset (backlog) — the agency re-sends the welcome.

## Admin (per-client) + agency surfaces
Tabs: Dashboard, Contacts, Conversations, Feedback, Edit Requests, Support, Automations, Upload Customers (reactivation), A2P Prep, Review & Finalize (`/admin/review`), SEO, Settings. `/agency` = cross-client (onboarding queue etc.).
- **Two-tier go-live checklist** (`src/lib/admin/checklist.ts`): RED = required-to-finalize (tier, notification_email, review_link, support_email, contact_email, legal_address, call_forwarding_number) — rendered always; YELLOW = post-launch (phone_display, 5 `telnyx_*` IDs, allowed_origins, company_website_link, review_link_domain) — only when `status='active'`. Any query feeding these checklists MUST `select("*")` — a narrow column list makes filled fields read `undefined` → flagged missing forever.
- **Required template_vars (8)** (`src/lib/admin/required-template-vars.ts`): company_owner_first_name, company_name, review_request_link, discount__on_referral, discount_amount, about_us, services, differentiators. `quote_form_link` is fallback-only (blank → runner substitutes `company_website_link`; no editor); `website_terms_page_link` optional.
- Settings cards own their template_vars keys; ALL template_vars writes read-merge-write the full object [LOCKED].

## Data model essentials
- `enrollments` keyed by `sequence_key`; UNIQUE (client_id, contact_id, sequence_key) — dedup before insert. Partial index on `next_run_at WHERE status='active'`.
- `send_settings.timezone`; soft-delete `deleted_at` on contacts/clients; phones E.164.
- Tiers 297 Starter / 397 Growth / 749 Pro; the only tier gate = `seo_cadence` (749).
- Owner email recipient = `notification_email ?? email` (dedicated column, NOT template_vars, not anon-projected).

## Messaging / providers
`clients.provider`: **telnyx = DEFAULT** (single account, ONE `TELNYX_API_KEY`; per-client telnyx_number / messaging-profile / TeXML-app / brand / campaign columns; live webhooks = `telnyx-*` Edge Functions, Ed25519-verified; ringback + AMD missed-call detection live-validated). **textgrid = FROZEN LEGACY** (existing clients only; `X-TextGrid-Signature` HMAC keyed by `client_provider_secrets.webhook_secret`). **A2P 10DLC registration runs on a SEPARATE external platform** fed by onboarding identity (+ CP 575); client sites stay a2p-compliant by design. Render-completeness guard: never transmit an SMS body with residual `{tokens}`.

## Send timing + cron [LOCKED]
Marketing SMS (review, one-year, reactivation): 9am–7pm client tz; outside → defer to 9am, preserve order. Lead-form drip branches on Business Hours (separate setting). Missed-call textback 24/7. Caps: daily send cap; enrollment cap default 50; reactivation 50/day + 2/20min + consent attestation, from the client's own number. Cron runner (`/api/public/cron/sequences`, `x-cron-secret`): bounded batch, `FOR UPDATE SKIP LOCKED`, blocked→reschedule WITHOUT advancing, 2× retry, every decision → `events`. pg_cron UNSCHEDULED until the launch gate (`?ping=1` health check; canonical prod URL only).

## Review funnel + drips
`/api/public/r/<token>`: rate 1–5 (threshold default 4, inclusive) → ≥thr Google (`review_link`) + Review Completed (→ One-Year); <thr private feedback + Negative Review. Tracked links: `trackedLinkUrl()` → `review_link_domain` set ? `clientdomain/review/<token>` : `PUBLIC_APP_URL` fallback (reviewbatch.com). Drips: Review Request (4 SMS), One-Year (5, exit on reply/opt-out/claim), Lead-Form, Missed-Call Textback (SMS#1 merges `{quote_form_link}`), Reactivation. Opt-out: STOP/HELP/START + sole-word "pass" at the inbound webhook; real-time drip exits.

## Owner notifications
3 channels: in-app feed (`writeNotification`) + Resend email (`sendOwnerEmail` — `alerts@notif.pierceworks.co`, gated by `email_notifications_enabled`, fail-open) + web push (VAPID). The client WELCOME email is separate/transactional — never gate it on the toggle, never let it fail silently.

## SEO = DATA
`content_pages` rows; templates render them; publishing never touches Lovable projects. `/admin/seo`: AI-seed map from services (`proposeSeoMap`, never writes) → correct vs the real GBP → Save (`saveSeoMap`, server-side merge) → Seed Core-30 (idempotent drafts) → AI-write per page → Publish. Geo/supporting ~monthly (749 cadence).

## Misc invariants
- App links (`/set-password`, `/download`) = `PUBLIC_APP_ORIGIN ?? https://app.pierceworks.co` [LOCKED]; `PUBLIC_APP_URL` = review-link base, never app URLs.
- Chat widget = capture-first lead form (NO AI); `/api/public/chat/optin`.
- Rate limiting DB-backed: `rate_limit_hits` + `check_rate_limit()` RPC (also the PoW replay guard).
- Bot shield: mint `/api/public/challenge` → Web-Worker PoW → `pow_token` verify (sig, 3s–10min, difficulty, one-time); `POW_SECRET` required.
- `server.ts` hostRedirect: lovable.app + reviewbatch non-funnel paths 302 → app.pierceworks.co.
