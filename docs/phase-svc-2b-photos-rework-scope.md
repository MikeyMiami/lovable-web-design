# SVC-2b REWORK — onboarding per-service photos in the Photos section (+ remove "work", relabel gallery) — SCOPE

> Scope + ripple analysis only, **no build.** Reworks the SVC-2b model: per-service photos captured in the PHOTOS step (auto-pulling the service list), remove the "Previous Work" category, relabel Gallery. Grounded on `cloud-spark-setup` @ `ad3e82a` + template `professional-landscpaing-template` @ `015690e`+. **Amends SVC-2b (not yet built).** Commits held.

## ⚠️ Two pre-existing latent bugs this ripple surfaced (must handle)
1. **`site_assets.work` (wizard) ≠ `site_assets.work_examples` (template).** The **wizard writes `site_assets.work`** (`Asset[]` = `{url,path}`, `OnboardWizard.tsx:309`); the **template reads `site_assets.work_examples`** (`string[]`) everywhere — hero (`index.tsx:50`), gallery (`gallery.tsx:19-21`), about (`about.tsx:23`), og_image fallbacks (`content-pages.ts:139/161/183/206`), types (`client-types.ts:47`). **These keys never connected** — real clients' "work" photos have NEVER reached the template (only the demo fixture uses `work_examples`). So the template's work fallbacks silently fall to `NICHE_DEFAULTS` for every real client today.
2. **`site_assets.services` shape mismatch.** The template expects a **slug-keyed map** — `t.site_assets?.services?.[s.slug]?.[0]` (`content-pages.ts:183`, service-page og_image fallback) — but the **wizard writes `services` as a flat `Asset[]`**. So per-service og_image never resolved either. **The new `by_service[slug]` model MATCHES the template's keyed expectation** — the fix is to point the template at `by_service`.

## Full consumer map of the affected keys
| Key | Where | Reads/Writes |
|---|---|---|
| `site_assets.work` (`Asset[]`) | **Wizard** `OnboardWizard.tsx` | `PhotoCat` type (`:79`), `PHOTO_CATS` "Previous work" (`:1234`), submit build (`:306-309`), `ReviewSummary.tsx:162/241` |
| `site_assets.work` | **Photo-Board** `admin.seo.tsx` | `SiteAssets` type (`:481`), `HERO_SOURCES`=["gallery,work,services"] (`:484`), `INLINE_SOURCES`=["work,services,gallery"] (`:485`), `allAssetsFlat` cats (`:503,:1494`) → the pool + auto-suggest |
| `site_assets.work_examples` (`string[]`) | **Template** | `client-types.ts:47`, `content-pages.ts:139/161/183/206`, `about.tsx:23`, `gallery.tsx:19-21`, `index.tsx:50`, `demo-client.ts:140` |
| `site_assets.services` (broad `Asset[]`) | Wizard (`:300` submit), Photo-Board (sources/pool), template (`content-pages.ts:183` — expects keyed map) |
| `site_assets.gallery`, `.about`, `.staff` | Wizard, Photo-Board, template (`about.tsx` staff, `gallery.tsx`) — **unaffected** |

## Reworked photos-section design
The onboarding **Photos step** categories become:
- **Services (per-service)** — auto-pull the client's `servicesRows` (from the earlier services step); render **one upload row per service** (name + its own upload button) + an **"I don't have photos of this service"** per service. Photos → `site_assets.by_service[slugify(name)]`. **Replaces** the old single broad "Services" dropzone AND absorbs "work" (per-service photos ARE the work photos).
- **Gallery / More Photos** — the catch-all for anything not service-specific. **Key unchanged (`site_assets.gallery`); only the display label changes** ("Gallery" → "Gallery/More Photos"). Confirmed: label-only, no storage-key change.
- **About** — unchanged (`site_assets.about`).
- **Staff** — unchanged.
- **REMOVED: "Previous Work"** (`site_assets.work`) — the whole category + its submit write.
- **Remove** the per-service dropzones SVC-2b added to the service NAME+PRICE rows.

