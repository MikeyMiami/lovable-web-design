# 1f Step 6 — A2P / 10DLC Registration: Full Field Requirements (record)

> Historical TextGrid build spec (frozen). Live path is now the Supabase edge functions; Telnyx go-forward per `skills/telnyx-provider`.

> Parked here at the audit (2026-06-16) so the A2P-registration step of 1f has the **complete real field list** when we reach it — not rediscovered piecemeal. Extracted verbatim from the **TextGrid 10DLC API** doc (`C:\Users\Pierc\Downloads\TextGrid 10DLC API.txt`). The per-client model: each client gets its own subaccount → **Brand** (per-client) → **Campaign** → number, all under the agency master account; each vets independently (~2–4 days). This is the real shape of the deferred "vertical-field gap" — **it is bigger than just vertical.**

## TL;DR — the onboarding/capture gaps
Our current model assumes "client EIN, ≥15 days old" + a single brand/campaign path. The docs require MORE, and our onboarding (`onboard-from-form`) does not capture it:
1. **`vertical`** — REQUIRED for every entity type **except SOLE_PROPRIETOR** (optional there). Enumerated (23 values). Must map the client's niche/`search_term` to one of the enum KEYS — cannot be free text.
2. **`entityType`** — REQUIRED, and it BRANCHES the whole flow: `SOLE_PROPRIETOR` has **no EIN** (uses `firstName`/`lastName` + an **SMS OTP** verification flow), while `PRIVATE_PROFIT` etc. require `ein` + `companyName`. **Many local service businesses are sole proprietors** → our EIN-only assumption excludes them.
3. **`brandRelationship`** — REQUIRED enum (BASIC/SMALL/MEDIUM/LARGE/KEY_ACCOUNT). Not captured today.
4. **Campaign `termsAndConditionsLink` AND `privacyPolicyLink`** — both REQUIRED (Nov-2024 TCR). We capture `website_terms_page_link`; confirm we generate/store BOTH a T&C and a privacy page link.
5. The **"≥15 days old EIN"** rule is **NOT in the TextGrid docs** — likely a stale TCR/Twilio-era assumption; verify before relying on it.

