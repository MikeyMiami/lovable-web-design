# SVC-2b-board — robust `by_service` slug match (fuzzy) — build spec [PARKED / ON THE SHELF]

> **PARKED 2026-07-05 — NOT built.** SVC-2b-board's exact `by_service[row.slug]` match works today (x3's `by_service` keys, `services_structured` slugs, and SEO map slugs all align exactly). This is the **ready fix to pull IF** a future client's AI-map service **page slug diverges** from the `by_service` key (= `slugify(onboarding service name)`) — e.g. page `hardscaping-services` / `hardscaping-columbus` vs key `hardscaping` — and per-service photos stop auto-matching. Deferred because it adds a fuzzy matcher + an ambiguity guard for a divergence not yet observed.

## When to pull this
Symptom: a service page's Photo-Board auto-suggest picks broad-pool photos instead of that service's `by_service` photos, AND checking shows the page slug ≠ the `by_service` key. Then apply the fix below.

## The fix (admin.seo.tsx, UI-only, ZERO schema)
Add `byServiceFor` (exact → prefix-fuzzy, most-specific/longest key wins) and use it in `serviceFirstCandidates`:
```ts
function byServiceFor(assets: SiteAssets, slug?: string): SiteAsset[] {
  const bs = assets.by_service;
  if (!slug || !bs) return [];
  if (bs[slug]?.length) return bs[slug]; // exact
  // page slug + by_service key both derive from the service name, but the AI map
  // may add context (city/category). Match on prefix either direction; prefer the
  // LONGEST key to avoid a short key over-matching (e.g. "lawn" vs "lawn-care").
  const keys = Object.keys(bs).sort((a, b) => b.length - a.length);
  for (const k of keys) {
    if (slug === k || slug.startsWith(`${k}-`) || k.startsWith(`${slug}-`)) return bs[k] ?? [];
  }
  return [];
}
// in serviceFirstCandidates: replace  assets.by_service?.[slug] ?? []  with  byServiceFor(assets, slug)
```

## Validation (when built)
Exact still wins (aligned slugs unaffected); a diverged page slug (`hardscaping-services` vs key `hardscaping`) matches; `lawn-care-columbus` with keys `lawn`+`lawn-care` matches `lawn-care` (longest); no match → broad pool.

**Status: PARKED.** Referenced from `docs/build-log/stage-svc-2b-board-validation.md` + the roadmap.
