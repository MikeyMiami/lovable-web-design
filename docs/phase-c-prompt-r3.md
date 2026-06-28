# Phase C — C-3 Revision R-3 (Review & Create readable summary) — Lovable prompt

> R-3 of the 3-slice revision (`docs/phase-c-c3-revision-pass.md`), revision item **#32**. **App-layer / UI only — NO schema, NO fn-contract change, NO assembly/payload change.** This is a **presentation layer** over the exact same wizard state `s` that already gets assembled and sent to `createClientFull`. Files: `src/routes/_authenticated/onboard.tsx` (final step swaps the raw dump for the summary) + ONE small new component `src/components/onboard/ReviewSummary.tsx`.
>
> **What it replaces:** the final step currently shows a raw code/JSON dump of the captured state. Replace it with a readable, grouped, proofread summary so the user can verify everything before pressing **Create**. The Create button stays at the bottom, unchanged.

## Hard constraints (do NOT cross)
- **No change** to the assembly (`buildPayload` / the `return { slug, fields, sendSettings, submission }`) or to the `createClientFull` call. The summary READS `s` for display only; it does not transform what gets submitted.
- **No new state, no migration, no schema, no fn-contract change.** Pure rendering of existing `s` (incl. `s.siteAssets`/`s.logoUrl` built in R-2).
- Group + label structure **mirrors the wizard's own step order** (Account Setup → Content → Branding → Industry & Style → Photos → Reviews → Returning Customer Discount → Texting Registration).
- Empty/skipped values read **gracefully** — "Not provided" (muted) or the relevant request-flag text — **never** blank, `undefined`, `null`, `{}`, or `[object Object]`.

---

# PROMPT R-3 — paste into Lovable

