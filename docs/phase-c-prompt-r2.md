# Phase C — C-3 Revision R-2 (uploads + site_assets manifest) — Lovable prompts

> R-2 of the revision (`docs/phase-c-c3-revision-pass.md`), option A. **App-layer only — NO schema, NO fn-contract change** (confirmed: `logo_url` already a field; `site_assets` rides open `template_vars`; `photo_request` rides open `submission`). Sub-sliced: **R-2a** = public-assets helper + logo upload; **R-2b** = categorised photos + staff + the `site_assets` manifest. Files: NEW `src/lib/clients/site-image-upload.ts` + `src/routes/_authenticated/onboard.tsx`.

## Confirmations (the things you asked to lock)
- **Bucket/path:** images → **`public-assets`** (public-read so the anon marketing site renders them). Paths: logo → `<draftId>/logo/<uuid>-<file>`; photos → `<draftId>/site/<category>/<uuid>-<file>` (categories: `work`, `gallery`, `about`, `services`, `staff`).
- **Why `draftId`, not `client_id`:** uploads happen DURING capture, before `createClientFull` runs → there is no `client_id` yet. We generate a wizard **draft id** (`crypto.randomUUID()`, stable per session) as the storage namespace. The marketing site reads images by **URL** from the manifest (not by scanning a `client_id` folder), so the namespace is just bookkeeping. *(Alternative if you ever want true `<client_id>/…` paths: add an optional `id` to `createClientFull` and pass the draftId as the client id — a small fn change. Not needed; recommend draftId.)*
- **⚠️ VERIFY before R-2 works:** the **`public-assets` bucket must be set Public** (Storage dashboard → `public-assets` → Public ON). `getPublicUrl` only serves files from a public bucket — and the marketing site needs permanent (non-expiring) URLs, so public is the right setting for these assets. (It's intended public per `scratch-foundation`; just confirm the flag.)
- **fn-contract change: NONE.** `fields.logoUrl` (exists) ← the uploaded logo URL; `templateVars.site_assets` (open) ← the manifest; `submission.photo_request` (open) ← the design-for-me flag.
- **Future client-facing mode (C-3d, NOT now):** `public-assets` is **admin-write**, so a logged-in client (`client_owner`, not admin) cannot upload directly. The token-based public onboarding (C-3d) will need a **server-fn upload proxy** (a `createServerFn` that takes the file bytes, verifies the onboarding token, and uploads via service-role). Note it; don't build.
- **Orphan housekeeping (note):** an abandoned wizard leaves uploaded files under its `draftId` with no client. A periodic GC of unreferenced `public-assets` objects is a future nicety — not R-2.

---

# PROMPT R-2a — paste into Lovable (public-assets helper + logo upload)

> **Build scope: app-layer only. NO migration, NO schema/fn-contract change.** Add one helper file + rework the Branding-step logo field. When done, report files changed + confirm no migration. **Prereq: confirm the `public-assets` bucket is Public in the Storage dashboard.**

## File 1 (NEW): `src/lib/clients/site-image-upload.ts`
Mirrors the ticket-upload UX but writes to **`public-assets`** and returns a **public** URL.
```ts
import { supabase } from "@/integrations/supabase/client";

const MAX = 10 * 1024 * 1024; // 10 MB per image
const isImage = (t: string) => t.startsWith("image/");

/** Upload an image to public-assets and return its permanent public URL + path.
 *  `category` is the sub-path, e.g. "logo" or "site/work". `namespaceId` = the wizard draft id. */
export async function uploadSiteImage(
  namespaceId: string,
  category: string,
  file: File,
): Promise<{ url: string; path: string }> {
  if (!isImage(file.type)) throw new Error("Please upload an image file");
  if (file.size > MAX) throw new Error("Image exceeds 10MB");
  const path = `${namespaceId}/${category}/${crypto.randomUUID()}-${file.name}`;
  const up = await supabase.storage.from("public-assets").upload(path, file, { upsert: false });
  if (up.error) throw up.error;
  const { data } = supabase.storage.from("public-assets").getPublicUrl(path);
  return { url: data.publicUrl, path };
}
```

## File 2: `src/routes/_authenticated/onboard.tsx` — logo upload
- Add a stable draft id at the top of the component: `const [draftId] = useState(() => crypto.randomUUID());`
- **Branding step — replace the logo URL paste input** with an image-upload control (the ticket-style rounded block + upload icon; after upload show the thumbnail). On file select:
  ```tsx
  const { url } = await uploadSiteImage(draftId, "logo", file);
  update("logoUrl", url);        // fields.logoUrl → clients.logo_url
  update("noLogo", false);       // an uploaded logo means they DO have one
  ```
  Show a preview `<img src={s.logoUrl}>` when set, with a "Replace" affordance.
- **Keep the R-1 "I don't have a logo" → "make one for you? Yes/No" toggles** as the alternative path (shown when no logo is uploaded). If a logo is uploaded, `noLogo=false`. They coexist: upload OR request-one.
- Assembly unchanged except `logoUrl` now holds the uploaded public URL (already wired).

**Drift check:** NEW `site-image-upload.ts` + `onboard.tsx` (logo control + draftId); no migration; no schema/fn change; `getPublicUrl` from `public-assets`.

### Validate R-2a (as `itsmikeymiami`)
Upload a logo in Branding → the thumbnail renders; finish + Create (slug `r2-logo-test`). Then:
```sql
select slug, logo_url from public.clients where slug='r2-logo-test';
-- logo_url = https://…/storage/v1/object/public/public-assets/<draftId>/logo/…  — paste it in a browser; it must load.
select name from storage.objects where bucket_id='public-assets' and name like '%/logo/%' order by created_at desc limit 3;
```
Pass = logo file at `<draftId>/logo/…`, `logo_url` is a public URL that loads, thumbnail renders. Cleanup: `delete from public.clients where slug='r2-logo-test';` (+ remove the test object via Storage dashboard).

---

# PROMPT R-2b — paste into Lovable AFTER R-2a (categorised photos + staff + manifest)

> **Build scope: app-layer only. NO migration, NO schema/fn-contract change.** Rework the Photos step (currently a placeholder) into the categorised upload system + assemble `template_vars.site_assets`. Reuses `uploadSiteImage` + `draftId` from R-2a. Report files changed + confirm no migration.

## State (add)
```ts
type Asset = { url: string; path: string };
type StaffAsset = { url: string; path: string; name: string; position: string };
// in State:
siteAssets: { work: Asset[]; gallery: Asset[]; about: Asset[]; services: Asset[]; staff: StaffAsset[] };
designForMe: boolean;   // "design this section for me"
// init: { work:[], gallery:[], about:[], services:[], staff:[] }, designForMe:false
```

## Photos step UI
- **Top option:** *"Don't have photos? That's okay. Select here and we will design this section for you."* → a toggle bound to `designForMe`. (When on, you may visually de-emphasise the category uploaders, but keep them usable.)
- **Four image categories** — `Previous projects/work` (`work`), `Gallery` (`gallery`), `About` (`about`), `Services` (`services`). Each: a row/grid of **rounded square upload blocks** (upload icon) → on file select `const a = await uploadSiteImage(draftId, "site/"+cat, file); update("siteAssets", { ...s.siteAssets, [cat]: [...s.siteAssets[cat], a] });` → render each uploaded image as a **thumbnail** with a remove (×). Allow multiple per category.
- **Staff** — a **repeatable list**; an "Add staff member" button appends a blank entry. Each entry: an image upload block (`uploadSiteImage(draftId, "site/staff", file)` → set that entry's `url`/`path`), a **Name** input, a **Position** input, and a remove (×). Store as `siteAssets.staff: StaffAsset[]`.

## Assembly (extend the existing `templateVars` + `submission`)
```ts
// inside templateVars (only if any images exist):
const sa = s.siteAssets;
const anyAssets = sa.work.length || sa.gallery.length || sa.about.length || sa.services.length || sa.staff.length;
if (anyAssets) {
  templateVars.site_assets = {
    work: sa.work, gallery: sa.gallery, about: sa.about, services: sa.services, staff: sa.staff,
  };
}
// submission:
submission.photo_request = { designForMe: s.designForMe };
```
(No fn change — `templateVars` + `submission` are open records.)

## Review step note
The Review & Create summary (R-3) will preview these thumbnails; in R-2b the existing review step is unchanged (R-3 reworks it).

**Drift check:** `onboard.tsx` changed (Photos step + state + assembly); no migration; no schema/fn change; uses `uploadSiteImage`/`draftId` from R-2a.

### Validate R-2b (as `itsmikeymiami`)
Upload ≥1 image to each of work/gallery/about/services, add one staff member (image + name + position), toggle "design this section for me" on a fresh run to test the flag. Create (slug `r2-photos-test`). Then:
```sql
select template_vars->'site_assets' as site_assets
  from public.clients where slug='r2-photos-test';
-- EXPECT: { "work":[{"url":...,"path":"<draftId>/site/work/..."}], ..., "staff":[{"url":...,"name":"...","position":"..."}] }
select name from storage.objects where bucket_id='public-assets'
  and name like '%/site/%' order by created_at desc limit 10;   -- files under <draftId>/site/<category>/
-- submission JSON → photo_request.designForMe recorded (download to inspect)
```
Pass = each category's images present in `site_assets` with working public URLs (paste one in a browser), staff entries carry name + position, files at `<draftId>/site/<category>/…`, `designForMe` recorded when toggled. Cleanup: `delete from public.clients where slug='r2-photos-test';` (+ Storage-dashboard remove the test objects).

### After R-2 is green
→ **R-3** (Review & Create: readable grouped proofread summary + logo/photo thumbnails — it previews the R-2 uploads).

---
**App-layer only. No schema, no fn-contract change. Verify `public-assets` is Public first. Every R-2 item retained.**
