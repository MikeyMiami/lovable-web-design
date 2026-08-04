# AI Builder — ▶ UNBLOCKED 2026-08-03 via manual entry — READ THIS FIRST

> **2026-08-03 — the Places blocker is ROUTED AROUND, not resolved.**
> Prompt 4 is re-specified with a typed **business name + phone** on step 1 instead of Google autocomplete, so the funnel can collect leads now without the ~$10 billing verification.
> **Use `ai-builder-prompt-4-MANUAL-business-name.md`.** The original `ai-builder-prompt-4-wizard-builder-mode.md` is kept for when Places is funded.
>
> **What this costs:** the Google Business Profile requirement was a quality gate and pre-filled six fields. Manual entry means more typos and junk, a longer form, and no dedupe by place id. Accepted deliberately to start collecting leads.
>
> **Places upgrade path:** step count, step slots and the `placeId` field are all preserved, so reinstating Places replaces ONE component (`BusinessStep` → `PlacesStep`). No renumbering, no schema change, no migration.
>
> **Still blocked on billing:** prompt 3 self-checks 5–7 only.

---

## Where we stopped

| # | Artifact | State |
|---|---|---|
| 0 | `ai-builder-migration.sql` | ✅ **SHIPPED** — migration `20260801150417`, commit `b35bb43` |
| 1 | `ai-builder-prompt-1-tenant-and-notify.md` | ✅ **SHIPPED + validated** — commit `a7b498a` |
| 1b | `ai-builder-prompt-1b-provision-login.md` | ✅ **COMPLETE** — login live, push received on phone end-to-end |
| 2 | `ai-builder-prompt-2-demo-insert-refactor.md` | ✅ **SHIPPED + validated** — `demo.functions.ts` +236 −75 |
| 3 | `ai-builder-prompt-3-places-proxy.md` | 🟡 **CODE SHIPPED, 8/11 checks green.** Checks 5, 6, 7 **BLOCKED** on the Google key (403 `PERMISSION_DENIED`) |
| 3b | `ai-builder-prompt-3b-internal-tenant-guard.md` | ✅ **SHIPPED + validated** — internal-tenant exposure closed |
| 4 | `ai-builder-prompt-4-MANUAL-business-name.md` | ⬜ **READY TO RUN** — no Places key needed |
| 4-orig | `ai-builder-prompt-4-wizard-builder-mode.md` | 🅿️ Parked — the Places version, for when billing is funded |
| 5 | `ai-builder-prompt-5-generate-route.md` | ⬜ Not started — needs 4. **Read the carried-forward notes at the end of prompt 4-MANUAL first** — three of its self-checks assume a real place id |
| 6 | `ai-builder-prompt-6-agency-requests.md` | ⬜ Not started — needs 5 |

**Prompts 4–6 can now proceed.** Only prompt 3's checks 5–7 remain gated on the Google key, and nothing downstream depends on them while step 1 is manual.

---

## ✅ CLOSED — the internal-tenant exposure (fixed before pausing)

**Prompt 3b SHIPPED + validated 2026-08-01.** `src/lib/tenant-resolver.server.ts` +10 −8: `is_internal` added to the `.select` and to the refusal in **both** `resolveTenantByOrigin` and `resolveTenantBySlug`; `resolveTenantByNumber` confirmed untouched by grep.

Validated live: all three real-client public paths (`intake` / `discount` / `chat/optin`) still return `200` and create contacts+enrollments normally on `central-florida-landscaping`, across **both** the origin-resolved and slug-fallback paths. The same three with `slug: "pierceworks"` return `403 unknown_tenant`, and PierceWorks row counts are `contacts 0 / enrollments 0 / messages 0 / conversations 0`. (`events 2` is pre-existing append-only log noise, not from the test.) `audit_tenant_rls()` still baseline-4.

**One untested path, recorded honestly:** the demo-slug → 403 check could not be executed because no demo clients exist in the DB right now. The `is_demo` branch is *unchanged* code — only OR'd with the new condition — so regression risk is nil, but it is verified by inspection rather than execution. **Re-run it the next time a demo client exists** (it will, in prompt 5's validation).