> **Build scope: app-layer / UI only. NO migration, NO schema/fn-contract change, NO assembly change.** Add one presentation component and render it in the final wizard step in place of the raw JSON dump. The state field names below are the DISPLAY labels — wire each to the **actual existing field in `onboard.tsx` state `s`** (don't rename or add state). Report files changed + confirm no migration / no assembly change.

## File 1 (NEW): `src/components/onboard/ReviewSummary.tsx`
A read-only proofread view of the wizard state. It takes the whole wizard state object and renders grouped sections. Use the app's existing card / muted-text styling (match the rest of the wizard).

```tsx
// Presentation only. Reads the wizard state; renders a grouped, readable summary.
// No data transforms beyond display formatting; nothing here affects the submitted payload.

type Asset = { url: string; path: string };
type StaffAsset = { url: string; path: string; name: string; position: string };

// --- display helpers ---
const TZ_LABELS: Record<string, string> = {
  "America/New_York": "Eastern (New York)",
  "America/Chicago": "Central (Chicago)",
  "America/Denver": "Mountain (Denver)",
  "America/Phoenix": "Arizona (Phoenix)",
  "America/Los_Angeles": "Pacific (Los Angeles)",
  "America/Anchorage": "Alaska",
  "Pacific/Honolulu": "Hawaii",
};

const STYLE_LABELS: Record<string, string> = {
  professional_modern: "Professional Modern",
  artistic_unique: "Artistic Unique",
  corporate: "Corporate",
  modern_tech: "Modern Tech",
  family_owned: "Family Owned / Local Business",
  owner_operated: "Owner Operated / Local Business",
};

const DAY_ORDER: { key: string; label: string }[] = [
  { key: "mon", label: "Monday" }, { key: "tue", label: "Tuesday" }, { key: "wed", label: "Wednesday" },
  { key: "thu", label: "Thursday" }, { key: "fri", label: "Friday" }, { key: "sat", label: "Saturday" },
  { key: "sun", label: "Sunday" },
];

function to12h(hhmm: string): string {
  if (!hhmm || !hhmm.includes(":")) return hhmm || "";
  const [h, m] = hhmm.split(":").map(Number);
  const ampm = h >= 12 ? "PM" : "AM";
  const h12 = h % 12 === 0 ? 12 : h % 12;
  return `${h12}:${String(m).padStart(2, "0")} ${ampm}`;
}

function formatUsPhone(v: string): string {
  const d = (v || "").replace(/\D/g, "").replace(/^1/, "").slice(0, 10);
  if (d.length === 10) return `(${d.slice(0, 3)}) ${d.slice(3, 6)}-${d.slice(6)}`;
  return v || "";
}

const NONE = "Not provided";

// A single label/value line. Empty value → muted "Not provided" (unless `hideIfEmpty`).
function Row({ label, value, hideIfEmpty }: { label: string; value?: React.ReactNode; hideIfEmpty?: boolean }) {
  const empty = value === undefined || value === null || value === "" ||
    (Array.isArray(value) && value.length === 0);
  if (empty && hideIfEmpty) return null;
  return (
    <div className="flex flex-col sm:flex-row sm:gap-3 py-1.5 border-b border-border/40 last:border-0">
      <div className="sm:w-48 shrink-0 text-sm font-medium text-muted-foreground">{label}</div>
      <div className="text-sm">{empty ? <span className="text-muted-foreground italic">{NONE}</span> : value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="rounded-lg border border-border p-4 space-y-1">
      <h3 className="text-sm font-semibold mb-2">{title}</h3>
      {children}
    </div>
  );
}

function Thumb({ src, alt }: { src: string; alt: string }) {
  return <img src={src} alt={alt} className="h-16 w-16 rounded-md object-cover border border-border" />;
}

function PhotoGrid({ label, assets }: { label: string; assets: Asset[] }) {
  if (!assets?.length) return null;
  return (
    <div className="py-1.5">
      <div className="text-sm font-medium text-muted-foreground mb-1">{label} ({assets.length})</div>
      <div className="flex flex-wrap gap-2">
        {assets.map((a, i) => <Thumb key={a.path || i} src={a.url} alt={`${label} ${i + 1}`} />)}
      </div>
    </div>
  );
}

export function ReviewSummary({ s }: { s: any }) {
  // ----- derived, display-only -----
  const hoursLines = DAY_ORDER.map(({ key, label }) => {
    const d = s.hours?.[key];
    const txt = d?.isOpen ? `${to12h(d.open)} – ${to12h(d.close)}` : "Closed";
    return { label, txt };
  });

  // Website / domain request → plain language
  let domainNode: React.ReactNode;
  if (s.noDomain) {
    const parts: string[] = [];
    if (s.preferredDomain) parts.push(`prefers "${s.preferredDomain}"`);
    if (s.wantsClosestDomain) parts.push("wants the closest available to the business name");
    domainNode = `No current domain — we'll source one${parts.length ? ` (${parts.join("; ")})` : ""}`;
  } else {
    domainNode = s.website || undefined;
  }

  // Logo → thumbnail / request text
  let logoNode: React.ReactNode;
  if (s.logoUrl) logoNode = <Thumb src={s.logoUrl} alt="Logo" />;
  else if (s.noLogo) logoNode = s.makeLogoForMe ? "We'll create a logo for you" : "No logo (none to be created)";
  else logoNode = undefined;

  // Colors → swatches / request text
  let colorsNode: React.ReactNode;
  if (s.notSureColors) {
    colorsNode = "We'll choose colors that best fit the business";
  } else {
    const swatches = [
      { hex: s.brandColor, name: "Primary" },
      { hex: s.brandSecondary, name: "Secondary" },
      { hex: s.brandTertiary, name: "Tertiary" },
    ].filter((c) => c.hex);
    colorsNode = swatches.length ? (
      <div className="flex flex-wrap gap-3">
        {swatches.map((c) => (
          <div key={c.name} className="flex items-center gap-2">
            <span className="h-5 w-5 rounded border border-border" style={{ backgroundColor: c.hex }} />
            <span className="text-xs text-muted-foreground">{c.name} {c.hex}</span>
          </div>
        ))}
      </div>
    ) : undefined;
  }

  const sa = s.siteAssets || { work: [], gallery: [], about: [], services: [], staff: [] };
  const anyPhotos = sa.work?.length || sa.gallery?.length || sa.about?.length || sa.services?.length || sa.staff?.length;

  return (
    <div className="space-y-4">
      <p className="text-sm text-muted-foreground">
        Review everything below before creating the client. Use Back to fix anything.
      </p>

      <Section title="Account Setup">
        <Row label="Owner" value={s.ownerFullName} />
        <Row label="Business name" value={s.businessName} />
        <Row label="Personal cell / business #" value={s.businessPhone ? formatUsPhone(s.businessPhone) : undefined} />
        <Row label="Business address" value={s.address} />
        <Row label="Website domain" value={domainNode} />
        <Row label="Notification email" value={s.notificationEmail} />
      </Section>

      <Section title="Content">
        <Row label="About us" value={s.aboutUs} />
        <Row label="Services" value={s.services} />
        <Row label="What sets them apart" value={s.differentiators} />
        <Row label="Service areas" value={s.serviceAreaCsv
          ? s.serviceAreaCsv.split(",").map((x: string) => x.trim()).filter(Boolean).join(", ")
          : undefined} />
        <Row label="Timezone" value={s.timezone ? (TZ_LABELS[s.timezone] || s.timezone) : undefined} />
        <div className="py-1.5">
          <div className="text-sm font-medium text-muted-foreground mb-1">Business hours</div>
          <ul className="text-sm space-y-0.5">
            {hoursLines.map((h) => (
              <li key={h.label} className="flex gap-2">
                <span className="w-24 text-muted-foreground">{h.label}</span>
                <span>{h.txt}</span>
              </li>
            ))}
          </ul>
        </div>
      </Section>

      <Section title="Branding">
        <Row label="Logo" value={logoNode} />
        <Row label="Brand colors" value={colorsNode} />
      </Section>

      <Section title="Industry & Style">
        <Row label="Industry / niche" value={s.segment} />
        <Row label="Site style" value={s.siteStyle ? (STYLE_LABELS[s.siteStyle] || s.siteStyle) : undefined} />
      </Section>

      <Section title="Photos">
        {s.designForMe && (
          <Row label="Photos" value="We'll design this section for you" />
        )}
        {anyPhotos ? (
          <>
            <PhotoGrid label="Previous work" assets={sa.work} />
            <PhotoGrid label="Gallery" assets={sa.gallery} />
            <PhotoGrid label="About" assets={sa.about} />
            <PhotoGrid label="Services" assets={sa.services} />
            {sa.staff?.length ? (
              <div className="py-1.5">
                <div className="text-sm font-medium text-muted-foreground mb-1">Staff ({sa.staff.length})</div>
                <div className="flex flex-wrap gap-3">
                  {sa.staff.map((m: StaffAsset, i: number) => (
                    <div key={m.path || i} className="flex flex-col items-center w-20 text-center">
                      <Thumb src={m.url} alt={m.name || `Staff ${i + 1}`} />
                      <span className="text-xs mt-1 leading-tight">{m.name || NONE}</span>
                      <span className="text-[11px] text-muted-foreground leading-tight">{m.position || ""}</span>
                    </div>
                  ))}
                </div>
              </div>
            ) : null}
          </>
        ) : (
          !s.designForMe && <Row label="Photos" value={undefined} />
        )}
      </Section>

      <Section title="Reviews">
        <Row label="Google review link" value={s.reviewLink} />
      </Section>

      <Section title="Returning Customer Discount">
        <Row label="Discount offer" value={s.discountOnReferral} />
        <Row label="Discount amount" value={s.discountAmount} />
      </Section>

      <Section title="Texting Registration (A2P)">
        <Row label="Legal business name" value={s.legalName} />
        <Row label="EIN" value={s.ein} />
        <Row label="DBA (optional)" value={s.dba} hideIfEmpty />
        <Row label="Industry / vertical" value={s.vertical} />
        <Row label="TCPA consent" value={s.tcpaAttestation ? "Agreed" : undefined} />
      </Section>
    </div>
  );
}
```

## File 2: `src/routes/_authenticated/onboard.tsx` — final step swap
- Import the component: `import { ReviewSummary } from "@/components/onboard/ReviewSummary";`
- In the **Review & Create step** (the last step, "Review & Create"), **remove the raw JSON/code dump** (the `<pre>{JSON.stringify(...)}</pre>` or equivalent) and render `<ReviewSummary s={s} />` in its place.
- **Keep the Create button** exactly where it is (below the summary), with its existing `onClick` → assembly → `createClientFull` flow **unchanged**.
- Do not touch any other step, the assembly, or the submit handler.

### Field-name wiring note (verified)
All `s.<field>` keys below are **verified against the current `onboard.tsx` `State` type on `origin/main` @ `93c1f99`** ("Enabled multi-file uploads" — R-1/R-2 present). Use them exactly; do not add or rename state:
- **Owner:** `s.ownerFullName` (string) — confirmed (feeds `company_owner_first_name` via `firstName = s.ownerFullName.trim().split(/\s+/)[0]`).
- **Service areas:** `s.serviceAreaCsv` (a **CSV string**, e.g. `"Miami, Hialeah"`) — split/trim/filter/join for display (as wired above); it is NOT an array.
- **A2P:** `s.ein`, `s.legalName`, `s.dba`, `s.vertical` (strings), `s.tcpaAttestation` (boolean) — confirmed.
- **Identity/content/branding/etc.:** `ownerFullName, businessName, businessPhone, address, website, noDomain, preferredDomain, wantsClosestDomain, notificationEmail, aboutUs, services, differentiators, serviceAreaCsv, hours, timezone, logoUrl, noLogo, makeLogoForMe, notSureColors, brandColor, brandSecondary, brandTertiary, segment, siteStyle, reviewLink, discountOnReferral, discountAmount` — all confirmed present in `State`.
- **Photos:** `s.siteAssets` (`{ work, gallery, about, services, staff }`) + `s.designForMe` (boolean) — confirmed.

Never render an object/array raw — arrays are joined, the hours object is formatted per-day.

## Drift check (report back)
1. Changed: NEW `src/components/onboard/ReviewSummary.tsx` + `onboard.tsx` (final-step render swap + import).
2. **No migration, no schema change, no fn-contract change.**
3. **Assembly and `createClientFull` call are byte-for-byte unchanged** — confirm the submitted payload is identical to before R-3 (this is presentation only).
4. The final step shows the grouped summary (8 sections in wizard order) + thumbnails; the raw JSON dump is gone; the Create button is still at the bottom and still works.
5. Build compiles; no `[object Object]`/`undefined`/empty `{}` rendered anywhere.

---

# VALIDATION — R-3 (as `itsmikeymiami`)

This slice is **UI-only**, so validation is **visual**, not SQL (no new data is written; the payload is unchanged from R-2). Walk the wizard and inspect the final step.

**Full-data pass** (business name "R3 Test Co"):
1. Fill every step with real values; upload a logo, ≥1 photo in each of work/gallery/about/services, and one staff member (image + name + position).
2. On **Review & Create**, confirm:
   - 8 sections in order: **Account Setup, Content, Branding, Industry & Style, Photos, Reviews, Returning Customer Discount, Texting Registration**.
   - Every field shows a clean **label + value** (no JSON, no braces, no `undefined`).
   - **Hours** render as a readable per-day list (e.g. *Monday 9:00 AM – 5:00 PM*, *Sunday Closed*).
   - **Phone** renders formatted `(305) 555-0142`; **timezone** + **site style** show their friendly names (not slugs).
   - **Logo thumbnail** renders; **photo thumbnails** render per category with counts; **staff** show photo + name + position.
   - **Brand colors** show swatches with hex labels.
3. Press **Create** → the client is created exactly as in R-2 (slug `r3-test-co`). Quick confirm nothing regressed:
   ```sql
   select slug, business_name, logo_url, template_vars->'site_assets' as site_assets
     from public.clients where slug='r3-test-co';
   -- EXPECT identical shape to an R-2 create: logo_url public URL, site_assets manifest populated.
   ```

**Empty/skipped-graceful pass** (fresh run, business name "R3 Empty Co"):
1. Fill ONLY the required fields (business name, site style, A2P requireds). Toggle the request flags instead of values: "I don't have a domain" (+ closest), "I don't have a logo" → make-for-me Yes, "not sure on colors", photos "design this section for me", leave DBA + differentiators + service areas blank.
2. On Review & Create, confirm:
   - Website domain reads *"No current domain — we'll source one (wants the closest available…)"*.
   - Logo reads *"We'll create a logo for you"*; colors read *"We'll choose colors that best fit the business"*; photos read *"We'll design this section for you"*.
   - Empty optional fields (differentiators, service areas) read *"Not provided"* (muted); **DBA is hidden** (hideIfEmpty); nothing shows blank/`undefined`.

**Pass:** grouped readable summary in wizard order; all formatting (hours/phone/tz/style/colors) correct; logo + categorized photo + staff thumbnails render from `s.siteAssets`/`s.logoUrl`; empties graceful; Create still produces the same client as R-2. **Cleanup:** `delete from public.clients where slug in ('r3-test-co','r3-empty-co');` (+ Storage-dashboard remove the test images).

### After R-3 is green
→ C-3 (R-1/R-2/R-3) is complete. **NEXT:** C-3d (client-facing onboarding via a token + server-fn upload proxy), then remaining Phase C (pre-gen console, immutable submission viewer, the §9b admin editors, agency-view extensions).

---
**App-layer / UI only. No schema, no fn-contract change, NO assembly change — presentation over the same submitted state. Revision item #32 satisfied (readable grouped summary + thumbnails). Every R-3 spec point retained.**
