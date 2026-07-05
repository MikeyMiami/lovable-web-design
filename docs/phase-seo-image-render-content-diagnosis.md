# SEO — inner-page render + content diagnosis (3 issues) — SCOPE [HELD]

> Diagnosed against real code (template `professional-landscpaing-template` @ `e1ff928`, backend `cloud-spark-setup` @ `044b865`) + **live RPC/SSR data** for `test-landscaping` / `irrigation`. No build. Commits held.

## ISSUE 1 — inline images missing (root cause = `body_format` mismatch, NOT the interleave)
**Evidence (live SSR of `/services/irrigation`):** `0` real `<h2>`, **`5` escaped `&lt;h2`**, **no `<figure>`**, only the hero renders. Live RPC: `body_format = null`, body is real HTML (starts `<!-- ai-written -->` then `<h2>…`, 5 `<h2>`s).
**Mechanism:** the template does `page.body_format === "html" ? page.body : renderMarkdownLite(page.body)` (`ContentPageView.tsx:25-26`). `body_format` is **null** on every real row (seedCoreThirty + aiWritePage never set it), so the AI's **HTML** is run through `renderMarkdownLite`, which **escapes `<`/`>`** → the `<h2>`s become `&lt;h2&gt;` text → `splitBodySections` finds **0 `<h2>`** → `sections=[]` → **no inline images placed** (the hero renders because it's sourced from `page.images` separately, not from `bodyHtml`). This breaks the whole body render on ALL live pages, not just images.
**The `splitBodySections`/interleave/`inline2At` code is CORRECT** — once `bodyHtml` is real HTML, the irrigation body (5 `<h2>` sections) interleaves fine (inline-1 after §1, inline-2 after §3). No change needed there.
**Fix (two — do both):**
- **Template (immediate):** default null→HTML — `const bodyHtml = page.body_format === "markdown" ? renderMarkdownLite(page.body ?? "") : (page.body ?? "");` (real content is HTML; only the demo fixture is explicitly `markdown`).
- **Backend (correctness):** set `body_format: "html"` on inserts in `seedCoreThirty` (aiWritePage already emits HTML) so rows are self-describing.

## ISSUE 2 — "Continue reading" links not clickable (root cause = key-name mismatch)
**Evidence:** live `internal_links = [{"href":"/services/irrigation-systems","anchor":"Irrigation Systems"}]` — keys `href`/`anchor`. Template `InternalLink` type + render use **`l.url`** (`ContentPageView.tsx:127` `href={l.url}`). `l.url` is **undefined** → `<a>` with no `href` → renders anchor text, **not clickable**. (Demo fixture uses `url`, so demo mode worked; live uses `href`.)
**Fix (template `normalize` in `content-pages.ts`):** map the shape — `internal_links: (row.internal_links ?? []).map((l:any) => ({ url: l.url ?? l.href, anchor: l.anchor, context: l.context }))`. Handles both shapes.

## ISSUE 3 — fabricated business facts (root cause = guard LEAK; NOT stale, NOT fixture) [PRIORITY]
**Body contains:** "family-owned and operated", "licensed", "insured", "same-day", "10-year warranty" (verified in the stored body; `<!-- ai-written -->` marker present).
**Source ruled in/out:**
- **NOT a fixture** — the marker proves AI-written; these phrases are not in `seedCoreThirty`'s templated body.
- **NOT stale** — `updated_at = 2026-07-05T03:12Z`, which **post-dates the anti-hallucination guard** (shipped 2026-07-02/03, Slice 3c-2). The guard was present when this was written.
- ⇒ **The guard is LEAKING.**
**The guard IS present** (`seo.functions.ts:805-811`) and explicitly forbids **"10-year warranty"** (`:808` — the exact leaked phrase!) and **licenses/insurance** (`:809`) — yet they appear. So the model **violates explicit negative constraints** for very-high-frequency local-business boilerplate. AND **"family-owned"** + **"same-day service"** are **not listed** in the guard → uncovered.
**Why:** negative-only prompts ("Do NOT invent X") are weak against strongly-primed boilerplate; and the guard's phrasing ("license *numbers*", "insurance *details*") reads as forbidding SPECIFICS, so the model emits the GENERIC claim ("licensed and insured").
**Fix (strengthen + belt-and-suspenders):**
1. **Broaden the guard** — add the missing high-frequency classes: **ownership** (family-/locally-/veteran-/woman-owned), **service-speed/availability** (same-day, 24/7, emergency, fast/quick response), and **reinforce licensed/insured/bonded as GENERIC claims** (not just numbers/details).
2. **Positive reframe** (strongest lever): "Describe ONLY attributes present in PROVIDED CONTEXT. Do NOT add trust/credibility boilerplate — ownership, licensing, insurance, bonding, warranties, guarantees, speed/availability, awards, experience — unless it appears in PROVIDED CONTEXT. When tempted, describe the service/benefit generically instead."
3. **Post-generation validator (recommended — prompts alone leak):** scan the AI output for a reject-list (`family[- ]owned`, `locally owned`, `licensed`, `insured`, `bonded`, `warrant`, `guarantee`, `same[- ]day`, `24/7`, `emergency`, `award`, `certified`, `years of experience`, `since \d{4}`, …); if a term appears that is NOT in PROVIDED CONTEXT → retry once with a stronger reminder, else strip/flag. Catches leaks the prompt misses.
4. **Then regenerate + verify** the page is clean.

## Answer to "delete all Core-30 + regenerate fresh"
- **Fixes Issues 1 & 2? NO** — those are render bugs (template `body_format` default + `internal_links` mapping) + the backend `body_format` set; regenerating content doesn't touch the template render. Fix the template (+ backend `body_format`) regardless.
- **Fixes Issue 3? NO, not alone** — the content is NOT stale; regenerating with the CURRENT (leaking) guard will **reproduce** the fabrications. **Strengthen the guard (+ validator) FIRST, then regenerate.**
- **Sequence:** (1) strengthen the aiWritePage guard (+ set `body_format='html'` in seed) [backend]; (2) fix the template (`body_format` default + `internal_links` map) [template]; (3) THEN delete + regenerate Core-30 → validate clean pages (real `<h2>` + inline images + clickable links + no fabricated claims).

## Files (when built)
- **Backend `seo.functions.ts`:** strengthen the STRICT ACCURACY block + positive reframe + (recommended) a post-generation reject-list validator in `aiWritePage`; set `body_format:"html"` in `seedCoreThirty` inserts.
- **Template `content-pages.ts`:** `normalize` maps `internal_links` `href`→`url`; **`ContentPageView.tsx`:** `body_format` default null→HTML.
- Frontend-only template changes (no schema); backend prompt/validator changes (no schema).

---
**Root causes: (1) null `body_format` → HTML mangled by markdown-lite → no `<h2>` → no inline images (interleave code is fine); (2) `internal_links` key mismatch `href` vs `url`; (3) anti-hallucination guard present but LEAKING (post-dates content) + missing ownership/speed classes. Delete+regenerate alone fixes none — strengthen guard + fix template first, then regenerate. No build; commits held.**
