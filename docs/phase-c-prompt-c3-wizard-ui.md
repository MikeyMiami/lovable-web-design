# Phase C — C-3 (Onboarding Wizard UI) — slice plan + build prompts

> Slice C-3 of `docs/phase-c-scope.md` — the wizard UI (the big bulk, ~2–3 days). **Additive app-layer frontend only — NO migration, NO server-fn change** (consumes the C-2 fns `createClientFull`/`updateClientSettings` + the B-0 `provisionClientOwner`, all live on origin/main). Baseline stays `golden-master-v1.7`. Sub-sliced (like B-design 2a/2b) so each stage is built + verified independently.

## C-3 decisions locked (2026-06-21)
- **Place ID — DROPPED from the wizard.** `review_place_id` is unused at runtime (no Google Places integration reads it; the review flow uses `review_link` only) and clients can't find it. Remove it from the Review-config step. *(Future enhancement, NOT built: a Google Places "Find Place From Text" on name+address → auto-resolve BOTH `review_link` + `review_place_id`.)*
- **Hours — SPLIT into two distinct fields:**
  - **Public business hours** → CLIENT-filled, writes **`clients.hours`**, tagged "Shows on your website" (Content step).
  - **Private timing hours** (lead-reply in-hours vs after-hours branch) → AGENCY-ONLY, writes **`send_settings.business_hours`** (Step 8, with the other send_settings config).
  - **Both pickers output the canonical shape** `{"mon":["09:00","17:00"],...}` (3-letter lowercase keys, zero-padded 24h `"HH:mm"`, **omit a day = closed**). This also FIXES the current bug: `onboard.tsx` writes `{ raw: "<text>" }` to `send_settings.business_hours` → `isWithinBusinessHours` reads `undefined` → **every lead currently reads as after-hours.**
