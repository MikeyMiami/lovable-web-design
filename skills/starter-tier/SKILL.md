---
name: starter-tier
description: Use when onboarding, delivering, or supporting a client on the $97/mo STARTER plan — website + forms with email-only lead alerts, no SMS automations, no mobile app handover. Starter is a per-client SWITCH (`template_vars.starter_mode`) reusing the proven demo-mode branch. Defines the switch, the copy that changes, the delivery order, and the one-way downgrade trap. NOT the full-plan flow (use onboard-from-form / new-client-site) and NOT drip copy (use automation-config).
---

# Starter Plan — $97/mo website, email-only leads

**One sentence:** the same site, the same forms, the same review funnel — but a lead notifies the owner **by email only**, nothing is ever texted, and the client is never told an app exists.

> **STATUS 2026-08-04: SPECIFIED, NOT BUILT.**

---

## 1. The switch

```
template_vars.starter_mode = true      ← the Starter plan
template_vars.demo_mode    = true      ← unchanged, still a sandbox toggle
```

Both point at the **same existing branch**: capture the contact, skip the enrollment, write the owner notification directly. That branch is live on all three public forms and in the cron runner since 2026-08-01.

**Two flags, one behaviour, different meanings.** Never set `demo_mode` on a paying client — the admin UI would show "DEMO" beside a real customer, and eventually somebody turns it off "because they're real" and starts texting people who never opted in.

`clients.tier` exists in the schema and is read nowhere. **Ignore it.** A boolean switch is the whole design; a tier enum was considered and rejected as unnecessary machinery.

## 2. What changes, and what does not

| | Starter | Full |
|---|---|---|
| Website, SEO, photos, forms | ✅ identical | ✅ |
| Lead alert to owner | **email only** | email + push + SMS drip |
| SMS drips / missed-call textback | ❌ never | ✅ |
| A2P / 10DLC | not needed | required |
| Mobile app | built, **never handed over** | handed over |
| Welcome email | **never sent** | sent |
| Google review link + funnel | ✅ identical | ✅ |
| Chat widget | ✅ included, email-only | ✅ |

**Commercially:** no 10DLC campaign, no per-message cost, no TCPA exposure. That removes the slowest and riskiest part of onboarding, which is most of why the plan is worth selling.

## 3. Flipping the switch

**Starter → Full (upgrade): clean.** A client who was always Starter has no enrollments — nothing was ever created. Flip it off and the next lead enrolls normally. Leads captured during Starter stay as plain contacts and do **not** retroactively enroll, which is correct: they arrived under a no-SMS arrangement.

**⚠️ Full → Starter (downgrade): DESTRUCTIVE AND ONE-WAY.** The runner guard is terminal:

```ts
if (demoModeClients.has(cid)) {
  await exitEnrollment(enr, "exited_demo_mode");   // terminal
```

One call site, **no resume path anywhere in the codebase**. Flipping Starter on for an existing Full client permanently exits every in-flight drip; flipping back does not revive them. Those contacts never receive the rest of their sequence.

**Selling Starter to new clients is safe. Downgrading an existing client is not.** Block it or warn hard.

## 4. Copy — the complete audit [repo side verified 2026-08-04]

**Only two places in the entire codebase mention the app to a client:**

### 4a. `src/lib/notifications/email.server.ts:45` — MUST FIX

```ts
text: body + "\n\n— Open your app to respond.",
```

Hardcoded, appended to **every** owner email of **every** type. A Starter client has no app. Make the suffix starter-aware — e.g. `— Reply to this lead directly.` This one line covers all 13 notification types.

### 4b. `src/lib/clients/welcome.functions.ts` — DO NOT SEND

> *"your new website and mobile app are complete and live... create your password, and install your app on your phone"*

Triggered **manually** from `admin.review.tsx`; nothing sends it automatically. Not sending it is the entire fix for app-secrecy, and it also withholds the set-password link.

**Consequence to accept:** a Starter client has no login. If they upgrade, send the welcome email then.

### 4c. Verified clean — no change needed

`tickets/notify.server.ts` · `api/public/r/feedback.ts` · `sendOnboardingLinkEmail` (operator composes subject/body) · the cron runner's own strings.

**Push is safe:** dispatch is fire-and-forget with `.catch()`, so a Starter client with no registered device fails silently and cannot error a request.

### 4d. Template bodies — check, do not assume

**11 of 13 notification templates live only in the database**, not in migrations. Only `demo_request_internal_notify` and `ai_chat_lead_internal_notify` are seeded in the repo.

Only **five** are reachable on Starter — the rest require an enrollment, which Starter never creates, so they are structurally impossible rather than suppressed:

- `lead_form_internal_notify`
- `lead_form_after_hours_owner_internal`
- `discount_claim_internal_notify`
- `ai_chat_lead_internal_notify`
- `negative_review_feedback_internal` *(the review link stays live)*

These are lead alerts — name, phone, email, message — so they most likely contain **no** app or automation language. Check them; do not rewrite them on spec. **Also confirm no per-client overrides exist** (`client_id is not null`), or a global fix will not reach those clients.

## 5. Delivery order [FINITE]

1. **Flip `starter_mode` ON before the first form submission.** A lead captured while it is off takes the Full path and enrolls into a drip — on a client with no consent record.
2. **Onboard using the normal form.** Step 5 hard-requires EIN / legal name / TCPA attestation: tick **"No EIN"** and move through. The attestation is collected and never acted on — untidy, not dangerous, because `starter_mode` is the real gate.
3. **Build the site** — identical. `new-client-site`, `website-structure`, `seo-build` unchanged.
4. **Forms** — identical wiring (`opt-in-forms`). The difference is downstream: no enrollment.
5. **Review link** — set up and deliver as normal. Independent of drips.
6. **Verify** — see §6.
7. **Deliver:** tell the client their site is live and enquiries go straight to their email.
8. **DO NOT** send the welcome email · **DO NOT** mention the app · **DO NOT** start A2P.

## 6. launch-check on Starter

`launch-check` treats A2P/10DLC and a running cron engine as go-live blockers. A Starter client legitimately has neither, so without a Starter branch every launch fails the gate — and people learn to ignore the gate, which is worse than not having one.

**SKIP:** A2P/10DLC, messaging-provider config, drip/runner materialization, outbound-send verification.
**KEEP:** CORS + domain allowlist, bot shield + rate limits on the public forms, RLS, secrets hygiene, review-link endpoint, and **owner-email delivery** — for this plan it is the *only* lead path and therefore the single most important check.

## 7. Traps

- **Downgrade is one-way** — §3.
- **Set the switch before the first lead** — §5.1.
- **Never `demo_mode` on a paying client** — §1.
- **Never enroll a Starter lead into anything**, not even "just the review drip". No consent path exists for this plan.
- **The chat widget is INCLUDED in Starter** (decided 2026-08-04) and needs no special handling. It is **not AI** — capture-first since 2026-07-16, a chat-skinned opt-in form that posts to `/api/public/chat/optin` exactly like the lead form. The `ai_chat_lead*` template keys are legacy identifiers from a PARKED design; see `/chat-widget`.

## 8. Boundaries

Site build, SEO, photos and forms are unchanged — use the existing skills. Drip copy is `automation-config` and does not apply here. The app is still built and functional (`mobile-app`); Starter simply never hands it over.

See `docs/ONBOARDING-ORDER-OF-OPERATIONS.md` §1b for where this branches from the full sequence.
