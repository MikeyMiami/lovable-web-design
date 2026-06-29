# Phase C — C-3d-2: token-gated upload proxy (client-mode uploads to public-assets)

> Second C-3d slice. **App-layer only — NO schema, NO migration, NO fn-contract change, NO new secret.** Held for review. Verified against `cloud-spark-setup` `origin/main` @ `ef5d7b8`.

## Scope
Client-mode (public) wizard uploads currently can't write `public-assets` (write RLS = `is_admin` only). Add a **token-gated service-role upload proxy** (`/api/public/onboarding/upload`): validate the onboarding token → derive its `draft_id` → upload via service-role to `public-assets/<draft_id>/<category>/…` → return the public URL. **Protection:** the single-use token (only a link-holder can call it) + per-token/per-IP **rate-limit** + image **MIME/10MB caps**. (Turnstile is concentrated on the SUBMIT in C-3d-3, where the net-new widget is added once — uploads are already gated by the secret token.) Wire `OnboardWizard` client mode (logo + categorized photos + staff) to the proxy; **agency mode keeps `uploadSiteImage` unchanged**.

## Verified facts
- `uploadSiteImage` (`src/lib/clients/site-image-upload.ts`) uploads **directly** via the authed browser client → fails for non-admins (public-assets write = `is_admin`). Client mode needs the proxy.
- Public-route + service-role + rate-limit pattern: `intake.ts` (`createFileRoute(...).server.handlers.POST`, `supabaseAdmin`, `checkRateLimit`/`clientIp` from `src/lib/security/rate-limit.server`).
- `onboarding_tokens` exists (`token`, `draft_id`, `status`); the proxy reads it via `supabaseAdmin` (service-role-only table).
- `OnboardWizard` upload sites: logo (~659/694), categorized photos sub-component (~1083), staff (~1105); `isAgency = mode==="agency"`; `draftId` prop. The public `/onboard/$token` route already has the token (URL param) — pass it to the wizard.

## Schema / fn flag
**NONE.** No migration, no new table, no fn-contract change, no new secret. New public API route + a client helper + wizard wiring (app-layer).

---

# PROMPT C-3d-2 — paste into Lovable

> **App-layer only. NO migration, NO schema/fn change, NO new secret.** Add a token-gated upload proxy and route client-mode wizard uploads through it. Report files changed + confirm no migration.

## File 1 (NEW): `src/routes/api/public/onboarding/upload.ts` — the proxy
Match the existing public-route handler shape (`intake.ts`). No auth; same-origin (no CORS needed).
```ts
import { createFileRoute } from "@tanstack/react-router";
import { checkRateLimit, clientIp } from "@/lib/security/rate-limit.server";

const MAX = 10 * 1024 * 1024; // 10 MB
const CATEGORIES = new Set(["logo", "site/work", "site/gallery", "site/about", "site/services", "site/staff"]);

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

export const Route = createFileRoute("/api/public/onboarding/upload")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        let form: FormData;
        try { form = await request.formData(); } catch { return json({ error: "invalid_form" }, 400); }

        const token = String(form.get("token") ?? "");
        const category = String(form.get("category") ?? "");
        const file = form.get("file");

        if (!token) return json({ error: "missing_token" }, 400);
        if (!CATEGORIES.has(category)) return json({ error: "invalid_category" }, 400);
        if (!(file instanceof File)) return json({ error: "missing_file" }, 400);
        if (!file.type.startsWith("image/")) return json({ error: "not_an_image" }, 400);
        if (file.size > MAX) return json({ error: "too_large" }, 400);

        // Rate-limit (per-token + per-IP) — reuse the intake limiter.
        const ip = clientIp(request) ?? "unknown";
        const [tokOk, ipOk] = await Promise.all([
          checkRateLimit(`onboard-upload:token:${token}`, 600, 40),
          checkRateLimit(`onboard-upload:ip:${ip}`, 600, 60),
        ]);
        if (!tokOk || !ipOk) return json({ error: "rate_limited" }, 429);

        const { supabaseAdmin } = await import("@/integrations/supabase/client.server");

        // Validate token → must be active; derive the authoritative draft_id namespace.
        const { data: row, error: tErr } = await supabaseAdmin
          .from("onboarding_tokens" as any)
          .select("draft_id, status")
          .eq("token", token)
          .maybeSingle();
        if (tErr) return json({ error: "lookup_failed" }, 500);
        if (!row) return json({ error: "invalid_token" }, 404);
        if ((row as any).status !== "active") return json({ error: "token_used" }, 403);
        const draftId = (row as any).draft_id as string;

        // Service-role write (bypasses the public-assets is_admin write RLS).
        const path = `${draftId}/${category}/${crypto.randomUUID()}-${file.name}`;
        const up = await supabaseAdmin.storage.from("public-assets").upload(path, file, { upsert: false, contentType: file.type });
        if (up.error) return json({ error: up.error.message }, 500);
        const { data: pub } = supabaseAdmin.storage.from("public-assets").getPublicUrl(path);
        return json({ url: pub.publicUrl, path }, 200);
      },
    },
  },
});
```

