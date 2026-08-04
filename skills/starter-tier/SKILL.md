---
name: starter-tier
description: Use when onboarding, delivering, or supporting a client on the $97/mo STARTER tier — website + forms with email-only lead alerts, no SMS automations, no A2P registration, no mobile app. Defines what Starter is, the mechanism that enforces it, the finite order of operations for delivery, the copy that must differ, and the traps (downgrade is destructive; never reuse demo_mode). NOT the full-tier flow (use onboard-from-form / new-client-site) and NOT the drip copy itself (use automation-config).
---

# Starter Tier — $97/mo website, email-only leads

**One sentence:** the same site, the same forms, the same review funnel — but a lead notifies the owner **by email only**, nothing is ever texted, and the client is never told an app exists.

> **STATUS 2026-08-04: SPECIFIED, NOT BUILT.** The enforcement mechanism exists (demo mode) and the tier column exists (`clients.tier`, currently dead). What is missing is the wiring, the copy variants, and the onboarding gate. **One hard dependency is open — see §7.**

---

## 1. What Starter is and is not

| | Starter $97 | Full $297 |
|---|---|---|
| Website, SEO pages, photos | ✅ same | ✅ |
| Public lead form / discount form | ✅ same | ✅ |
| Lead alert to owner | **email only** | email + push + SMS drip |
| SMS drips / sequences | ❌ never | ✅ |
| Missed-call textback | ❌ never | ✅ |
| A2P / 10DLC registration | **not required** | required |
| Mobile app (PWA) | built, **never handed over** | handed over |
| Welcome email | **never sent** | sent |
| Google review link + funnel | ✅ same | ✅ same |
| AI chat widget | decide per client — see §6 | ✅ |

**The commercial point:** a Starter client needs no 10DLC campaign, no per-message cost, and carries **zero TCPA exposure**. That removes the slowest and riskiest part of onboarding, which is most of why the tier is worth having.

## 2. The mechanism — derive, never overload

```
clients.tier = 'starter' | 'full'      ← drives behaviour
template_vars.demo_mode = true         ← stays a MANUAL sandbox toggle
```

The three public forms and the cron runner already branch on "capture the contact, skip the enrollment, write the owner notification directly." That branch is Demo Mode, it is live since 2026-08-01, and it is exactly the Starter behaviour.

**Point that branch at `tier === 'starter' || demo_mode === true`.** One condition, two independent reasons.

**❌ Do NOT set `demo_mode = true` on Starter clients.** It is the same engine but the wrong name: the admin UI would show "DEMO" beside a paying customer, and sooner or later somebody toggles it off "because they're a real client" and starts texting people who never consented. Keep the sandbox toggle for sandboxing.

`clients.tier` exists in the schema today and is **read nowhere in app code** — a leftover from the single-tier decision ([[project_backlog_single_tier_consolidation]]). Wiring it is new work, not a revival.

## 3. What can and cannot fire on Starter

Starter never creates an enrollment, so every drip-driven notification is unreachable by construction — not suppressed, structurally impossible.

**Can never fire:** `review_request_final` · `lead_form_day10_reminder` · `reactivation_click` · `one_year_reply_interest` · `one_year_after_sms2` · `one_year_final` · `missed_call` (needs SMS textback)

**Can fire:** `lead_form_business_hours` · `lead_form_after_hours` · `discount_claim` · `ai_chat_lead` (if the widget is on) · `negative_review_feedback` (the review link stays live)

**So only five templates need a Starter variant, not thirteen.** Scope the copy work to those.

## 4. Copy that must differ

### 4a. The wrapper line — affects every email [CONFIRMED]

`src/lib/notifications/email.server.ts:45`

```ts
text: body + "\n\n— Open your app to respond.",
```

Hardcoded, appended to **every** owner email of every type. A Starter client has no app. This single line is the biggest copy leak and the easiest fix: make the suffix tier-aware, e.g. `— Reply to this lead directly.` for Starter.

It is in **version control**, so it is a normal code change.

### 4b. The five reachable template bodies — PENDING AUDIT

**11 of the 13 notification templates are NOT in version control.** Only `demo_request_internal_notify` and `ai_chat_lead_internal_notify` are seeded by migration; the rest exist only as rows in the database. Their copy cannot be reviewed from the repo.

Until the audit in §7 returns, **do not write Starter copy variants** — it would be guessing at text nobody has read.

### 4c. The welcome email — do not send it

`sendClientWelcome` is triggered **manually** from `admin.review.tsx`. Nothing sends it automatically. For Starter you simply never click it, which also solves the app problem, because that email is what reveals the app:

> *"your new website and mobile app are complete and live... create your password, and install your app on your phone"*

It also carries the set-password link. Not sending it means the client is never given app credentials and never learns the app exists.

**Consequence to accept:** a Starter client has no login. If they later need one (upgrade), send the welcome email then.

## 5. Order of operations — Starter delivery [FINITE]

