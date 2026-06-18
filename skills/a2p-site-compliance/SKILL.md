---
name: a2p-site-compliance
description: Use when preparing a client site and copy pack for TextGrid A2P 10DLC Campaign registration — the compliance layer baked into the main marketing site (two-checkbox opt-in consent, Privacy/Terms/SMS-Program pages, the per-client copy-paste Brand+Campaign pack, the working review page, and the verbatim compliance templates filled by deterministic token substitution + a per-niche category library). PREPARES everything A2P registration consumes; the A2P submission itself is deferred and gated (TextGrid verification). Folds into website-structure, onboard-from-form, admin-view, new-client-site, launch-check, textgrid-provider. NOT the backend (scratch-foundation) and NOT the per-client orchestration (new-client-site).
---

# A2P Site Compliance — carrier-ready site + copy-paste registration pack (Stage-5 / A2P-prep)

The **compliance layer that the A2P 10DLC Campaign registration consumes.** A2P registration itself (subaccount → Brand → Campaign → number) is **deferred and gated** on TextGrid verification (HANDOFF §2 LIVE-flip gates — chiefly the parent-on-subaccount auth confirm); this skill **PREPARES everything A2P needs** so that when the gate clears, every field, page, URL, and message sample already exists, is consistent, and is carrier-shaped. It is the bridge between `/onboard-from-form` (capture), `/website-structure` (the site that gets submitted), `/admin-view` (the copy-paste pack), and `/textgrid-provider` §4 (the actual registration calls).

## Canonical copy source [SINGLE SOURCE OF TRUTH]
All carrier-load-bearing boilerplate lives **verbatim** in **`docs/a2p-compliance-copy-source-of-truth.md`** (Sections A–H). That file is authoritative; this skill reproduces its load-bearing copy and operational model. **The wording is LOAD-BEARING — it is what passes 10DLC carrier review. Do NOT paraphrase, summarize, reorder, or "clean up" any of it. AI may fill `{tokens}`; AI may NOT rewrite the compliance language.** If this skill and the canonical doc ever diverge, **the doc wins** — update both together.

## Architecture decision [LOCKED]
- **NO separate lander / compliance microsite / second domain.** A2P compliance is **baked into the MAIN client marketing site.** The real site URL is what gets submitted to A2P as the Campaign's opt-in / message-flow URL — so the live site IS the proof carriers review.
- **Contact email domain MUST equal the site domain.** Prefill the A2P contact email from the site domain and **enforce the match** (capture + admin-view validation). Carriers check domain-match, not deliverability/bounce. This is the #1 hard decline rule.
- **Email-deliverability fallback = known edge, NOT built [documented, not implemented].** If a Campaign is ever declined specifically on email *deliverability* (not domain-match), we set up forwarding on the site domain at that point. Do **not** build mailbox/forwarding infrastructure now.

## Token schema [the one source every surface fills from]
One per-client business-data schema, populated at onboarding; every copy surface (site pages AND the TextGrid paste) draws from it so all copy is **byte-identical** across surfaces (a carrier consistency requirement):

`{business_name}` (legal name as on EIN) · `{dba_name}` · `{contact_email}` (domain == site domain) · `{support_email}` · `{phone}` (display) · `{phone_e164}` · `{address}` / `{street}` / `{city}` / `{state}` / `{zip}` / `{country}` · `{site_url}` · `{privacy_url}` · `{terms_url}` · `{optin_url}` · `{review_link}` (→ the on-site dummy review page) · `{effective_date}` · `{contact_person}` · `{segment}` (vertical — keys the niche library + drives description/sample context) · `{ein}` / `{ein_country}` / `{duns_giin_lei_type}` / `{duns_giin_lei_number}` · **`{customer_care_category}` + `{marketing_category}`** (the two niche-variable consent-category descriptions, filled from the per-niche library keyed by `{segment}` — see the Niche library below).

---

## Section 0 — Canonical approved reference: Review Harvest LLC [VERBATIM gold standard]

A **real, carrier-APPROVED** A2P campaign (canonical doc §E). It anchors BOTH (a) the per-client copy generation and (b) the `/admin-view` A2P-prep panel's **"view approved example" side-by-side toggle** (Section 3). Generated per-client copy must match this **STRUCTURE**; only tokenized identifiers + niche context change.

**Campaign Description (approved):**
> REVIEW HARVEST LLC sends text messages to users who consent to receive promotional and customer care SMS messages. After the transaction, we request feedback from the user and direct them to Google to leave a review. We only ask for reviews we do not filter these reviews or send any other sort of marketing message. We will follow up via SMS if a user has not left a review. We also may contact our customers via SMS if they have submitted a support request. Msg volume may vary

**Call to Action / Message Flow (approved):**
> Clients will be able to sign up to receive SMS notifications by checking their preference (customer care, marketing, or both) by clicking on https://www.reviewharvest.com/contact-us at https://www.reviewharvest.com/ at the very bottom of the website in the footer. Where they'll see a form to fill out information, and can click a specific box for marketing, and a specific box for customer care. The text for each reads: [ ] By providing a telephone number, clicking this button, and submitting the form, you are consenting to be contacted by SMS text message from REVIEW HARVEST LLC, regarding account issues and outages (customer care), (our message frequency may vary). Message & data rates apply. Reply STOP to unsubscribe from further messaging from REVIEW HARVEST LLC. Reply HELP for more information. See our Privacy Policy (containing our SMS Terms) at the bottom of the page for more information. [ ] By providing a telephone number, clicking this button, and submitting the form, you are consenting to be contacted by SMS text message from REVIEW HARVEST LLC, regarding new offers (marketing), (our message frequency may vary). Message & data rates apply. Reply STOP to unsubscribe from further messaging from REVIEW HARVEST LLC. Reply HELP for more information. See our Privacy Policy (containing our SMS Terms) at the bottom of the form for more information. Consent is provided exclusively for REVIEW HARVEST LLC to contact the user based on the selection, not any other third parties mentioned on the site. SMS opt-in data is not shared/sold to third parties for promotional/marketing purposes. Privacy Policy URL: https://www.reviewharvest.com/privacy-policy

