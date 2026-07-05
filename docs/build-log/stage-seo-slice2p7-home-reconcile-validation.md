# Stage SEO Slice 2.7 — home CMS reconcile + home-intro strengthenings — validation

> Point-in-time validation record, 2026-07-05. Two repos, both app-layer, **ZERO schema**: template `professional-landscpaing-template` @ `015690e` (2.7 home render) + backend `cloud-spark-setup` @ `4e644e0` (home-case brief). Specs: `docs/phase-seo-slice2p7-home-cms-reconcile-build-spec.md` + the home-intro brief edits. Roadmap: Slice 2.7.

## What shipped
1. **Slice 2.7 — home CMS reconcile (template `index.tsx`).** The bespoke home now renders the CMS `home` row's SEO content inside the designed layout, replacing the wrong-tier `t.services` grid.
2. **Home-intro strengthenings (backend `aiWritePage` `case "home"`).** Two passes: (a) intro → direct customer-facing why-choose-us pitch grounded in `differentiators`; (b) reframed to **capability/outcomes** ("can THIS business do what I need?") — breadth + ability/speed + differentiators-as-proof, no invented tenure.

## Validation (PASS — real code + live)
- **Template 2.7 (`index.tsx` @ 015690e):** imports `splitBodySections` (`:6`); computes `{intro, sections}` + `heroImg` from `page.images` (`:45-46`); hero `src`/`alt`/`width`/`height` from the CMS hero image with fallback chain (`:48/53/81-82`); CMS **intro** rendered `prose-ish` (`:100`); **category cards** = `sections.map` → `<article class="prose-ish border border-border bg-card p-8">` via `dangerouslySetInnerHTML` (`:138/141`) preserving the inline editorial `<a href="/services/{category}">` (home→**category**, not home→service); **A-fallback** styled prose block (`:148`); **bespoke fallback** `t.services` grid (`:153`). ✅
- **Live home confirmed:** CMS hero + CMS H1 + CMS intro + category cards with home→category editorial links; still the designed layout (cards, not a text wall); one `<h1>`; schema/meta intact. ✅
- **Backend home-case brief (@ 4e644e0):** the `case "home"` return leads with capability/outcomes ("can THIS business do what I need?", BREADTH, ability/speed), uses `differentiators` as reasons-they-can-deliver, **guards tenure** ("do NOT invent tenure/founding year"), bans generic self-description (`:765-769`); category `<h2>`+editorial-link lines unchanged; other type cases + PROVIDED CONTEXT + STRICT ACCURACY + validator untouched. ✅
- **Live intro confirmed:** reads as a capability/outcomes pitch grounded in the client's differentiators, **no invented tenure/claims** (validator clean). ✅
- **Drift:** template = `index.tsx` only (reuses `splitBodySections`); backend = `case "home":` block only. **No schema/migration** either side. ✅

## Method fidelity
- Home = GBP landing page: title/H1 = **primary category + city** (`40-page:102-108`) — unchanged, method-correct (single-city home H1 anchors to the primary/GBP city; other areas → geo pages, Slice 3). Intro talks directly to the searcher + why-choose-us before routing to categories (`seo-content` §3, updated). Editorial **home→category** in-content links now render (the load-bearing authority fix vs the old nav-card `t.services` grid).

## Context (prerequisite template/backend fixes, validated en route)
This arc rode on recently-validated fixes (their own commits, not separately build-logged): template `body_format` default→HTML + `internal_links` `href→url` map (render/links), the inner-page image interleave (`splitBodySections`, `<section>`-flatten + bare-`<h2>`), the `.prose-ish` article typography, and the backend anti-hallucination guard strengthening + ctx-aware reject-list validator. *(Offer: a consolidated build-log for those if a complete record is wanted.)*

## Skills brought to parity (mirror handed)
- **`seo-content` §3** — homepage intro = capability/outcomes + why-choose-us from `differentiators` (never invented), then route to categories; H1/title = primary category + city (`40-page:102-108`).

## Roadmap
**Slice 2.7 → DONE.** Slice 2 **Part B (inner-page image render) → DONE** (validated). LOC-1 gains the explicit-primary-city note (folded into Slice 3).
