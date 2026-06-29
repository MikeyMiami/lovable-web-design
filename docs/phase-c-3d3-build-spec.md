# Phase C — C-3d-3 (finale): F3 refactor → public submit → Turnstile. Build prompts 3a/3b/3c.

> Run back-to-back: **3a** (F3 refactor, zero-schema) → **3b** (public submit + wire + success, zero-schema) → **3c** (Turnstile; needs env keys). Held until the batch validates; then commit together. Grounded on `cloud-spark-setup` `origin/main` @ `eb40f65`. Settled: slug auto-resolve (suffix), claim-first, Turnstile keys WILL be set, client success "All Set!" copy, route forces `status='pending'`.

---

# PROMPT C-3d-3a — F3 refactor (extract `insertClientFull`) — paste into Lovable

> **App-layer refactor of validated code. ZERO schema/migration. `createClientFull` external signature UNCHANGED.** Report files changed + confirm no migration.

## File: `src/lib/clients/onboarding.functions.ts`
Extract the create logic from `createClientFull` into a shared, exported helper, then have `createClientFull` call it. **No behavior change.**

1. Add (above `createClientFull`):
```ts
/** Shared client-create: insert clients row + upsert send_settings + write the immutable
 *  submission JSON. Used by createClientFull (admin) AND the public onboarding submit
 *  (token-gated). Caller supplies the service-role client + the status. */
export async function insertClientFull(
  supabaseAdmin: any,
  args: {
    slug: string;
    fields: z.infer<typeof ClientFields> & { businessName: string };
    sendSettings?: z.infer<typeof SendSettingsFields>;
    submission: Record<string, unknown>;
    status?: string;
  },
): Promise<{ clientId: string; slug: string }> {
  const insert: Record<string, unknown> = {
    slug: args.slug,
    business_name: args.fields.businessName,
    status: args.status ?? "pending",
    ...clientPatch(args.fields),
  };
  const { data: client, error: cErr } = await supabaseAdmin
    .from("clients").insert(insert as any).select("id, slug").single();
  if (cErr) {
    if ((cErr as any).code === "23505") throw new Error(`Slug "${args.slug}" is already taken`);
    throw new Error(cErr.message);
  }
  const clientId = client.id as string;

  if (args.sendSettings) {
    const { error: sErr } = await supabaseAdmin
      .from("send_settings").upsert({ client_id: clientId, ...sendPatch(args.sendSettings) }, { onConflict: "client_id" });
    if (sErr) throw new Error(sErr.message);
  }

  const { error: upErr } = await supabaseAdmin.storage
    .from("client-assets")
    .upload(`${clientId}/onboarding-submission.json`,
      new Blob([JSON.stringify(args.submission, null, 2)], { type: "application/json" }),
      { contentType: "application/json", upsert: false });
  if (upErr) throw new Error(`submission record: ${upErr.message}`);

  return { clientId, slug: client.slug };
}
```
2. Replace `createClientFull`'s handler body with a call to it (keep middleware + `assertAgencyAdmin`):
```ts
.handler(async ({ data, context }) => {
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  await assertAgencyAdmin(supabaseAdmin, context.userId as string);
  return await insertClientFull(supabaseAdmin, {
    slug: data.slug, fields: data.fields, sendSettings: data.sendSettings,
    submission: data.submission, status: "pending",
  });
});
```
3. **Export `CreateClientFullInput`** (change `const CreateClientFullInput` → `export const CreateClientFullInput`) — the public submit route (3b) reuses it.

## Drift check
1. `onboarding.functions.ts` only (+`insertClientFull`, `createClientFull` calls it, export the input schema). No other fn touched.
2. **No migration, no schema, no signature change.**
3. `tsc` passes.

## Validation (3a — the regression)
Agency self-fill `/onboard` (authed) → walk + Create → **still creates a pending client**:
```sql
select status from public.clients where slug='<new-agency-slug>';  -- EXPECT 'pending'
select 1 from public.send_settings where client_id=(select id from public.clients where slug='<new-agency-slug>'); -- EXPECT a row
-- + the submission JSON exists at client-assets <id>/onboarding-submission.json
```
Pass = identical agency behavior after the extraction. (Cleanup: delete the test client.)

---

# PROMPT C-3d-3b — public submit + wire client submit + mode-aware success — paste into Lovable

> **App-layer. ZERO schema/migration.** New public submit route (token claim-first → `insertClientFull` `status='pending'` → back-link). Wire client-mode submit to it; mode-aware success. Report files changed + confirm no migration.