**Sample Messages (approved, 5):**
> 1. Hi John! Could you take a second to leave a review for Review Harvest? It only takes a few clicks, and it helps us out tremendously! Here's the link: {review-link} Reply STOP to opt out. Powered By Review Harvest
> 2. Hi Greg! Would you be willing to leave a review for Review Harvest? It only takes 30 seconds! Here's the link: {review-link} Reply STOP to opt out. Powered By Review Harvest
> 3. Hi Jessica! Would you be willing to leave a review for Review Harvest? It only takes 30 seconds! Here's the link: {review-link} Text STOP to opt out. Powered By Review Harvest
> 4. Hi Cody, thanks for reaching out! We have received your support ticket, please email us at support@reviewharvest.com or call us at 850-600-2205 if you need something in the mean time. We look forward to solving your problem! Text STOP to opt-out. Powered By Review Harvest
> 5. Hi Jenny, thanks for reaching out! For any support, please email us at support@reviewharvest.com or call us at 850-600-2205. We're here to help you! Text STOP to opt-out. Powered By Review Harvest

**Why this shape passes:** named brand in every message; ≥2 explicit STOP/opt-out; real human first names + real values (NO bare `{Name}`/`{Company}` curly fields — carriers reject those); the review/support split mirrors the Description's use cases; the link token resolves to a LIVE page (Section C).

---

## Section 1 — Website compliance requirements [folds into /website-structure + /new-client-site]

The generated client site carries ALL of the following on the **main marketing site**. `/website-structure` builds them; `/launch-check` §E verifies they shipped. **The copy is the verbatim canonical-doc templates — reproduce byte-for-byte, tokens only.**

### 1.1 Opt-in form (canonical doc §C — verbatim)
Two SEPARATE checkboxes, **UNCHECKED by default**, **NOT a condition of service** (form submits without them); phone field **optional**:

> **Request Information** — Contact us to learn more about our services and how we can assist with your needs.
> - Full Name * · Email Address * · Mobile Phone Number (Optional)
>
> **☐ (unchecked)** I consent to receive **{customer_care_category}** from {business_name}. Message frequency varies, up to 4 messages per month. Message & data rates may apply. Text HELP for assistance, reply STOP to opt out.
>
> **☐ (unchecked)** I consent to receive **{marketing_category}** from {business_name} at the phone number provided. Message frequency varies, up to 4 messages per month. Message & data rates may apply. Text HELP for assistance, reply STOP to opt out.
>
> [ Privacy Policy ]({privacy_url}) · [ Terms of Service ]({terms_url}) — **[Submit]**

The "I consent to receive … Message frequency varies … Message & data rates may apply … Text HELP … reply STOP to opt out" wording is the **FIXED compliance skeleton** — never varies. Only `{customer_care_category}` / `{marketing_category}` vary (Niche library below). *(Layout per the uploaded opt-in form screenshot; the COPY is now the canonical-doc verbatim.)*

### 1.2 Privacy Policy page (canonical doc §B — verbatim; NOT generic, names the company)
Reproduce the full Privacy Policy from canonical §B byte-for-byte (tokens only). The **carrier-load-bearing** parts that must appear exactly:
> **IMPORTANT NOTICE REGARDING TEXT MESSAGING DATA** — {business_name} ("we," "us," or "our") DOES NOT share customer opt-in information, including phone numbers and consent records, with any affiliates or third parties for marketing, promotional, or any other purposes unrelated to providing our direct services. All text messaging originator opt-in data is kept strictly confidential.
>
> **3. SMS Messaging & Compliance** — the Opt-In & Consent / Opt-Out / Message Frequency / Help & Support / Carrier Information bullets (canonical §B.3, verbatim).
>
> **SMS Data Protection Statement** — No mobile information will be shared with third parties/affiliates for marketing/promotional purposes. Information sharing to subcontractors in support services, such as customer service is permitted. … (canonical §B, verbatim).

### 1.3 Terms of Service page (canonical doc §A — verbatim; NOT generic, names the company)
Reproduce the full ToS from canonical §A byte-for-byte (tokens only). The **carrier-load-bearing** part is the **SMS Messaging & Compliance** block, clauses **1–8** + the TCPA/CTIA closing line, which must appear exactly:
> 1. **Program Description** … explicitly opted in … dedicated checkbox for SMS consent …
> 2. **Cancellation Instructions** … text "STOP" … we will confirm your unsubscribe status …
> 3. **Support Information** … reply "HELP" … {support_email} or call {phone} …
> 4. **Carrier Liability** … not liable for delayed or undelivered messages.
> 5. **Message & Data Rates** … Message frequency varies … contact your wireless provider.
> 6. **Supported Carriers** … AT&T, T-Mobile, Verizon, Sprint, and most regional carriers.
> 7. **Age Restriction** … 18 years or older …
> 8. **Privacy Policy** … refer to our Privacy Policy.
> *(+ "We comply with all applicable laws and regulations, including the Telephone Consumer Protection Act (TCPA) and CTIA guidelines …")*

### 1.4 SMS Program page (canonical doc §D — verbatim)
> **SMS Program** — {business_name} may send SMS messages to customers who provide their mobile number and consent. Message frequency may vary. Message & data rates may apply.
> - **Opt out:** Reply **STOP** at any time. — **Help:** Reply **HELP** for assistance. — **Support:** {contact_email} • {phone}
> - For additional details, please review our [Privacy Policy]({privacy_url}) and [Terms of Service]({terms_url}).
> - {business_name} · {address} · {contact_email} • {phone}

*(Layout per the uploaded SMS-Program screenshot; the COPY is now the canonical-doc verbatim.)*

### 1.5 Working review page
The live `{site_url}/review` page (Section C); `{review_link}` in the samples must resolve to it.

### 1.6 Footer links
**Privacy / Terms / SMS Program on every page.** All links working, no typos (Section 4 rule).

---

## Niche library — the two consent-category strings [STRUCTURED + EXTENSIBLE]

The consent checkbox (Section 1.1) and the campaign Call-to-Action paragraph (Section 3) share a **FIXED compliance skeleton** + two niche-variable slots: `{customer_care_category}` and `{marketing_category}`. **Only the category DESCRIPTION is niche-relevant; the compliance mechanics around it are fixed.** The two slots are filled from this per-niche library keyed by `{segment}`. The **same two strings** fill the form AND the A2P submission so they stay byte-consistent.

