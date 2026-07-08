# FUTURE SLICE — Per-page Backlink Tracker (the expert's REAL "authority links") — HELD SCOPE

> **DO NOT BUILD YET.** Scope-capture only, so the correct authority-link model isn't lost. Grounded in the expert transcripts (cited). Decoupled from the build/publish flows.

## The scope correction (why this doc exists)
The tool had **conflated two different things** under "authority links." Verified against `tactiq-free-transcript-ZKZnDORR0ds.txt`:

- **What the expert MEANS by "authority link per page" = OFF-PAGE INBOUND BACKLINKS** — links *from other websites TO our page*, **acquired externally**:
  - `ZKZnDORR0ds:228` — *"With links, Google sees that **other sites trust your content enough to link to it**."*
  - `:232-233` — *"one per page… 30 core 30 pages, that's 30 external links… **where do you get these links? …reach out to relevant blogs, to websites… services that provide quality links**."*
  - `:239-243` — *"the second type… **local authority links**… **links from** [local orgs]… chamber of commerce… you get a **link from their website back to yours**."*
  - Same prescription repeats: supporting pages `:348-350` ("10 or 20 more external links"), geo pages `:383-384` ("another 10 to 20 external links").
  - Two sub-types: **"not-AI-slop" links** (medium-quality validation backlinks) + **"local authority" links** (chamber of commerce, local orgs).
- **What the tool's `content_pages.external_link` ACTUALLY is = an on-page OUTBOUND link** (from our page out to an authority source, woven into the body by the deep-writer, `writer.ts:272`). That maps to the expert's *separate, minor* practice (transcript-2 `FifSqbB0:~535` "inserting external links to authority sources") — **NOT** the headline "30 external links / 30 core pages."

**Consequence (handled in the CTA + gate build, 2026-07-07):** the misleading "authority links" gate was removed from the core flow, and the per-page `external_link` field relabeled to "optional outbound reference link." The expert's real authority links need the tracker below.

## What to build (future)
A **per-page backlink tracker** — off-page, non-blocking, decoupled from deep-write/publish:
- Per `content_pages` row, track a list of **acquired inbound backlinks**: `{ source_url, source_domain, type: "not-ai-slop" | "local-authority", status: "planned" | "requested" | "live", acquired_at }`.
- Store additively (e.g. `content_pages.backlinks` jsonb, or `template_vars.seo.backlinks[slug]`) — **zero migration**, mirrors the research-store pattern.
- **UI:** a per-page backlink checklist in the SEO tab — operator records outreach progress (chamber of commerce, blog outreach, link services) and marks each live. A per-page count + a client-level "N/M pages have ≥1 authority backlink" rollup against the expert's "one per page minimum."
- **NOT** woven into page content; **NOT** a build/publish gate. It's an ongoing acquisition workflow the operator runs over weeks (matches the expert's monthly cadence).

## Expert quantities (targets the tracker measures against)
- Core-30: **≥1 backlink per page** → 30 (`:232`). Supporting: **+1 per page** → +10-20 (`:348-350`). Geo: **+1 per page** → +10-20 (`:383-384`).
- Best local-authority backlink = **chamber of commerce** directory listing (`:241-244`).

## Relationship to other work
- Complements [[project_flow1_core_build_complete]] (on-page build) — this is the **off-page** layer the build flows don't touch.
- The on-page optional outbound reference link (`external_link`) remains a minor separate feature; if kept, fix its ordering (capture BEFORE deep-write so it's woven into the body — currently set-after-write = never rendered).

---
**Status: HELD SCOPE — not built.** Captures the corrected authority-link model (off-page backlinks) so it isn't re-conflated with the on-page outbound link.
