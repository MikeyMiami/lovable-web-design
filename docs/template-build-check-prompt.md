# Template Build-Check Prompt — acceptance gate (v1.1, 2026-07-27)

> Run against a FINISHED template project (fresh build via `docs/template-build-prompt-TEMPLATE.md`, or any template being re-blessed after edits). It verifies the wiring WITHOUT a live-client end-to-end.
>
> **DEFAULT ROUTE (free): don't paste this into Lovable at all.** GitHub-connect + publish the preview, and Claude runs this ENTIRE A–J checklist from the cloned repo + curls the preview (Claude's audit is also more trustworthy — Lovable self-reports have been caught wrong). Fixes then go back to Lovable as one small fix prompt. **FALLBACK ROUTE (costs credits): paste the prompt below into the project** when you want Lovable to fix-as-it-verifies in one pass, or Claude isn't in the loop. Either way, **PART C at the bottom is never for Lovable** — it's the external post-publish probe. A template is blessed for remixing only when A–J is all-PASS **and** PART C passes. The one check needing human eyes: the hero lead-form card visually fitting the hero viewport at 1366×768.

## The prompt (paste into the template's Lovable project)

```
AUDIT this template project against the checklist below. You are a verifier, not a builder: for each numbered item output PASS or FAIL with one line of evidence (file + line, or what you observed in the preview). Where a FAIL has a mechanical fix that this checklist itself fully specifies, apply the fix, note "FIXED", and re-verify; where the fix needs a human decision, leave it FAILED and add it to the flag list. NEVER "fix" compliance copy by writing your own prose — compliance text may only be corrected by copying byte-for-byte from the a2p-site-compliance skill appendix. Finish with the summary table, the flag list, and any template_vars keys referenced in code that are absent from demo-client.ts.

A. PROJECT HYGIENE
A1. Frontend-only: no Lovable Cloud/database/auth enabled; no supabase service-role key anywhere; no DB-writing server functions; grep for "service_role" = zero hits.
A2. .env contains EXACTLY: VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY, VITE_PLATFORM_API_HOST=https://app.pierceworks.co, VITE_CLIENT_SLUG= (empty), VITE_SITE_URL= (empty, with the warning comment distinguishing it from the API host).
A3. package.json has overrides.seroval (^1.5.2 or newer patched).
A4. No file matches *.client.* (Lovable SSR strips them → publish crash).
A5. grep for "@tanstack/react-start/server" — appears ONLY inside route server-handler files (robots/sitemap style), never in client-reachable modules like site-url/client-data.
A6. grep for "turnstile" (any case) = zero hits. Type check passes.

B. CONNECTION RESILIENCE (the remix-survival contract)
B1. src/lib/client-data.tsx: SUPABASE_URL, the anon key, AND the API host each read env with a NON-EMPTY hardcoded fallback constant (pattern: (import.meta.env.X ?? "").trim() || "hardcoded").
B2. src/lib/content-pages.ts: the SAME three fallbacks present (this file fetches independently; a remix without them silently kills every SEO page).
B3. No module exports a SITE_URL constant; absolute URLs resolve only through src/lib/site-url.ts (resolveSiteUrl: VITE_SITE_URL → window.location.origin → last-resort constant) and isIndexableOrigin returns false when VITE_SITE_URL is unset or the host ends ".lovable.app".
B4. RPC wiring exact: get_client_public { _slug }; get_client_pages { _slug }; get_client_page { _slug, _page_slug }; all with anon headers; any fetch failure returns the demo client (never a crash/blank).
B5. getClientCached() exists (~60s TTL) and every route's head()/loader reads the client through it — grep route files for direct demo-client imports = zero hits.

C. DATA-DRIVEN PURITY
C1. grep src (excluding demo-client.ts and src/assets) for the demo business name, its phone digits, its street/email, and the demo niche word — zero hits in components/routes (case-sensitive on proper nouns).
C2. Route head() titles/descriptions/og:* compose from loaded client fields + route params — no niche/business literals.
C3. In the preview with a blank slug: the FULL site renders on demo data; change demo brand_color → the site re-themes; add/remove a demo services_structured entry → the services section adapts; empty one site_assets category → niche-default fallback images render.
C4. Lander title fallback chain: with no published home row the <title> is "{segment} in {first service_area} | {business_name}" (then segment-only, then name-only) — never "Welcome"/"Home".

D. ROUTE REGISTRY (LOCKED cross-system contract)
D1. These route files exist with EXACTLY these names: __root.tsx, index.tsx, about.tsx, services.index.tsx, services.$slug.tsx, locations.tsx, service-area.$slug.tsx, $slug.tsx, gallery.tsx, contact.tsx, get-your-discount.tsx, review.index.tsx, review.$token.tsx, thank-you.tsx, terms.tsx, privacy.tsx, sms-program.tsx, robots[.]txt.tsx, sitemap[.]xml.tsx.
D2. services.$slug renders ONLY content_pages type category|service (404 otherwise); service-area.$slug ONLY type geo; the $slug catch-all ONLY type supporting; each 404s cleanly on any other type or missing row.
D3. review.$token performs an immediate redirect to https://reviewbatch.com/api/public/r/{token} — no UI, not linked anywhere.
D4. /locations lists published geo pages as links shaped /service-area/{slug} (plus the service_area strip) with a graceful empty state.
D5. /get-your-discount is linked from NOWHERE (grep nav/footer/sitemap for it = zero); /thank-you excluded from the sitemap.
D6. Every nav/heading label is inside its page's allowed_display_labels set from /website-structure; Terms of Service / Privacy Policy / SMS Program labels are exact and unflexed.
D7. Footer on EVERY page: the three named compliance links (working), social_links (only present ones), license_number line only when present, visible phone via formatPhoneUS while tel: href stays E.164.

E. SEO / HEAD / INDEXABILITY
E1. robots[.]txt.tsx is a dynamic server route: origin from new URL(request.url).origin; Disallow: / when not indexable, Allow: / when indexable; ALWAYS an absolute Sitemap: {origin}/sitemap.xml line. No static public/robots.txt exists.
E2. sitemap[.]xml.tsx derives the origin from the request; includes the 6 statics (/, /services, /locations, /about, /contact, /gallery) + published, index-robots content pages mapped home→/, category|service→/services/{slug}, geo→/service-area/{slug}, supporting→/{slug}; excludes discount/thank-you/review/compliance.
E3. pageHeadMeta forces robots to "noindex,follow" whenever isIndexableOrigin(siteUrl) is false — verify a stored "index,follow" row still emits noindex in the preview (a *.lovable.app origin).
E4. Exactly ONE h1 per page (layout-owned); ContentPageView strips a duplicate leading h1/h2 from bodies.
E5. JSON-LD: LocalBusiness (home + geo), Service (category/service), BreadcrumbList — all absolute URLs from the resolved siteUrl; telephone in E.164; homepage falls back to identity-built LocalBusiness when no home row.
E6. Google Maps embed on the lander: iframe google.com/maps?q={encoded address}&output=embed, rendered ONLY when address is non-blank.
E7. og:image on content pages = the ORIGINAL storage object URL (never a /render/image/ transformed URL).

F. IMAGE PIPELINE
F1. img.ts: imgUrl swaps object→render path with width/quality (+height&resize=cover); returns the input unchanged for non-Supabase URLs. srcSet caps candidates at naturalWidth (single capped candidate when all exceed it) and returns "" for non-Supabase URLs.
F2. SiteImage: omits srcSet AND sizes when srcSet is ""; priority → eager+fetchPriority=high else lazy; always decoding="async" + width/height attributes.
F3. ContentPageView hero: fixed-height box (h-[52vh] min-h-[380px]) + absolute object-cover, srcSet widths 640–2048 sizes 100vw, eager; inline images inside aspect-[16/9] overflow-hidden figures, object-cover, lazy, widths 480–1024, with an onError that hides the figure; focal {x,y} applied as objectPosition on both.
F4. site_slots resolution with full fallback chains: about_image → g[1] → g[0] → work_examples[1] → NICHE_DEFAULTS; team → staff images → names-only; gallery → galleryUrls → work_examples → NICHE_DEFAULTS; lander hero NOT read from site_slots (home row's hero → galleryUrls[0] → work_examples[0] → NICHE_DEFAULTS.hero).
F5. Every client-photo surface (lander hero, about, team, gallery tiles, content hero/inline) renders through SiteImage/imgUrl — grep for raw <img src={...url...}> on client photos = zero (logo exempt).

G. FORMS + BOT SHIELD (backend is fail-closed — an unwired form = zero leads)
G1. ONE shared LeadForm used by BOTH the hero card and /contact (placements differ only by layout props). Hero-card fit: full card (title→submit) visible in the hero viewport at 1366×768 in the preview; no transform:scale anywhere.
G2. Lead POST body keys EXACTLY { first_name, last_name?, phone_e164, email?, notes?, website, pow_token } to {host}/api/public/intake; phone REQUIRED with E.164 client normalization + inline error; email optional; no client_id, no source, no consent field in the payload.
G3. Discount POST body EXACTLY { first_name, last_name?, phone_e164, your_message?, consent, website, pow_token } to /api/public/discount; the consent checkbox is REQUIRED and gates submit, sending literal true.
G4. Chat widget: bubble only when client.chat_widget_enabled; greeting/confirmation from template_vars with fallbacks; REQUIRED consent; POST /api/public/chat/optin with { first_name, last_name?, phone_e164, consent: true, website, pow_token }; capture-first, NO AI. ALSO opens on a window "open-chat-widget" CustomEvent, and there is exactly ONE chat implementation — grep for a duplicated chat form/submit handler/bot-shield flow behind the hero CTA = zero hits.
G5. Call-Now button: rendered INSIDE Header.tsx (centered between logo and nav — NOT a full-width strip, NOT mounted in PageShell/HeroShell); the whole pill is one <a>; href = tel:{phone_e164} (NEVER derived from phone_display); visible number goes through formatPhoneUS(phone_display) with a phone_e164 fallback; label = resolveCopy("home.call_bar_label"); returns null when phone_e164 is blank; not sticky/fixed; no hardcoded phone number anywhere in the component. **MOBILE PLACEMENT IS A HARD CHECK [FINAL 2026-07-27]:** the pill renders in the header bar at EVERY breakpoint. A `hidden md:` wrapper around it = FINDING. A `<CallNowBar>` inside the `{open && …}` mobile-menu dropdown = FINDING (built and rejected — it buries the highest-intent action behind a hamburger tap). `grep -c CallNowBar Header.tsx` must show exactly ONE render site. At 360px the logo mark + the FULL pill (label · visible divider · number) + hamburger fit on one row, ≥44px touch target, no wrapping.
G4c. iOS STATUS-BAR BAR: `styles.css` must set a DARK `html { background-color }` (matching the template's own dark tone, not a neutral black) with a corresponding `<meta name="theme-color">`, while `body` stays on `--color-background`. Without it iOS Safari paints the light page background behind the status bar and in the overscroll region, producing a white bar that is pinned to the top on mobile only and has NO element in the DOM to find. Also confirm `viewport-fit=cover` is absent unless `env(safe-area-inset-*)` padding exists — with it, a `top-0` header renders under the clock/battery. See `/template-builder` §8b.
G4b. HERO MOBILE FIT: at 360×640 and 390×844 the hero lead-form card must be FULLY visible — headline, CTA button and the card's submit button all on screen, nothing clipped. A hero that is `h-[100vh]` + `overflow-hidden` below `md` is a FINDING: it clips the stacked layout as soon as anything is added under the H1 (this is how the hero CTA button cut the bottom off the lead form). Expected: `min-h-[100vh]` with auto height below `md`, fixed `h-[100vh]` retained at `md`+, the inner grid's `h-full` relaxed on mobile, and a strip of hero image still visible BELOW the card.
G5b. Call-Now button CONTRAST: compare the pill's fill against EVERY background it renders over — the transparent/overlaid hero header and the solid interior header. If the pill's fill is within ~0.05 OKLCH lightness of any of those, it merges into the chrome and stops reading as a button = FINDING (the reference build shipped a pill byte-identical to the interior header bg). Prefer a brand-token fill + hairline border over a hardcoded color, and confirm the text color stays AA-legible against whatever fill the client's `brand_color` produces.
G6. Hero chat CTA: a real <button type="button"> directly under the homepage H1; label = resolveCopy("home.cta_button"); onClick dispatches the "open-chat-widget" CustomEvent; rendered ONLY when client.chat_widget_enabled !== false; does not submit or navigate; the H1 text and source are unchanged.
G5. Consent copy on all three = the verbatim marketing skeleton with {marketing_category}/{business_name} resolving (render in preview — no literal {token}); lead-form checkbox UNCHECKED + optional; Privacy/Terms links point to /privacy and /terms.
G6. Bot shield: challenge minted on mount via POST {host}/api/public/challenge with body { slug }; solved in a Web Worker (grep for new Worker / worker blob); token format challenge.sig.nonce; TTL refresh (~9 min); hidden "website" honeypot input positioned off-screen — NEVER display:none; fail-soft (simulate challenge failure → form still renders, page never crashes).
G7. Demo mode: all three forms no-op with a toast and no network POST (verify in preview with blank slug).
G8. The platform host everywhere = getPlatformHost() (VITE_PLATFORM_API_HOST → hardcoded app.pierceworks.co) — never the supabase origin, never a lovable.app origin, never window.location.

H. COMPLIANCE SURFACE (byte parity)
H1. Privacy = appendix §B ENTIRE (IMPORTANT NOTICE header + SMS section + SMS Data Protection Statement + all numbered sections); Terms = §A ENTIRE (SMS clauses 1–8 + TCPA/CTIA line + General Terms); SMS Program = §D ENTIRE. Spot-verify byte-parity on 3 random sentences per page against the imported a2p-site-compliance appendix, including straight ASCII quotes/apostrophes (search the rendered components for curly quotes “ ” ‘ ’ = zero hits).
H2. Rendered as JSX (grep compliance components for dangerouslySetInnerHTML = zero).
H3. All {tokens} resolve from template_vars in the preview — grep the rendered pages for a literal "{" token = zero.
H4. /review page: a working CTA to client.review_link and NOTHING that POSTs to /api/public/intake.

I. COPY SYSTEM
I1. default-copy.ts has EXACTLY the 10 slots (home.hero_sub, home.services_intro, services.index_intro, about.overview, about.approach, contact.intro, gallery.intro, discount.sub, home.call_bar_label, home.cta_button — the last two are LITERAL micro-copy defaults "Call Now" / "Chat with us now", NOT data-composed, and must not interpolate business_name/city/services); resolveCopy = content[slot] override → buildDefault, NO raw-display tier; grep pages for direct raw rendering of about_us/differentiators/tagline as body copy = zero (they may feed buildDefault only).
I2. buildDefault for the 3 SEO-critical slots names the trade + city in plain search language.
I3. hours render through the tolerant normalizer (array + legacy object shapes; absent day = "Closed"); temporarily set a demo day to a malformed value → renders "Closed", no crash (then revert).
I4. No invented facts anywhere in template copy: grep for "licensed", "insured", "certified", "award", "years of experience", "since 19", "since 20" in components = zero (such claims may only arrive via live data).

J. REPORT
Output: (1) the full A–I table with PASS/FIXED/FAIL + evidence; (2) the flag list (every FAIL needing a human decision, every improvised decision found); (3) every template_vars key read in code but missing from demo-client.ts, and every key in demo-client.ts the code never reads; (4) confirm type check passes after your fixes.
```

