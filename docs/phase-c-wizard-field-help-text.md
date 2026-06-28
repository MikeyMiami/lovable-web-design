# Onboarding Wizard — field-level help text (analyzed from real consumption)

> For `onboard.tsx` (the 10 capture steps). **Part 1** = the analyzed per-field content (maps-to / used-for / description / example / note) for review. **Part 2** = the Lovable build prompt (adds it as muted helper text via the existing `Field` component — content-only). **Part 3** = client-facing-mode scoping (separate future slice).
>
> Grounding (live v1.7): the marketing site reads exactly the **`get_client_public` 13-col projection** — `slug, business_name, tagline, phone_display, address, hours, license_number, logo_url, brand_color, service_area, social_links, template_vars, review_link`. SMS/notification copy + merge vars from `automation-config`. Chat bundle = `business_name` + ALL `template_vars` (`knowledge.server.ts` iterates them). Review funnel uses `review_link`/`review_place_id`/`star_threshold`/`google_review_toggle`. `notification_email`, `call_forwarding_number`, `allowed_origins`, `review_place_id`, A2P fields are **internal/private — NOT on the public site**.
>
> **Audience [LOCKED]:** written in plain second-person for the **business owner**, accurate whether you fill it or (soon) the client does. Fields marked **[agency-set]** are technical/config the client shouldn't fill — hide them in the future client-facing mode.

---

## Part 1 — per-field analysis