Follow exactly. The point of a fixed order is that nothing gets tangled and no step blocks on a capability this tier does not have.

1. **Set the tier FIRST.** `clients.tier = 'starter'` before anything else touches the client. Every later step reads it. Setting it late is how a Starter client ends up enrolled.
2. **Onboarding form** — agency mode, with the tier selector set to Starter. **Step 5 (A2P) is skipped.** See §5a.
3. **Build the site** — identical to full tier. `new-client-site`, `website-structure`, `seo-build` all apply unchanged.
4. **Forms** — identical wiring. `opt-in-forms` applies unchanged; the difference is downstream, in whether an enrollment is created.
5. **Review link** — set up as normal. The tracked-link endpoint is independent of drips and works identically. Deliver the link to the client.
6. **Verify with `launch-check`, Starter branch.** See §5b.
7. **Deliver.** Tell the client their site is live and that enquiries go straight to their email.
8. **DO NOT** send the welcome email. **DO NOT** mention the app. **DO NOT** start A2P registration.

### 5a. The onboarding conflict — decide this before building

Onboarding step 5 hard-requires EIN, legal name, legal address, vertical and the TCPA attestation:

```js
if (i === 5) {
  if (!s.ein.trim() && !s.noEin)  e.push("EIN is required");
  if (!s.legalName.trim())        e.push("Legal business name is required");
  if (!s.tcpaAttestation)         e.push("TCPA attestation required");
}
```

A Starter client would be hard-blocked there. Two options, and **they are not equivalent**:

- **✅ Preferred — a tier selector on the form (agency mode, step 0).** The form knows, step 5 is skipped, the order of operations stays finite. Costs a small form change and means the tier is chosen *during* onboarding rather than after.
- **❌ Avoid — leave the form alone and have Starter clients tick "No EIN" and accept the TCPA attestation.** Zero code, but it records a TCPA consent attestation for a business that will never send a text. Do not create compliance records that are not true.

**Open decision.** The operator's stated preference was to select the tier *after* onboarding, which conflicts with the form needing to know at step 5. The selector resolves it; nothing else does cleanly.

### 5b. launch-check on Starter

`launch-check` currently treats A2P/10DLC registration and a running cron/sequence engine as **go-live blockers**. A Starter client legitimately has neither.

Without a Starter branch, every Starter launch fails the gate and somebody learns to ignore the gate — which is worse than not having one.

**Starter branch: SKIP** the A2P/10DLC section, the messaging-provider sections, the drip/runner materialization checks, and the outbound-send verification.
**Starter branch: KEEP** CORS + domain allowlist, the bot shield and rate limits on the public forms, RLS, secrets hygiene, the review-link endpoint, and **owner-email delivery** — which for this tier is the *only* lead path and therefore the single most important check.

## 6. Decide once, per tier: the AI chat widget

`ai_chat_lead` fires through the same opt-in path and can run email-only. Include it in Starter or exclude it — but decide before the first client, because changing it afterwards changes what people have already paid for.

## 7. ⛔ OPEN DEPENDENCY — the copy audit

Nothing in §4b can be specified until this returns:

1. The verbatim bodies of all 13 global notification templates (`client_id is null`).
2. **Whether any per-client overrides exist** (`client_id is not null`). If real clients have overridden these keys, a global Starter variant will not reach them and the plan needs a different shape.
3. Every line in those bodies mentioning the app, automation, drips, or texting.

An audit prompt was written 2026-08-04. **Get those bodies into migrations while you are in there** — the fact that 11 of 13 live only in the database has already caused one silent-revert risk ([[project_status_ai_builder_lead_magnet]]).

## 8. Traps

- **⚠️ DOWNGRADE IS DESTRUCTIVE AND IRREVERSIBLE.** The runner's demo-mode guard is terminal: it calls `exitEnrollment(enr, "exited_demo_mode")`. Flipping a client to Starter **permanently exits every in-flight drip**, and moving them back to Full does **not** resume them. New Starter clients are unaffected — no enrollment ever existed. **Block downgrades, or warn explicitly.**
- **Never reuse `demo_mode` as the tier flag.** §2.
- **A Starter client has no registered device**, so push notifications have nowhere to go. Confirm a failed push is silent and cannot error the request.
- **Do not enrol Starter leads into anything, ever** — not even "just the review drip". No consent path exists for this tier, and the phone numbers came from a website form with no SMS opt-in.
- **The tier must be set before the first form submission.** A lead captured while `tier` is unset takes the Full path and gets enrolled.

## 9. Boundaries

- Site build, SEO, photos, forms → unchanged. Use the existing skills.
- Drip message copy → `automation-config`, and it does not apply to Starter.
- The mobile app itself is still built and functional — see `mobile-app`. Starter simply never hands it over.

See [[project_backlog_single_tier_consolidation]] for why `clients.tier` went dormant, and `docs/ONBOARDING-ORDER-OF-OPERATIONS.md` for the full-tier sequence this one branches from.