## Services ↔ Photos cross-step wiring
- **Keep the per-service photo DATA on the service rows** (`servicesRows[i].photos: Asset[]` + `.noPhotos: boolean`, from SVC-2b) — but **move the upload UI to the Photos step**, which reads the live `s.servicesRows` and renders a per-service uploader writing back to each row's `photos`. Data lives with the row; UI lives in the photos step (decoupled).
- **Add/remove/rename handled gracefully** because photos travel WITH the row: a service renamed → its photos stay on the row (slug re-derived at submit); a service removed → its row (and photos) gone; a service added after visiting Photos → appears (live read of `servicesRows`). **Submit builds `by_service` only for current rows** (name + photos + !noPhotos) → orphaned photos of removed/renamed-away services are naturally dropped. Upload path per service = `uploadImage("site/services/" + slugify(row.name), file)`.

## Removal / migration plan for `work` (no data migration needed)
- **New clients:** no `site_assets.work` (category removed); they get `by_service` + `gallery` + `about` + `staff`.
- **Existing clients** (have `site_assets.work` + broad `services`): **keep the CONSUMERS reading those keys for back-compat** — the **Photo-Board pool + auto-suggest keep `work`/`services` in their source lists AND add `by_service`** (union), so old photos still pool and new photos work. **No data migration** (don't rewrite existing `template_vars`). *(Optional later cleanup: map old `work` → `gallery`; not required.)*
- **Template fix (fixes bug #1 + #2):** point the template at the REAL keys — hero/gallery/about read **`gallery`** (+ per-service pages read **`by_service[slug]`**) instead of the dead `work_examples`; the service-page og_image fallback reads **`by_service?.[slug]`** not `services?.[slug]`. Keep `work_examples` as an additional fallback for the demo. **Do not remove template `work_examples` reads without adding the real-key reads** (else real clients lose their gallery/hero images — though today they already fall to defaults, so this is a net improvement).

## Slice plan (amends SVC-2b)
- **SVC-2b-rev (onboarding, backend):** Photos-step per-service uploaders (auto-pull `servicesRows` → `by_service`), remove "Previous Work" + its submit write, convert broad "Services" → per-service, relabel Gallery (label only), remove the row-level dropzones, keep the upload-route `site/services/<slug>` relax (`upload.ts`), submit builds `site_assets.by_service`. Update `ReviewSummary`.
- **SVC-2b-board (Photo-Board):** add `by_service` to `allAssetsFlat` + `HERO_SOURCES`/`INLINE_SOURCES` (keep `work`/`services` for back-compat). *(Overlaps SVC-4 pre-fill — can merge.)*
- **SVC-2b-template (template fix — its own repo):** point hero/gallery/about at `gallery` + service-page images at `by_service[slug]` (fix bugs #1/#2); keep `work_examples` as demo fallback. Frontend-only, no schema.
- **Sequence:** onboarding rework → Photo-Board update → template fix. All additive JSON; upload-route relax is the only route change; **ZERO DB schema** across all three.

## Confirmations (as asked)
- **`work` consumers before removal:** wizard (capture) + Photo-Board (pool/auto-suggest) read `work`; template reads `work_examples` (a DIFFERENT, effectively-dead key). Nothing breaks on removal IF the Photo-Board keeps reading `work` for existing clients (back-compat) — which the plan does. No data migration.
- **Cross-step wiring:** Photos step reads live `s.servicesRows`; photos stored on the rows; submit maps to `by_service[slugify(name)]`; add/remove/rename safe.
- **Gallery rename:** **display label only** — `site_assets.gallery` key unchanged. Confirmed.

---
**Scope + ripple. Two pre-existing bugs surfaced (`work`≠`work_examples`; `services` array vs keyed map) — this rework fixes them by pointing the template at real keys. Remove `work` capture (keep consumers reading it for back-compat, no migration); per-service photos → `by_service[slug]` captured in the Photos step (auto-pulled from servicesRows, data on the rows); relabel Gallery (label only). Slices: onboarding rework → Photo-Board → template fix. No build; commits held.**