### Step 1 · Identity
| Field | Maps to | Actually used for | Help text (Description · Example · Note) |
|---|---|---|---|
| Owner full name | `template_vars.company_owner_first_name` (first token) | The **first name** signs every customer SMS ("-{company_owner_first_name} from {company_name}") + greets every owner notification. | **Description:** Your full name — we use your first name to sign the texts we send your customers, so they feel personal. **Example:** `Mike Alvarez`. **Note:** Customers see "Mike," so it reads like it's from you. |
| Official business name | `clients.business_name` + `template_vars.company_name` | Shown across the **marketing site** (header/footer/title), in **every customer SMS** ("{company_name}"), and the **AI chat** identifies as this business. | **Description:** Your business's official name, exactly as you want it shown to customers. **Example:** `Evergreen Landscape Studio`. **Note:** Appears on your website and in every text — use your real customer-facing name, not an abbreviation. |
| Slug | `clients.slug` (unique) | **Internal handle only** — the system's lookup key + how we identify you in our dashboard. **Never shown to customers.** | **Description:** A short internal ID for your account (auto-filled from your business name). **Example:** `evergreen-landscape-studio`. **Note:** Internal only — customers never see it. Auto-suggested; you can edit it, but it can't change after launch. *(agency-set in client mode — usually hidden/auto.)* |
| Business phone | `clients.call_forwarding_number` (seed) | **[private]** Your real phone — where missed calls forward and where we point you to reach leads. **Not shown publicly** (the public number is your messaging number). | **Description:** Your real business phone number — where you take calls. **Example:** `+1 305 555 0142`. **Note:** Private. Used so missed calls reach you and lead alerts point to the right place; it's not the number shown on your site. |
| Display address | `clients.address` (public projection) | Shown on the **marketing site** (Contact/footer) + used for **local SEO** + carrier A2P checks. | **Description:** Your business address as you want it shown on your website. **Example:** `1450 NW 2nd Ave, Miami, FL 33136`. **Note:** Public — appears on your Contact page. A real local address also helps you rank locally. (If you work from home and don't want it public, tell us.) |
| Website | `template_vars.company_website_link` | The base link in **customer discount SMS** ("{company_website_link}/get-your-discount") + an **AI-chat** knowledge source + a site reference. | **Description:** Your current website address (if you have one). **Example:** `https://evergreenlandscape.com`. **Note:** We use it as the base for the discount link we text customers, and the AI chat can reference it. Leave blank if you don't have one yet. |
| Notification email | `clients.notification_email` (**private**, anon-denied) | **[private]** Where **owner email alerts** go (new lead / discount / "we saved you from a bad review"). Defaults to your account email. | **Description:** The email where you want new-lead and alert emails sent. **Example:** `mike@evergreenlandscape.com`. **Note:** Private — only you receive these. This is where we email you every time a customer fills out a form. |

### Step 2 · Content (your site copy + the AI chat's knowledge)
| Field | Maps to | Actually used for | Help text |
|---|---|---|---|
| About Us | `template_vars.about_us` | Source for your **marketing site** About/Home copy AND the **AI chat widget's** knowledge (it answers visitors using this). | **Description:** 3–5 sentences about your business — who you are, what you do, what makes you trustworthy. **Example:** `Evergreen is a family-run landscaping studio serving Miami since 2009. We design and maintain custom outdoor spaces, from drought-friendly gardens to full backyard builds. Licensed, insured, and known for showing up on time.` **Note:** This becomes your website's story copy and teaches the AI chat how to talk about you — the more real detail, the better it sounds. |
| All services offered | `template_vars.services` | Generates a **Service page per service** on your site (up to 12) + feeds the **AI chat** ("only discuss this business and its services"). | **Description:** List every service you offer, separated by commas. **Example:** `Lawn maintenance, Garden design, Irrigation install, Tree trimming, Sod installation`. **Note:** Each one can become its own page on your site (great for getting found on Google), and the AI chat only answers about the services you list here. |
| Differentiators | `template_vars.differentiators` | **Marketing site** copy (why-choose-us) + **AI-chat** knowledge. | **Description:** What makes you different or better than competitors. **Example:** `Same-week scheduling, 5-year plant warranty, owner on every job, eco-friendly products`. **Note:** We use these as your selling points on the site and in the chat. Be specific — "great service" is weak; "owner on every job" sells. |
| Service areas | `clients.service_area` (public; max 14) | A **Service-Area page per area** (local-SEO, "[service] in [city]") + shown on the site. | **Description:** The cities/areas you serve, separated by commas (up to 14). **Example:** `Miami, Coral Gables, Miami Beach, Hialeah, Doral`. **Note:** Each area can get its own page so you rank for "landscaping in [that city]." List the places you actually want customers from. |
| Business hours | `send_settings.business_hours` | Decides whether a **fresh website lead** gets the live "just got your form, I'll be in touch shortly" text or the after-hours version + shown on site. | **Description:** The hours you're open/reachable, per day. **Example:** `Mon–Fri 8:00am–6:00pm, Sat 9:00am–1:00pm, Sun closed`. **Note:** When someone fills out your form, we check these hours to send the right reply — an in-hours "I'll be right with you" or an after-hours "we'll reach out as soon as we can." |

### Step 3 · Branding
| Field | Maps to | Actually used for | Help text |
|---|---|---|---|
| Logo | `clients.logo_url` (public) | Shown on your **marketing site**, in your **mobile app**, and in your admin. *(C-3b adds upload; paste a URL for now.)* | **Description:** Your business logo. **Example:** a PNG/SVG with a transparent background. **Note:** Appears on your website and in your app. No logo yet? Leave it — we can create one for you. |
| Primary brand color | `clients.brand_color` (public) | **Themes both** your marketing site AND your mobile app (buttons, accents). | **Description:** Your main brand color, as a hex code. **Example:** `#2E7D32`. **Note:** This colors your website and your app, so they match your brand. Don't have brand colors? We'll pick them from your logo/style. |
| Secondary / tertiary color | `template_vars.brand_secondary` / `brand_tertiary` | Supporting accents in the **site + app** theme. | **Description:** Optional supporting colors (hex). **Example:** `#A5D6A7`, `#1B5E20`. **Note:** Optional — used as accents alongside your primary color. Skip if you only have one. |

### Step 4 · Niche & style
| Field | Maps to | Actually used for | Help text |
|---|---|---|---|
| Niche / segment | `template_vars.segment` | Keys the **compliance copy library** (your opt-in/consent wording) + steers **site content** + the **A2P** category. | **Description:** Your industry/trade. **Example:** `Landscaping` (or plumbing, roofing, HVAC, …). **Note:** This tailors your site's wording and the legally-required texting-consent language to your trade. |
| Site style | `clients.site_style` | Selects which **design template** your marketing site is built from (copy voice + visual feel). | **Description:** The look & feel you want for your site. **Example:** `Family Owned / Local Business` (warm, approachable) vs `Modern Tech` (clean, minimal). **Note:** This sets your site's tone and style — your real content fills it in either way. *(agency-guided — we'll help you choose.)* |

### Step 5 · Photos *(uploads land in C-3b — placeholder here)*
| Field | Maps to | Actually used for | Help text |
|---|---|---|---|
| Work / service / staff photos | `public-assets`/`client-assets` + `template_vars.site_assets` manifest | Your site's **Gallery** + service pages; missing categories fall back to stock-for-your-niche. | **Description:** Photos of your real work (and optionally your team). **Example:** 25–60 clear, well-lit job photos. **Note:** Real photos massively outperform stock. Group them by job/service if you can. *(Coming in the next step.)* |

