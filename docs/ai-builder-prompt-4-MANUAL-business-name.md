# AI Builder — Prompt 4 (MANUAL variant): `mode="builder"` on OnboardWizard + the `/build` route

> **This REPLACES `ai-builder-prompt-4-wizard-builder-mode.md`.** Same scope, one deliberate change: step 1 is a manual business-name input instead of Google Places search.
>
> Places is blocked on Google Cloud billing. Rather than hold the whole funnel behind ~$10, we ship the wizard now with manual entry and drop Places in later as a pure upgrade to one component.
>
> Spec: `docs/ai-builder-lead-magnet-build-spec.md` §2. Prompts 0–3b are already shipped. **Do not fork `OnboardWizard`. Extend it.**

---

## Context

`src/components/onboard/OnboardWizard.tsx` already contains almost every field the public builder needs, already runs unauthenticated in `mode="client"`, and already autosaves drafts server-side. We are adding a third mode with a different step order and a reduced field set — not a new component.

Forking would immediately drift the per-service photo behaviour (`ServicePhotoRow`, ~line 1422), which is exactly the "services carry over to photos" requirement.

---

## What changed from the original prompt 4, and why

| | Original | This version |
|---|---|---|
| Step 1 | `PlacesStep` — Google autocomplete, GBP required | `BusinessStep` — typed business name |
| Name / address / phone / hours / city | Prefilled from Google | Typed by the prospect |
| `placeId` | Real Google place id | Empty string, field retained |
| Quality gate | "Must have a Google Business Profile" | None — accepted trade, see below |

**The trade, stated plainly.** The GBP requirement was a quality gate: it guaranteed the business was real, and it pre-filled six fields so the form felt like magic. Losing it means more typos, more junk submissions, and a longer form. We are accepting that to start collecting leads now. Everything else in this prompt is built so Places can be reinstated later by replacing one component — no renumbering, no schema change, no migration.

---

## Scope

### 1. Extend the component contract

```ts
mode: "agency" | "client" | "builder"
```

Add `const isBuilder = mode === "builder";` next to the existing `isAgency`.

Add to `State` (and to `initial`):
```ts
suggestions: string;   // free-text creative direction
placeId: string;       // "" in this version — see below
```

**Keep `placeId` even though nothing sets it.** Prompt 5 maps it to `clients.demo_place_id`, and the column already exists and is nullable. Retaining the field means the Places upgrade later touches one component instead of the whole chain.

### 2. Builder step order

Add alongside the existing `STEPS` (~line 211):

```ts
const BUILDER_STEPS = [
  "Your business",
  "What you do",
  "About you",
  "Where you work",
  "Hours",
  "Make it yours",
  "Show your work",
  "Creative direction",
  "Where to send it",
] as const;
```

Still **nine** steps — the same count and the same slots as the Places version, so reinstating Places renames step 1 and nothing else.

Use `const ACTIVE_STEPS = isBuilder ? BUILDER_STEPS : STEPS` everywhere the current code reads `STEPS` (bounds clamping, progress indicator, stepper header).

Show **"Step N of 9"** from the very first screen. The prospect must always see the finish line.

### 3. Step contents

| Step | Renders | Notes |
|---|---|---|
| 1 Your business | New `BusinessStep` (below) | |
| 2 What you do | `segment` selector + `servicesRows[].name` | Reuse existing services rows; **hide price_min/price_max in builder mode** |
| 3 About you | `aboutUs`, `differentiators` | Existing Content-step fields |
| 4 Where you work | `primaryCity` (**now required**), `additionalAreasCsv` | Was prefilled from Places; nothing prefills it now, so it must be entered and validated |
| 5 Hours | existing hours grid + `timezone` | See below — framing changes and it becomes skippable |
| 6 Make it yours | logo upload + **exactly two** colour pickers (`brandColor`, `brandSecondary`) | Two selectors only. Do **not** render `brandTertiary` in builder mode |
| 7 Show your work | existing `PhotosStep` + `ServicePhotoRow` | **Must be skippable** |
| 8 Creative direction | `suggestions` textarea | Copy below |
| 9 Where to send it | `firstName`, `lastName`, `email`, `phone` — **all required** | Submit: **"Generate My Website"** |