**Seed entries** (grows over time as more niches are approved — append new approved niche blocks here; each entry is JUST the two category-description strings):

| `{segment}` key | `{customer_care_category}` | `{marketing_category}` |
|---|---|---|
| **DEFAULT / generic** (any niche not yet listed) | messages regarding account issues and customer care | promotional messages about new offers |
| **Home services / Plumbing / HVAC / Trades** (seed: Mike's Plumbing) | non-marketing messages about job status updates, estimate follow-ups, and service confirmations | promotional notifications about new services, seasonal maintenance tips, and exclusive savings |
| **Review / reputation service** (seed: Review Harvest) | messages regarding account issues and outages (customer care) | messages regarding new offers (marketing) |

**RULES:**
- A niche block **ONLY** supplies the two category-description strings. It must **NEVER** alter the surrounding compliance language (STOP/HELP/rates/frequency/privacy-link).
- If a niche isn't in the library yet, use the **DEFAULT** block — **never freestyle the consent copy.**
- Add new approved niches by appending a row (key = the `{segment}` value); nothing else changes.

---

## Section 2 — Onboarding-form fields [folds into /onboard-from-form]

Capture these so the pack (Section 3) + the compliant site (Section 1) generate deterministically. These are the **A2P-prep additions** to `/onboard-from-form`; surface + edit them in `/admin-view` Settings like all onboarding values.

- **Agency contact** — kept separate from the client business contact.
- **Client BUSINESS info:** full legal company name (as on EIN) → `{business_name}`; DBA/brand if different → `{dba_name}`; **legal org type** (default **Private Profit**; enum → TextGrid `entityType`); **segment/vertical** (full TextGrid list, canonical §G — keys the niche library + maps to the `vertical` enum KEY in `docs/1f-step6-a2p-registration-field-requirements.md`); **EIN/TIN** + issuer country; optional **DUNS/GIIN/LEI** (+ type); **address/city/state/zip/country** (as on EIN); **website** (= `{site_url}`); **contact email** (**PREFILL to match the website domain; enforce the match**); **contact phone** (E.164 → `{phone_e164}`); **business description** ("what you do / who you serve / where" — the only AI-bounded generation input, Section B); **logo upload** (≤ 400px); **TCPA / A2P-10DLC attestation checkbox** (required); **business-domain email flag** (Yes → use theirs; No → use an email on the site domain you provide, to keep email-domain == site-domain).

---

## Section 3 — Admin-view A2P-prep panel (per client) [folds into /admin-view]

Per-client panel that **PRE-GENERATES the business-customized registration copy for copy-paste into TextGrid**, filled deterministically from the token schema + niche library, with a **toggle to view the approved Review Harvest example (Section 0) side-by-side.** Templates are canonical §F (campaign) + §G (brand fields).

- **Brand fields (canonical §G):** legal name, DBA, entity type (default Private Profit), segment/vertical, EIN + issuer, DUNS/GIIN/LEI, address, **website (= site URL)**, **contact email (= on-site-domain, match-enforced)**, E.164 phone.
- **Campaign Description** — filled template (canonical §F, anchored to §0).
- **Call-to-Action / consent paragraph** — filled template (canonical §F); its `{customer_care_category}`/`{marketing_category}` **MUST be the same niche-library strings rendered on the form** (Section 1.1) — single source, so what the campaign claims matches what the form shows.
- **5 sample messages** — canonical §F templates filled with **REAL distinct first names + real values** (NOT literal `{contact_person}`, NOT generic `{Name}`/`{Company}` — carrier reject); **≥ 2 contain STOP**; niche context may reflect `{segment}` but the **structure stays fixed.**
- **Privacy Policy URL + Terms URL** boxes.
- **Side-by-side toggle:** generated per-client copy vs the verbatim §0 Review Harvest approved example, to eyeball structural match before pasting into TextGrid.

---

## Section 4 — Compliance RULES [durable reference — what gets a campaign declined] (canonical §H)

- **Email domain == website domain** — the #1 hard rule (prefill + enforce; deliverability is a non-built fallback).
- **Policies are NOT generic** — they name `{business_name}` with real contact info; both linked in the footer of every page AND referenced in the SMS opt-in.
- **Privacy Policy MUST state** mobile opt-in data is not shared with third parties for marketing (the SMS Data Protection Statement — §1.2).
- **ToS MUST carry the SMS disclosure** (message types, "message frequency may vary," "message & data rates may apply," privacy link, "Text STOP to opt out") — §1.3 clauses 1–8.
- **All links work + no typos** (both are decline triggers — validate links + spellcheck the generated site).
- **Opt-in checkboxes:** two separate, **unchecked by default**, **optional** (not a condition of service), exact consent language.
- **Sample messages:** real values (no generic curly fields), ≥2 with STOP, consistent with the campaign description; if a sample contains a URL/phone, flag it in the campaign's "Campaign Attributes."
- **`{review_link}` resolves to a LIVE working page** at submission (the on-site dummy review page) — carriers may click it.

### A. Verbatim templates — RETAIN EXACTLY, do NOT paraphrase or "clean up"
Stored verbatim in **`docs/a2p-compliance-copy-source-of-truth.md`**; the generated site/pack reproduces them byte-for-byte, substituting ONLY the marked tokens. Index:
- **ToS — SMS Messaging Terms & Compliance** (clauses 1–8 + TCPA/CTIA line) → canonical §A (load-bearing excerpt embedded at §1.3).
- **Privacy Policy — SMS section** + **"SMS Data Protection Statement"** + **"IMPORTANT NOTICE REGARDING TEXT MESSAGING DATA"** header → canonical §B (load-bearing excerpt embedded at §1.2).
- **Opt-in form** — two consent checkboxes (fixed skeleton + niche slots) → canonical §C (embedded at §1.1).
- **SMS Program page** → canonical §D (embedded at §1.4).
- **Campaign Description / CTA / 5 samples** → canonical §F (anchored to the §0 approved structure).
- **Substitution points (the ONLY editable slots):** the token schema above. Everything else in the compliance language is LOCKED.

### B. The substitution mechanism [LOCKED] — verbatim AND business-specific via deterministic token-fill (NOT AI rewriting)
- **EVERY copy surface fills `{tokens}` from the ONE schema** → byte-identical across the site AND the TextGrid paste. This cross-surface consistency is itself a **carrier requirement.**
- **Compliance language = LOCKED template; only tokens vary; AI does NOT rephrase boilerplate.**
- **Niche variability is bounded to the library:** `{customer_care_category}`/`{marketing_category}` come ONLY from the Niche library (keyed by `{segment}`; DEFAULT fallback; never freestyled).
- **The ONLY free generation:** the **business-description text** + the **contextual noun in sample scenarios** (e.g. plumbing vs roofing), from the onboarding description + segment, **anchored to the §0 approved structure.** Sample-message **STRUCTURE stays fixed** (named brand, ≥2 STOP, real values, link token).

### C. The dummy review page [BUILD into the generated site]
- **v1 [frontend-only]:** the `/review` page = the always-present "Review Us" page (`/website-structure`); it must **load + present a working review action** — a CTA to `client.review_link` (Google) and/or an optional comment box POSTing to the **existing** `/api/public/intake` route. `review_link_url` = that page's URL, **prefilled into the sample-message link token.** No new backend route (a brand-new public review route would touch the frozen backend — not v1).
- **[BACKLOG]** a real on-site review-capture pipeline (new public route) when the review system is built; when it lands, the URL **matches or gets swapped — note the swap in the handoff.**
- The page **must actually load + accept the review action** (carriers may click it) — not a placeholder/404.

---

## Cross-references & mirror lines [hand to the user for parity]

Skills/specs that need a pointer at `/a2p-site-compliance`. Anchor points + suggested mirror text (exact placement confirmed with the user at commit):

- **`/onboard-from-form`** — extend the §9b field set + the "A2P field coverage (FLAG)" note with the Section 2 fields (legal name/DBA/entity type/segment→niche-key/EIN+issuer/alt-id/address/website/contact-email domain-match/phone/description/logo/attestation/business-domain-email). *Mirror: "A2P-prep field capture + compliance copy generation → `/a2p-site-compliance` (canonical copy `docs/a2p-compliance-copy-source-of-truth.md`)."*
- **`/website-structure`** — the page set + §9b.C terms/privacy generation produce the Section 1 compliant pages (two-checkbox opt-in, named Privacy/ToS, SMS Program page, footer links, `/review` page), copy verbatim from the canonical doc. *Mirror beside the Turnstile launch-prereq note.*
- **`/admin-view`** — new per-client **A2P-prep panel** (Section 3) with the side-by-side approved-example toggle; sits with the Settings surfacing of all onboarding values. *Mirror in the Tabs list + Settings notes.*
- **`/new-client-site`** — step 2 (A2P registration) + step 4 (design) reference `/a2p-site-compliance` for the pre-generated pack + compliant pages registration consumes. *Mirror in the launch sequence steps 2 & 4.*
- **`/launch-check`** — §E gains the compliance go-live rows (Section 4 rules: domain-match, named policies, working links, samples real-values + ≥2 STOP, unchecked/optional opt-in, "not shared for marketing" clause, live `/review` page). *Mirror as a new §E checklist block.*
- **`/textgrid-provider` §4** — Campaign registration **consumes** the Section 3 pack (Description, CTA, samples, T&C + privacy URLs); cross-link as the copy/URL source. *Mirror at the Brand/Campaign field references.*
- **Spec §9b/§9c** — per-client model + the A2P-prep compliance layer; cross-ref the canonical copy doc + this skill.

## Notes / open items
- **A2P registration itself is deferred + gated** — this skill only PREPARES. Submission flow + field list: `docs/1f-step6-a2p-registration-field-requirements.md` + `/textgrid-provider` §4; LIVE-flip gates in HANDOFF §2.
- **Email-deliverability domain-match fallback** = known edge, **not built** (forwarding only if a Campaign is declined on deliverability).
- **`vertical` enum mapping** — the Section 2 segment labels (canonical §G) resolve to the TextGrid enum KEYS (`docs/1f-step6-a2p-registration-field-requirements.md`); confirm at build.
- **Review-page URL swap** — when the real review system lands, reconcile `{review_link}` (Section C) and note it in the handoff.
- **Niche library grows** — append approved niche rows over time; DEFAULT covers unlisted niches; consent copy is never freestyled.
- **The compliance surface is BAKED into the STYLE template at build time** (`/template-builder`), so every per-client remix inherits it. Tokens fill at remix from `template_vars`; `{customer_care_category}`/`{marketing_category}` are sourced from the Niche library (keyed by `template_vars.segment`) at onboarding → the SAME values feed the site form AND the §3 admin pack (single source, byte-consistent). The niche is a DATA layer decoupled from the style (any niche × any style). See `docs/stage5-template-builder-build-spec.md`.

---

## Appendix — Canonical Verbatim Copy

> **This appendix makes the skill SELF-CONTAINED at build time** — it holds the COMPLETE carrier-tested copy directly, so Lovable never reconstructs from excerpts. It is the full verbatim content of `docs/a2p-compliance-copy-source-of-truth.md` (kept in the repo too for human reference + parity). **Reproduce byte-for-byte; fill `{tokens}` only; NEVER paraphrase the compliance language.** The operational model, niche library, and rules above govern HOW this copy is used; the raw copy is below.

# A2P Compliance Copy — VERBATIM SOURCE OF TRUTH (for the a2p-site-compliance skill)

> **PURPOSE.** This file holds the EXACT, carrier-tested boilerplate copy that every generated client site + A2P submission must use. The wording is LOAD-BEARING (it is what passes 10DLC carrier review). It must be stored VERBATIM in the a2p-site-compliance skill and reproduced byte-for-byte on each client site, with ONLY the marked `{tokens}` substituted from the per-client business-data schema. **Do NOT paraphrase, summarize, reorder, or "clean up" any of this copy.** AI may fill tokens; AI may NOT rewrite the compliance language.
>
> **TOKEN SCHEMA** (one source, filled from onboarding; every surface draws from these so all copy is byte-identical across the site + the TextGrid paste):
> `{business_name}` (legal name as on EIN) · `{dba_name}` · `{contact_email}` (domain == site domain) · `{support_email}` · `{phone}` (display) · `{phone_e164}` · `{address}` (full street/city/state/zip) · `{site_url}` · `{privacy_url}` · `{terms_url}` · `{optin_url}` · `{review_link}` (→ the on-site dummy review page) · `{effective_date}` · `{contact_person}` · `{segment}` (vertical — keys the niche copy library + drives description/sample context) · `{customer_care_category}` + `{marketing_category}` (the two niche-variable consent-category descriptions, filled from the per-niche copy library keyed by `{segment}` — see Section C)

---

## SECTION A — TERMS OF SERVICE (verbatim template)

> The **SMS Messaging Terms & Compliance** block (clauses 1–8) is the carrier-load-bearing part and is reproduced exactly. The General Terms below it are standard site ToS and may be reused as-is. Token slots are the ONLY substitutions.

### {business_name} Terms of Service
**Effective Date: {effective_date}**

#### SMS Messaging Terms & Compliance

1. **Program Description:** This messaging program sends appointment confirmation and reminder messages to customers who have booked an appointment with {business_name} through our website, or via our scheduling forms, and have explicitly opted in to receive SMS notifications. Opt-in is collected via web forms with a dedicated checkbox for SMS consent. Messages include scheduling confirmations, appointment reminders, rescheduling updates, and customer support communications.

2. **Cancellation Instructions:** You can cancel the SMS service at any time. Simply text "STOP" to the same number that sent you messages. Upon sending "STOP," we will confirm your unsubscribe status via SMS. Following this confirmation, you will no longer receive SMS messages from us. To rejoin, sign up as you did initially, and we will resume sending SMS messages to you.

3. **Support Information:** If you experience issues with the messaging program, reply with the keyword "HELP" for more assistance, or reach out directly to {support_email} or call {phone} during business hours.

4. **Carrier Liability:** Carriers are not liable for delayed or undelivered messages.

5. **Message & Data Rates:** Message and data rates may apply for messages sent to you from us and to us from you. Message frequency varies based on your service usage and appointment schedule. For questions about your text plan or data plan, contact your wireless provider.

6. **Supported Carriers:** Our SMS program works with all major U.S. wireless carriers, including AT&T, T-Mobile, Verizon, Sprint, and most regional carriers.

7. **Age Restriction:** You must be 18 years or older to participate in our SMS program.

8. **Privacy Policy:** For privacy-related inquiries, please refer to our Privacy Policy.

We comply with all applicable laws and regulations, including the Telephone Consumer Protection Act (TCPA) and CTIA guidelines, regarding the use of SMS communications.

#### General Terms
This website (the "Site") is owned and operated by {business_name} ("COMPANY," "we" or "us"). By using the Site, you agree to be bound by these Terms of Service and to use the Site in accordance with these Terms of Service, our Privacy Policy, and any additional terms and conditions that may apply to specific sections of the Site or to products and services available through the Site or from {business_name}.

Accessing the Site, in any manner, whether automated or otherwise, constitutes use of the Site and your agreement to be bound by these Terms of Service.

We reserve the right to change these Terms of Service or to impose new conditions on the use of the Site from time to time, in which case we will post the revised Terms of Service on this website. By continuing to use the Site after we post any such changes, you accept the Terms of Service, as modified.

**Intellectual Property Rights — Our Limited License to You.** This Site and all the materials available on the Site are the property of {business_name} and/or our affiliates or licensors and are protected by copyright, trademark, and other intellectual property laws. The Site is provided solely for your personal non-commercial use. You may not use the Site or the materials available on the Site in a manner that constitutes an infringement of our rights or that has not been authorized by us. Unless explicitly authorized, you may not modify, copy, reproduce, republish, upload, post, transmit, translate, sell, create derivative works, exploit, or distribute in any manner or medium any material from the Site. However, you may download and/or print one copy of individual pages for your personal, non-commercial use, provided that you keep intact all copyright and other proprietary notices.

**Your License to Us.** By posting or submitting any material (including comments, blog entries, social media posts, photos, and videos) to us via the Site, internet groups, or other digital venues, you represent that you own the material or have obtained the necessary permissions. You grant us a royalty-free, perpetual, irrevocable, non-exclusive, worldwide license to use, modify, transmit, sell, exploit, create derivative works from, distribute, and publicly perform or display such material.

**Disclaimers.** Throughout the Site, we may provide links and pointers to Internet sites maintained by third parties. Our linking to such third-party sites does not imply an endorsement or sponsorship of such sites or the information, products, or services offered on or through the sites. The information, products, and services offered on or through the Site are provided "as is" and without warranties of any kind, either express or implied. To the fullest extent permissible pursuant to applicable law, we disclaim all warranties, including implied warranties of merchantability and fitness for a particular purpose.

**Indemnification.** You agree at all times to indemnify and hold harmless {business_name}, its affiliates, and their respective officers, directors, agents, and employees from any claims, causes of action, damages, liabilities, costs, and expenses arising out of or related to your breach of any obligation, warranty, or representation under these Terms of Service.

**Online Commerce.** Certain sections of the Site may allow you to purchase products and services from third-party vendors. We are not responsible for the quality, accuracy, timeliness, reliability, or any other aspect of these products and services. If you make a purchase from a third party linked through the Site, the information obtained during your visit, including payment information, may be collected by both the merchant and us. Your participation in any dealings with third-party vendors is solely between you and the third party. {business_name} shall not be responsible for any loss or damage incurred as a result of such dealings.

**Registration & Passwords.** To access certain features of the Site, you may be required to register and create an account. You agree to provide accurate, current, and complete information during the registration process. You are responsible for maintaining the confidentiality of your login credentials and for all activities conducted under your account. If you suspect unauthorized use of your account, notify us immediately at {support_email}. We are not liable for any loss or damage arising from your failure to comply with this obligation.

**Termination.** We reserve the right to terminate or suspend your access to the Site, without notice, if we determine that you have violated these Terms of Service or engaged in conduct that we deem inappropriate or unlawful. Upon termination, you must cease all use of the Site and any content obtained from it.

**Governing Law.** These Terms of Service shall be governed by and construed in accordance with the laws of the state in which {business_name} operates. Any dispute arising under these Terms shall be resolved exclusively through binding arbitration in that jurisdiction.

**Changes to Terms of Service.** We may update these Terms of Service from time to time. The latest version will always be available on our website with the effective date.

**Contact Us.** For any questions regarding these Terms of Service, please contact us at: {business_name}, Phone: {phone}, Email: {contact_email}.

By using our website and services, you consent to these Terms of Service.

---

## SECTION B — PRIVACY POLICY (verbatim template)

> The SMS sections + the **SMS Data Protection Statement** + the **IMPORTANT NOTICE** header are the carrier-load-bearing parts — reproduced exactly. Token slots only.

### {business_name} Privacy Policy
**Effective Date: {effective_date}**

**IMPORTANT NOTICE REGARDING TEXT MESSAGING DATA**

{business_name} ("we," "us," or "our") DOES NOT share customer opt-in information, including phone numbers and consent records, with any affiliates or third parties for marketing, promotional, or any other purposes unrelated to providing our direct services. All text messaging originator opt-in data is kept strictly confidential.

**1. Information We Collect.** We collect the following types of information. *Personal Information:* Name, email address, phone number, physical address; Payment information when you make a purchase or request a quote; Opt-in records and timestamps for all communication channels (SMS, email, etc.). *Non-Personal Information:* IP address, browser type, device information; Website usage patterns and analytics; Cookies and similar technologies. *Customer Communication:* Records of inquiries and service requests; Appointment details and preferences; Service history and feedback.

**2. How We Use Your Information.** We use collected data for: Providing and improving our services; Processing transactions and payments; Communicating with you about your inquiries, appointments, and promotions; Enhancing website functionality and user experience; Ensuring security and fraud prevention; Maintaining records of your communication preferences and consent.

**3. SMS Messaging & Compliance.** *Text Message Program Terms & Conditions.* By opting into our SMS messaging services, you agree to receive text messages related to our services, including appointment reminders, customer support, and important updates.
- *Opt-In & Consent:* You will only receive messages if you have explicitly opted in. We maintain timestamped records of all opt-in actions. We comply with the Telephone Consumer Protection Act (TCPA) and all applicable laws.
- *Opt-Out Instructions:* You can cancel SMS notifications at any time by replying "STOP." You will receive a final confirmation message, and no further messages will be sent unless you re-opt in. All opt-out requests are processed immediately.
- *Message Frequency & Content:* Message frequency varies based on your interactions with our business. Messages will be directly related to the services you have requested. We do not send promotional content without specific consent.
- *Help & Support:* Reply "HELP" for assistance or contact us at {support_email}. Customer support is available during regular business hours.
- *Carrier Information:* Standard message and data rates may apply. Carriers are not liable for delayed or undelivered messages. Supported carriers include AT&T, Verizon, T-Mobile, Sprint, and most regional carriers.

**SMS Data Protection Statement.** No mobile information will be shared with third parties/affiliates for marketing/promotional purposes. Information sharing to subcontractors in support services, such as customer service is permitted. All other use case categories exclude text messaging originator opt-in data and consent; this information will not be shared with any third parties. We implement strict data protection measures to safeguard your SMS opt-in information and consent records.

**4. Information Sharing & Disclosure.** We do not sell, rent, or trade personal information. We may share information with: *Service Providers:* Third-party vendors who assist in our operations (e.g., payment processing, appointment scheduling); SMS aggregators and providers solely for the purpose of delivering messages you've consented to receive; All service providers are contractually obligated to maintain confidentiality and security. *Legal Compliance:* If required by law, legal process, or to protect our rights; In response to valid law enforcement requests or court orders. *Business Transfers:* In case of mergers, acquisitions, or sale of assets; In such cases, your data remains protected under the terms of this policy. All the above categories exclude text messaging originator opt-in data and consent; this information will not be shared with any third parties, excluding aggregators and providers of the Text Message services.

**5. Data Security.** We implement and maintain reasonable security measures to protect your personal information: Encryption of sensitive data in transit and at rest; Secure access controls and authentication mechanisms; Regular security assessments and updates; Employee training on data protection; Breach notification protocols in accordance with applicable laws; Secure backup systems and disaster recovery procedures. Despite these measures, no method of transmission over the Internet or electronic storage is 100% secure. We strive to use commercially acceptable means to protect your personal information but cannot guarantee absolute security.

**6. Cookies & Tracking Technologies.** We use cookies and similar technologies to: Analyze site traffic and user behavior; Remember your preferences; Improve website functionality and user experience; Measure the effectiveness of our services. You may control cookies through your browser settings. Disabling cookies may limit your ability to use certain features of our website.

**7. Your Rights & Choices.** You have the right to: Access, update, or delete your personal information; Opt-out of marketing emails by clicking "unsubscribe" in our emails; Opt-out of SMS messages by replying "STOP"; Request information on how we process your data; Withdraw consent at any time for future communications; Lodge a complaint with a supervisory authority if you believe your rights have been violated. To exercise these rights, please contact us using the information in Section 10.

**8. Third-Party Links.** Our website may contain links to third-party websites. We are not responsible for their privacy practices and encourage you to review their policies. This privacy policy applies only to information collected by {business_name}.

**9. Changes to This Privacy Policy.** We may update this policy periodically. The latest version will always be available on our website with the effective date. For significant changes, we will notify you by email or through a notice on our website.

**10. Contact Us.** If you have questions about this Privacy Policy or how your information is handled, contact us at: {business_name}, Phone: {phone}, Email: {contact_email}.

By using our website and services, you consent to this Privacy Policy.

---

## SECTION C — OPT-IN FORM (verbatim template)

> Two SEPARATE checkboxes, UNCHECKED by default, NOT a condition of service. Phone field optional. The consent text below is the carrier-load-bearing language. Modeled on the approved Review Harvest consent language + the uploaded form screenshot.

**Request Information** — Contact us to learn more about our services and how we can assist with your needs.

- Full Name * (text field)
- Email Address * (text field)
- Mobile Phone Number (Optional) (text field)

**☐ (unchecked)** I consent to receive **{customer_care_category}** from {business_name}. Message frequency varies, up to 4 messages per month. Message & data rates may apply. Text HELP for assistance, reply STOP to opt out.

**☐ (unchecked)** I consent to receive **{marketing_category}** from {business_name} at the phone number provided. Message frequency varies, up to 4 messages per month. Message & data rates may apply. Text HELP for assistance, reply STOP to opt out.

[ Privacy Policy ]({privacy_url}) · [ Terms of Service ]({terms_url})

**[Submit]**

> **NICHE-LIBRARY MODEL (critical structure).** The consent checkbox = a FIXED compliance skeleton (the "I consent to receive … from {business_name} … message frequency varies … message & data rates may apply … Text HELP … reply STOP to opt out" wording is carrier-load-bearing and NEVER varies) + two niche-variable slots: `{customer_care_category}` and `{marketing_category}`. These two slots are filled from a PER-NICHE COPY LIBRARY keyed by `{segment}` (the business vertical). Only the category DESCRIPTION is niche-relevant; the compliance mechanics around it are fixed. The same two category strings also fill the campaign Call-to-Action paragraph (Section F) so the form and the A2P submission stay byte-consistent.
>
> **Per-niche copy library (seed entries — grows over time as more niches are approved; add new approved niche blocks here):**
> - **DEFAULT / generic** (any niche not yet in the library): `{customer_care_category}` = "messages regarding account issues and customer care", `{marketing_category}` = "promotional messages about new offers"
> - **Home services / Plumbing / HVAC / Trades** (seed from Mike's Plumbing): `{customer_care_category}` = "non-marketing messages about job status updates, estimate follow-ups, and service confirmations", `{marketing_category}` = "promotional notifications about new services, seasonal maintenance tips, and exclusive savings"
> - **Review/reputation service** (seed from Review Harvest): `{customer_care_category}` = "messages regarding account issues and outages (customer care)", `{marketing_category}` = "messages regarding new offers (marketing)"
> - *(future niches added here as they're approved — each entry is just the two category descriptions; the surrounding compliance language is always the fixed skeleton above)*
>
> RULE: a niche block ONLY supplies the two category-description strings. It must NEVER alter the surrounding compliance language (STOP/HELP/rates/frequency/privacy-link). If a niche isn't in the library yet, use the DEFAULT block — never freestyle the consent copy.

---

## SECTION D — SMS PROGRAM PAGE (verbatim template)

> Modeled on the uploaded SMS Program screenshot.

**SMS Program**

{business_name} may send SMS messages to customers who provide their mobile number and consent. Message frequency may vary. Message & data rates may apply.

- **Opt out:** Reply **STOP** at any time.
- **Help:** Reply **HELP** for assistance.
- **Support:** {contact_email} • {phone}

For additional details, please review our [Privacy Policy]({privacy_url}) and [Terms of Service]({terms_url}).

{business_name}
{address}
{contact_email} • {phone}

---

## SECTION E — CANONICAL APPROVED CAMPAIGN REFERENCE (Review Harvest LLC — the gold standard)

> This is a REAL APPROVED 10DLC campaign. It is the source-of-truth example the per-client generator anchors to, and it is shown side-by-side in the admin-view A2P-prep panel as the "approved example." The generated per-client copy must match this STRUCTURE; only tokenized identifiers + niche context change. Stored verbatim.

**Campaign Description (approved):**
REVIEW HARVEST LLC sends text messages to users who consent to receive promotional and customer care SMS messages. After the transaction, we request feedback from the user and direct them to Google to leave a review. We only ask for reviews we do not filter these reviews or send any other sort of marketing message. We will follow up via SMS if a user has not left a review. We also may contact our customers via SMS if they have submitted a support request. Msg volume may vary

**Call to Action / Message Flow (approved):**
Clients will be able to sign up to receive SMS notifications by checking their preference (customer care, marketing, or both) by clicking on https://www.reviewharvest.com/contact-us at https://www.reviewharvest.com/ at the very bottom of the website in the footer. Where they'll see a form to fill out information, and can click a specific box for marketing, and a specific box for customer care. The text for each reads: [ ] By providing a telephone number, clicking this button, and submitting the form, you are consenting to be contacted by SMS text message from REVIEW HARVEST LLC, regarding account issues and outages (customer care), (our message frequency may vary). Message & data rates apply. Reply STOP to unsubscribe from further messaging from REVIEW HARVEST LLC. Reply HELP for more information. See our Privacy Policy (containing our SMS Terms) at the bottom of the page for more information. [ ] By providing a telephone number, clicking this button, and submitting the form, you are consenting to be contacted by SMS text message from REVIEW HARVEST LLC, regarding new offers (marketing), (our message frequency may vary). Message & data rates apply. Reply STOP to unsubscribe from further messaging from REVIEW HARVEST LLC. Reply HELP for more information. See our Privacy Policy (containing our SMS Terms) at the bottom of the form for more information. Consent is provided exclusively for REVIEW HARVEST LLC to contact the user based on the selection, not any other third parties mentioned on the site. SMS opt-in data is not shared/sold to third parties for promotional/marketing purposes. Privacy Policy URL: https://www.reviewharvest.com/privacy-policy

**Sample Messages (approved):**
1. Hi John! Could you take a second to leave a review for Review Harvest? It only takes a few clicks, and it helps us out tremendously! Here's the link: {review-link} Reply STOP to opt out. Powered By Review Harvest
2. Hi Greg! Would you be willing to leave a review for Review Harvest? It only takes 30 seconds! Here's the link: {review-link} Reply STOP to opt out. Powered By Review Harvest
3. Hi Jessica! Would you be willing to leave a review for Review Harvest? It only takes 30 seconds! Here's the link: {review-link} Text STOP to opt out. Powered By Review Harvest
4. Hi Cody, thanks for reaching out! We have received your support ticket, please email us at support@reviewharvest.com or call us at 850-600-2205 if you need something in the mean time. We look forward to solving your problem! Text STOP to opt-out. Powered By Review Harvest
5. Hi Jenny, thanks for reaching out! For any support, please email us at support@reviewharvest.com or call us at 850-600-2205. We're here to help you! Text STOP to opt-out. Powered By Review Harvest

---

## SECTION F — PER-CLIENT CAMPAIGN TEMPLATES (tokenized from Section E)

> These are the templates the admin-view A2P-prep panel fills + displays for copy-paste into TextGrid. Same structure as the approved Review Harvest campaign; tokens from the business-data schema; sample-message structure FIXED, only the contextual nouns + identifiers vary.

**Campaign Description (template):**
{business_name} sends text messages to users who consent to receive promotional and customer care SMS messages. After the transaction, we request feedback from the user and direct them to Google to leave a review. We only ask for reviews we do not filter these reviews or send any other sort of marketing message. We will follow up via SMS if a user has not left a review. We also may contact our customers via SMS if they have submitted a support request. Msg volume may vary

**Call to Action / Message Flow (template):**
Clients will be able to sign up to receive SMS notifications by checking their preference (customer care, marketing, or both) by clicking on {optin_url} at {site_url} at the very bottom of the website in the footer. Where they'll see a form to fill out information, and can click a specific box for marketing, and a specific box for customer care. The text for each reads: [ ] By providing a telephone number, clicking this button, and submitting the form, you are consenting to be contacted by SMS text message from {business_name}, regarding {customer_care_category}, (our message frequency may vary). Message & data rates apply. Reply STOP to unsubscribe from further messaging from {business_name}. Reply HELP for more information. See our Privacy Policy (containing our SMS Terms) at the bottom of the page for more information. [ ] By providing a telephone number, clicking this button, and submitting the form, you are consenting to be contacted by SMS text message from {business_name}, regarding {marketing_category}, (our message frequency may vary). Message & data rates apply. Reply STOP to unsubscribe from further messaging from {business_name}. Reply HELP for more information. See our Privacy Policy (containing our SMS Terms) at the bottom of the form for more information. Consent is provided exclusively for {business_name} to contact the user based on the selection, not any other third parties mentioned on the site. SMS opt-in data is not shared/sold to third parties for promotional/marketing purposes. Privacy Policy URL: {privacy_url}

> The `{customer_care_category}` / `{marketing_category}` here MUST be the same niche-library strings used in the form checkboxes (Section C) — single source, so what the campaign paragraph claims matches what the form actually renders (a carrier consistency requirement).

**Sample Messages (template — fixed structure, ≥2 with STOP, real values not generic fields):**
1. Hi {contact_person}! Could you take a second to leave a review for {business_name}? It only takes a few clicks, and it helps us out tremendously! Here's the link: {review_link} Reply STOP to opt out. Powered By {business_name}
2. Hi {contact_person}! Would you be willing to leave a review for {business_name}? It only takes 30 seconds! Here's the link: {review_link} Reply STOP to opt out. Powered By {business_name}
3. Hi {contact_person}! Would you be willing to leave a review for {business_name}? It only takes 30 seconds! Here's the link: {review_link} Text STOP to opt out. Powered By {business_name}
4. Hi {contact_person}, thanks for reaching out! We have received your support ticket, please email us at {support_email} or call us at {phone} if you need something in the mean time. We look forward to solving your problem! Text STOP to opt-out. Powered By {business_name}
5. Hi {contact_person}, thanks for reaching out! For any support, please email us at {support_email} or call us at {phone}. We're here to help you! Text STOP to opt-out. Powered By {business_name}

> When filling the 5 samples for submission, use REAL distinct first names (not literal `{contact_person}` and not generic `{Name}`) — generic curly-brace fields are a carrier reject trigger. The niche context (e.g. "review for your recent plumbing service") may reflect {segment}, but the structure stays fixed.

---

## SECTION G — BRAND FIELDS (the A2P Brand registration form — admin-view pre-fills these per client)

> Pre-filled, business-customized, for copy-paste into TextGrid. Match enforced: contact email domain == website domain.

- Full Legal Company Name (as on IRS/EIN docs): {business_name}
- DBA or Brand Name (if different): {dba_name}
- Legal organization type: **Private Profit** (default — select every time)
- Segment: {segment}  *(one of: Agriculture · Construction, Materials, and Trade Services · Education · Energy and Utilities · Entertainment · Financial Services · Gambling and Lottery · Government Services and Agencies · Healthcare and Life Sciences · Hospitality and Travel · HR, Staffing or Recruitment · Information Technology Services · Insurance · Legal · Manufacturing · Media and Communication · Non-profit Organization · Political · Postal and Delivery · Professional Services · Real Estate · Retail and Consumer Products · Transportation or Logistics)*
- EIN/TIN Number: {ein}
- EIN/TIN Issuer (Country): {ein_country}
- DUNS/GIIN/LEI (if applicable): {duns_giin_lei_type} / {duns_giin_lei_number}
- Address/Street: {street} · City: {city} · State: {state} · Zip: {zip} · Country: {country}
- Website: {site_url}
- Contact Email Address: {contact_email}  ⚠️ **domain MUST match {site_url}'s domain — mismatch = campaign decline**
- Contact Phone Number: {phone_e164}  (E.164, e.g. +17183083801)

---

## SECTION H — COMPLIANCE RULES (durable reference — what gets a campaign declined)

- **Email domain MUST equal website domain** (the #1 hard rule). Prefill {contact_email} from {site_url}'s domain. (Deliverability bounce-testing is a NON-built fallback — if ever declined on it, set up forwarding then.)
- Privacy Policy + ToS are **NOT generic** — they name the company ({business_name}) and give real contact info; both are linked in the footer of every page AND referenced in the SMS opt-in.
- Privacy Policy MUST state mobile opt-in data is not shared with third parties for marketing (the SMS Data Protection Statement — Section B).
- ToS MUST carry the SMS disclosure (message types, "message frequency may vary," "message & data rates may apply," privacy link, "Text STOP to opt out").
- **All links must work; no typos** (both are decline triggers — validate links + spellcheck the generated site).
- Opt-in checkboxes: **two separate, unchecked by default, optional (not a condition of service)**, with the exact consent language.
- Sample messages: **real values (no generic `{Name}`/`{Company}` curly fields), ≥2 with STOP language, consistent with the campaign description.** If samples contain URLs/phone numbers, flag that in the campaign's "Campaign Attributes."
- `{review_link}` must resolve to a LIVE working page at submission (the on-site dummy review page) — carriers may click it.