### Step 6 · Review config *(mostly [agency-set])*
| Field | Maps to | Actually used for | Help text |
|---|---|---|---|
| Google review link | `clients.review_link` | The destination customers land on (via a tracked link) when we text them asking for a review — i.e. **where they leave your Google review**. | **Description:** The direct link to leave your business a Google review. **Example:** `https://g.page/r/CXyz…/review`. **Note:** This is what customers tap to review you. *(We usually grab this from your Google Business Profile for you.)* *[agency-set]* |
| Google Place ID | `clients.review_place_id` | **[internal]** Identifies your Google listing for the review flow. | **Description:** Your Google Place ID. **Example:** `ChIJ7cv00DwsDogRAMDACa2m4K8`. **Note:** Technical — we look this up from your Google listing. *[agency-set]* |
| Star threshold | `clients.star_threshold` (default 4) | **[internal]** The review funnel: ratings **≥ threshold** go to Google; **below** go to a private feedback form (so unhappy customers reach you, not your public reviews). | **Description:** The minimum star rating that gets sent straight to Google. **Example:** `4`. **Note:** Happy customers (4–5★) go to Google; anyone lower reaches you privately first. *[agency-set]* |
| Review gate toggle | `clients.google_review_toggle` (gated/direct) | **[internal]** `gated` = use the funnel above; `direct` = send everyone straight to Google. | **Description:** Whether to filter reviews (recommended) or send everyone to Google. **Example:** `Gated (recommended)`. **Note:** Gated protects your public rating; direct skips the filter. *[agency-set]* |
| Direct review URL | `template_vars.review_request_link` | The plain Google review link we put in **your owner notifications** ("here's your direct review link if you need it"). | **Description:** Your own Google review link (for your reference in alerts). **Example:** `https://g.page/r/CXyz…/review`. **Note:** Often the same as the review link above; it's the one we hand back to *you* in reminders. *[agency-set]* |

### Step 7 · Offers
| Field | Maps to | Actually used for | Help text |
|---|---|---|---|
| Referral / return discount | `template_vars.discount__on_referral` | The exact offer wording in your **1-year follow-up customer texts** ("I'm running a special and giving {discount__on_referral}"). | **Description:** The discount you offer past customers for returning or referring. **Example:** `$50 off your next service`. **Note:** This phrase drops straight into the texts we send your past customers — write it as you'd say it. |
| Discount amount | `template_vars.discount_amount` | Used where a short numeric amount is merged. | **Description:** The headline amount of that discount. **Example:** `$50` (or `15%`). **Note:** Keep it short — it's the number customers see. |

### Step 8 · Config *(mostly [agency-set])*
| Field | Maps to | Actually used for | Help text |
|---|---|---|---|
| Timezone | `send_settings.timezone` | **[internal]** Anchors every send window + "this week/month" stat to your local time. | **Description:** Your business's timezone. **Example:** `America/New_York (Eastern)`. **Note:** So texts send at sensible local hours and your stats line up with your day. |
| SMS send window | `send_settings.sms_send_window` (default 09:00–19:00) | **[internal]** The hours marketing texts (review + follow-up) are allowed to send — not your customers' choice. | **Description:** The daily window marketing texts may send in. **Example:** `9:00am–7:00pm`. **Note:** Protects your customers from off-hours texts. *[agency-set]* |
| Daily send cap | `send_settings.daily_send_cap` (default 500) | **[internal]** Max texts/day (deliverability/carrier safety). | **Description:** Max marketing texts per day. **Example:** `500`. **Note:** A safety limit so you stay in carriers' good graces. *[agency-set]* |
| Daily enrollment cap | `send_settings.daily_enrollment_cap` (default 50) | **[internal]** Max new customers entering the review drip per day. | **Description:** Max new customers added to the review campaign per day. **Example:** `50`. **Note:** Overflow rolls to the next day. *[agency-set]* |
| Marketing domain(s) | `clients.allowed_origins` | **[internal]** Authorizes your website to submit its forms to our backend (security allowlist). | **Description:** Your website's domain(s). **Example:** `evergreenlandscape.com`. **Note:** Technical — lets your site's forms talk to us securely. *[agency-set]* |
| Quote-form link | `template_vars.quote_form_link` | The link in your **missed-call textback** ("click this link for a free quote: {quote_form_link}"). Defaults to your site. | **Description:** The page where customers request a quote. **Example:** `https://evergreenlandscape.com/contact`. **Note:** When you miss a call, we text this link. Defaults to your website if left blank. |
| Terms page link | `template_vars.website_terms_page_link` | Your **Terms** URL referenced in compliance copy/texts. | **Description:** Your Terms of Service page link. **Example:** `https://evergreenlandscape.com/terms`. **Note:** We generate a compliant Terms page with your site, so this is usually set automatically. *[agency-set]* |

### Step 9 · Texting registration (A2P) — **private, legal**
> Intro hint for the step: *"These details are used to legally register your business to send text messages (a carrier requirement). They're kept private and are never shown on your website."*

