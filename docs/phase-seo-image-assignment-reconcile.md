# SEO Images — assignment-model reconcile (photo-board vs onboarding-per-service) — SCOPE [HELD]

> Scope + reconcile only, **no build.** Rethinks the image ASSIGNMENT experience on top of the shipped Slice 2 storage. Grounded on `cloud-spark-setup` `origin/main` @ `ad33789`. Roadmap: `docs/seo-completion-roadmap.md`. Commits held.

## What Slice 2 Part A actually shipped (read-only-verify @ ad33789)
The **storage foundation is done and stays** — no redo:
- Migration `20260704235805`: `alter table content_pages add column if not exists images jsonb;` (additive; `audit_tenant_rls()` unaffected — no policy change).
- `updatePage` `.strict()` patch gained `images` (`seo.functions.ts:571-579`); `og_image` derived from the hero.
- `deleteAllClientPages(clientId)` (`:667`) — Reset Core-30 (admin-gated, statusCode, client-scoped).
- `admin.seo.tsx`: `PageImage` shape `{url,alt,position:hero|inline-1|inline-2,width,height}`, `SLOT_ORDER`, **per-page `ImagesManager`** (3-slot picker) with **auto-suggest**, client-side natural-dims via `new Image()` (`:513-515`), hero→`og_image`, Reset Core-30 button.
- **What's NOT there:** a cross-page photo *pool*, drag-and-drop, or any AI image-fill. Assignment today = per-page dropdown/slot picker.

