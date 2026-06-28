# Phase C — C-3 Revision R-1 (copy/renames/removals/derive-hours/enum) — Lovable prompt

> R-1 of the 3-slice revision (`docs/phase-c-c3-revision-pass.md`). **App-layer only — NO schema.** One fn-contract change (the `siteStyle` enum). Files: `src/lib/clients/onboarding.functions.ts` (1 line) + `src/routes/_authenticated/onboard.tsx`. **Excludes** uploads/site_assets (R-2) and the review-page rework (R-3 — the review step stays as-is in R-1).
>
> **Note on Place ID:** R-1's Review-config removals include dropping `reviewPlaceId` (the earlier-approved Place-ID drop) alongside #20. Flag if you'd rather handle that separately — it's a 2-line removal, cleaner here.

---

# PROMPT R-1 — paste into Lovable

> **Build scope: app-layer only. NO migration, NO schema change.** Edit two files. When done, report both files changed + confirm no migration.

## File 1 — `src/lib/clients/onboarding.functions.ts` (one line)
Update the `siteStyle` enum in `ClientFields` to the finalized 6 styles:
```ts
siteStyle: z.enum(["professional_modern","artistic_unique","corporate","modern_tech","family_owned","owner_operated"]).optional(),
```

## File 2 — `src/routes/_authenticated/onboard.tsx`
A revision pass. Apply ALL of the following; don't drop any.

### A. Step list — collapse Config, rename steps
New `STEPS` (9 steps; the old "Config" step is removed, timezone moves into Content):
```ts
const STEPS = ["Identity","Content","Branding","Industry & Style","Photos","Reviews","Returning Customer Discount","Texting Registration","Review & Create"];
```
Renumber the `step === N` blocks to match. **Photos stays a placeholder in R-1** (uploads = R-2). **Review & Create stays as it currently is in R-1** (the readable-summary rework is R-3).

### B. State changes
- Change `siteStyle` type to `"" | "professional_modern" | "artistic_unique" | "corporate" | "modern_tech" | "family_owned" | "owner_operated"`.
- **Remove** these state fields (+ their UI + assembly + any validation): `reviewPlaceId`, `starThreshold`, `googleReviewToggle`, `reviewRequestLink`, `smsWindowStart`, `smsWindowEnd`, `dailySendCap`, `dailyEnrollmentCap`, `marketingDomainsCsv`, `quoteFormLink`, `termsLink`, `entityType`, and the old free-text `businessHours: string`.
- **Add** request-flag fields: `noDomain: boolean`, `preferredDomain: string`, `wantsClosestDomain: boolean`, `noLogo: boolean`, `makeLogoForMe: boolean`, `notSureColors: boolean` (all default false/"").
- **Add** structured hours state (replaces the free-text):
```ts
type DayKey = "mon"|"tue"|"wed"|"thu"|"fri"|"sat"|"sun";
type DayHours = { isOpen: boolean; open: string; close: string };
const DAYS: { key: DayKey; label: string }[] = [
  {key:"mon",label:"Monday"},{key:"tue",label:"Tuesday"},{key:"wed",label:"Wednesday"},
  {key:"thu",label:"Thursday"},{key:"fri",label:"Friday"},{key:"sat",label:"Saturday"},{key:"sun",label:"Sunday"},
];
// initial: ALL 7 days default OPEN 09:00–17:00 (weekends selectable too — #8)
const DEFAULT_HOURS = Object.fromEntries(DAYS.map(d => [d.key, { isOpen:true, open:"09:00", close:"17:00" }])) as Record<DayKey, DayHours>;
// State: hours: Record<DayKey, DayHours>  (init DEFAULT_HOURS)
```

