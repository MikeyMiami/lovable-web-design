# Phase C — C-3d-1 add-on: email the onboarding link via mailto (Option A)

> Folds onto C-3d-1's generate-link card. **App-layer / UI only — NO schema, NO fn, NO secret, NO email provider.** Held for review. Verified against `cloud-spark-setup` `origin/main` @ `e94687f`.

## Why mailto (decided)
No email provider exists to reuse (`notify.server.ts` writes `owner_email_stub` queue markers only; invites use Supabase Auth's fixed template). A real send = a separate infra project (provider + secret + verified domain) with worse deliverability until the domain verifies. `mailto:` sends from the agency's real address → best deliverability + client recognizes the sender, zero infra. Option B (provider) deferred.

## Scope
On `src/routes/_authenticated/agency.onboarding.tsx`, inside the existing `{generated && (...)}` block (so it appears after a link is generated): a **client email** input + an **editable subject + body template** (default constants + `localStorage` persistence + Reset) + an **"Email this link"** button that opens the agency's mail client via `mailto:` with `{link}` substituted. Keep **Copy** as the fallback. App-layer only.

## Schema / fn flag
**NONE.** No migration, no server fn, no secret, no provider. Pure client-side UI + `localStorage` + a `mailto:` URL.

---

# PROMPT — Email the onboarding link (mailto) — paste into Lovable

> **App-layer / UI only. NO migration, NO schema/fn change, NO secret, NO email provider.** Add an "Email this link" composer to the existing generate-link card in `src/routes/_authenticated/agency.onboarding.tsx`. Report files changed + confirm no migration.

## File: `src/routes/_authenticated/agency.onboarding.tsx`

### 1. Constants + localStorage keys (module scope, above the component)
```tsx
const EMAIL_SUBJECT_KEY = "agency.onboardEmail.subject";
const EMAIL_BODY_KEY = "agency.onboardEmail.body";

const DEFAULT_EMAIL_SUBJECT = "Your onboarding form — let's get your website started";

const DEFAULT_EMAIL_BODY = `Hi there,

Thanks for choosing us to build your website! To get started, please fill out our quick onboarding form:

{link}

It takes just a few minutes and walks you through everything we need — your business info, hours, photos, branding, and the details to register your texting. Have your logo and a few photos handy if you can.

A couple of notes:
- This link is private and for one-time use, so please complete it in a single sitting.
- If anything's unclear, just reply to this email and we'll help.

Looking forward to building this for you!

Best,
`;
```

### 2. State (in the component) — seed from localStorage with an SSR guard
```tsx
const [clientEmail, setClientEmail] = useState("");
const [emailSubject, setEmailSubject] = useState(() =>
  (typeof window !== "undefined" && window.localStorage.getItem(EMAIL_SUBJECT_KEY)) || DEFAULT_EMAIL_SUBJECT);
const [emailBody, setEmailBody] = useState(() =>
  (typeof window !== "undefined" && window.localStorage.getItem(EMAIL_BODY_KEY)) || DEFAULT_EMAIL_BODY);

function updateSubject(v: string) { setEmailSubject(v); try { window.localStorage.setItem(EMAIL_SUBJECT_KEY, v); } catch {} }
function updateBody(v: string) { setEmailBody(v); try { window.localStorage.setItem(EMAIL_BODY_KEY, v); } catch {} }
function resetTemplate() {
  setEmailSubject(DEFAULT_EMAIL_SUBJECT); setEmailBody(DEFAULT_EMAIL_BODY);
  try { window.localStorage.setItem(EMAIL_SUBJECT_KEY, DEFAULT_EMAIL_SUBJECT); window.localStorage.setItem(EMAIL_BODY_KEY, DEFAULT_EMAIL_BODY); } catch {}
}

function emailThisLink() {
  if (!generated || !clientEmail.trim()) return;
  const body = emailBody.split("{link}").join(generated.url); // {link} → the onboarding URL
  const mailto = `mailto:${encodeURIComponent(clientEmail.trim())}`
    + `?subject=${encodeURIComponent(emailSubject)}`
    + `&body=${encodeURIComponent(body)}`;
  window.location.href = mailto;
}
```

### 3. UI — inside the existing `{generated && (...)}` block, after the Copy row
Add a divider + the composer (uses the existing `Input` / `Button`; add `Textarea` to the imports):
```tsx
<div className="pt-3 border-t space-y-2">
  <div className="text-sm font-medium">Email the link</div>
  <Input
    type="email"
    placeholder="client@email.com"
    value={clientEmail}
    onChange={(e) => setClientEmail(e.target.value)}
  />
  <Input
    value={emailSubject}
    onChange={(e) => updateSubject(e.target.value)}
    placeholder="Subject"
  />
  <Textarea
    rows={10}
    className="text-sm"
    value={emailBody}
    onChange={(e) => updateBody(e.target.value)}
  />
  <div className="flex items-center justify-between gap-2">
    <p className="text-[11px] text-muted-foreground">
      Opens your email app pre-filled (sent from your address). <code>{"{link}"}</code> is replaced with the onboarding URL. Your edits are saved in this browser.
    </p>
    <div className="flex gap-2 shrink-0">
      <Button variant="ghost" size="sm" onClick={resetTemplate}>Reset to default</Button>
      <Button size="sm" disabled={!clientEmail.trim()} onClick={emailThisLink}>Email this link</Button>
    </div>
  </div>
</div>
```
Add `import { Textarea } from "@/components/ui/textarea";` to the imports.

### Notes / guardrails
- **App-layer only** — no migration, no server fn, no secret, no email provider. The mail is composed in the agency's own mail client; the app never sends mail.
- `{link}` substitution uses `split/join` (no `replaceAll` target concerns). The template persists per-browser via `localStorage` (guarded for SSR); Reset restores both subject + body.
- Keep the existing **Copy** button as the fallback.

## Drift check (report back)
1. `agency.onboarding.tsx` only (email composer + localStorage template + `mailto:`; `Textarea` import).
2. **No migration, no schema/fn change, no secret, no provider.**
3. `tsc` passes.

---

# VALIDATION — (as `itsmikeymiami`)

1. `/agency` → Onboarding → **Generate onboarding link** → enter a client email → the subject + body show the default template; edit the body, reload the page → your edit **persists** (localStorage).
2. Click **Email this link** → your email client opens with: **To** = the client email, **Subject** = your subject, **Body** = your template with the real `/onboard/<token>` URL in place of `{link}`. Send it to yourself and confirm the link works (opens the client-mode wizard).
3. **Reset to default** → subject + body return to the defaults (and persist).
4. **Copy** still works as the fallback.
5. No network/email call is made by the app itself (it's all `mailto:`); no console/network errors.

**Pass:** composer appears after generating a link; template editable + persisted + resettable; "Email this link" opens a correctly pre-filled draft from your address with the link substituted; Copy fallback intact; no schema/fn/secret. (Nothing to clean up — no DB writes.)

### Folds into
The C-3d-1 mirrors — `agency-view` (Onboarding: generate-link + **email-this-link via mailto**, editable localStorage template) — committed together once C-3d-1 + this validate.

---
**App-layer / UI only. No schema, no fn, no secret, no provider. mailto from the agency's real address; template default + localStorage + Reset.**
