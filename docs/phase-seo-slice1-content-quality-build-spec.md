# SEO SLICE 1 — content-quality wins (per-type prompts + structure) — build spec [HELD]

> Prompt-only changes inside `aiWritePage` (+ one read-addition: the client phone for the CTA). **ZERO schema.** Branches the content prompt by page type to `seo-content` §3's patterns + upgrades structure/formatting to §1 "well-formatted" + §4 conversion. All locked guards unchanged. Grounded on `origin/main` @ `d51ba38`. Awaiting review.

## Read-only-verify findings (against d51ba38)
- **The gap is real + isolated to the prompt.** `aiWritePage` builds one `prompt` array (`seo.functions.ts:714-746`); `Page type: ${page.type}` is passed as a *fact* (`:720`) but the instruction body is **identical for all types** — the generic "Write genuinely useful… what's included, why it matters, what to expect" (`:735-736`) + a flat "Formatting rules" block (`:738-745`). No §3 per-type branching.
- **Phone for the CTA:** `aiWritePage` currently selects `business_name, address, service_area, template_vars` (`:678`) — **no phone.** `clients` has **`phone_display`** + **`twilio_number`** (`types.ts:64/78`). Public NAP phone per `seo-build` §6 = `twilio_number` (provisioned tracking number, single-source) with `phone_display` fallback. ⇒ add both to the select; `publicPhone = twilio_number ?? phone_display`. (One read line; still zero-schema, confined to `aiWritePage`.)
- **Guards to preserve verbatim:** PROVIDED CONTEXT + STRICT ACCURACY block (`:717-733`), start-at-`<h2>`/no-`<h1>` (`:740`), inline editorial `<a>` (`:744-745`), Title Case (`:741`), the `<!-- ai-written -->` marker (`:764`, post-generation), code-fence strip (`:756`), body-only `update` (`:769`). This slice changes only the per-type BRIEF + the STRUCTURE block.

## Per-type prompt intent ↔ `seo-content` §3 pattern (fidelity map — verify here)
| Type | `seo-content` §3 pattern | New prompt BRIEF (what SLICE 1 asks) |
|---|---|---|
| **home** | "talks directly to the searcher (what you do, how fast, where); each secondary category gets an H2 + 50–100 words + an editorial link to its category page." | *"This is the HOMEPAGE (GBP landing page). Speak DIRECTLY to the searcher: what {business} does, how quickly/reliably, and where (serving {city}). Open with a short searcher-focused intro. Then for EACH editorial link below (each is a CATEGORY page) write an `<h2>` for that category + 50–100 words (what it is, why customers need it, why {business} is good at it), weaving that category's editorial `<a>` inline. Keep it an overview that routes visitors to the category pages — don't go deep on any single service."* |
| **category** | "what the category is / why customers need it; each service under it gets an H2 + 50–100 words + editorial link to the service page." | *"This is a CATEGORY page for '{h1}'. Explain what this category is and why customers in {city} need it. Then for EACH editorial link below (each is a SERVICE in this category) write an `<h2>` for that service + 50–100 words, weaving that service's editorial `<a>` inline. A mid-level overview that routes visitors to the individual service pages."* |
| **service** | "specific to that one service: why customers need it, what's included, how long, what to expect, cost ranges where useful. Not generic advice." | *"This is a SERVICE page for '{h1}' — go DEEP on this ONE service (not generic advice). Separate sections for: why customers in {city} need it; WHAT'S INCLUDED (use the bulleted list here); the PROCESS / what to expect (timeline, steps); and why it matters locally in {city} (local conditions/specifics). Weave the editorial link(s) below inline (typically back to the parent category)."* |
| *default* (geo/supporting — not creatable yet) | (deep single-topic, genuinely local) | *"Go deep on this single topic ('{h1}') with genuinely useful, locally-specific content for {city}; weave the editorial link(s) below inline."* |