### C. Helpers (add near the top)
```ts
function buildHours(h: Record<DayKey, DayHours>) {
  const out: Record<string, [string, string]> = {};
  (Object.keys(h) as DayKey[]).forEach(k => { if (h[k].isOpen) out[k] = [h[k].open, h[k].close]; });
  return out; // { mon:["09:00","17:00"], ... } — closed days omitted
}
function formatUsPhone(v: string) {
  const d = v.replace(/\D/g, "").slice(0, 10);
  if (d.length > 6) return `(${d.slice(0,3)}) ${d.slice(3,6)}-${d.slice(6)}`;
  if (d.length > 3) return `(${d.slice(0,3)}) ${d.slice(3)}`;
  if (d.length > 0) return `(${d.slice(0,3)}`;
  return "";
}
function toE164US(v: string) {
  const d = v.replace(/\D/g, "");
  const ten = d.length === 11 && d.startsWith("1") ? d.slice(1) : d;
  return ten.length === 10 ? `+1${ten}` : "";
}
```

### D. Step 1 · Identity
- **Owner full name** — append to hint: *"This can be adjusted later if needed."*
- **Business name** — hint: *"Your business's official name, exactly as you want it shown to customers. It appears on your website, can sometimes appear in text automations, and is how your AI chat assistant identifies you to help customers on your website."*
- **Slug** — **remove the visible `<Field>`/input entirely.** Keep the existing `slugify` auto-derive on business-name change and keep `slug` in the payload (it just no longer shows).
- **Business phone** — relabel **"Personal Cell / Personal Business Number"**; hint: *"Your real phone number, where missed calls can be set to forward to, and so we can send you updates about your website. This is NOT the number shown publicly on your website."* Input uses the mask (no country code): `onChange={(e)=>update("businessPhone", formatUsPhone(e.target.value))}`, placeholder `(305) 555-0142`.
- **Display address** — hint: *"Your business address as you want it shown on your website. Be sure to include street, city, state, zip. Also helps your local search ranking."*
- **Website → relabel "Website Domain."** Hint (has-domain): *"Your current website domain if you already have one. Example: evergreenlandscape.com"*. Add a **"I don't have a domain"** toggle (`noDomain`). When `noDomain` is true, reveal: a field *"Do you have a preferred website domain you'd want? Example: mikesplumbing.com"* (`preferredDomain`) + a button *"Just get me the closest domain to my business name"* (sets `wantsClosestDomain=true`). These only RECORD the request (no live lookup).
- **Notification email** — change the tag wording "agency"→**"business"**; append to hint: *"(alerts also show in your app, this can be turned off later)"*.

### E. Step 2 · Content (+ public hours + timezone)
- Keep About Us / Services / Differentiators / Service areas.
- **Replace the free-text business-hours field with the per-day picker** (default all 7 days open; native `<input type="time">` outputs `"HH:mm"`):
```tsx
<Field label="Business hours" hint="Shown on your website. Set the days and times you're open; turn off a day to mark it closed.">
  <div className="space-y-2">
    {DAYS.map(({ key, label }) => (
      <div key={key} className="flex items-center gap-3 text-sm">
        <label className="w-32 flex items-center gap-2">
          <input type="checkbox" checked={s.hours[key].isOpen}
            onChange={(e)=>update("hours",{...s.hours,[key]:{...s.hours[key],isOpen:e.target.checked}})} />
          {label}
        </label>
        {s.hours[key].isOpen ? (
          <>
            <input type="time" value={s.hours[key].open}
              onChange={(e)=>update("hours",{...s.hours,[key]:{...s.hours[key],open:e.target.value}})} />
            <span>to</span>
            <input type="time" value={s.hours[key].close}
              onChange={(e)=>update("hours",{...s.hours,[key]:{...s.hours[key],close:e.target.value}})} />
          </>
        ) : <span className="text-muted-foreground">Closed</span>}
      </div>
    ))}
  </div>
</Field>
```
- **Add the timezone field here** (moved from the removed Config step):
```tsx
<Field label="Timezone" hint="So texts send at sensible local hours and your stats match your day.">
  <select value={s.timezone} onChange={(e)=>update("timezone", e.target.value)} className="w-full border rounded-md px-3 py-2 bg-background text-sm">
    <option value="America/New_York">Eastern (New York)</option>
    <option value="America/Chicago">Central (Chicago)</option>
    <option value="America/Denver">Mountain (Denver)</option>
    <option value="America/Phoenix">Arizona (Phoenix)</option>
    <option value="America/Los_Angeles">Pacific (Los Angeles)</option>
    <option value="America/Anchorage">Alaska</option>
    <option value="Pacific/Honolulu">Hawaii</option>
  </select>
</Field>
```

### F. Step 3 · Branding
- Keep the **logo URL paste field for now** (upload is R-2). Add a **"I don't have a logo"** toggle (`noLogo`); when true, reveal *"Would you like us to make one for you for your website? Yes / No"* (`makeLogoForMe`).
- Keep the three color inputs as-is for now (the spectrum picker is R-2). **Above the colors**, add a **"Not sure which colors to choose? Select here and we will choose them for you based on what looks best with your business."** toggle (`notSureColors`).

### G. Step 4 · Industry & Style
- Relabel the niche field **"Business Industry / Niche"**; example/placeholder *"(Plumber, Pet Groomer, Roofer, Phone Repair, etc.)"*.
- **Site style dropdown → the finalized 6** (replace the old options):
```tsx
<option value="">— select —</option>
<option value="professional_modern">Professional Modern</option>
<option value="artistic_unique">Artistic Unique</option>
<option value="corporate">Corporate</option>
<option value="modern_tech">Modern Tech</option>
<option value="family_owned">Family Owned / Local Business</option>
<option value="owner_operated">Owner Operated / Local Business</option>
```
*(Future, not now: per-style preview thumbnails.)*

### H. Step 5 · Photos
Leave as the existing placeholder (R-2 reworks it).

### I. Step 6 · Reviews
- **Remove** the star-threshold, review-gate-toggle, direct-review-URL, and Place-ID fields entirely. The step keeps **only the Google review link**.
- Google review link — hint: *"The direct link customers tap to leave you a review on your Google Business Profile."*

### J. Step 7 · Returning Customer Discount
- Section title → **"Returning Customer Discount Offer."**
- Intro/label copy: *"When we follow up with your past customers, you can offer a discount as an incentive for repeat business. What would you like the discount amount to be? Example: 5% off your next job!"*
- Discount amount field — hint clarifies it's just the exact number/value of the discount itself (e.g. `$50` or `15%`).

### K. Step 8 · Texting Registration (A2P)
- **Remove the Entity type field** entirely.
- **Required to advance:** `ein`, `legalName`, `vertical`, `tcpaAttestation` (checkbox must be checked). **`dba` is optional.** Add these to the step's `validate` checks.

### L. Assembly (`buildPayload` / the `return { slug, fields, sendSettings, submission }`)
Replace the assembled objects with:
```ts
const hoursObj = buildHours(s.hours);

const templateVars: Record<string, unknown> = {
  company_name: s.businessName,
  company_owner_first_name: firstName,
  company_website_link: (!s.noDomain && s.website) ? s.website : undefined,
  about_us: s.aboutUs,
  services: s.services,
  differentiators: s.differentiators || undefined,
  brand_secondary: s.brandSecondary || undefined,
  brand_tertiary: s.brandTertiary || undefined,
  segment: s.segment || undefined,
  review_request_link: s.reviewLink || undefined,   // derive = the Google review link
  discount__on_referral: s.discountOnReferral || undefined,
  discount_amount: s.discountAmount || undefined,
  // REMOVED: quote_form_link, website_terms_page_link (agency-set later)
};
Object.keys(templateVars).forEach(k => templateVars[k] === undefined && delete templateVars[k]);

const fields = {
  businessName: s.businessName,
  callForwardingNumber: toE164US(s.businessPhone) || undefined,
  address: s.address || undefined,
  notificationEmail: s.notificationEmail || undefined,
  logoUrl: s.logoUrl || undefined,
  brandColor: s.brandColor || undefined,
  siteStyle: s.siteStyle || undefined,
  serviceArea: serviceArea.length ? serviceArea : undefined,
  reviewLink: s.reviewLink || undefined,
  hours: Object.keys(hoursObj).length ? hoursObj : undefined,   // clients.hours (PUBLIC)
  templateVars,
  // REMOVED: reviewPlaceId, starThreshold, googleReviewToggle, allowedOrigins
};

const sendSettings = {
  timezone: s.timezone,
  businessHours: hoursObj,   // DERIVE from public hours (#28) — correct shape, fixes the {raw} bug
  // REMOVED: smsSendWindow, dailySendCap, dailyEnrollmentCap → DB defaults apply
};

const submission: Record<string, unknown> = {
  capturedAt: new Date().toISOString(),
  ...s,
  domain_request: { hasDomain: !s.noDomain, currentDomain: s.website || null, preferred: s.preferredDomain || null, wantsClosest: s.wantsClosestDomain },
  logo_request: { needsLogo: s.noLogo, makeForMe: s.makeLogoForMe },
  color_request: { chooseForMe: s.notSureColors },
};

return { slug: s.slug, fields, sendSettings, submission };
```

### M. Validation cleanup
Remove validations for all removed fields (the old `businessHours` string check, any Config-field checks). Keep: business name required; site style required; A2P requireds (K). Slug needs no validation (auto-derived, hidden).

## Drift check (report back)
1. Changed: `onboarding.functions.ts` (the `siteStyle` enum line) + `onboard.tsx` (the revision).
2. **No migration, no schema change.**
3. Removed from the form: Place ID, star threshold, review-gate toggle, direct review URL, SMS window, daily caps, marketing domains, quote-form link, terms link, entity type, the standalone Config step, the visible slug input.
4. Build compiles; `createClientFull` still called with `{ slug, fields, sendSettings, submission }`.

---

# VALIDATION — R-1 (as `itsmikeymiami`)

**Walk the wizard** (slug auto-derives; use business name "R1 Test Co" → expect slug `r1-test-co`):
1. Slug input is **gone**; phone field masks to `(305) 555-0142` and shows no country code; Website Domain shows the "I don't have a domain" reveal (preferred + closest-domain) when toggled.
2. Content: the **per-day hours picker** shows **all 7 days open by default incl. Sat & Sun**; toggling a day off shows "Closed"; timezone selector present.
3. Branding: "I don't have a logo" reveal + the "not sure on colors" toggle present.
4. Industry & Style: the dropdown lists the **6 finalized styles**.
5. Reviews step shows **only** the Google review link (no threshold/toggle/URL/Place ID).
6. A2P: can't advance without EIN / legal name / vertical / TCPA checkbox; **DBA optional**; **no Entity type field**.
7. Create the client.

**SQL check** (substitute the new client's slug `r1-test-co`):
```sql
select slug, business_name, call_forwarding_number, site_style, template_vars,
       review_link, hours, review_place_id, star_threshold, google_review_toggle, allowed_origins
  from public.clients where slug='r1-test-co';
-- EXPECT: call_forwarding_number = '+1XXXXXXXXXX' (E.164);
--         site_style in the 6 set; hours = {"mon":["09:00","17:00"],...,"sat":[...],"sun":[...]} (weekends present if left open);
--         template_vars has company_name/segment/discount__on_referral, review_request_link = the review link,
--           and NO quote_form_link / website_terms_page_link;
--         review_place_id = NULL; star_threshold = 4 (default); google_review_toggle = 'gated' (default); allowed_origins = '{}' (default).

select timezone, business_hours, sms_send_window, daily_send_cap, daily_enrollment_cap
  from public.send_settings where client_id=(select id from public.clients where slug='r1-test-co');
-- EXPECT: business_hours = the SAME object as clients.hours (derived); timezone set;
--         sms_send_window = default 9–7; daily_send_cap = 500; daily_enrollment_cap = 50 (DB defaults, not sent).

-- submission JSON has the request flags + no entityType:
select name from storage.objects
  where bucket_id='client-assets'
    and name = (select id::text from public.clients where slug='r1-test-co') || '/onboarding-submission.json';
-- (download/inspect → domain_request / logo_request / color_request present; entityType absent)
```

**Pass:** all renames/removals visible; phone stored E.164; `clients.hours` AND `send_settings.business_hours` both the correct `{day:[open,close]}` shape and EQUAL (derive); weekends present when open; removed fields at their DB defaults; `site_style` from the 6.

**Cleanup:** `delete from public.clients where slug='r1-test-co';` (cascades send_settings; the submission JSON is a harmless private artifact — Storage dashboard to remove).

### After R-1 is green
→ **R-2** (uploads + `site_assets` manifest: logo upload, categorised photos, staff repeater, public-assets helper) → **R-3** (review-page readable summary + thumbnails).

---
**App-layer only. No schema. One fn enum line. Every R-1 item retained.**