**Hidden in builder mode** (present in `mode="client"`, must not render here): domain / `preferredDomain` / `noDomain`, `notificationEmail`, `supportEmail`, the entire Social Links step, the entire Texting Registration step (EIN, `legalName`, `dba`, `vertical`, `tcpaAttestation`, `legalAddress`, EIN letter upload), `slug`, and `discountOffer`.

**Step 5 hours — changed from the original.** The Places version prefilled these and asked "look right?". Nothing prefills them now, and an empty seven-row grid early in a funnel is where people quit. So:
- Default every day to a sensible **9:00–5:00, Mon–Fri open, Sat/Sun closed**, and say so: *"We've assumed standard hours — change anything that's wrong."*
- Default `timezone` from the browser (`Intl.DateTimeFormat().resolvedOptions().timeZone`), falling back to `America/New_York`.
- Add **"Skip — I'll set hours later"** as a secondary action.

**Step 7 skip.** Prominent secondary action: **"Skip — use stock photos for now"**. Most prospects have no photos to hand, and a mandatory photo step is where this funnel would die. Skipping is a normal, unpenalised path.

**Step 8 copy**, verbatim:
> **Any suggestions or creative direction you'd like to tell the AI about how you want your site to look, feel, features, etc?**
> *Optional — but the more you tell us, the closer the first draft lands.*

**Step 9 framing.** This is delivery, not capture. Headline: **"Where should we send your site?"** Sub: *"We'll build it and send you the link."* Do not label it "Contact information".

### 4. New `BusinessStep` component — replaces `PlacesStep`

Same file, alongside `PhotosStep`. Deliberately small: it exists to be swapped for the Places version later.

**Fields**
1. **Business name** — required.
   - Label: **"Business name"**
   - Helper, verbatim: *"Exactly as you want it to appear on your website."*
   - Writes to the same `State` field the Places version would have populated (`companyName` / whatever the existing wizard already uses — **reuse the existing field, do not add a new one**).
   - Trim on blur. Collapse runs of internal whitespace to one space.
2. **Phone** — required.
   - Label: **"Business phone"**, helper: *"The number customers should call."*
   - This is the anti-bounce capture the Places version got from `nationalPhoneNumber`. It is the single most valuable field on the page for the operator, so it is required here rather than left to step 9.
   - Accept any format; normalise to 10 digits for storage; reject anything that is not a valid 10-digit US number with an inline message.

**Validation — Next stays disabled until:**
- business name is **≥ 2 characters after trimming**, and
- phone normalises to exactly **10 digits**.

**Do not** add a "search Google instead" affordance, a placeId input, or a hidden autocomplete. There is nothing behind them yet, and a dead control is worse than an absent one.

**Do not** validate the business name against any external source. There is no gate in this version — that is the accepted trade, not an oversight to work around.

### 5. Session bootstrap + PoW — unchanged from the original prompt

On mount of the `/build` route:
1. `POST /api/public/builder/challenge` → `{ challenge, sig, bits }`.
2. Solve the PoW **in a Web Worker** so the UI never blocks: increment `nonce` until `SHA-256(challenge + "." + nonce)` has ≥ `bits` leading zero bits. Token is `` `${challenge}.${sig}.${nonce}` ``.
3. `POST /api/public/builder/start` with `{ pow_token, website: "" }` → store `{ token, draftId }` in component state **and** `sessionStorage` so a refresh resumes.
4. Mint a **second** challenge in the background once the first is spent — step 9's `generate` call needs its own fresh token (the replay guard makes them single-use).

> `verifyPow` rejects challenges younger than **3 seconds** (`pow.server.ts:20,147`). Minting on mount and solving in the background satisfies this naturally. Do **not** mint on button click.

### 6. Wiring uploads and drafts — unchanged

- Uploads: reuse `uploadSiteImageViaProxy(token, category, file)` and `uploadClientLogo(token, "contain", file, "proxy")` — the same calls `mode="client"` makes. `api/public/onboarding/upload.ts` needs **no change**; it resolves `draft_id` from the token row.
- Draft autosave: the existing 1.5s-debounced `saveOnboardingDraft({ token, draft: { s, step } })` effect currently guards on `mode !== "client"`. Widen it to `mode === "client" || mode === "builder"`, and also POST `last_step` so the Abandoned queue is accurate.
- Keep the existing `localStorage` draft behaviour — it is what lets someone close the tab and come back.

### 7. The route — unchanged

New **public** (not `_authenticated`) route `src/routes/build.tsx`:

