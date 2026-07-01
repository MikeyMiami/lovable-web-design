# SEO — operator's guide (what it means for YOU)

> Plain-English companion to `seo-build` + `seo-content` + `docs/seo-system-analysis-and-skill-plan.md`. The four things you actually need to understand: **(1) what to COLLECT, (2) what shows up in ADMIN/ONBOARDING, (3) what the skills CREATE, (4) how to TEST it's working.** Living doc — firmed up as we build each piece.

## 1. What you'll need to COLLECT (spoiler: almost nothing new)
**Already captured today (no new client questions):** business name, address, hours, services, service areas, niche, differentiators/about, **GBP link**, socials (IG/FB/LinkedIn), photos, logo, domain. All of it feeds SEO.

**New inputs — but AGENCY-set, not asked of the client** (AI drafts them; you confirm — this is the future **admin "SEO panel"**):
- **GBP categories** — primary + 2–4 secondary. These decide how many pages the site gets. *(AI suggests from the niche + GBP; you approve.)*
- **Services-by-category** — the ~20–30 services grouped under those categories = the **"Core 30" page map**. *(AI derives from your services + niche + GBP; you refine.)*
- **Geo coordinates** — auto-geocoded from the address; you rarely touch.
- **Public phone** — this is the provisioned messaging number (comes at A2P/Phase D), not a separate thing to collect.
- *(Later, tool-driven:)* target neighborhoods — chosen from rank-map data after launch, not asked upfront.

**Bottom line:** the CLIENT provides nothing extra for SEO. The only new inputs are agency-set categories/services, and AI writes the first draft.

## 2. What shows up in ADMIN / ONBOARDING (the actionables)
- **Onboarding (client-facing): no new SEO fields.** We already collect the GBP link, services, areas, socials, etc. Onboarding stays as-is.
- **Admin — a new "SEO / Core-30" panel** (per-client, in Settings or the Review & Finalize console). You'll:
  - Review/confirm the AI-suggested **GBP categories**.
  - Review/edit the **services-by-category** — literally the list of pages the site will build.
  - Confirm the **geo coordinates**.
  - *(With the content tool, later:)* a **"Build Core 30 / generate content"** action, a **content queue** (pages drafted/published), and a **rank-map upload** (drop in a Lead Snap CSV → it tells you whether to build topical or geographic pages next).
- **Launch-check:** the finalize step gets an **SEO gate** (won't green-light go-live until titles/schema/NAP/sitemap/Core-30 are correct).

## 3. What the skills CREATE (outputs)
**From the site build (Lovable, via `seo-build`) — every client site:**
- The **Core 30 pages**: a homepage that mirrors the GBP (the 8 consistency signals), **category pages**, and **service pages** — one per GBP category/service. *(Not just home + a services list.)*
- **Genuinely-local neighborhood pages** (structure now; the local copy comes from the content side).
- On **every** page: correct **title + meta description**, **one H1**, **schema markup** (LocalBusiness, Service, etc.), clean semantic HTML, **image alt text**, canonical, social-share (OG) tags.
- **sitemap.xml + robots.txt**, and **fast, mobile-first pages** with no layout jump.
- **First-pass local content** per page from your client data.

**From the content side (`seo-content` + the future tool) — ongoing:**
- Monthly **supporting/FAQ pages** and **neighborhood pages**, written to the expert quality bar, **published into the site automatically** (they become rows the site renders — no rebuilding the site per article).
- Optional **GBP assets** you can paste into Google: category recommendations, a full services list, the 750-char description, **52 weekly GBP posts**, and a **local-link-opportunity list** (chambers/sponsorships).

## 4. How to TEST it's working (two layers)
**Layer A — I verify the code against the skill** (same drift-check workflow we've used all along): after Lovable builds a template or a client site, I read the built code and confirm it has the schema components, the render routes, the meta/title logic, the Core-30 structure, etc. — and flag anything missing. You get a pass/fail per build.

**Layer B — you verify the live/preview site** (no dev skills needed):
1. **Structure** — does the site have category pages + service pages mirroring the GBP (≈30), not just home + a services list?
2. **Homepage 8 signals** — browser-tab title = "Category City Brand"? Big heading (H1) = category + city? A Google Map embed? A Google-reviews widget? **Address + phone identical to the GBP, character-for-character?**
3. **Schema** — paste a page URL into **Google's Rich Results Test** (search.google.com/test/rich-results) → it should detect **LocalBusiness** (home/contact) and **Service** (service pages) with no errors.
4. **Titles/meta** — install the free **"Detailed SEO Extension"** (Chrome) → click through a few pages → each has a **unique** title + meta description following the formula.
5. **Internal links** — are there links **inside the page text** (not just the menu) from the homepage → category pages → service pages?
6. **Sitemap/robots** — visit `yoursite.com/sitemap.xml` and `/robots.txt` → both load; sitemap lists the pages.
7. **Speed/mobile** — run a page through **PageSpeed Insights** (pagespeed.web.dev, mobile) → good scores, no big layout shift (CLS), mobile-friendly.
8. **Local-ness** — a service/area page actually mentions **local specifics** (neighborhoods, local conditions), not generic filler.
9. *(Optional, deep)* run the site through **Screaming Frog** (free up to 500 URLs) for a full crawl audit of titles/H1s/schema/broken links.
10. *(Content store, later)* add a test content row in admin → the new page appears on the site automatically (proves the CMS-backed pipeline works).

**How you'll know Lovable is "using the skill":** if Layer A passes (I confirm the built template matches `seo-build`) and Layer B checks pass on the live site (schema detected, 8 signals present, Core-30 structure, sitemap, fast) — it's using it. If a build misses something, my drift check catches it and we re-prompt Lovable, exactly like the onboarding arc.

---
*I hold the full SEO mental model (from the 5 expert transcripts). You hold this operator view. As we build `seo-build` → `seo-content` → the content store → the tool, each section above gets concrete + testable, and I'll validate every build against the skills before it's called done.*