## What SLICE 1 does NOT do — the per-page-writer ↔ content-tool boundary [explicit]
SLICE 1 makes the per-page writer follow **§3 (per-type patterns)** + **§1 (well-formatted structure)** + keeps **§1b (anti-hallucination)**, **§6 (editorial links)**. It remains a **single `generateText` call** — a "lighter first pass." It does **NOT**, and these stay **deferred to the content-automation tool:**
- **§5 research inputs** — no People-Also-Ask / Reddit / competitor / real local research fed in. Local specificity is *asked for* but not *sourced*, so the model generalizes within the anti-hallucination guard (safe but shallow-local). *(Feeding real local data — esp. for geo pages — is a later multi-location/tool concern.)*
- **§4 8-pass pipeline** — no research→brief, no strategic outline, no section-by-section separate calls, no **burstiness** pass, no **perplexity/de-AI** pass, no **human-bookends** pass, no **AI-detection scoring**, no multi-pass **QC**. One pass only.
- **cost ranges from real data / pricing** — the guard forbids inventing; no pricing source exists yet.
- **§7-8 rank-map decisioning + monthly cadence** — the tool's brain, unbuilt.
So: **following the method now** = per-type patterns + well-formatted structure + accuracy + editorial linking. **Still the lighter first pass (tool later)** = research depth + multi-pass human-passing refinement + rank-map loop.

---

# PROMPT SEO SLICE 1 — paste into Lovable (cloud-spark-setup)

> **App-layer on `golden-master-v1.7`. ZERO schema change** — prompt-only changes inside `aiWritePage` (`src/lib/seo/seo.functions.ts`) + add the client phone to that fn's existing `clients` select (for the CTA). No migration, no new fn, no other file. Report the diff + confirm no DB/schema change.

## 1. Read the phone (for the CTA)
In `aiWritePage`, change the `clients` select from `business_name, address, service_area, template_vars` to **`business_name, address, service_area, template_vars, phone_display, twilio_number`**. Compute `const publicPhone = String(client.twilio_number ?? client.phone_display ?? "").trim();`.

## 2. Add the phone to PROVIDED CONTEXT (guard-consistent)
Append one line to the PROVIDED CONTEXT block: `` `- Business phone (use ONLY this number in a CTA; if "(none)", invite contact WITHOUT inventing a number): ${publicPhone || "(none)"}` ``. **Leave the STRICT ACCURACY RULES block unchanged.**

## 3. Branch the content BRIEF by page type (self-contained — briefs inlined)
Build a `typeBrief` (array of lines) via `switch (page!.type)`. Insert it into the prompt **after** the STRICT ACCURACY block, under a header line `"PAGE BRIEF — write to THIS page type's job:"`. This **replaces** the generic two-line "Write genuinely useful, locally-specific content…" (`:735-736`). Use template literals with `businessName`, `cityDisp`, `h1Disp`. The branches:
- **`case "home"`:**
  - `This is the HOMEPAGE (the Google Business Profile landing page).`
  - `Speak DIRECTLY to the searcher: what ${businessName} does, how quickly and reliably, and where (serving ${cityDisp}).`
  - `Open with a short searcher-focused intro paragraph (what you do + where + why choose you).`
  - `Then, for EACH editorial link listed below (each link is a CATEGORY page), write an <h2> for that category followed by 50-100 words on what it is, why customers need it, and why ${businessName} is good at it - weaving that category's editorial <a> inline in the paragraph.`
  - `Keep this an overview that routes visitors to the category pages; do NOT go deep on any single service here.`
- **`case "category"`:**
  - `This is a CATEGORY page for "${h1Disp}".`
  - `Explain what this category of service is and why customers in ${cityDisp} need it.`
  - `Then, for EACH editorial link listed below (each link is a SERVICE in this category), write an <h2> for that service followed by 50-100 words about it - weaving that service's editorial <a> inline in the paragraph.`
  - `This is a mid-level overview of the category's services that routes visitors to the individual service pages.`
