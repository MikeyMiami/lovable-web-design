# Phase C — Move "Returning Customer Discount" out of onboarding → agency-set in admin

> Follow-on onboarding change after C-3 (R-1/R-2/R-3). **App-layer only — no schema, no migration, no fn-contract change.** Held for review before Lovable. Grounded on `cloud-spark-setup` `origin/main` @ `97ff80b`.

## Scope / plan — read first (the #4 merge question, answered)

**Goal:** the discount is an agency-set campaign offer, not owner-onboarding input. Remove the wizard step; add an admin-only per-client editor; do NOT clobber other `template_vars` when editing just the two discount keys.

### Findings (verified against live code @ `97ff80b`)
1. **`updateClientSettings` REPLACES `template_vars` (wholesale).** `clientPatch` does `p.template_vars = f.templateVars` → `UPDATE clients SET template_vars = <value>`. A jsonb column assignment is a full replace, so sending just `{discount__on_referral, discount_amount}` through this fn **would wipe `about_us`/`services`/`differentiators`/`site_assets`/…**. The #4 concern is real for this fn.
2. **But the live per-client admin editor does NOT use `updateClientSettings`.** `src/routes/_authenticated/admin.settings.tsx` writes via the **authed browser supabase client under RLS** (`saveClient.mutate → supabase.from("clients").update(patch).eq("id", clientId)` — "NEVER service-role" by design). It **already loads the full `client.template_vars`** and its "Template Variables" section already round-trips the whole object (inherent merge). `discount__on_referral`/`discount_amount` are in fact **already editable** in that raw JSON textarea AND already listed in `REQUIRED_TEMPLATE_VARS` (flagged when blank).
3. **`updateClientSettings` is only called by the throwaway test harness** (`onboard-harness.tsx`) — not wired into any production UI. Its replace-semantics are latent/unused.