<details>
<summary>Original finding, kept for context</summary>

**Finding (2026-08-01): the PierceWorks internal tenant was publicly resolvable.**

`resolveTenantBySlug` (`src/lib/tenant-resolver.server.ts:73-91`) matches on `slug` + `status='active'` + `deleted_at is null`, and **explicitly refuses only `is_demo === true`** (line 85). Its own comment (line 83) records why: *"Slug resolution never checks `allowed_origins` and templates post `slug` in every form body — so demos must be refused explicitly here."*

PierceWorks is `status='active'`, `is_demo=false`, `is_internal=true` → **it resolves.** `allowed_origins='{}'` does not help, because slug resolution never consults it.

**Exposure:** a crafted POST to `/api/public/intake`, `/api/public/discount` or `/api/public/chat/optin` carrying `slug: "pierceworks"` creates a `contacts` row and an `enrollments` row on the internal tenant. `claim_due_enrollments` filters only `c.status='active' AND c.deleted_at IS NULL`, which PierceWorks passes — so the drip runner picks it up, finds no messaging config, and the enrollment **stalls in a `send_config_missing` retry loop**. That is precisely the failure mode the Demo Clients spec §4 Layer 2 was built to prevent; `is_internal` simply was not in scope when that guard was written.

**Mitigating factors (why this is moderate, not urgent):** the attacker must know or guess the slug `pierceworks`, and the three public lead forms are behind the native PoW bot shield. No exposure exists today from normal traffic.

**Fix — one line in each of two functions.** See `ai-builder-prompt-3b-internal-tenant-guard.md`.

</details>

---

## Is the platform safe in its current state? — audit

**Yes, once the fix above ships.** Everything else was checked:

| Area | State |
|---|---|
| **Migration** | Purely additive. Every new column is nullable or defaulted; the two check constraints allow `null`. Existing rows untouched (16 pre-existing tokens all read `source='agency'`). Zero risk. |
| **`createDemoClient` / `/agency/demos`** | Regression-verified: an agency-created row is byte-identical to pre-refactor apart from `demo_source='agency'`, `demo_status=null`, `demo_place_id=null`. |
| **`purgeDemoClient`** | `is_demo === true` re-read guard intact. The new recursive storage walk is safe by construction — only a bare top-level segment starting with `demo-` reaches `purgePublicPrefix`; anything containing `/` gets a single-object remove. It cannot wander into another tenant's prefix. |
| **Notification changes** | Additive only — one new `NotificationType` and three map entries. Dispatch, email mirror and push mirror untouched. |
| **The three `is_internal` filters** | Applied to `agency.access.tsx`, `admin.tsx`, `listSeoStatus`. Real clients verified still passing all three. |
| **New public builder routes** | `challenge` and `start` are live and unauthenticated but **harmless**: PoW-gated, IP rate-limited (30/600s and 10/600s), and they only write throwaway `onboarding_tokens` rows. `places/*` requires a valid builder token, and Google currently refuses the key, so **no spend is possible**. Leave them — they are validated, and removing them is churn. |
| **Drip runner** | Unaffected. PierceWorks has zero enrollments (guaranteed once the fix above ships). |
| **`audit_tenant_rls()`** | Still the known baseline of 4. Nothing we added has a `client_id` column or an RLS policy. |

**One operational consequence to remember:** `michael@pierceworks.co` **can no longer log into Central Florida Landscaping's client PWA** — that grant was revoked so PWA tenant resolution would be deterministic. If CFL PWA access is ever needed again, re-grant via `assignUserRole`, but expect the `.limit(1)` ambiguity to return.

---

## ⚠️ Template drift — the demo_request body is NOT in migration history