## The reframe — the two ideas are DIFFERENT LAYERS, not competitors
1. **Onboarding per-service capture** (Mikey's 2nd idea) = the **DATA layer** — how photos arrive + get pre-tagged to services at intake.
2. **Operator photo-board** (Mikey's 1st idea) = the **ASSIGNMENT layer** — how photos land in the 3 slots per page.
3. **AI-fill** = the **GAP layer** — fill slots no real photo covers.
They compose. The decisive facts: the **board is needed regardless** (existing clients already dumped photos; even perfectly-tagged photos still need hero/best-of curation + 2-3/page), while **onboarding-capture only helps FUTURE clients** and adds intake friction + a name-matching problem. So capture-time tagging is a **multiplier on the board**, not a replacement for it.

## Recommendation — layer all three; don't choose (sequence below)
- **The board is the keystone** — universal, immediate, works for every client today including dumped-photo ones.
- **Onboarding per-service capture** is a strong **data-quality enhancement** that makes the board near-automatic for future clients (photos pre-placed) AND surfaces AI-gen needs at intake — but it's forward-only and still relies on the board for curation. Do it, as its own onboarding slice, after/parallel to the board.
- **AI-fill** closes the tail, after an image-gen spike.

---

## a) Feasible on the shipped foundation? YES — UI layered on the same storage, no rework
- **Unchanged/reused:** `images jsonb`, `updatePage({patch:{images, og_image}})`, the `PageImage` shape, the natural-dims + deterministic-alt helpers, `deleteAllClientPages`. **No schema, no write-path change.**
- **What changes vs shipped:** add a **Photo Board** view; the per-page `ImagesManager` (edit-dialog dropdown) is **augmented** (kept as the single-page detail editor), the board becomes the primary *bulk visual* assignment. The board writes the **same** `images` jsonb via the **same** `updatePage`. Auto-suggest (already built) becomes the board's first pass.
- Net: **additive UI**, not a redo.

## b) Pool → drag-and-drop → 3-slots UX (augments, doesn't replace)
- **Photo Board** view in the SEO panel (active client):
  - **POOL:** merge `template_vars.site_assets` across ALL categories (work + gallery + services + about + staff) into one **dedup'd-by-url** thumbnail grid; each thumb shows its category as a chip; filter by category / search.
  - **PAGES:** the client's pages as rows, each with 3 **drop-zone slots** (hero / inline-1 / inline-2) showing current thumbnails.
  - **Interactions:** drag a pool thumb onto a slot → assign (compute alt + natural dims via the existing helper → `updatePage`); drag between slots to move; click-to-clear; **"Auto-suggest all"** (existing) = first pass, then drag to override/fill; per-row "empty slots: N" indicator.
  - **Impl note:** HTML5 DnD or `dnd-kit` (a real UI build; **zero backend change**). Keep the edit-dialog `ImagesManager` as the per-page fallback/detail editor.

## c) AI-fill (Option B) — real requirements; SEPARATE slice (needs a spike)
- **Model/endpoint [GATING UNKNOWN]:** the Lovable gateway is **text-only** today (`createLovableAiGatewayProvider` → OpenAI-compatible **text**, `gemini-3-flash-preview`). Image-gen needs EITHER (i) a **Lovable-gateway image model** IF it exposes one (e.g. a Gemini image / Imagen route via the same gateway — **must confirm with Lovable**), OR (ii) a **separate provider** (OpenAI `gpt-image-1`, Google Imagen/Vertex, Replicate/Flux) = a **new runtime secret** (`scratch-foundation` §10) + a `fetch` integration (Workers = fetch, no native SDK). **This is the spike.**
- **Cost:** ~$0.01–0.08+/image (model-dependent). Slot-scoped + agency-triggered bounds it; a confirm dialog with the count (“Generate N images?”).
- **Storage [LOCKED]:** generate → fetch bytes → `supabaseAdmin.storage.from('public-assets').upload('{client_id}/ai/{page-slug}-{position}-{uuid}.png')` → `getPublicUrl` → write into `images` jsonb (same shape; optionally `source:'ai'`). **Never hotlink the ephemeral gen url.**
- **Prompt/guard:** "generic, tasteful, photorealistic image of {service} (or its result) in a {city}-appropriate setting; **NO text, NO logos, NO signage, NO identifiable faces, NO storefronts implying a specific business, NO awards/badges.**" Extends the anti-hallucination discipline to imagery. Alt stays deterministic.
- **Trigger + slot-scope:** a **"Fill empty slots with AI"** button (per-page and/or global "fill all remaining empty") that touches **ONLY slots still empty after human placement**; **one gen call per empty slot**, sequential batch (Worker-safe, per-image error collection, like AI-write-all).
- **Verdict:** **separate slice** (new infra + a model/cost spike). Do a **small spike first** (confirm gateway image support vs pick a provider; get one image end-to-end into `public-assets`), then build.

## d) Recommended build plan
- **KEEP** the shipped `images jsonb` + `updatePage` + `deleteAllClientPages` (storage foundation; `audit_tenant_rls()=0`). **No schema redo.**
- **Slice 2 (storage + per-page manager) = effectively DONE** — validate + close it (build-log + roadmap); the per-page `ImagesManager` is a usable v1 while the board is built.
- **Slice 2.5 — Operator Photo-Board** (UI/UX on the existing storage): pool + drag-drop + reuse auto-suggest as first pass + per-slot clear. **No schema; reuses `updatePage`.** The assignment-experience upgrade.
- **Slice 2.6 — AI-fill** (separate; after the image-gen spike): model/secret/storage/guard + slot-scoped agency-triggered batch.
- **Independent — Onboarding per-service photo capture** (the 2nd idea): a forward-looking onboarding slice — after the client lists services, render **per-service upload categories** (from their listed services) + an **"I don't have photos of this service"** option → store as `template_vars.site_assets.by_service[serviceName] = [{url,path}]` (additive to the jsonb, **no DB schema change**). At seed/board time, **pre-place** those into the matching service pages' slots + flag services with no photo as **AI-gen candidates**. **Caveats:** future clients only; friction if the service list is long (mitigated by "I don't have this" + keeping to their listed ~5-15 services); the onboarding free-text services vs the AI-derived Core-30 map services need a **name→slug match** at seed (operator reconciles mismatches in the board). Its own slice (touches `OnboardWizard` + submit + `site_assets` shape + a seed-time match step). **Benefits most once the board exists** (the tags have somewhere to land).

## Sequence (recommended)
Close Slice 2 storage → **Slice 2.5 board** (universal, immediate) → **onboarding per-service capture** (data multiplier for future clients; can run parallel) → **Slice 2.6 AI-fill** (after the image-gen spike). The board first because it's the one piece every client needs regardless of how photos were captured.

---
**Reconcile: the two ideas are complementary layers (data / assignment / gap), not either-or. Keep the shipped `images jsonb` storage. Build the operator board (2.5, no schema) as the keystone; add onboarding per-service capture as a forward-looking data multiplier; add AI-fill (2.6) after an image-gen model/cost/storage spike. No build yet.**