## File 1 (NEW): `src/routes/api/public/onboarding/submit.ts`
Public (no auth); same-origin. Reuses `CreateClientFullInput` (3a export) + `insertClientFull`.
```ts
import { createFileRoute } from "@tanstack/react-router";
import { z } from "zod";
import { checkRateLimit, clientIp } from "@/lib/security/rate-limit.server";
import { CreateClientFullInput } from "@/lib/clients/onboarding.functions";

const Input = z.object({ token: z.string().min(1).max(200), payload: CreateClientFullInput });

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

export const Route = createFileRoute("/api/public/onboarding/submit")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        let body: unknown;
        try { body = await request.json(); } catch { return json({ error: "invalid_json" }, 400); }
        const parsed = Input.safeParse(body);
        if (!parsed.success) return json({ error: "invalid_input", issues: parsed.error.issues }, 400);
        const { token, payload } = parsed.data;

        // Rate-limit (per-token + per-IP)
        const ip = clientIp(request) ?? "unknown";
        const [tokOk, ipOk] = await Promise.all([
          checkRateLimit(`onboard-submit:token:${token}`, 600, 5),
          checkRateLimit(`onboard-submit:ip:${ip}`, 600, 20),
        ]);
        if (!tokOk || !ipOk) return json({ error: "rate_limited" }, 429);

        // === (C-3d-3c inserts the Turnstile verify HERE, after rate-limit, before claim) ===

        const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
        const { insertClientFull } = await import("@/lib/clients/onboarding.functions");

        // Claim-first (single-use): only succeeds if still active.
        const { data: claimed, error: claimErr } = await supabaseAdmin
          .from("onboarding_tokens" as any)
          .update({ status: "claimed", claimed_at: new Date().toISOString() })
          .eq("token", token).eq("status", "active")
          .select("draft_id").maybeSingle();
        if (claimErr) return json({ error: "claim_failed" }, 500);
        if (!claimed) return json({ error: "token_used_or_invalid" }, 403);

        // Create the pending client; auto-resolve slug collisions (client can't edit the hidden slug).
        let result: { clientId: string; slug: string } | undefined;
        let slug = payload.slug;
        for (let attempt = 0; attempt < 4; attempt++) {
          try {
            result = await insertClientFull(supabaseAdmin, {
              slug, fields: payload.fields, sendSettings: payload.sendSettings,
              submission: payload.submission, status: "pending", // forced server-side
            });
            break;
          } catch (e: any) {
            if (/already taken/i.test(e?.message ?? "") && attempt < 3) {
              slug = `${payload.slug}-${crypto.randomUUID().slice(0, 4)}`;
              continue;
            }
            return json({ error: "create_failed", detail: e?.message ?? "error" }, 500);
          }
        }

        // Back-link the created client to the token.
        await supabaseAdmin.from("onboarding_tokens" as any)
          .update({ created_client_id: result!.clientId }).eq("token", token);

        return json({ ok: true }, 200);
      },
    },
  },
});
```
**Trust boundary:** the route forces `status:'pending'` and ignores any client-sent status/client_id; it trusts only the validated payload fields + the server-side token claim.

## File 2: `src/components/onboard/OnboardWizard.tsx` — wire client submit + success
- Add client-mode success state: `const [submitted, setSubmitted] = useState(false);`
- In `onCreate()`, branch by mode:
```ts
const payload = buildPayload();
if (isAgency) {
  const res = await createClientFull({ data: payload as any });
  setCreatedClientId(res.clientId);
} else {
  const res = await fetch("/api/public/onboarding/submit", {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token, payload }),   // (3c adds turnstileToken)
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error((data as any)?.error ?? "Submit failed");
  setSubmitted(true);
}
```
- **Un-gate the client submit** (remove the "Submitting enables shortly" disabled state; the final button now calls `onCreate` in both modes).
- **Mode-aware success** — before the existing agency `if (createdClientId)` block, add:
```tsx
if (!isAgency && submitted) {
  return (
    <div className="max-w-2xl mx-auto p-8 space-y-3 text-center">
      <h1 className="text-2xl font-semibold">All Set!</h1>
      <p className="text-sm text-muted-foreground">Thanks for submitting! You'll receive login details soon.</p>
    </div>
  );
}
```
(No "add another" / no Admin link in client mode. Agency success unchanged.)

## Drift check
1. NEW `api/public/onboarding/submit.ts`; `OnboardWizard.tsx` (client submit → public route, un-gate, mode-aware success). `createClientFull`/`insertClientFull` unchanged from 3a.
2. **No migration, no schema/fn-contract change, no new secret.** Route forces `status='pending'`.
3. `tsc` passes.

