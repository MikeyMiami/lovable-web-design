# SEO — Outbound authority link (in-content) — build spec [HELD]

> The genuine on-page half of the expert's external-link requirement: ONE in-content outbound link to an authority source per page (`W3deWbeigsg:141` "an outbound link gets placed"; `FifSqbB0:534-535` "inserting highly relevant external links to authority sources"). **INBOUND backlinks are OFF-SITE agency ops — NOT in this build** (see `docs/seo-method-congruence-audit.md` + the roadmap's Agency Link-Building Tracker). **ZERO schema** — reuses the existing `content_pages.external_link` column + `updatePage` patch. Grounded on `cloud-spark-setup` `origin/main` @ `ad33789`. Awaiting review.

## Read-only-verify findings (against ad33789)
- **`external_link` already plumbed end-to-end EXCEPT the AI weave:** column exists (STORE-1); `updatePage` `.strict()` patch accepts it (`seo.functions.ts:568`); the panel edit dialog has an `externalLink` state (`admin.seo.tsx:937`), an input (`:1055`), and saves it (`:991`); the pages query selects it (`:560`).
- **The gap:** `aiWritePage` does NOT select `external_link` (its page select is `id, client_id, slug, type, title, h1, target_keyword, internal_links`) and does NOT weave it into the body. That's the build.
- **Anti-hallucination boundary:** the outbound URL must be **operator-provided** — the AI must NEVER invent an authority URL (a fabricated/wrong citation is a hallucination). If `external_link` is empty, no outbound link is written.
- **AI-write-safe:** the URL lives in the `external_link` column (not `body`), so it's re-woven from the column on every rewrite — never lost, never fabricated. Same pattern as `internal_links`.

---

# PROMPT — Outbound authority link — paste into Lovable (cloud-spark-setup)

> **App-layer on `golden-master-v1.7`. ZERO schema change** — reuses `content_pages.external_link` (column + `updatePage` patch already exist). Two changes: (1) label the existing panel field as the "Outbound authority link"; (2) make `aiWritePage` weave it into the body when present. Report the diff + confirm no DB/schema change.

## 1. Panel (mostly reuse) — `src/routes/_authenticated/admin.seo.tsx`
- The edit dialog's existing `external_link` input (`:1055`): **relabel to "Outbound authority link"** with helper text — *"A relevant authority source (industry body, .gov/.edu, standards/manufacturer page — not a competitor). The AI weaves one natural in-content link to it. Leave blank to omit."* Saves as-is via `updatePage` (`external_link`).
- **Optional [flag]:** add the same field to the **Photo-Board** row/detail (Slice 2.5) and/or a Pages-list **"needs authority link"** badge when `external_link` is empty (per the method's "every page needs one").
- No other panel change; `external_link` continues to save through the existing `updatePage` patch.

## 2. `aiWritePage` weave — `src/lib/seo/seo.functions.ts`
- **Read:** add `external_link` to the page select (currently `id, client_id, slug, type, title, h1, target_keyword, internal_links` → add `, external_link`). Compute `const externalLink = String(page!.external_link ?? "").trim();`.
- **PROVIDED CONTEXT:** append one line — `` `- Outbound authority link (if present, weave EXACTLY ONE natural in-content link to it; if "(none)", do NOT invent one): ${externalLink || "(none)"}` ``.
- **STRUCTURE & FORMATTING:** add one rule — `"- If an Outbound authority link is provided above, weave EXACTLY ONE natural sentence that links out to it as <a href=\"URL\" target=\"_blank\" rel=\"noopener\">sensible anchor</a> (relevant, not forced). If none is provided, do NOT invent or add any external link."`
- **Do NOT** touch the STRICT ACCURACY block, the internal-link weave, one-`<h1>`, the marker, or the body-only `update`. Still one `generateText` call.

## Guardrails
- **ZERO schema/migration** — only `admin.seo.tsx` (label + optional flag) + `aiWritePage` (read + 2 prompt lines).
- AI weaves the outbound link **only when `external_link` is set**; **never invents** a URL (anti-hallucination).
- URL in the `external_link` column → **AI-write-safe** (re-woven each rewrite). Body-only `update` preserved. One `generateText` call (Worker-safe).
- **INBOUND backlinks are NOT built here** (off-site agency ops).

## Drift check (report back)
1. Files: `admin.seo.tsx` (label/helper + optional flag) + `seo.functions.ts` (`aiWritePage`: `external_link` in select + 2 prompt lines). No migration/new fn/schema.
2. `aiWritePage` weaves ONE outbound `<a rel="noopener">` when `external_link` present; adds nothing when absent.
3. `external_link` continues to save via the existing `updatePage` patch.

## VALIDATION
1. Set a page's Outbound authority link (e.g. an industry/.gov URL) → Save → AI-write the page → body contains ONE natural sentence with `<a href="…" target="_blank" rel="noopener">…</a>` to that URL.
2. Leave `external_link` blank → AI-write → **no external link** in the body (none invented).
3. Re-AI-write → the outbound link is re-woven from the column (survives; not duplicated).
4. Anti-hallucination intact (no invented URLs/facts); one-`<h1>`; internal links still weave.
5. Zero schema; body-only; non-admin blocked.

## Status
**HELD — awaiting review before sending to Lovable.** Pairs with the `seo-content` §6 correction (three link types) + the congruence audit + the roadmap's Agency Link-Building Tracker (inbound, off-site).