**2026-08-03.** The `demo_request_internal_notify` body was reordered (business
name + business phone first, the person's cell below) as a **live data edit**,
per a workspace rule against committing data ops as migrations.

Migration `20260801150417` still seeds the OLD body — the one without
`{business_phone}`. **If this database is ever rebuilt from migrations, or a
fresh environment is stood up, the alert silently reverts**: the business phone
disappears, nothing errors, and the first sign is an alert that looks wrong.

Note the precedent cuts the other way: that original body WAS seeded by a
migration in this repo, so an idempotent upsert would be consistent with
existing practice rather than a new data-op exception. A prompt for that fix
was written 2026-08-03; if it was never run, this note is the only record.

Current intended body:

```
New demo request

{business_name}
{business_phone}

{full_name}
{phone}
{email}
{city}

{build_notes}

Submitted {request_time}
```

---

## Open items carried into the backlog

1. **[DEFERRED, no longer a blocker] Google Cloud billing** — ~$10 verification. Now gates only prompt 3's checks 5–7 and the eventual `BusinessStep` → `PlacesStep` upgrade. The funnel ships without it.
2. **[CHECK WHEN UNBLOCKED] Places pricing tier.** Never estimated on purpose. Confirm the per-SKU cost of the prompt-3 field mask before launch and size the budget alert from it. If it looks expensive, the cheapest cut is dropping `websiteUri` (stored only as competitive context). `nationalPhoneNumber` and `regularOpeningHours` must stay — they are the auto-fill and the anti-bounce phone capture.
3. **[LATENT BUG, not ours] `app.tsx:42-54`** resolves the PWA tenant with a bare `.limit(1).maybeSingle()` and no `ORDER BY`. Any user holding `client_owner` on two tenants gets a nondeterministic tenant. Fix before any real client ever owns two.
4. **[BACKLOG] Downstream AI site-generation cost per lead** — still unanswered from the original lead-magnet scoping. The economics question this whole feature rests on.
5. **[DEFERRED] Prompt 2 checks 2/4/5** — the template-remix render and live storage-prefix purge could not run in a sandbox. Fold them into prompt 5's validation, where a real generated demo with real uploads exists.

---

## Hard-won facts — do not re-derive these

- **`public.clients` has NO `timezone` column.** It exists only on `send_settings` (`20260609034320` §9). And `get_client_public` projects `hours` + `template_vars` but no timezone — so `template_vars.timezone` is the *only* path that reaches the marketing template. Do not add the column.
- **`audit_tenant_rls()` baseline is 4, not 0.** `client_provider_secrets` (zero-policy service-role-only, deliberate) + `push_subscriptions` ×3 (keyed on `user_id`). Assert "no new rows". **Never "fix" these four** — adding a policy to `client_provider_secrets` would weaken it.
- **`writeNotification` needs BOTH `submittedAt` and `action` passed explicitly.** `ACTION_BY_TEMPLATE_KEY` is consulted only by `writeNotificationByTemplateKey`; the direct caller's `action` is inserted verbatim. Proven empirically — both are already in prompt 5.
- **The Lovable sandbox is signed out** and cannot invoke session-gated server fns. Workaround: call the underlying audited RPCs directly with the platform-admin actor. Never a raw DELETE/INSERT on `user_roles`.
- **Host redirects belong in `hostRedirect()` (`src/server.ts:66-84`)**, which runs before the app handler — not in a route's `beforeLoad`. Already corrected in prompt 4 §7b.
- **`sendClientWelcome` throws unless `template_vars.company_website_link` is set** (`welcome.functions.ts:112`).

## Key IDs

```
PierceWorks client      93624096-20d3-4086-99d8-70338cfc5f88
michael@pierceworks.co  f8be84c7-20d0-4fd1-a25a-bfdc9c92b03a  (auth user, created 2026-07-24)
platform admin actor    775d20b1…  (itsmikeymiami@gmail.com)
CFL client (disposable) 0dce803a-1c4e-488b-94cf-860e6089cdd1
builder domain          aibuilder.pierceworks.co  (live, serves cloud-spark-setup)
```

## Prompt artifacts

All in `lovable-web-design/docs/`, and mirrored in the copy-ready page at
`https://claude.ai/code/artifact/a7a38cc8-3b70-4821-9461-68b7a22f6d0a`.
