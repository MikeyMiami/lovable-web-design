# Project 1 - Shared Backend + Admin + Client PWA (app.pierceworks.co)

The golden-master backend (workspace rules apply in full): multi-tenant API + DB for ALL clients, agency admin (`/admin`, `/agency`), white-label client PWA (`/app`, `/login`, `/set-password`, `/download`). Frozen infrastructure - changes are surgical, prompt-scoped, additive.

## Onboarding + auth
7-step wizard (authed `/onboard` or tokenized link) -> `clients.status='pending'` (dormant, not anon-visible) -> `/admin/review` -> **Finalize & Activate** (`provisionClientOwner`: silent `createUser` + audited `client_owner` grant + flip `active`, **no email**) or **Decline** (pending-only; purges row + storage). The client's ONE email = **Send Client Welcome** (active-only): agency-editable intro above 3 links - website / set-password / app download. Set-password uses `generateLink().properties.hashed_token` -> `{PUBLIC_APP_ORIGIN}/set-password?token_hash=...` (NEVER `action_link` - it leaks the supabase.co URL). Direct Resend fetch; bypasses the notifications toggle; THROWS on failure.
`/login` = email+password only. `/set-password` = recovery session -> `updateUser` -> `/download` (branded PWA install, requires sign-in). No self-serve reset - the agency re-sends the welcome.

## Admin + agency surfaces
Tabs: Dashboard, Contacts, Conversations, Feedback, Edit Requests, Support, Automations, Upload Customers, Review & Finalize, **Content** (`/admin/content` - Site Copy overrides at `template_vars.content.<slot>`; **TEN slots** incl. micro-copy `home.call_bar_label` + `home.cta_button`), SEO, Settings. `/agency` = cross-client. **No A2P Prep tab and none planned** - A2P registration is MANUAL/out-of-app; copy lives in `docs/a2p-compliance-copy-source-of-truth.md`.
- **Go-live checklist** (`src/lib/admin/checklist.ts`): RED = required-to-finalize, **6 items** (notification_email, review_link, support_email, contact_email, legal_address, call_forwarding_number; `tier` removed 2026-07-29). YELLOW = post-launch (phone_display, **3** telnyx IDs - number/brand/campaign, allowed_origins, company_website_link, review_link_domain), only when `status='active'`. Any query feeding these MUST `select("*")` - a narrow column list makes filled fields read `undefined` and flag as missing forever.
- **Required template_vars (8)**: company_owner_first_name, company_name, review_request_link, discount__on_referral, discount_amount, about_us, services, differentiators. `quote_form_link` is fallback-only (blank -> runner uses `company_website_link`).
- ALL template_vars writes read-merge-write the full object [LOCKED].

## Data model essentials
- `enrollments` keyed by `sequence_key`; UNIQUE (client_id, contact_id, sequence_key). Partial index on `next_run_at WHERE status='active'`.
- `send_settings.timezone`; soft-delete `deleted_at`; phones E.164.
- **SINGLE TIER - $297/mo, everyone gets everything (2026-07-29).** The 297/397/749 split is GONE, `entitlements.ts` deleted, no feature gates anywhere. `clients.tier` survives as an unread column - do not reintroduce it in UI, checklists or queries.
- Owner email recipient = `notification_email ?? email` (dedicated column, not template_vars, not anon-projected).

## Messaging / providers
`clients.provider`: **telnyx = DEFAULT** - single account, ONE `TELNYX_API_KEY` + ONE `TELNYX_PUBLIC_KEY`, no per-client credentials. **Only THREE per-client columns: `telnyx_number`, `telnyx_brand_id`, `telnyx_campaign_id`** (+ `telnyx_a2p_status`). **The messaging profile and TeXML voice app are SHARED platform-wide (2026-07-29)** - one profile + one voice app, every client number on both; numbers under different 10DLC brands/campaigns may share a profile, and 10DLC does not govern voice at all. `telnyx_messaging_profile_id`/`telnyx_texml_app_id` remain as unused columns, removed from Settings/onboarding/checklist - never read at runtime (sends use the `from` number; inbound resolves by the `to` number). **Number Pooling must stay OFF** - it overrides the `from`, so Client A would send from Client B's number and the reply would land in the WRONG inbox. Webhooks = `telnyx-*` Edge Functions, Ed25519. **Inbound voice IS signed; status/AMD callbacks are NOT - hard-verify inbound only, or you kill AMD and missed-call textback.** **textgrid = FROZEN LEGACY** (existing clients only). Never send an SMS body with residual `{tokens}`.

## Send timing + cron [LOCKED]
Marketing SMS (review, one-year, reactivation): 9am-7pm client tz; outside -> defer to 9am, preserve order. Lead-form branches on Business Hours; missed-call is 24/7. Caps: daily send; enrollment 50; reactivation 50/day + 2/20min + consent attestation. Runner: bounded batch, `FOR UPDATE SKIP LOCKED`, blocked -> reschedule WITHOUT advancing, 2x retry, every decision -> `events`.
**pg_cron LIVE since 2026-07-29** - job `drip-runner`, `*/2 * * * *`, `net.http_post` -> **`https://app.pierceworks.co/api/public/cron/sequences`**, `timeout_milliseconds := 30000`. **Always the app host, never the lovable.app one** - that 302s and `net.http_post` does not follow redirects, so it ticks forever with zero sends and zero errors. Verify BOTH `cron.job_run_details` AND `net._http_response` (the post is async, so cron reports success merely for queueing). `?ping=1` is POST-only.

