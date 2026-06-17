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
- Build a **real review-submission page** at **`{site_url}/review`** that records a review internally; `review_link_url` = that URL, **prefilled into the sample-message link token.**
- If the real review flow isn't wired yet at submission, the dummy page makes the link **valid**. When the real review system lands, the URL **matches or gets swapped — note the swap in the handoff.**
- The page **must actually load + accept a submission** (carriers may click it) — not a placeholder/404.

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
