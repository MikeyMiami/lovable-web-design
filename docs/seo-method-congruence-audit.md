# SEO Method Congruence Audit — 2026-07-04

> Read-only audit: does what we built (map → seed → manage → write → images) match the expert method in the transcripts (`C:\Users\Pierc\Documents\SEO\`, 6 files)? **No build.** Companion to `docs/seo-system-audit-2026-07-03.md` (gap audit) + `docs/seo-completion-roadmap.md`.

## Congruent — structure/linking/schema/GBP-mirror
Matches the "40-page" blueprint (`How to Use Content to Rank… #1 on Google.txt`) almost point-for-point:
- **Homepage = GBP landing page**; title + H1 = **primary category + city**; keyword in the first paragraph; secondary categories as **H2 sections** (`40-page:95-122`). ✅ (our `home` per-type prompt)
- **Dedicated category pages** (category + location) + **individual service pages per GBP service**, **primary → secondary → services** hierarchy with each service page **linked from its category page** (`40-page:124-170`). ✅ (seed + `internal_links`)
- **LocalBusiness schema matching GBP char-for-char** + **Google Maps embed** on the homepage (`40-page:218-225`). ✅ (`seo-build` §1/§3; Maps-embed = a known template 6/8 gap).
- **AI-written**, **well-formatted with images** (client photos best, AI works), callouts/tables/bullets/short paras (`ZKZnDORR0ds:204-209`). ✅ (Slice 1 structure + Slice 2 images — images are method-grounded, not invented).

## Fidelity gaps (honest)
1. **Word counts — LOW vs the method.** Method: **300–400 words per secondary-category section on the homepage** (`40-page:119-120`) + **800–1500 words per service page** (`40-page:156`). Ours: `aiWritePage` ~400–700 total; `seo-content` §3 previously said 50–100 for home sections. **Corrected in `seo-content` §3** — the method targets are documented as the **content-automation tool's** job; the single-pass first draft runs shorter *by design* (avoid slop). Not a defect in what shipped; a boundary that's now honest in the skill.
2. **Pricing ranges — wanted, not captured.** Method wants pricing/ranges on service pages (`40-page:159`). Our anti-hallucination guard correctly forbids inventing them → we omit pricing. **Fix = CAPTURE real ranges** (onboarding / SEO panel) to feed as PROVIDED CONTEXT; guard stays. Noted in `seo-content` §3.
3. **"Areas you serve for this service"** (`40-page:160`) = **multi-location** — already **Slice 3** on the roadmap (correctly deferred).

## The INBOUND external-link requirement — HARD method requirement, OUTSIDE the build [prominent]
The method is emphatic that **every page needs ≥1 inbound backlink pointing to it** — *"not optional… mandatory… Google uses external links as a quality verification signal, especially for AI content"* (`40-page:195-204`); *"other sites trust your content enough to link to it… one per page… 30 external links for the core 30"* (`ZKZnDORR0ds:228-232`). These are **off-site backlinks on OTHER websites** (chamber directories, paid "not-AI-slop" link services ~$25-35/link, sponsorships) — **nothing is stored on our page and the AI writes nothing.** They are a **hard prerequisite for ranking** — per the method, the Core-30 pages **will not rank on structure alone** without them. This lives entirely in **agency ops** (see the roadmap's **Agency Link-Building Tracker**), NOT the page builder. The three link types are separated in `seo-content` §6.
- Distinct from the **outbound** in-content authority link (`W3deWbeigsg:141` / `FifSqbB0:534-535`) — that IS an on-page element (operator-provided URL → `content_pages.external_link` → AI-woven), specced in `docs/phase-seo-outbound-link-build-spec.md`.

## Verdict
- **Structure / linking / schema / GBP-mirror / images: congruent + method-grounded.**
- **Close in the writer/roadmap:** word-count targets (documented; tool hits them) + pricing-range capture.
- **Own it as agency-ops, off-site:** inbound backlink acquisition (mandatory per method, not a page feature).
- Nothing built; skills corrected (`seo-content` §3 + §6); outbound-link + inbound-tracker scoped.