### Recommendation (diverges from "via updateClientSettings" — for the better)
**Add a dedicated "Returning Customer Discount" Section to `admin.settings.tsx` using the page's existing direct-RLS read-merge-write pattern** — write the **full current `template_vars` with the two discount keys overlaid** (`{ ...client.template_vars, discount__on_referral, discount_amount }`). This:
- **merges safely** (writes the whole object → no other keys lost),
- **avoids `updateClientSettings`** entirely (no fn change; matches the page's deliberate direct-RLS architecture),
- is **admin-only** (`/admin` is `is_admin` RLS-gated),
- is **pure app-layer** — no schema, no migration, no fn-contract change.

**Flag (not in scope, for awareness):**
- `updateClientSettings` replace-semantics is a latent footgun for any FUTURE caller doing a *partial* `template_vars` edit. If it's ever wired to a real partial-edit UI, harden it to merge (read existing → spread → overlay) — a fn behavior change requiring re-validation. Today: don't route partial `template_vars` edits through it.
- **Dual-writer interaction in `admin.settings.tsx`:** the existing "Template Variables" JSON-textarea section ALSO writes `template_vars` from its own mount-seeded text. If an admin saves the new discount section, then saves the JSON textarea (seeded before the discount change), the textarea save reverts the discount. This staleness already exists on the page. Mitigation: treat the discount section as the canonical editor for those two keys (the JSON textarea is a power-user escape hatch); optionally re-seed the textarea after any `template_vars` save. Not a blocker.

### Affected files
- `src/routes/_authenticated/onboard.tsx` — remove the step (9→8 steps), state, validation renumber, step-block renumber, assembly.
- `src/components/onboard/ReviewSummary.tsx` — remove the discount section (7 sections shown).
- `src/routes/_authenticated/admin.settings.tsx` — add the discount Section (direct-RLS merge-write).
- Skills: `onboard-from-form` (drop step; now 8; note moved to agency-set), `admin-view` (discount = dedicated agency-editable Settings section).

---

# PROMPT A — Wizard removal (paste into Lovable)

> **App-layer / UI only. No migration, no schema/fn-contract change.** Remove the "Returning Customer Discount" step from the onboarding wizard and its slot in the review summary. Report files changed + confirm no migration.

## File 1: `src/routes/_authenticated/onboard.tsx`
1. **STEPS array** — remove the `"Returning Customer Discount",` entry (it sits between `"Reviews"` and `"Texting Registration"`). The wizard goes **9 → 8 steps**.
2. **State type** — remove `discountOnReferral: string;` and `discountAmount: string;`.
3. **State init** — remove `discountOnReferral: "",` and `discountAmount: "",`.
4. **`stepErrors`** — the A2P validation block is currently gated on **`i === 7`**; change it to **`i === 6`** (A2P becomes step 6 after the removal). Leave the `i === 0`, `i === 1`, `i === 3` guards unchanged (they're before the removed step).
5. **Step render blocks** — delete the entire `{step === 6 && ( … "Returning Customer Discount Offer." … )}` block. Then **renumber the two blocks after it**: the A2P block `{step === 7 && (` → `{step === 6 && (`; the Review & Create block `{step === 8 && (` → `{step === 7 && (`. (Blocks 0–5 — Account Setup/Content/Branding/Industry & Style/Photos/Reviews — unchanged.)
6. **Assembly (`buildPayload`, `templateVars`)** — remove these two lines:
   ```ts
   discount__on_referral: s.discountOnReferral || undefined,
   discount_amount: s.discountAmount || undefined,
   ```
   The wizard no longer writes these; they stay **unset at create** (agency sets them later in admin Settings). The `submission` object spreads `...s`, so once the two state fields are gone they drop out of the submission automatically — no other change there.
7. Confirm **no remaining references** to `discountOnReferral` / `discountAmount` / `discount__on_referral` / `discount_amount` in `onboard.tsx`.

## File 2: `src/components/onboard/ReviewSummary.tsx`
Remove the entire discount section:
```tsx
<Section title="Returning Customer Discount">
  <Row label="On referral" value={s.discountOnReferral || undefined} />
  <Row label="Discount amount" value={s.discountAmount || undefined} />
</Section>
```
The summary now shows **7 sections**: Account Setup, Content, Branding, Industry & Style, Photos, Reviews, Texting Registration.

## Drift check (report back)
1. `onboard.tsx` (STEPS 9→8, state + init removed, `stepErrors` A2P guard `7→6`, step blocks renumbered `7→6`/`8→7`, assembly discount lines removed) + `ReviewSummary.tsx` (discount section removed).
2. **No migration, no schema, no fn-contract change.**
3. Payload no longer carries `discount__on_referral`/`discount_amount` (unset at create); everything else identical.

## Validation (as `itsmikeymiami`)
Walk the wizard: **8 steps**, no discount step; **Reviews → Texting Registration** directly; A2P still blocks on EIN/legal/vertical/TCPA; **Review & Create shows 7 sections** (no discount). Create a client (slug `disc-removed-test`):
```sql
select template_vars ? 'discount__on_referral' as has_offer,
       template_vars ? 'discount_amount'      as has_amount
from public.clients where slug='disc-removed-test';
-- EXPECT: both false (keys absent — unset at create).
```
Cleanup: `delete from public.clients where slug='disc-removed-test';`

---

# PROMPT B — Admin discount setting (paste into Lovable AFTER A)

> **App-layer / UI only. No migration, no schema/fn-contract change.** Add an admin-only "Returning Customer Discount" editor to the per-client Settings page, written via the page's existing direct-RLS pattern. **⚠️ MERGE REQUIREMENT:** `UPDATE clients SET template_vars = <obj>` REPLACES the whole jsonb — the save MUST write the **full current `template_vars`** with the two discount keys overlaid, NEVER just the two keys (else `about_us`/`services`/etc. are wiped). Report files changed + confirm no migration.

## File: `src/routes/_authenticated/admin.settings.tsx`
The page already loads the full row (`supabase.from("clients").select("*")`), exposes `initialVars = (client.template_vars ?? {})`, and saves via `saveClient.mutate(patch)` → `supabase.from("clients").update(patch).eq("id", clientId)`.

1. **Add local state** (seed from the loaded vars), near the other section state:
   ```tsx
   const [discount, setDiscount] = useState({
     offer: (initialVars.discount__on_referral as string) ?? "",
     amount: (initialVars.discount_amount as string) ?? "",
   });
   ```
2. **Reset on active-client change** (mirror the existing `identity` effect):
   ```tsx
   useEffect(() => {
     const v = (client.template_vars ?? {}) as Record<string, string>;
     setDiscount({ offer: v.discount__on_referral ?? "", amount: v.discount_amount ?? "" });
   }, [clientId]); // eslint-disable-line react-hooks/exhaustive-deps
   ```
3. **Add the Section** (place it near "Review Config" / "Template Variables"). On save, **merge against the live full `template_vars`**:
   ```tsx
   <Section
     title="Returning Customer Discount"
     hint="Agency-set campaign offer dropped into the 1-year follow-up texts (and shown on the site). Not collected during client onboarding."
     saving={saveClient.isPending}
     onSave={() => {
       const base = { ...(client.template_vars ?? {}) } as Record<string, any>;
       const offer = discount.offer.trim();
       const amount = discount.amount.trim();
       if (offer) base.discount__on_referral = offer; else delete base.discount__on_referral;
       if (amount) base.discount_amount = amount; else delete base.discount_amount;
       saveClient.mutate({ template_vars: base });          // FULL object → no other keys lost
       setTemplateVarsText(JSON.stringify(base, null, 2));  // dual-writer guard: re-seed the JSON textarea
     }}
   >
     <div className="grid grid-cols-2 gap-3">
       <Field label="Discount offer (full text)" hint="Reads exactly as it appears in the text / on site. Example: $50 off your next service.">
         <Input value={discount.offer} onChange={(e) => setDiscount({ ...discount, offer: e.target.value })} placeholder="$50 off next service" />
       </Field>
       <Field label="Discount amount" hint="The exact value, e.g. $50 or 15%.">
         <Input value={discount.amount} onChange={(e) => setDiscount({ ...discount, amount: e.target.value })} placeholder="$50" />
       </Field>
     </div>
   </Section>
   ```
   `discount__on_referral` / `discount_amount` remain in `REQUIRED_TEMPLATE_VARS`, so they still flag as "missing" in the Template Variables section when blank — keep that.
4. **Dual-writer guard [REQUIRED]:** this discount Section is the **canonical editor** for those two keys. Because the existing "Template Variables" JSON-textarea section ALSO writes `template_vars` from its mount-seeded text, the discount `onSave` **re-seeds that textarea** (`setTemplateVarsText(JSON.stringify(base, null, 2))`) so a later textarea save can't revert the discount with stale text. (`setTemplateVarsText` is the existing state setter on this page.)

**Do NOT** introduce `updateClientSettings` here (it replaces `template_vars`) — keep using the existing direct-RLS `saveClient` mutation.

## Drift check (report back)
1. `admin.settings.tsx` only (discount state + reset effect + Section).
2. Writes via the existing direct-RLS `saveClient` (no `updateClientSettings`, no server-fn, no schema, no fn-contract change).
3. Save writes the **FULL** `template_vars` (merge — no clobber).

## Validation (as `itsmikeymiami`)
Pick a client with populated `template_vars` (about_us/services/etc.). In the new section set offer + amount → **Save**:
```sql
select template_vars->>'discount__on_referral' as offer,
       template_vars->>'discount_amount'       as amount,
       template_vars ? 'about_us' as keep_about, template_vars ? 'services' as keep_services
from public.clients where id='<clientId>';
-- EXPECT: offer/amount set; keep_about / keep_services STILL true (merge, no clobber).
```
Then **clear** both fields → Save → keys removed, other keys still present; the Template Variables "missing" flag re-appears for the two keys. Pass = discount edits round-trip and never wipe other `template_vars`.

---
**App-layer only. No schema, no fn-contract change. Discount moved from owner-onboarding → agency-set admin Settings. Merge-write protects other `template_vars` keys.**