```tsx
export const Route = createFileRoute("/build")({
  head: () => ({ meta: [{ title: "Free AI Website Builder — PierceWorks" }] }),
  component: () => <OnboardWizard mode="builder" />,
});
```

Standalone marketing-quality chrome — no agency/app nav. Mobile-first: a large share of prospects will hit this from a phone.

**Footer disclosure, required:**
> By using this tool you agree we may contact you about your website.

### 7b. Host-based root redirect — unchanged, still required

`src/routes/index.tsx` hard-redirects `/` to `/login`, so without a change a prospect hitting the bare builder domain lands on the operator login page.

**Do this in `hostRedirect()` in `src/server.ts`, NOT in the route's `beforeLoad`.** That function already exists, runs **before the app handler**, and already implements exactly this shape for `reviewbatch.com`.

Add a branch for the builder host **before** the final `return null`:

```ts
if (host === BUILDER_HOST) {
  if (url.pathname === "/") {
    return Response.redirect(`https://${BUILDER_HOST}/build${url.search}`, 302);
  }
  return null;   // /build and /api/public/builder/* serve normally
}
```

- **Never redirect this host to `app.pierceworks.co`.** That would break the form entirely. Only `/` → `/build`, on the same host.
- Put the hostname in a config constant (`BUILDER_HOST`), not an inline literal — it differs between preview and production.
- Preserve `url.search` so campaign/UTM params survive the hop.

**Regression — verify all four:**
- `aibuilder.pierceworks.co/` → 302 → `aibuilder.pierceworks.co/build`
- `aibuilder.pierceworks.co/build` → 200, serves the form
- `app.pierceworks.co/` → still 307 → `/login`
- `cloud-spark-setup.lovable.app/` → still 302 → `app.pierceworks.co`

---

## Invariants

- `mode="agency"` and `mode="client"` behaviour is **completely unchanged**. Every builder-specific branch is additive and guarded by `isBuilder`.
- `ServicePhotoRow` and `PhotosStep` are reused as-is, not copied.
- No A2P field is rendered, submitted, or stored anywhere in this flow.
- **Do not touch** `src/routes/api/public/builder/places/*`. Those routes are shipped and validated; they are simply unused until the key works. Deleting them is churn and would have to be rebuilt.

---

## Self-check before reporting done

1. **Regression:** run the full `/onboard` agency wizard and a `/onboard/$token` client wizard end to end. Both unchanged — same steps, same fields, same submit.
2. `/build` loads on mobile viewport; PoW solves without freezing the UI; a session row appears in `onboarding_tokens`.
3. Step 1: Next is disabled with an empty name; disabled with a 1-character name; disabled with a malformed phone; enabled once both are valid.
4. Phone accepts `(555) 123-4567`, `555-123-4567` and `5551234567`, and stores the same 10 digits for all three.
5. Walk all 9 steps. Confirm no EIN, no social links, no domain, no `notificationEmail` field appears anywhere.
6. Step 5 shows the assumed 9–5 Mon–Fri defaults and a working skip.
7. Step 6 shows exactly **two** colour pickers.
8. Step 7 skip works and leaves `siteAssets` empty without blocking progress.
9. Add 3 services in step 2 → step 7 shows a photo row per service, correctly labelled.
10. Refresh the browser mid-form → progress and entered data survive.
11. `select last_step from onboarding_tokens where token=...` tracks the current step.

## Report back with

- Screenshots of steps 1, 5, 6, 7 and 9 at mobile width.
- Confirmation that the agency and client wizards were re-run and are unchanged.
- The stored phone value for the three input formats in check 4.

---

## Carried into prompt 5 — read before running it

Prompt 5 assumes a real `placeId`. With manual entry it will be `""`:

1. **`clients.demo_place_id` will be null.** The column is nullable — write `null` rather than an empty string, so "no Google listing" is distinguishable from "empty".
2. **Prompt 5's self-check 2** expects "place id present". That assertion must be dropped for manually-entered demos.
3. **Prompt 5's double-submit check** dedupes on `select count(*) ... where demo_place_id = '<id>'`. That does not work with nulls. The single-use token replay guard (`403 token_used_or_invalid`) is still the real protection; verify that instead.
4. **Duplicate businesses become possible.** Two people can submit the same business name and both get a demo. Acceptable while collecting leads; if it becomes noisy, dedupe on normalised name + phone rather than reinstating a fake place id.
