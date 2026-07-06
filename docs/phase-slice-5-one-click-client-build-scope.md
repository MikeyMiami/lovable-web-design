# SLICE 5 — One-click client build (automation of the proven order-of-operations) — HELD SPEC

> **DO NOT BUILD YET.** Faithful capture of the operator's "one-button automation" vision, for a future slice. Build AFTER: (a) the 8-pass **scope-drift hardening** (`docs/` Part-1 analysis), and (b) **S4-D5** (deep-write UI) land. These flows ORCHESTRATE already-proven, already-built steps (research, deep-write/`content_jobs` runner, image auto-suggest, S4-C supporting, publish) — the automation is a **queue/orchestration layer**, NOT new writing logic.

## The vision (operator's words, preserved)
Instead of clicking every button one-by-one for every page — now that we have a **finite, proven order of operations** and proven per-page buttons (research → deep-write → images → publish) — collapse it into **THREE one-click flows** that mirror the expert's build sequence, with **human intervention ONLY at the gates that genuinely need it** (photo placement, inbound links).

## FLOW 1 — "Build All Core Pages" (first-time full build, one button)
- Takes the business's already-captured info (services + service areas that match their GMB/GBP, business identity, differentiators, etc.) and automatically applies the full order-of-operations to create **EVERY page needed for the client at their subscription tier**.
- Builds the **Foundation + Core-30 in hierarchy**: home (H1 = primary category + city) → category pages → service pages, all anchored to the **primary city**.
- For each page, automatically: **RESEARCH** (competitor + OSM-verified landmarks) → **8-pass DEEP WRITE** → **auto-assign images** from whatever photos are available for that page/service.
- Runs as a **QUEUE** — page by page, back-to-back, each built with the proven full order-of-operations, all via AI, **resumably** (reuse the `content_jobs` runner pattern; this is a batch of deep-write jobs).
- **HUMAN-INTERVENTION GATE** — after the queue builds all pages, take the operator to the **PHOTO section** to configure which photos go on each page (the existing photo-drag UI). It should:
  - ask if the operator wants to **AUTO-SUGGEST photo placement** (the existing auto-suggest-by-service capability), and
  - ask whether to **AI-GENERATE images** for empty photo spots, or use **ONLY provided images with NO AI images**.
- Then give the operator the chance to input **INBOUND LINKS** if they have them (the one authority external link per page the expert prescribes).
- Then **FINALIZE + PUBLISH** everything (publish the Core-30 — the topical foundation first, per the expert sequence).
- **Net:** ONE button → all pages build off the business's services/service-areas (matching their GMB) with the full proven pipeline → operator prompted only for the approvals that matter (photo placement per page + inbound links) → publish. No looking over every page or remembering the order.

## FLOW 2 — "Build Geo Pages" (~30 days later, after the rank check, one button)
- After the ~30-day rank check (the **S4-B SEO cadence / SEO-status board**), if the signal says build geo (**at/above threshold**), the operator gets a one-click option to **CREATE GEO PAGES** — for every eligible page, or **SELECT specific ones**.
- Runs the SAME system: research → 8-pass deep-write → images, one by one in the queue (**in waves** per the expert), then publishes properly.

## FLOW 3 — "Build Supporting Pages" (~30 days after geo, or per the signal, one button)
- One-click option to create ALL necessary supporting pages for the necessary geo/core pages — or **choose specific ones**.
- Runs the same: research (for all supporting) → 8-pass deep-write → **auto FAQ+link on the parent** (the existing S4-C mechanism) → publish.

## Framed against the expert sequence (which the tool already matches)
1. Foundation → Core-30 (home → category → service, primary-city-anchored) → publish  **[= FLOW 1]**
2. Wait ~30 days → rank check (rank map → top-3% vs competitor threshold — the S4-B cadence board)
3. Per signal: below → supporting · at/above → geo (waves) · dominating → maintain  **[FLOW 2 = geo, FLOW 3 = supporting]**

## Key design notes (for the future build)
- **Orchestration only:** these flows sequence already-built, already-proven steps. The **deep-write scope-hardening (Part 1) MUST be DONE FIRST** so batch-building many pages produces reliably-scoped content — do NOT automate a drift problem across 30 pages.
- **Tier-gated:** builds pages appropriate to the client's subscription tier (reuse `entitlements.ts`).
- **Reuse the `content_jobs` durable/resumable runner** for the queue (a batch of deep-write jobs, resumable, progress display).
- **Human gates are explicit checkpoints:** (1) photo placement per page (+ auto-suggest option + AI-generate-vs-provided-only choice), (2) inbound-links input. Everything else automatic.
- **Depends on:** the scope-hardening (Part 1) + **S4-D5** (deep-write UI) landing first. This is essentially **Slice 5**.

## Open questions to flag at build time (do NOT resolve now)
- How the queue surfaces **per-page progress + failures** (a page fails mid-batch → skip/retry/pause?).
- Whether **photo config** happens per-page inline or as **one batched photo-review step** at the end.
- How **"matches their GMB"** is sourced — operator **confirms** the service/area list before the queue runs, vs. pulled straight from existing client data (`services_structured` + `service_area`/`seo.locations`).
- **AI-image generation** capability — does it exist yet / is it a dependency (the Slice 2.6 image-gen spike was deferred; this flow's "AI-generate images" option depends on it).

---
**Status: HELD SPEC — not built.** Faithful source for a future "Slice 5 — one-click client build." Build sequence: finish the deep-writer scope-hardening + S4-D5 first, then orchestrate these three flows over the proven per-page steps.