- **`case "service"`:**
  - `This is a SERVICE page for "${h1Disp}" - go DEEP on this ONE service (not generic advice).`
  - `Cover, as separate sections: why customers in ${cityDisp} need this service; WHAT'S INCLUDED (use the bulleted list here); the PROCESS / what to expect (timeline, steps); and why it matters locally in ${cityDisp} (local conditions/specifics).`
  - `Weave the editorial link(s) listed below inline (typically a link back to the parent category).`
- **`default`:**
  - `Go deep on this single page topic ("${h1Disp}") with genuinely useful, locally-specific content for ${cityDisp}; weave the editorial link(s) listed below inline.`

## 4. Upgrade the formatting block (replace the old "Formatting rules" `:738-745`)
Under a header `"STRUCTURE & FORMATTING (well-formatted, scannable — like a real local-business page):"`:
- Output HTML only (no markdown, no code fences).
- Start at `<h2>` (NO `<h1>` — the page already has one).
- **At least 3 `<h2>` sections**; use `<h3>` subheadings where a section has sub-points.
- **Short paragraphs (2–4 sentences)** — no walls of text.
- **Include one bulleted `<ul>`** where it fits (e.g. a "What's Included" / "What We Cover" list).
- **End with a short call-to-action section** (`<h2>` or `<h3>`) inviting the reader to call — **use ONLY the provided Business phone; if none provided, invite them to get in touch without inventing a number.**
- Proper Title Case for every heading; preserve acronyms exactly (HVAC, AC, LLC — never "Hvac"/"llc").
- Approximately **400–700 words** (bumped from 300–600 for the richer structure).
- No keyword-stuffing.
- **You MUST weave each of these editorial links inline as `<a href="HREF">ANCHOR</a>` inside sentences (not a list):** + `linkList`.

## 5. Unchanged (do NOT touch)
PROVIDED CONTEXT (except the added phone line) + STRICT ACCURACY block; the `generateText` call (one call, `gemini-3-flash-preview`); the code-fence strip; the `<!-- ai-written -->` marker prepend; the **body-only** `update({ body, updated_at })`; `statusCode`-on-throw; `assertAgencyAdmin`. **`aiWritePage` still updates `body` only.**

## Guardrails
- **ZERO schema/migration**, no new fn, only `aiWritePage` changes (+ the phone in its select). `body`-only write preserved (og_image/images-to-come untouched).
- Anti-hallucination, one-H1, inline editorial links, Title Case, ai-written marker — all preserved.
- Still **one** `generateText` call (Worker-safe).

## Drift check (report back)
1. File: `seo.functions.ts` (`aiWritePage` only) + the phone in its `clients` select. No migration/new fn.
2. Prompt branches by `type` (home/category/service/default) per §3; PROVIDED CONTEXT gained the phone line; STRICT ACCURACY unchanged.
3. Structure block enforces ≥3 `<h2>`, a `<ul>`, short paras, a CTA with the provided phone.
4. Guards intact; body-only update; one `generateText` call.

## VALIDATION
1. **AI-write a `home` page** → talks to the searcher + an `<h2>` per category with its editorial `<a>` inline; overview, not deep.
2. **AI-write a `category` page** → explains the category + an `<h2>` per service with its editorial `<a>`.
3. **AI-write a `service` page** → deep single-service: why-needed / **What's Included bulleted list** / process / local — with the parent-category `<a>` inline.
4. **All three:** start at `<h2>` (no `<h1>`), ≥3 sections, short paras, a closing CTA using the client's real phone (or a no-number CTA if none); Title Case; `<!-- ai-written -->` marker present; badge shows.
5. **Anti-hallucination holds** — no invented name/year/warranty/awards/pricing; a client with no phone → CTA has no fabricated number.
6. Zero schema; body-only (og_image untouched); non-admin blocked.

## Status
**HELD — awaiting review.** Sets up images-v2 (≥3 sections → hero + inline-1 + inline-2 interleave). Next per the sequence: images v2 (`images jsonb`) → multi-location → ongoing tool.
