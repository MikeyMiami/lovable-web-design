# Stage — Template real-client rendering + photo dedup (closes the LIVE BUG, render side) — validation

> Point-in-time validation record, 2026-07-05. **Template-only (`professional-landscpaing-template`); ZERO schema/backend.** Consolidates the validated template fixes that make real-client sites actually render as the real client + never repeat a photo per page. Ties to the live-bug flag in `docs/seo-completion-roadmap.md` + the diagnosis in `docs/phase-svc-2b-photos-rework-scope.md`.

## 1. Real-client wiring [architectural — the biggest fix]
**Bug:** `getInitialClient()` returned `demoClient` **unconditionally** and the root had **no loader** — so for EVERY real client the template rendered demo chrome (name/logo/brand/photos/services); only SEO page content was live. `fetchClient()` also queried the `clients` table directly (RLS-blocked for anon).
**Fix (validated):** `fetchClient()` now calls the **`get_client_public` RPC** + a `mapPublicRowToClient()` mapper (derives `phone_e164` from `phone_display`, `services: Service[]` from `template_vars.services_structured`, defaults the fields the public projection omits), a **root loader** feeds `ClientProvider` (SSR — real data at first paint, no demo flash), with `demoClient` fallback on empty/error. Validated: **x3-landscaping renders its real name/logo/brand/photos/services end-to-end.**
- Debugging note: real client photos initially didn't render because **x3 was `status='pending'`** → the anon RPCs gate on `active` → RPC returned nothing → demo fallback. **Root cause = client lifecycle, not code.** Activating the client resolved it.

## 2. Render-key fix — the work/work_examples + services-shape LIVE BUG (render side)
**Bug:** wizard wrote `site_assets.work` (`{url,path}[]`) + a broad `services` array, but the template read `site_assets.work_examples` (`string[]`) and expected a slug-keyed `services` map → **real clients' photos never reached the template.** (Capture side fixed in SVC-2b-rev → `by_service[slug]`.)
**Fix (validated):** `galleryUrls()` + hero/About/Gallery now read the **real keys** (`by_service` + `gallery`, extracting `.url`), with `work`/broad-`services` legacy reads for pre-rework clients and `work_examples` kept only as the demo fallback. Real clients' photos now render.

## 3. Per-page photo dedup (photo once per page; cross-page reuse preserved)
`galleryUrls` (aggregate) + `ContentPageView` hero/inline dedup so a photo appears at most once per page; a deduped slot renders nothing (graceful). Validated.

## 4. Filename-identity dedup [root-cause fix]
**Bug:** URL-dedup missed visual duplicates because the **same file uploaded to multiple services** gets distinct `{uuid}-{name}` URLs. Deployed `/gallery` proved it: 4 `<img>` = **2 real photos** each under 2 URLs.
**Fix (validated):** `fileKey(url)` strips the UUID prefix → dedup by original filename in `galleryUrls` + `ContentPageView`. x3 `/gallery` now shows **2 distinct photos**, not 4; no false dedup on genuinely-different files.

## Drift / scope
All template-side (`client-data.tsx`, `__root.tsx`, `site-assets.ts`, `content-pages.ts`, `gallery.tsx`, `index.tsx`, `about.tsx`, `ContentPageView.tsx`). **ZERO DB schema/backend.** Uses the existing `get_client_public` RPC. Real-client sites now render correctly + photos dedup per page.

## Backlog logged
Robust **upload-side asset identity** (content-hash or shared-asset-id at upload) to dedup at storage + avoid same-file-multiple-URL copies — future backend enhancement (see roadmap backlog note). Filename-dedup is the render-side interim.

## Roadmap
Live-bug render side **CLOSED**; real-client wiring DONE; SVC-2b-template DONE. Next: **SVC-2b-board** (Photo-Board reads `by_service` to pre-fill service-page slots).