These imply additive `clients` columns at the A2P step (beyond the already-planned `a2p_brand_id`/`a2p_campaign_id`/`a2p_status`): e.g. `a2p_vertical`, `a2p_entity_type`, `a2p_brand_relationship`, **`legal_address`** (the registered legal business address from the client's IRS documents — may differ from the public `clients.address`), sole-prop person fields, T&C + privacy links. (Confirm names at build.)

---

## Brand registration
`POST {baseUrl}/{version}/campaigns/brand/nonblocking` → returns `PENDING`; async TCR callback `BRAND_IDENTITY_STATUS_UPDATE` → VERIFIED/UNVERIFIED.
The body also accepts **`subAccountSID`** (attach the brand to the client's subaccount; blank = master) and `ipAddress`. *(Note: this `subAccountSID` body field is the ONLY place the docs sanction "parent acts on subaccount" — relevant to the outbound auth question, audit C2.)*

**Required fields by `entityType`** (Req / Opt / N/A):

| Field | SOLE_PROPRIETOR | PRIVATE_PROFIT | PUBLIC_PROFIT | NON_PROFIT | GOVERNMENT |
|---|---|---|---|---|---|
| `displayName` | Req | Req | Req | Req | Req |
| `companyName` | N/A | Req | Req | Req | Req |
| `ein` | N/A | Req | Req | Req | Req |
| `einIssuingCountry` | N/A | Opt | Opt | Opt | Opt |
| `firstName` | Req | N/A | N/A | N/A | N/A |
| `lastName` | Req | N/A | N/A | N/A | N/A |
| `phone` | Req | Req | Req | Req | Req |
| `mobilePhone` | Req (for OTP) | N/A | N/A | N/A | N/A |
| `street` | Req | Req | Req | Req | Req |
| `city` | Req | Req | Req | Req | Req |
| `state` | Req | Req | Req | Req | Req |
| `postalCode` | Req | Req | Req | Req | Req |
| `country` | Req | Req | Req | Req | Req |
| `email` | Req | Req | Req | Req | Req |
| `stockSymbol` | N/A | N/A | Req | N/A | N/A |
| `stockExchange` | N/A | N/A | Req | N/A | N/A |
| `brandRelationship` | N/A | Req | Req | Req | Req |
| **`vertical`** | **Opt** | **Req** | **Req** | **Req** | **Req** |
| `referenceId` | Req | Opt | Opt | Opt | Opt |
| `website` | Opt (all) | | | | |
| `altBusinessId` / `altBusinessIdType` | Opt (all) | | | | |
| `mock` | Opt (all) | | | | |

**SOLE_PROPRIETOR OTP flow:** `POST .../campaigns/brand/{brandId}/smsOtp` → then `PUT .../campaigns/brand/{brandId}/smsOtp` with `{"otpPin":"…"}`.

### Enums
- **`vertical`** (`GET .../campaigns/enum/vertical` — request uses the KEY): `PROFESSIONAL, REAL_ESTATE, HEALTHCARE, HUMAN_RESOURCES, ENERGY, ENTERTAINMENT, RETAIL, TRANSPORTATION, AGRICULTURE, INSURANCE, POSTAL, EDUCATION, HOSPITALITY, FINANCIAL, POLITICAL, GAMBLING, LEGAL, CONSTRUCTION, NGO, MANUFACTURING, GOVERNMENT, TECHNOLOGY, COMMUNICATION`. *(Map our niche/`search_term` → one of these. e.g. roofing/HVAC/plumbing → `CONSTRUCTION`; law → `LEGAL`; clinics → `HEALTHCARE`; agencies → `PROFESSIONAL`.)*
- **`entityType`**: `PRIVATE_PROFIT, PUBLIC_PROFIT, NON_PROFIT, GOVERNMENT, SOLE_PROPRIETOR`
- **`brandRelationship`**: `BASIC_ACCOUNT, SMALL_ACCOUNT, MEDIUM_ACCOUNT, LARGE_ACCOUNT, KEY_ACCOUNT`
- **`altBusinessIdType`**: `NONE, DUNS, GIIN, LEI`
- **`stockExchange`**: `NONE, NASDAQ, NYSE, AMEX, AMX, ASX, B3, BME, BSE, FRA, ICEX, JPX, JSE, KRX, LON, NSE, OMX, SEHK, SGX, SSE, STO, SWX, SZSE, TSX, TWSE, VSE, OTHER`

---

## Campaign registration (two-step)
1. **Qualify:** `GET {baseUrl}/{version}/campaigns/brand/{brandId}/usecase/{usecase}` → returns `minSubUsecases`, `maxSubUsecases`, per-MNO `minMsgSamples`, required flags.
2. **Create:** `POST {baseUrl}/{version}/campaigns/campaign`.

**Body schema (verbatim):**
```json
{
  "brandId","usecase","subUsecases":[],"description",
  "embeddedLink","embeddedPhone","numberPool","ageGated","directLending",
  "subscriberOptin","subscriberOptout","subscriberHelp",
  "sample1","sample2","sample3","sample4","sample5",
  "termsAndConditionsLink","privacyPolicyLink","messageFlow",
  "helpKeywords","helpMessage","optinKeywords","optinMessage",
  "optoutKeywords","optoutMessage","mnoIds":[],"referenceId",
  "autoRenewal","affiliateMarketing","expediteCampaign"
}
```
- **`usecase`** REQUIRED, enumerated (`GET .../campaigns/enum/usecase`): `2FA, ACCOUNT_NOTIFICATION, AGENTS_FRANCHISES, CARRIER_EXEMPT, CHARITY, CUSTOMER_CARE, DELIVERY_NOTIFICATION, EMERGENCY, FRAUD_ALERT, HIGHER_EDUCATION, K12_EDUCATION, LOW_VOLUME, MARKETING, MIXED, POLITICAL, POLLING_VOTING, PROXY, PUBLIC_SERVICE_ANNOUNCEMENT, SECURITY_ALERT, SOCIAL, SOLE_PROPRIETOR, SWEEPSTAKE, TRIAL, UCAAS_HIGH, UCAAS_LOW`. *(Our review/reactivation/lead drips → likely `MIXED` or `MARKETING` + `CUSTOMER_CARE`; confirm against use-case rules.)*
- **`subUsecases`** required only when the use-case's `minSubUsecases > 0` (e.g. `LOW_VOLUME` 1–5; `MIXED` 2–5).
- **Sample messages** `sample1`–`sample5` — count required is dynamic (Step-1 per-MNO `minMsgSamples`, commonly 2). We have the drip SMS copy → samples exist.
- **`termsAndConditionsLink` + `privacyPolicyLink`** now REQUIRED; `description` must disclose message frequency ("message frequency may vary"); opt-in/opt-out/HELP messages must contain the brand name + required disclosures.
- Opt-in/out/help keywords + messages: we have STOP/HELP/START + "pass" → register `optinKeywords`/`optinMessage`/`optoutKeywords`/`optoutMessage`/`helpKeywords`/`helpMessage`.
- Optional: CTA `POST .../campaigns/{campaignId}/cta`; MMS media `.../mms` (base64).

**Attach number to campaign:** `POST {baseUrl}/{version}/campaigns/number/{campaignId}` with `{"phoneNumberSids":["…"]}` (the number **Sid**, not the E.164). Shared/imported campaigns: `GET .../campaigns/{campaignId}/import/{accountSid}` (TextGrid CSP ID = `SD3HNY9`).

## TCR event webhook (account-level)
Dashboard → Settings → Advanced → **TCR Event Callback URL**. TextGrid POSTs `?TCREvent=<event>`. Events incl. `BRAND_IDENTITY_STATUS_UPDATE`, `BRAND_SCORE_UPDATE`, `CAMPAIGN_DCA_COMPLETE`, `CAMPAIGN_BILLED`, `CAMPAIGN_EXPIRED`, … Payload (flat JSON): `cspId, brandName, campaignId, brandReferenceId, brandId, description, mock, eventType, cspName, campaignReferenceId`. *(This is how we learn a per-client Brand/Campaign got approved — wire it at step 6 to flip `a2p_status`.)*

---
**Owner:** A2P-registration step of 1f (step 6). Cross-refs: spec §9b/§A2P (per-client model), `onboard-from-form` (capture gaps), HANDOFF §4 item 2 (the original vertical-gap flag — now superseded by this full list).