## Review funnel + drips
`/api/public/r/<token>`: rate 1-5 (threshold default 4, inclusive) -> at/above Google + Review Completed; below -> private feedback + Negative Review. `trackedLinkUrl()` -> `review_link_domain` set ? `clientdomain/review/<token>` : `PUBLIC_APP_URL` (reviewbatch.com).
Drips: **Review Request** (4 SMS day 0/4/11/18 + terminal owner notif day 20), **One-Year** (5, starts day 30, exits on reply/opt-out/discount-claim), **Lead-Form** (branches on Business Hours), **Missed-Call** (+1min, +2min), **Reactivation** (day 0/7/14/21 since 2026-07-29; shares Review Request's 4 templates).
**TWO paths into One-Year, different code:** clickers enrol from the FUNNEL (`r/$token.ts`, `r/rate.ts`); contacts who ignore all 4 texts enrol via `handoffToOneYear()` in the runner's terminal branch (built 2026-07-29 - previously documented but never implemented). Both skip opt-outs.
**Copy [LOCKED]:** the FIRST customer message of every drip ends with a blank line then `Reply STOP to opt-out.` - never on follow-ups, never on internal notifications.
**Bodies live in `templates`** (`key`,`body`,`client_id`; global = `client_id IS NULL`). **Timing lives in `sequences`** - `start_delay_minutes` = enrolment to first step; `steps_json[i].offsetMinutes` = gap between step i and i+1 (NOT absolute); a step with NO offsetMinutes is terminal. Neither is seeded by migration.
Opt-out = TWO LAYERS (2026-07-29). App (`parseIntent`): STOP synonyms + sole-word "pass" -> opt out + exit ALL active drips; START/YES/UNSTOP -> re-opt-in; HELP is NOT app-handled. Telnyx: auto opt-out is DEFAULT and cannot be disabled - it auto-confirms STOP and hard-blocks later sends (40300, matched by the runner's D13 sync). **Telnyx blocks are PROFILE-WIDE: STOP to any client's number blocks that phone for EVERY client on the shared profile.**

## Owner notifications
3 channels: in-app feed (`writeNotification`) + Resend email (`alerts@notif.pierceworks.co`, gated by `email_notifications_enabled`, fail-open) + web push (VAPID). The client WELCOME email is transactional - never gate it on the toggle. **Action buttons come from the `action` jsonb, NEVER literal text in a body.** `ACTION_BY_TEMPLATE_KEY` maps **all 12** template keys to `{open_conversation:true}`; `lead_form_day10_owner_reminder` carries BOTH `{auto_enroll:true, open_conversation:true}`. Buttons render only when `related_contact_id` is set; a per-call `args.action` overrides the map. **In-app and email are SEPARATE `templates` rows** - fixing one never touches the other.

## SEO = DATA
`content_pages` rows; templates render them; publishing never touches Lovable projects. `/admin/seo`: AI-seed (`proposeSeoMap`, never writes) -> correct vs the real GBP -> Save (`saveSeoMap`, server-side merge) -> Seed Core-30 -> AI-write -> Publish. Geo/supporting monthly, every client.

## Client PWA - Inbox
- **Archive**: nullable `conversations.archived_at`; writes via role-verified `setConversationArchived` (scoped by BOTH id and client_id). Swipe on touch, hover/focus overlay at `md`+. **Two invariants:** `admin.conversations.tsx` stays UNTOUCHED (the agency keeps full visibility); and a new inbound reply AUTO-UNARCHIVES via the DB trigger `trg_unarchive_on_inbound` - it MUST be a trigger, since inbound arrives via Edge Functions and would bypass app code, silently burying a lead.
- **Lead-type avatar**: the row circle shows lead TYPE, not a name initial. Match order is load-bearing (engagement outranks acquisition): Star (review/reactivation, `contacts.status`) -> Percent (discount, `enrollments.sequence_key`) -> PhoneMissed -> MessageSquare (`web_form`|`chat_widget`) -> User. **The discount form writes `source='web_form'`, identical to the lead form**, so `contacts.source` can NEVER identify a discount claimer - the enrolment join is the only honest signal.

## Misc invariants
- App links = `PUBLIC_APP_ORIGIN ?? https://app.pierceworks.co` [LOCKED]; `PUBLIC_APP_URL` = review-link base, never app URLs.
- Chat widget = capture-first lead form (NO AI); `/api/public/chat/optin`.
- Rate limiting DB-backed: `rate_limit_hits` + `check_rate_limit()` RPC (also the PoW replay guard).
- Bot shield: `/api/public/challenge` -> Web-Worker PoW -> `pow_token` verify (sig, 3s-10min, difficulty, **one-time**); `POW_SECRET` required.
- `server.ts` hostRedirect: lovable.app + reviewbatch non-funnel paths 302 -> app.pierceworks.co.
