# SEO Slice 2.7 — home-CMS reconcile (+ home hero image) — build spec [HELD]

> Option B hybrid: the bespoke home design populated by the CMS `home` row's SEO content — CMS hero image + H1 + searcher intro + category `<h2>` sections rendered as designed cards with their **editorial home→category `<a>` links preserved**, with graceful fallbacks. Owns ALL of `index.tsx` (Part B does not touch it). Drift-checked against the clone `professional-landscpaing-template` @ `f16e186` (`index.tsx` hero `:64-79`, intro `:82-97`, services grid `:99-137`). Frontend-only, no schema. Depends on Part B's `PageImage`/`images` type in `content-pages.ts` — send Part B first. Awaiting review.

---

# PROMPT — SEO Slice 2.7 (home-CMS reconcile) — paste into the TEMPLATE project (`professional-landscpaing-template`)

> **Frontend-only. No backend/schema/RPC change.** Make the bespoke home page (`src/routes/index.tsx`) render the CMS `home` row's SEO substance inside the designed layout: CMS **hero image + H1 + searcher intro**, and **replace the `t.services` card grid with the CMS body's `<h2>`-split category sections rendered as designed cards via `dangerouslySetInnerHTML` so the inline editorial `<a href="/services/{category}">` home→category links are preserved** (the load-bearing SEO fix — today's grid links the wrong tier home→service and passes no editorial authority). Graceful fallbacks throughout. Touch `src/routes/index.tsx` + add a shared splitter to `src/lib/content-pages.ts`. Report files changed + confirm no schema/backend change.

## 1. Shared `splitBodySections` helper — `src/lib/content-pages.ts`
(Reused by Part B's inline interleave — if Part B already added a body-splitter, reuse it instead of duplicating. Also relies on the `PageImage` / `images` type Part B adds to `ContentPage`.)
```ts
// Split rendered body HTML into an intro (before the first <h2>) + one chunk per <h2> section.
export function splitBodySections(html: string): { intro: string; sections: string[] } {
  if (!html) return { intro: "", sections: [] };
  const startsWithH2 = /^\s*<h2/i.test(html);
  const parts = html.split(/(?=<h2)/i);
  const intro = startsWithH2 ? "" : (parts.shift() ?? "");
  return { intro: intro.trim(), sections: parts.filter((s) => s.trim()) };
}
```

## 2. `src/routes/index.tsx` — populate the design from the CMS `home` row
Import `renderMarkdownLite` + `splitBodySections` from `@/lib/content-pages`. In the `Index` component, after `const { page } = Route.useLoaderData();`:
```ts
const bodyHtml = page
  ? (page.body_format === "html" ? (page.body ?? "") : renderMarkdownLite(page.body ?? ""))
  : "";
const { intro, sections } = splitBodySections(bodyHtml);
const heroImg = page?.images?.find((i) => i.position === "hero");
```

- **Hero image (was `featured`/`featuredName`, `:39-40`):** set the hero `<img>` (`:65-71`) `src` = `heroImg?.url ?? page?.og_image ?? t.site_assets?.work_examples?.[0] ?? NICHE_DEFAULTS.hero` and `alt` = `heroImg?.alt ?? featuredName`; add `width`/`height` from `heroImg` when present. Keep the existing hero `<section>` styling, gradient, and the H1 overlay.
- **Hero H1:** unchanged — already `page?.h1 ?? t.hero_headline ?? c.business_name` (`:41`).
- **Intro section (`:82-97`):** if `intro` is non-empty, render it as `<div className="prose-ish" dangerouslySetInnerHTML={{ __html: intro }} />` (optionally keep `t.hero_subhead` as a short eyebrow/tagline above it). If `intro` is empty, fall back to today's `t.hero_subhead ?? c.tagline`.
- **Replace the "Services preview" grid (`:99-137`)** — keep the section wrapper + eyebrow/heading ("What we do" / "Services") + the "View all → `/services`" link, but render the body:
  - **If `page` && `sections.length > 0`:** the same grid classes (`grid gap-6 sm:grid-cols-2 lg:grid-cols-3`), each card a **non-link container** — `<article className="border border-border bg-card p-8 prose-ish" dangerouslySetInnerHTML={{ __html: section }} />` — so each card shows the CMS `<h2>{category}</h2>` + its blurb **with the inline editorial `<a href="/services/{category-slug}">` preserved**. **Do NOT wrap the card in a `<Link>`** — the editorial `<a>` inside the prose is the authority-passing link; a wrapping nav-card link is not.
  - **A-fallback (`page` but no `<h2>`, `sections.length === 0`):** render one styled block — `<section className="prose-ish" dangerouslySetInnerHTML={{ __html: bodyHtml }} />` — inside the designed section wrapper.
  - **Bespoke fallback (no home row `!page`, or empty `bodyHtml`):** render today's existing `t.services` grid (the `<Link>` cards) + `t.hero_subhead` intro, unchanged — a client without a generated home still shows the designed page.
- **Keep unchanged:** the hero `<section>` markup, the service-area section, the CTA, the LocalBusiness schema (`page?.schema_jsonld ?? composed`), and the `head`/`pageHeadMeta(page, "/", …)` — H1/schema/meta are already CMS-driven.

## Guardrails
- **Frontend-only**; reads the existing loader `page` data; **no schema/backend/RPC change**; deterministic (no AI at render).
- **The editorial `<a>` links MUST render inside the cards** (via `dangerouslySetInnerHTML`, not stripped) — this is the load-bearing SEO fix (home→**category** authority).
- Exactly **one `<h1>`** (the hero) preserved; graceful fallbacks (A-fallback for no-`<h2>`, bespoke fallback for no-home-row).
- `index.tsx` is the ONLY file changed here besides the `splitBodySections` helper; Part B owns the inner-page renderer.

## Drift check (report back)
1. Files: `src/routes/index.tsx` + `src/lib/content-pages.ts` (`splitBodySections`, if not already present from Part B). No schema/backend.
2. Home renders the CMS hero image, CMS H1, CMS intro, and CMS category sections as designed cards with inline `<a href="/services/{category}">` (home→**category**, not home→service).
3. Fallbacks present: A-fallback (no `<h2>`) → styled prose block; bespoke fallback (no home row) → today's grid.

## VALIDATION
1. With a published `home` row whose body has category `<h2>` sections + inline editorial links: the home shows the designed layout with **CMS hero image** + **CMS H1** (hero) + **CMS searcher intro** + **each category as a designed card containing its `<h2>` + blurb + a real `<a href="/services/{category}">`** (inspect element — home→**category**, editorial in-content, not a wrapping nav card). LocalBusiness schema + meta intact; exactly one `<h1>`; no CLS regression.
2. Home row with body lacking `<h2>` → styled prose block (A-fallback), links still render.
3. No home row → today's bespoke `t.services` grid unchanged (graceful).
4. No image assigned → hero falls back through `og_image` → `work_examples[0]` → `NICHE_DEFAULTS.hero`.

## Status
**HELD — awaiting review.** Send Part B (inner pages) first (adds the `images` type). Then this owns the full home page. Drift-check the result against the clone.