## Validation (3b — the loop closes)
1. Generate a link → open **logged-out** → fill + upload (proxy) → **Submit** → client sees **"All Set!"**. Then:
```sql
select status, slug from public.clients order by created_at desc limit 1;          -- EXPECT 'pending'
select status, created_client_id is not null as linked from public.onboarding_tokens order by created_at desc limit 1; -- EXPECT 'claimed', linked=true
```
2. The new pending client appears in **/agency → Onboarding**; **Open** → `/admin/review` shows it (submission viewer + uploaded images) → **Finalize & Invite** → active + client_owner.
3. **Single-use:** re-open the same link → "already used" (claimed). Double-submit can't create a second client (claim-first).
4. **Slug collision:** submit a second client whose business name derives the same slug → it still creates (auto-suffixed slug); SQL shows `slug='<base>-xxxx'`.
5. **Agency regression:** authed `/onboard` self-fill still creates a pending client.

---

# PROMPT C-3d-3c — Turnstile on submit — ⛔ BACKLOGGED (decided against 2026-06-29)

> **NOT BUILT — decided against for now.** The public submit is already gated by the **single-use token + per-token/per-IP rate-limit**, and links are **private one-time links sent to known clients** (not a public signup). Worst case is one junk pending client deleted from the queue — not a real threat. **Revisit ONLY if onboarding becomes publicly accessible.** The prompt below is retained verbatim for that future case.

> **App-layer. ZERO schema/migration.** Add the Turnstile frontend widget to the client-mode submit + verify it on the public submit route. **Requires env keys (below).** Report files changed + confirm no migration.

## ENV (set these — not code)
- **`VITE_TURNSTILE_SITE_KEY`** — Cloudflare Turnstile **site key** (public; frontend widget).
- **`TURNSTILE_SECRET_KEY`** — Turnstile **secret** (backend; `verifyTurnstile`). *(If unset, `verifyTurnstile` fails-OPEN — submit still works, just unprotected; the token + rate-limit still gate.)*

## File 1 (NEW): `src/components/onboard/TurnstileWidget.tsx`
```tsx
import { useEffect, useRef } from "react";
declare global { interface Window { turnstile?: any } }

export function TurnstileWidget({ onToken }: { onToken: (t: string) => void }) {
  const ref = useRef<HTMLDivElement>(null);
  const siteKey = import.meta.env.VITE_TURNSTILE_SITE_KEY as string | undefined;
  useEffect(() => {
    if (!siteKey || !ref.current) return;
    const render = () => window.turnstile?.render(ref.current!, { sitekey: siteKey, callback: onToken });
    if (window.turnstile) { render(); return; }
    const s = document.createElement("script");
    s.src = "https://challenges.cloudflare.com/turnstile/v0/api.js";
    s.async = true; s.onload = render; document.head.appendChild(s);
  }, [siteKey]); // eslint-disable-line react-hooks/exhaustive-deps
  if (!siteKey) return null; // no key → no widget (submit not Turnstile-gated until configured)
  return <div ref={ref} className="my-2" />;
}
```

## File 2: `src/components/onboard/OnboardWizard.tsx`
- `const [turnstileToken, setTurnstileToken] = useState<string | null>(null);`
- In **client mode only**, render `<TurnstileWidget onToken={setTurnstileToken} />` on the final/submit step (near the Submit button).
- Include the token in the submit POST: `body: JSON.stringify({ token, payload, turnstileToken })`.
- *(Optional UX: if `VITE_TURNSTILE_SITE_KEY` is set, disable Submit until `turnstileToken` is present.)*

## File 3: `src/routes/api/public/onboarding/submit.ts`
- Extend `Input`: add `turnstileToken: z.string().optional()`.
- After the rate-limit block, before the claim, add:
```ts
const { verifyTurnstile } = await import("@/lib/security/turnstile.server");
const captchaOk = await verifyTurnstile(parsed.data.turnstileToken ?? "", ip); // fails-OPEN if secret unset
if (!captchaOk) return json({ error: "captcha_failed" }, 403);
```

## Drift check
1. NEW `TurnstileWidget.tsx`; `OnboardWizard.tsx` (widget + token in submit); `submit.ts` (verify). No schema/fn-contract change, no new DB secret (Turnstile keys are env).
2. `tsc` passes.

## Validation (3c — with both keys set)
1. Open a client link → the **Turnstile widget renders** on the submit step; complete it → Submit succeeds → pending client created (as 3b).
2. **Fail path:** with the keys set, force a failed/again challenge (Turnstile test key `2x00000000000000000000AA` = always-fail) → Submit blocked (`captcha_failed`).
3. **Keys-unset path** (if not yet configured): widget absent; submit still works (fails-open) — token + rate-limit still gate.

---
**3a + 3b = ZERO schema. 3c = ZERO schema but needs `VITE_TURNSTILE_SITE_KEY` + `TURNSTILE_SECRET_KEY` env. `createClientFull` contract preserved (F3 internal). Commit all three together after the batch validates.**
