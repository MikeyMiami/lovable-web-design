# CONTENT-EDIT-1 — Settings editors for the AI/SEO content fields — build spec [HELD]

> Friendly editors for the `template_vars` fields that feed the SEO/AI writer (`differentiators`, `about_us`, `services`, `segment`) — today JSON-only. Server-side-merge `updateClientContent` fn (saveSeoMap posture, no clobber) + a "Business & SEO Content" section in `admin.settings` + a read-only preview + Edit-in-Settings link in `admin.seo`. Grounded on `cloud-spark-setup` @ `4e644e0`. **ZERO schema.** Scope: `docs/phase-template-vars-editors-scope.md`. Awaiting review.

## Read-only-verify findings
- **Settings pattern** (`admin.settings.tsx`): `<Section title hint saving onSave>` (owns the save button) + `<Field label hint><Input/Textarea/></Field>`; sections build a payload in `onSave` and call a mutation. The discount section (`:490-515`) is the template_vars precedent (client-side read-merge-write via `saveClient`). Client query already loads `template_vars`; `queryClient` (`useQueryClient`) + `toast` + `Textarea` already imported.
- **Server-side-merge precedent:** `saveSeoMap` (`seo.functions.ts`) — `requireSupabaseAuth` + `assertAgencyAdmin` + re-read `template_vars` + overlay + write merged + `propagateError`/`statusCode`. `updateClientContent` mirrors it.
- **`admin.seo.tsx`** already loads `client.template_vars` (`:91`) and can render a read-only preview + a `Link` to `/admin/settings`.
- **Note:** `services` here is the current **flat free-text string** (`template_vars.services`); a later SVC-1 slice will restructure it — this editor edits the flat string for now (coexists).

---

# PROMPT CONTENT-EDIT-1 — paste into Lovable (cloud-spark-setup)

> **App-layer on `golden-master-v1.7`. ZERO schema change.** Add friendly editors for the AI/SEO content `template_vars` fields via a **server-side-merge** fn (no clobber), plus a read-only preview in the SEO panel. Report the diff + confirm no migration.

## 1. New server fn `updateClientContent` — `src/lib/seo/seo.functions.ts`
Mirror `saveSeoMap` (server-side merge; `requireSupabaseAuth` + `assertAgencyAdmin`; `propagateError`/`statusCode`):
- Input `{ clientId: uuid, fields: { about_us?: string, differentiators?: string, services?: string, segment?: string } }` (all optional).
- Re-read the client's current `template_vars` server-side → for each **provided** field: `const val = String(v ?? "").trim(); if (val) merged[key] = val; else delete merged[key];` (blank clears the key, like the social editor) → write the full merged `template_vars` back.
- Return `{ ok: true }`. Wrap in the try/catch that rethrows with `statusCode`.
- **Only these 4 keys** are ever touched; all other `template_vars` keys are preserved by the re-read+merge.

## 2. Settings section — `src/routes/_authenticated/admin.settings.tsx`
- Import `updateClientContent` from `@/lib/seo/seo.functions`.
- State from `client.template_vars` (re-seed on active-client change, mirroring the discount `useEffect`): `content = { about_us, differentiators, services, segment }`.
- A `useMutation` `saveContent` → `updateClientContent({ data: { clientId: activeClientId, fields } })`; `onSuccess` → toast + **invalidate the settings query** (re-seeds the fields + the raw `template_vars` JSON textarea — dual-writer guard); `onError` → toast.
- A new **"Business & SEO Content"** `<Section>` (place it near the Template Variables section) with `saving={saveContent.isPending}` and `onSave={() => saveContent.mutate({ about_us: content.about_us, differentiators: content.differentiators, services: content.services, segment: content.segment })}`:
  - **Differentiators** — `<Textarea rows={3}>`; hint: *"Concrete reasons to choose (e.g. Same-day service, licensed & insured, free estimates). The AI page writer may ONLY state claims present here — this governs the allowed claims."*
  - **About us** — `<Textarea rows={4}>`; hint: *"The business description the AI writes from."*
  - **Services (comma-separated)** — `<Textarea rows={3}>`; hint: *"Feeds the SEO map AI-seed. (Structured per-service capture comes later.)"*
  - **Industry segment** — `<Input>`; hint: *"Industry category (e.g. Home services) — feeds the map seed + A2P."*

## 3. SEO-panel preview — `src/routes/_authenticated/admin.seo.tsx`
Near the **Generate Core-30 / AI-write** actions, a compact **read-only** card (reads the already-loaded `client.template_vars`):
- Eyebrow: *"AI writes from this"*.
- **Differentiators (claims the AI may use):** `{tv.differentiators || "— none set —"}`.
- **About:** `{tv.about_us ? tv.about_us.slice(0,160) + "…" : "— none set —"}`.
- An **"Edit in Settings →"** `Link` to `/admin/settings` (import `Link` from `@tanstack/react-router` if not already). Read-only here — single source stays Settings.

## Guardrails
- **ZERO schema/migration.** New server fn (`updateClientContent`) + Settings section + admin.seo read-only preview. No new column/policy.
- **No clobber** — server-side re-read + overlay only the 4 keys; every other `template_vars` key preserved. Admin-gated (`assertAgencyAdmin`), `statusCode`-on-throw.
- The SEO-panel preview is **read-only** (single source = Settings).

## Drift check (report back)
1. Files: `seo.functions.ts` (+`updateClientContent`), `admin.settings.tsx` (+Business & SEO Content section), `admin.seo.tsx` (+read-only preview + link). No migration.
2. `updateClientContent` re-reads `template_vars` server-side and overlays only the 4 keys.
3. Settings save re-seeds the fields + the raw JSON textarea (no clobber).

## VALIDATION
1. Settings → edit `differentiators` / `about_us` / `services` / `segment` → Save → re-read the `clients` row: those 4 `template_vars` keys updated AND `discount__*` / `social_links` / `seo` / `site_assets` / other keys **intact**.
2. Blank a field → Save → that key removed; others unaffected.
3. `admin.seo` shows the read-only **Differentiators** + **About** preview + a working "Edit in Settings" link.
4. Non-admin blocked; `audit_tenant_rls()` unaffected; no migration.

## Status
**HELD — awaiting review.** After this: CONTENT-EDIT-2 (remaining scalar keys + display copy) and the structured-services arc (SVC-1..5) which will restructure `services`.