- **App-layer fn tweak required (NO schema):** add a `hours` field to `ClientFields` + `clientPatch` in `src/lib/clients/onboarding.functions.ts` so `createClientFull`/`updateClientSettings` persist `clients.hours` (the column already exists; the fns just don't accept it yet — confirmed they currently do NOT).
- **`clients.hours` shape contract:** it has **no backend-enforced shape** today (only the PWA Account view reads it, as a raw JSON dump; the marketing template — separate repo — is the real renderer). We define it as the **same** `{"mon":["09:00","17:00"],...}` shape as `business_hours` for one canonical format. Record this contract in `website-structure` when hours-display is built into the style templates so the marketing site reads that shape.

## Slice plan
| Sub-slice | Covers | Validation |
|---|---|---|
| **C-3a — Stepper shell + capture steps + Create** | A standalone agency-gated `/onboard` route + a multi-step **stepper** with the 10 capture steps (text/select fields only; **logo = URL-paste fallback**, photos step deferred). A **Review** final step that assembles the captured state into the `createClientFull` payload and **creates the client** (clients row + `send_settings` + immutable submission JSON). | Walk the wizard as `itsmikeymiami` → fill all steps → Create → a complete client appears in `/admin` Settings; SQL confirms the `clients` row (`template_vars` populated, defaults correct), `send_settings`, and the submission JSON object. |
| **C-3b — Uploads** | Replace the logo URL-paste with a **file-upload → `public-assets`** + `<img>` preview; add the **work-examples photo upload** (→ bucket + a `template_vars.site_assets` manifest). *(Per D6: logo + work-examples now; full per-service/staff categorization = a fast follow-on.)* | Upload a logo + a couple of work photos → files land at the right bucket paths; `logo_url` + `site_assets` set on the client; preview renders. |
| **C-3c — Finalize: pre-gen console + submission viewer + invite + Remix handoff** | Upgrade the Review step into the **pre-gen console** (assemble selections + branding + niche + A2P-prep for a congruence check; **edit-after-create via `updateClientSettings`**); add the **read-only immutable submission viewer** (an `/admin` surface); add the **"Invite client" step** (`provisionClientOwner`) + emit the **Remix handoff checklist**. | Review a created client, edit a field (persists via `updateClientSettings`), view the immutable submission, invite a test email (login minted — the B-0 green path), and see the handoff checklist (slug / env / allowed-origins / matched style). |

**Order:** C-3a → C-3b → C-3c. They're additive; each leaves the wizard working.

## Carried config items — they land in **C-3c (the invite step)**, NOT before
Neither blocks building the capture UI (C-3a/C-3b). Handle at C-3c, and **both must be set before inviting a REAL client**:
- **`VITE_INVITE_REDIRECT_URL`** → repoint from the B-0 temporary target to the **client PWA set-password/callback route** (so the invite magic-link lands the owner on the PWA to set their password). For *testing* C-3c the login still mints; only the redirect UX is affected.
- **Custom SMTP** (Supabase Auth) → so the invite email actually reaches the inbox (the default sender rate-limits + lands in spam). Testing-optional; real-client-required.

---

# PROMPT C-3a — paste into Lovable (stepper shell + capture steps + Create)

> **Build scope: app-layer frontend only. NO migration, NO server-fn / table / RLS change.** Add a new agency-gated `/onboard` route group (a stepper + steps) that captures a new client and calls the EXISTING `createClientFull` server fn. **Logo = URL paste for now (file-upload is C-3b); skip the photo-upload step (C-3b).** Reuse the existing agency-admin role-gate pattern. When done, report files added/changed + confirm no migration and no server-fn change.

Build the **client onboarding wizard** — a multi-step stepper that takes a business from nothing to a created, fully-configured client. Agency-only (`admin`/`agency_owner`). It captures into local component state across steps, then a final **Review** step assembles the payload and calls **`createClientFull`** (from `@/lib/clients/onboarding.functions`).

### Files
| File | Change |
|---|---|
| `src/routes/_authenticated/onboard.tsx` (NEW) | The wizard shell/route: agency role-gate (same pattern as `agency.tsx`) + a stepper (step indicator, Back/Next, per-step validation) holding the captured state + the final Create action. |
| `src/routes/_authenticated/admin.tsx` (MODIFY) | Add ONE "New Client" link to `/onboard` in the sidebar (next to the Agency link). Nothing else. |
| `src/components/onboard/*` (NEW, optional) | Per-step form components if you prefer to split them out (Identity, Content, Branding, NicheStyle, ReviewConfig, Offers, Config, A2P, Review). |

### Role gate (reuse the `agency.tsx` pattern)
```tsx
const { data: isAgencyAdmin, isLoading } = useQuery({
  queryKey: ["onboard-authz"],
  queryFn: async () => {
    const { data, error } = await supabase.from("user_roles").select("role").in("role", ["admin","agency_owner"]);
    if (error) throw error; return (data ?? []).length > 0;
  }, staleTime: 60_000,
});
// !isAgencyAdmin → "Not authorized". Otherwise render the stepper.
```

### The capture steps (state keys → where they go in the `createClientFull` payload)
Hold one state object; each step writes its slice. **The mapping is the `onboard-from-form` contract** — assemble into `{ slug, fields, sendSettings, submission }` at Create.

1. **Identity** — owner full name; official business name; **slug** (auto-suggest from business name, lowercase-hyphen, editable); business phone; display address; website; notification email.
   → `fields.businessName`; `slug`; `fields.callForwardingNumber` (= business phone, seed); `fields.address`; `fields.notificationEmail`; `templateVars.company_name` (= business name), `templateVars.company_owner_first_name` (= first token of full name), `templateVars.company_website_link`.
2. **Content (AI-knowledge)** — About Us; all services; differentiators; service areas (≤14, list); business hours.
   → `templateVars.about_us` / `.services` / `.differentiators`; `fields.serviceArea[]`; `sendSettings.businessHours`.
3. **Branding** — logo URL (paste for now); primary/secondary/tertiary brand colors.
   → `fields.logoUrl`; `fields.brandColor` (primary); `templateVars.brand_secondary` / `.brand_tertiary`.
4. **Niche + style** — niche/segment (select); site style (1 of `corporate|standard|family_owned|owner_operated`).
   → `templateVars.segment`; `fields.siteStyle`.
5. **Photos** — *placeholder step in C-3a* ("uploads come next slice"); no writes.
6. **Review config (agency)** — Google review link + Place ID; star threshold (def 4); review toggle (gated/direct); the business's direct review URL.
   → `fields.reviewLink`, `fields.reviewPlaceId`, `fields.starThreshold`, `fields.googleReviewToggle`; `templateVars.review_request_link`.
7. **Offers** — return/referral discount + amount.
   → `templateVars.discount__on_referral` / `.discount_amount`.
8. **Config (agency)** — timezone; SMS send window (start/end); daily send cap; daily enrollment cap; marketing domains (allowed origins, list); quote-form link; terms page link.
   → `sendSettings.timezone` / `.smsSendWindow` / `.dailySendCap` / `.dailyEnrollmentCap`; `fields.allowedOrigins[]`; `templateVars.quote_form_link` / `.website_terms_page_link`.
9. **A2P-prep (prepares, does not submit)** — EIN; legal name / DBA; entity type; vertical; TCPA attestation. **No standing columns** (D5): the anon-safe ones (e.g. vertical/segment) → `templateVars`; the PII (EIN, legal name) → the **submission** only.
   → `submission.*` (EIN, legal_name, entity_type, dba, tcpa_attested, vertical, shipping_address); `templateVars` for anon-safe values. (`a2p_status` is left at its DB default `not_started`.)
10. **Review (pre-gen — basic in C-3a)** — show a summary of everything captured; **Create** assembles + calls `createClientFull`.

### Create action (assemble + call the live fn)
```tsx
import { createClientFull } from "@/lib/clients/onboarding.functions";
// ...assemble `fields`, `sendSettings`, `submission`, `slug` from state, then:
const res = await createClientFull({ data: { slug, fields, sendSettings, submission } });
// res.clientId — show a success screen with the new clientId + a "Go to client in Admin" link
// and a note: "Logo/photo uploads, review & invite come next." (C-3b/C-3c)
```
- **Slug collision:** if `createClientFull` throws `"… is already taken"`, surface it on the Identity step (let them edit the slug + retry).
- Put the whole `submission` = the raw captured answers (including the PII fields) so the immutable record is faithful.

### Security / invariants
- Agency-gated (`admin`/`agency_owner`); a `client_owner` hitting `/onboard` sees "Not authorized."
- The wizard writes NOTHING directly — the only mutation is `createClientFull` (which re-verifies role server-side). No `supabaseAdmin` in the route.
- Required-field validation per step before Next (at minimum: business name + slug; About Us; services; hours — the `onboard-from-form` "(req)" fields).

### Drift check (report back)
1. Added: `src/routes/_authenticated/onboard.tsx` (+ any `src/components/onboard/*`); changed: `admin.tsx` (one "New Client" link).
2. No migration; no server-fn / table / RLS change; no `supabaseAdmin` in the route; `createClientFull` imported from `@/lib/clients/onboarding.functions`.
3. Build compiles.

---

# VALIDATION — C-3a (as `itsmikeymiami`)
1. `/onboard` reachable from the admin sidebar; gated (a non-admin would see "Not authorized").
2. Walk all steps (use slug **`c3-test-co`**); required-field validation blocks Next when empty.
3. **Create** → success screen with a `clientId`; "Go to client in Admin" opens it in `/admin` Settings showing the captured values.
4. SQL spot-check:
```sql
select id, slug, business_name, site_style, brand_color, template_vars, google_review_toggle, star_threshold,
       status, access_suspended, a2p_status
  from public.clients where slug='c3-test-co';   -- row complete; defaults active/false/not_started; template_vars has segment/about_us/services
select timezone, sms_send_window, daily_send_cap, daily_enrollment_cap, business_hours
  from public.send_settings where client_id=(select id from public.clients where slug='c3-test-co');
```
5. **Slug collision:** run Create again with `c3-test-co` → the Identity step shows "already taken."

**Cleanup:** `delete from public.clients where slug='c3-test-co';` (cascades `send_settings`). The submission JSON object is a harmless private-bucket artifact (remove via the Storage dashboard if you want it gone). *(Keep the wizard route — it's the product, not a throwaway.)*

### After C-3a is green
→ **C-3b (uploads)** — logo file-upload + work-examples photos.

---
**App-layer only. No migration. Baseline `golden-master-v1.7` unchanged. C-3a → C-3b → C-3c.**