| Field | Maps to | Actually used for | Help text |
|---|---|---|---|
| EIN (Tax ID) | submission JSON (**private**) | **A2P Brand registration** — carriers verify your business is real before you can text. | **Description:** Your business's federal EIN (Tax ID). **Example:** `12-3456789`. **Note:** Required by phone carriers to approve business texting. Kept private — never shown publicly. Sole proprietor with no EIN? Tell us — there's an alternate path. |
| Legal business name | submission JSON (**private**) | **A2P Brand** — must match your EIN registration exactly. | **Description:** Your business's legal name, exactly as registered with the IRS. **Example:** `Evergreen Landscape Studio LLC`. **Note:** Must match your EIN records exactly or registration is rejected. (Can differ from your customer-facing name above.) |
| DBA (if any) | submission JSON (private) | A2P — "doing business as" name. | **Description:** Any "doing business as" name, if different from your legal name. **Example:** `Evergreen Landscaping`. **Note:** Leave blank if you don't use one. |
| Entity type | submission JSON (private) | **A2P** — determines the registration path. | **Description:** Your business structure. **Example:** `LLC` (or Sole Proprietor, Corporation, …). **Note:** Sole proprietors register a bit differently — we handle that. |
| Vertical / industry | submission JSON + `template_vars` | **A2P Campaign** — the industry carriers file you under. | **Description:** Your industry. **Example:** `Landscaping / Home Services`. **Note:** Used on your texting registration; usually matches your niche above. |
| TCPA / consent attestation | submission JSON (private) | **A2P** — you confirm you only text people who opted in. | **Description:** Confirmation that you'll only text customers who agreed to receive texts. **Example:** ☑ checkbox. **Note:** A legal requirement for business texting — we only message people who opted in through your forms. |

### Step 10 · Review & create — *(no input fields; a summary + "Create client")*

---

## Part 2 — Lovable build prompt (adds the help text)

> **Build scope: UI/content only in `src/routes/_authenticated/onboard.tsx`. NO field-mapping, server-fn, table, RLS, or data-flow change** — only render helper text under each existing field. When done, confirm only `onboard.tsx` changed + no migration / no data-flow change.

1. **Extend the existing `Field` component** to take an optional hint and render it as muted helper text under the control:
```tsx
function Field({ label, hint, children }: { label: string; hint?: React.ReactNode; children: React.ReactNode }) {
  return (
    <label className="block space-y-1">
      <span className="text-sm font-medium">{label}</span>
      {children}
      {hint ? <span className="block text-xs text-muted-foreground leading-snug">{hint}</span> : null}
    </label>
  );
}
```
*(Keep whatever markup `Field` already uses; just add the `hint` slot below `children`.)*

2. **Add a `hint="…"` to every `<Field>`** using the strings below (compact Description + Example + Note). For the A2P step, also render the step intro line above the fields. Use plain second-person; these will be shown to clients too.

> *(Implementer: use the "Help text" column from Part 1 verbatim, condensed to one or two sentences each — Description, then "e.g. <example>," then the Note. Keep it muted/`text-xs`. Mark no field required-state changes.)*

3. Optional polish: for the long ones (About Us, services, differentiators) put the hint **above** the textarea; for short inputs, below is fine. No behavior change.

**Drift check:** only `onboard.tsx` changed (the `Field` `hint` prop + `hint` strings + the A2P step intro); no migration; no change to the `createClientFull` payload assembly, validation, or any mapping.

---

## Part 3 — Client-facing mode (FUTURE slice — scoping notes only, do NOT build)
**Goal:** the same wizard, fillable by the **client themselves after payment**, with the agency reviewing/approving before anything goes live.

**Recommended architecture — reuse the proven token + public-route pattern, don't bolt auth onto the wizard:**
- **A tokenized public intake**, mirroring the existing `/r/$token` + `intake`/`discount` public-route model (server-resolved, no client login, Turnstile-guarded). The agency generates a **one-time onboarding token** for a prospect → emails them a link `/<onboarding>/$token` → they fill the SAME step UI → it POSTs to a **public server route** that writes a **draft submission** (the raw answers JSON to `client-assets` or a lightweight `onboarding_drafts` store), **NOT** straight to a live `clients` row.
- **Agency review = the pre-gen console (C-3c):** the draft pre-populates the wizard in *your* admin for review/edit; **only you** run `createClientFull` + `provisionClientOwner`. So a client never creates their own live tenant or mints their own login — they fill a form; you approve it into existence. This keeps the create/provision boundary exactly where it is today (admin/agency_owner only).
- **Why this over giving clients an authed wizard:** no new auth surface, no RLS carve-out for "a not-yet-client," reuses the Turnstile/CORS/token security already built, and keeps the human approval gate. The capture UI is identical (this is why the help text is written client-first now).
- **Decisions to settle when we scope it:** token store + expiry; draft persistence (`client-assets` JSON vs a small `onboarding_drafts` table — likely the first, migration-free); which fields are hidden in client mode (everything marked **[agency-set]** above); resume/save-progress; and the notify-agency-on-submit hook (reuse the owner-email-stub pattern).

This is a **separate upcoming slice** — flagged, not built. The current wizard stays admin-only; the help text already serves both modes.
