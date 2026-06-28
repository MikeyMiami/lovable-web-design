# Phase C — Move the Google review link → agency-set; capture Google Business Profile link at onboarding

> Follow-on onboarding→agency move (same principle as the discount). **App-layer only — no schema, no migration, no fn-contract change.** Grounded on `cloud-spark-setup` `origin/main` @ `9319873`.

> **SHIPPED + VALIDATED 2026-06-28.** Built + SQL-validated (test client `test-landscaping` + admin-merge path). **Delta vs the Prompt B below:** the Google Business Profile link shipped **EDITABLE in admin Review Config**, not read-only. As built: `review` state gained `google_business_profile_link` (seeded from `client.template_vars` directly — TDZ-safe, since `initialVars` is declared after the `review` state), the field is an editable `<Input>`, and the section `onSave` overlays `google_business_profile_link` into the same merge-safe `base` object alongside `review_request_link` (full `template_vars` written, JSON textarea re-seeded). Everything else in Prompt B shipped as written.

## Scope / plan — read first

**Goal:** the *precise* Google review URL must be formatted correctly to work → that's the agency's job, set in admin Settings per client. At onboarding the client instead gives their **Google Business Profile link** (easy to find) so the agency can look them up and set the correct review link.

### Findings (verified @ `9319873`)
1. **Is `review_link` already editable in admin? YES.** `admin.settings.tsx` → "Review Config" section already round-trips `review_link` (+ `review_place_id`, `star_threshold`, `google_review_toggle`) via the `review` state → `saveClient.mutate(...)` (direct-RLS `clients` update). **No new editor needed** for `review_link` — it's already there.
2. **`review_link` vs `review_request_link` (consumers):**
   - `clients.review_link` (column) — the formatted Google review destination. **Funnel redirects** read it (`r/$token.ts:119`, `r/rate.ts:135` → `dest = client.review_link`); PWA account displays it (`app.account.tsx`). Must be correctly formatted → **agency-set**.
   - `template_vars.review_request_link` — a **static message merge value** (the business's own Google review URL, merged into message text; `runner.server.ts:832`). In messages this is distinct from `{review_link}`, which is a **per-contact tracked** link (`trackedLinkUrl(token)`, `runner.server.ts:863`) that 302-redirects to `clients.review_link`.
   - Today the wizard sets BOTH `clients.review_link` (via `fields.reviewLink`) and `template_vars.review_request_link` from the one onboarding field.
3. **What `review_request_link` should do now → MOVE to agency-set (do NOT derive from the Business Profile link).** It needs the same correctly-formatted Google URL as `review_link` (a GBP link is the wrong URL for messages). **Recommendation: keep it in sync with the column** — when the agency saves the "Review link" in admin Review Config, also write `template_vars.review_request_link` = the same value (read-merge-write + dual-writer guard, exactly like the discount). One agency action sets both; no drift. *(Alternative: leave `review_request_link` to be hand-edited in the Template Variables JSON textarea — more manual, drift-prone. Not recommended.)*

### #2 Business Profile link — storage home (NO schema)
**Recommend `template_vars.google_business_profile_link`.** Rationale:
- **No schema** (open jsonb). Captured by the wizard at onboarding; also lands in the immutable `submission` JSON automatically (the assembly spreads `...s`), giving a durable raw copy.
- **Viewable in admin TODAY** — it shows in the existing Template Variables JSON textarea immediately, and the build adds a friendly **read-only display in the Review Config section** so the agency sees it right next to the `review_link` input it needs to set.
- **Not rendered on the public site** — no template references `{google_business_profile_link}`, so it won't appear anywhere on the marketing site.
- **Caveats (both harmless):** it's anon-readable via `get_client_public` (it's a *public* GBP URL — no PII/secret), and it's iterated into the AI-chat knowledge prompt (`knowledge.server.ts` reads the full `template_vars`) — a stray URL, harmless.
- *(Alternatives considered: `social_links.google_business_profile` — but social_links renders in the site footer/contact, which we don't want for an internal lookup value; `submission`-only — semantically clean + private, but not conveniently viewable until the [BUILD] submission viewer exists. `template_vars` wins for "agency must view + act on it now.")*

### #5 Round-trip walkthrough (the core question) — confirmed
- **Onboarding:** client enters their **Google Business Profile link** → wizard writes `template_vars.google_business_profile_link` (+ an immutable copy in `submission`). The wizard **no longer writes** `clients.review_link` or `template_vars.review_request_link`.
- **Admin (agency):** open the client's Settings → **Review Config** shows the **GBP link (read-only)** → the agency looks the business up on Google → enters the correctly-formatted **"Review link (Google URL)"** → **Save** writes `clients.review_link` **and** syncs `template_vars.review_request_link` to the same value (+ re-seeds the JSON textarea).
- **Consumers:** funnel (`r/$token`, `r/rate`) → `clients.review_link`; messages → `{review_request_link}` (static) + `{review_link}` (per-contact tracked → redirects to `clients.review_link`); PWA account → `clients.review_link`.
- **Confirms:** the admin can **READ** the GBP link (`template_vars.google_business_profile_link`, surfaced in Review Config + the JSON textarea) AND **WRITE** `review_link` (the existing Review Config input). ✔

### App-layer / contract
**No schema, no migration, no fn-contract change** across all files. (`createClientFull`/`ClientFields` already accept `templateVars` + `reviewLink`; we just stop sending `reviewLink` and add a `template_vars` key — both ride the open jsonb.)

### Affected files
- `src/routes/_authenticated/onboard.tsx` — Step-6 field, state, assembly.
- `src/components/onboard/ReviewSummary.tsx` — Reviews section label/value.
- `src/routes/_authenticated/admin.settings.tsx` — Review Config: read-only GBP display + sync `review_request_link` on save.
- Skills: `onboard-from-form` (Reviews step now captures the GBP link; `review_link`/`review_request_link` agency-set), `admin-view` (Review Config: GBP link viewable + `review_request_link` synced to `review_link`).

---

# PROMPT A — Onboarding wizard (paste into Lovable)

> **App-layer / UI only. No migration, no schema/fn-contract change.** Replace the Step-6 review-link field with a Google Business Profile link field; stop the wizard setting `review_link` / `review_request_link`; store the GBP link in `template_vars`. Report files changed + confirm no migration. *(Independent of the discount-move change; anchor by name, not line number.)*

## File 1: `src/routes/_authenticated/onboard.tsx`
1. **State type** — rename `reviewLink: string;` → `googleBusinessProfileLink: string;`.
2. **State init** — rename `reviewLink: "",` → `googleBusinessProfileLink: "",`.
3. **Step 6 · Reviews UI** — replace the existing field:
   ```tsx
   <Field
     label="Google Business Profile link"
     tag="So we can find your business"
     tagTone="private"
     hint="Paste the link to your Google Business Profile (your business listing on Google Maps/Search). We use it to look you up and set up your review link correctly — this is NOT shown on your website."
     example="https://maps.app.goo.gl/XXXXXXXX"
   >
     <Input
       value={s.googleBusinessProfileLink}
       onChange={(e) => update("googleBusinessProfileLink", e.target.value)}
       placeholder="https://maps.app.goo.gl/…"
     />
   </Field>
   ```
4. **Assembly (`buildPayload`)**:
   - In `templateVars`, **remove** `review_request_link: s.reviewLink || undefined,` and **add** `google_business_profile_link: s.googleBusinessProfileLink || undefined,`.
   - In `fields`, **remove** `reviewLink: s.reviewLink || undefined,` (the wizard no longer sets `clients.review_link`).
   - `submission` spreads `...s`, so `googleBusinessProfileLink` is captured in the immutable record automatically; `reviewLink` drops out once removed from state.
5. Confirm **no remaining references** to `reviewLink` / `review_request_link` in `onboard.tsx`. *(`review_link` lookups elsewhere in the app are unaffected — only the wizard stops writing it.)*

*(Optional, your call: the GBP link can be left optional, like the old review-link field — no validation added. Say if you want it required to advance.)*

## File 2: `src/components/onboard/ReviewSummary.tsx`
Update the Reviews section:
```tsx
<Section title="Reviews">
  <Row label="Google Business Profile link" value={s.googleBusinessProfileLink || undefined} />
</Section>
```

## Drift check (report back)
1. `onboard.tsx` (state rename, Step-6 field, assembly: −`review_request_link`, −`fields.reviewLink`, +`google_business_profile_link`) + `ReviewSummary.tsx` (Reviews row).
2. **No migration, no schema, no fn-contract change.**
3. Payload no longer sets `clients.review_link` or `template_vars.review_request_link`; `template_vars.google_business_profile_link` is set; submission carries the GBP link.

## Validation (as `itsmikeymiami`)
Walk the wizard: Step 6 asks for the **Google Business Profile link** (not a review link). Create a client (slug `gbp-test`):
```sql
select template_vars->>'google_business_profile_link' as gbp,
       template_vars ? 'review_request_link' as has_rrl,
       review_link
from public.clients where slug='gbp-test';
-- EXPECT: gbp = the entered URL; has_rrl = false (wizard no longer sets it); review_link = NULL (agency sets later).
```
Cleanup: `delete from public.clients where slug='gbp-test';`

---

# PROMPT B — Admin Review Config (paste into Lovable AFTER A)

> **App-layer / UI only. No migration, no schema/fn-contract change.** In the per-client Settings "Review Config" section: show the onboarding **Google Business Profile link** (read-only) and, on save, keep `template_vars.review_request_link` in sync with the `review_link` column. **⚠️ MERGE:** writing `template_vars` REPLACES the jsonb — write the FULL object with `review_request_link` overlaid, never just that key. Report files changed + confirm no migration.

## File: `src/routes/_authenticated/admin.settings.tsx`
In the **"Review Config"** `<Section>`:

1. **Add a read-only GBP display** (above the "Review link" input), reading from the loaded row:
   ```tsx
   <Field
     label="Google Business Profile link (from onboarding)"
     hint="The client's GBP link from onboarding — use it to look them up and set the correctly-formatted Review link below."
   >
     {(client.template_vars as any)?.google_business_profile_link ? (
       <a
         className="text-sm text-primary underline-offset-2 hover:underline break-all"
         href={(client.template_vars as any).google_business_profile_link}
         target="_blank"
         rel="noreferrer"
       >
         {(client.template_vars as any).google_business_profile_link}
       </a>
     ) : (
       <span className="text-sm text-muted-foreground italic">Not provided at onboarding</span>
     )}
   </Field>
   ```
2. **Sync `review_request_link` on save** — replace the section's `onSave` with a merge-safe write that sets the column AND the matching message merge value, then re-seeds the JSON textarea (dual-writer guard):
   ```tsx
   onSave={() => {
     const base = { ...(client.template_vars ?? {}) } as Record<string, any>;
     const rl = review.review_link.trim();
     if (rl) base.review_request_link = rl; else delete base.review_request_link;
     saveClient.mutate({
       review_place_id: review.review_place_id || null,
       review_link: rl || null,
       star_threshold: Number(review.star_threshold),
       google_review_toggle: review.google_review_toggle,
       template_vars: base,                                 // keep review_request_link in sync with the column
     });
     setTemplateVarsText(JSON.stringify(base, null, 2));    // dual-writer guard: re-seed the JSON textarea
   }}
   ```
   (`review.review_link`, `saveClient`, and `setTemplateVarsText` all already exist on this page. `review_request_link` stays in `REQUIRED_TEMPLATE_VARS` → still flagged when blank.)

**Do NOT** use `updateClientSettings` (it replaces `template_vars`) — keep the existing direct-RLS `saveClient` mutation.

## Drift check (report back)
1. `admin.settings.tsx` only (Review Config: read-only GBP `<Field>` + merge-safe `onSave` syncing `review_request_link` + textarea re-seed).
2. No `updateClientSettings`, no server-fn, no schema, no fn-contract change.
3. The save writes the FULL `template_vars` (merge — no clobber).

## Validation (as `itsmikeymiami`)
On the `gbp-test`-style client (has `google_business_profile_link`, has populated `template_vars`):
1. Open Settings → Review Config shows the **GBP link** (clickable, read-only).
2. Enter a "Review link (Google URL)" → **Save**:
   ```sql
   select review_link,
          template_vars->>'review_request_link' as rrl,
          template_vars->>'google_business_profile_link' as gbp,
          template_vars ? 'about_us' as keep_about, template_vars ? 'services' as keep_services
   from public.clients where id='<clientId>';
   -- EXPECT: review_link = entered URL; rrl = SAME URL (synced); gbp still present;
   --         keep_about / keep_services STILL true (merge, no clobber).
   ```
3. Clear the Review link → Save → `review_link` NULL and `review_request_link` removed; GBP + other keys still present. Confirm the JSON textarea reflects each change.

Pass = admin reads the GBP link, sets `review_link`, `review_request_link` stays in sync, and no other `template_vars` keys are lost.

---
**App-layer only. No schema, no fn-contract change. Onboarding captures the Google Business Profile link (`template_vars.google_business_profile_link` + submission); the formatted `review_link` + synced `review_request_link` are agency-set in admin. Merge-write + dual-writer guard protect other `template_vars` keys.**