## PROMPT 2-V — visual-delta check (Lovable fallback, AFTER a PROMPT 1-V change; costs credits — the free default is Claude's delta audit in the runbook)

```
AUDIT the visual changes just made to this blessed template. Verifier role: PASS/FAIL + one line of evidence per item; fix only mechanical fails; FLAG anything needing a decision. 
1. SCOPE: list every file changed for this change-set. PASS only if all are presentational components/styles/assets — any wiring file (src/lib/*, route loaders/head logic, .env, package.json, form endpoints/payloads, robots/sitemap handlers, compliance text) = FAIL that file.
2. Type check passes; blank slug renders the FULL demo site with the changes.
3. Every copy slot (home.hero_sub, home.services_intro, services.index_intro, about.overview, about.approach, contact.intro, gallery.intro, discount.sub, home.call_bar_label, home.cta_button) still renders somewhere via resolveCopy, or is explicitly reported as an intentionally-orphaned slot. No slot text was hardcoded/reworded in code.
4. Purity: grep changed files for the demo business name/phone/niche words + any factual-claim literals (licensed/insured/award/years) = zero.
5. Data bindings intact in the changed sections: services still LOOP services_structured; phone visible = formatPhoneUS with tel: E.164; images still via SiteImage/imgUrl fallback chains (no hardcoded image URLs); hours via the normalizer.
6. If the lander changed: the published-home-row precedence (title/H1/body) still wins over fallback copy; the hero lead-form card still fits the hero viewport at 1366×768; the maps embed still renders when address is set.
7. Forms still no-op with the demo toast on blank slug; footer compliance links present on every page; nav/page labels within allowed_display_labels.
REPORT: table 1–7, files-changed list, orphaned/new slots or template_vars keys, anything a guardrail blocked.
```

## PART C — external probe (Claude/human, AFTER publish — not part of the Lovable prompt)

1. Publish; GitHub-connect. Claude clones and re-greps A/B/C-class checks from the raw repo (Lovable self-reports can be wrong).
2. `curl` the published preview: `<meta name="robots">` = `noindex,follow` on every route; `/robots.txt` = `Disallow: /` + absolute Sitemap on the preview origin; `/sitemap.xml` locs on the preview origin; `<title>` shows the DEMO business (SSR head sanity, no template-domain canonicals... the canonical will show the last-resort constant while noindexed — acceptable by design).
3. `OPTIONS {app host}/api/public/intake` preflight from a test Origin → 204; challenge POST with `{slug}` returns a signed challenge.
4. Set `VITE_CLIENT_SLUG` to a real test client + add the preview origin to that client's `allowed_origins` → live data renders (name/phone/services/hours), one PoW lead E2E lands a contact (then delete it), then blank the slug + remove the origin.
5. Only then: bless for remixing; tag/CHANGELOG the version.
