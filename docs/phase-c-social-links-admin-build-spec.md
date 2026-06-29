# Phase C — Friendly social-link editors in admin Settings — build spec

> App-layer / UI only — **NO schema, NO fn change** (`clients.social_links` + its admin save already exist). Held for review. Verified against `cloud-spark-setup` `origin/main` @ `1e328ea`.

## The clobber/merge question — answered (read-only verify)
- `clients.social_links` is a **dedicated jsonb COLUMN** (not `template_vars`). `saveClient.mutate({ social_links: <obj> })` → `UPDATE clients SET social_links = <obj>` → **REPLACES the whole column** (like any column).
- **No clobber TODAY** because the existing **Brand & Site** save already round-trips the **WHOLE object**: `social_links: safeJson(brand.social_links, {})` (`admin.settings.tsx:315`) — it parses the "Social links (JSON)" textarea (seeded from `client.social_links`, line 171) and writes the entire object.
- **So adding friendly fields is safe IFF they merge into that full object** (overlay just instagram/facebook/linkedin onto the parsed-textarea base), NOT write only the three keys. Writing only the three would wipe other keys (bbb/tiktok/yelp) — same failure mode as `template_vars`.
- **Dual-writer:** the JSON textarea AND the friendly fields both target `social_links`. Keep them in the **SAME Brand & Site save** and reconcile in `onSave` (base = parsed textarea, overlay the 3 friendly fields) + **re-seed the textarea** after — same dual-writer guard pattern as the discount/template_vars work. (Putting socials in a *different* section from the JSON editor would create a second `social_links` writer → cross-section clobber; don't.)

## Location decision
- **Recommend: Brand & Site** (the `social_links` home — where the JSON textarea already lives → single writer, no cross-section clobber). The friendly fields sit right above the JSON textarea.
- The **GBP editable field lives in Review Config** (a different data home: `template_vars.google_business_profile_link` + `review_link`), so socials can't share GBP's exact save without routing `social_links` through Review Config (which would split the `social_links` writer → clobber risk). If you truly want them visually beside GBP, the alternative is to move the whole `social_links` editor into Review Config (bigger change) — not recommended. *(Flag for your call; the prompt uses Brand & Site.)*

## Schema / fn flag
**NONE.** Existing column + existing admin save; friendly inputs + a merge + a textarea re-seed.

---

# PROMPT — Friendly social-link editors in admin Settings — paste into Lovable

> **App-layer / UI only. NO migration, NO schema/fn change.** Add editable Instagram / Facebook / LinkedIn inputs to the **Brand & Site** section of admin Settings (where `social_links` already lives), pre-filled from `clients.social_links`, merged into the full object on save (no clobber) with a JSON-textarea re-seed. Report files changed + confirm no migration.

## File: `src/routes/_authenticated/admin.settings.tsx` — Brand & Site section

### 1. Local state (seed from the loaded `social_links`)
```tsx
const sl = (client.social_links ?? {}) as Record<string, string>;
const [social, setSocial] = useState({
  instagram: sl.instagram ?? "",
  facebook: sl.facebook ?? "",
  linkedin: sl.linkedin ?? "",
});
```
(Seeded on mount; `SettingsForm` remounts on active-client change, so it re-seeds. Optional: also reset in the existing `clientId` effect.)

### 2. Merge-safe save — replace the Brand & Site section's `onSave` so it overlays the friendly fields onto the full `social_links` object and re-seeds the JSON textarea
```tsx
onSave={() => {
  const base = safeJson<Record<string, any>>(brand.social_links, {}); // full current object (other keys preserved)
  const setOrDel = (k: string, v: string) => { const t = (v ?? "").trim(); if (t) base[k] = t; else delete base[k]; };
  setOrDel("instagram", social.instagram);
  setOrDel("facebook", social.facebook);
  setOrDel("linkedin", social.linkedin);
  saveClient.mutate({
    logo_url: brand.logo_url || null,
    brand_color: brand.brand_color,
    site_style: brand.site_style || null,
    service_area: brand.service_area.split(",").map((s) => s.trim()).filter(Boolean),
    social_links: base,                                   // FULL merged object → no clobber
  });
  setBrand({ ...brand, social_links: JSON.stringify(base, null, 2) }); // dual-writer guard: re-seed the JSON textarea
}}
```
(Keep the section's other fields exactly as they are; this only adds the social overlay + the re-seed. `safeJson` already exists on the page.)

### 3. Friendly inputs — add above the existing "Social links (JSON)" textarea
```tsx
<div className="grid grid-cols-3 gap-3">
  <Field label="Instagram" hint="Profile URL (blank = remove).">
    <Input value={social.instagram} onChange={(e) => setSocial({ ...social, instagram: e.target.value })} placeholder="https://instagram.com/…" />
  </Field>
  <Field label="Facebook" hint="Page URL (blank = remove).">
    <Input value={social.facebook} onChange={(e) => setSocial({ ...social, facebook: e.target.value })} placeholder="https://facebook.com/…" />
  </Field>
  <Field label="LinkedIn" hint="Company/profile URL (blank = remove).">
    <Input value={social.linkedin} onChange={(e) => setSocial({ ...social, linkedin: e.target.value })} placeholder="https://linkedin.com/company/…" />
  </Field>
</div>
```
Leave the existing **"Social links (JSON)"** textarea in place (now a power-user view of the same object; it re-seeds after each save so the friendly fields + JSON stay in sync). Empty friendly field → that platform key is removed from `social_links`.

## Drift check (report back)
1. `admin.settings.tsx` only (Brand & Site: `social` state + 3 inputs + merge-safe `onSave` + textarea re-seed).
2. **No migration, no schema/fn change.** Save writes the FULL `social_links` (other keys preserved); JSON textarea re-seeded.
3. `tsc` passes.

## Validation (as `itsmikeymiami`)
On a client whose `social_links` has multiple keys (e.g. seed `{"instagram":"a","yelp":"y"}`):
1. Brand & Site shows **Instagram** pre-filled (`a`); the JSON textarea shows the full object.
2. Set **Facebook** + **LinkedIn**, change **Instagram** → Save:
   ```sql
   select social_links from public.clients where id='<clientId>';
   -- EXPECT: {"instagram":"<new>","yelp":"y","facebook":"<set>","linkedin":"<set>"}  (yelp preserved — no clobber)
   ```
   The JSON textarea now reflects the merged object (re-seed).
3. **Blank a field** (e.g. clear Instagram) → Save → `instagram` key removed; other keys intact.
4. The onboarding-captured socials appear here pre-filled for any client created via the (Social Links) wizard.

**Pass:** friendly IG/FB/LinkedIn editors pre-filled from `social_links`, merge-safe save (other keys + each other preserved), JSON textarea stays in sync, blank = remove. Nothing to clean up beyond the test client.

---
**App-layer only. No schema/fn. `social_links` is a column written wholesale → friendly fields MERGE into the full object (+ re-seed the JSON textarea). Brand & Site (the social_links home).**