## File 2: `src/lib/clients/site-image-upload.ts` — add the client-mode proxy helper (keep `uploadSiteImage` as-is)
```ts
/** Client-mode upload: POST to the token-gated proxy (public-assets is admin-write, so
 *  unauthenticated clients upload via the service-role proxy). Same {url, path} shape as uploadSiteImage. */
export async function uploadSiteImageViaProxy(
  token: string,
  category: string,
  file: File,
): Promise<{ url: string; path: string }> {
  if (!file.type.startsWith("image/")) throw new Error("Please upload an image file");
  if (file.size > 10 * 1024 * 1024) throw new Error("Image exceeds 10MB");
  const form = new FormData();
  form.set("token", token);
  form.set("category", category);
  form.set("file", file);
  const res = await fetch("/api/public/onboarding/upload", { method: "POST", body: form });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error((data as any)?.error ?? "Upload failed");
  return { url: (data as any).url, path: (data as any).path };
}
```

## File 3: `src/components/onboard/OnboardWizard.tsx` — mode-aware uploads
- Add a `token?: string` prop (client mode).
- Add one mode-aware upload helper and use it for ALL image uploads (logo + categorized photos + staff):
  ```ts
  const uploadImage = (category: string, file: File) =>
    isAgency ? uploadSiteImage(draftId, category, file) : uploadSiteImageViaProxy(token!, category, file);
  ```
- Replace the existing direct calls:
  - logo: `uploadSiteImage(draftId, "logo", f)` → `uploadImage("logo", f)` (both sites ~659/694).
  - categorized photos: `uploadSiteImage(draftId, "site/" + cat, file)` → `uploadImage("site/" + cat, file)`.
  - staff: `uploadSiteImage(draftId, "site/staff", file)` → `uploadImage("site/staff", file)`.
  - The photos/staff sub-component currently takes `draftId` and calls `uploadSiteImage` directly — thread the mode-aware `uploadImage` (or `mode`+`token`) into it so client mode routes through the proxy. (Import `uploadSiteImageViaProxy` alongside `uploadSiteImage`.)
- **Un-gate client-mode uploads** (remove the client-mode "uploads enable shortly" disabled state — they work now). **Leave the final submit gated** ("Submitting enables shortly") — that's C-3d-3.

## File 4: `src/routes/onboard.$token.tsx` — pass the token
Pass the URL token to the wizard: `<OnboardWizard mode="client" draftId={data.draftId} prefill={data.prefill} token={token} />`.

## Drift check (report back)
1. NEW `api/public/onboarding/upload.ts` (proxy) + `site-image-upload.ts` (+`uploadSiteImageViaProxy`, `uploadSiteImage` unchanged) + `OnboardWizard.tsx` (mode-aware uploads, client uploads un-gated) + `onboard.$token.tsx` (pass `token`).
2. **No migration, no schema/fn change, no new secret.** Agency-mode uploads unchanged (`uploadSiteImage`).
3. Proxy: token-gated (active only) + per-token/per-IP rate-limit + image/10MB caps; service-role write under the token's `draft_id`.
4. `tsc` passes.

---

# VALIDATION — C-3d-2 (as `itsmikeymiami` + a logged-out browser)

1. **Generate** an onboarding link (`/agency` → Onboarding) and open it **logged-out**. In client mode, upload a **logo**, ≥1 photo in **each** category (work/gallery/about/services), and a **staff** photo → all succeed (no "enables shortly" on uploads). Confirm:
   ```sql
   select name from storage.objects
   where bucket_id='public-assets' and name like (
     select draft_id || '/%' from public.onboarding_tokens order by created_at desc limit 1
   ) order by created_at desc;
   -- EXPECT: files under <draft_id>/logo/…, <draft_id>/site/work/…, …/site/staff/…
   ```
   The uploaded images render as thumbnails in the wizard.
2. **Token gating:** SQL-set the newest token `status='claimed'` → attempt an upload → rejected (403 `token_used`). A bogus token → 404. (The submit is still gated — that's C-3d-3.)
3. **Caps:** a >10MB image or a non-image → rejected (400) with a clear message.
4. **Agency regression:** authed `/onboard` self-fill uploads still work (direct `uploadSiteImage`, not the proxy) and create a pending client.
5. No service-role key on the client; the proxy is the only service-role writer.

**Pass:** client-mode uploads succeed via the proxy under the token's `draft_id`; token/claimed/caps enforced; agency uploads unchanged. Cleanup: `delete from public.onboarding_tokens where created_by='<me>';` + remove the test objects from `public-assets`.

### After C-3d-2 is green
→ **C-3d-3** (public submit → shared `insertClientFull` → `status='pending'` + token claim + Turnstile on submit + mode-aware success). **F3 + the self-fill-after-helper regression land here.**

---
**App-layer only. No schema, no fn-contract change, no new secret. Upload proxy gated by the single-use token + rate-limit + caps; agency uploads unchanged.**
