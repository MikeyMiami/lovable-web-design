# Template Claude-Audit Runbook (v1, 2026-07-27)

> **Who runs this: Claude, in Claude Code — NOT Lovable.** This is Route A of template validation (zero Lovable credits): the complete acceptance audit of a finished template, executed against the GitHub repo + the published preview. It is the executable twin of `docs/template-build-check-prompt.md` (A–J) plus the external probe. Findings go back to Lovable as ONE consolidated fix prompt authored by Claude.
>
> **Inputs Claude needs from the operator:** the repo (GitHub-connected project) · the published preview origin (`https://<project>.lovable.app`) · the DEMO BUSINESS NAME + DEMO NICHE used in the build · scratch or restyle build (if restyle: the PREVIOUS demo niche/name, and the parent template repo for the diff).

## 0. Setup
- `git clone` (or fetch) the repo; audit `origin/main`, never a stale working tree.
- **Restyle builds first:** `git diff <parent-tag-or-first-commit>..origin/main --stat` — the changed-file set must be styles / presentational components / demo-client / niche-default assets (+ explicitly flagged exceptions). Any diff touching `src/lib/client-data|content-pages|site-url|img|bot-shield|phone|hours|default-copy`, route loaders/head logic, or `.env`/`package.json` beyond the spec = finding.
- File inventory: `git ls-tree -r --name-only origin/main` — compare `src/routes/` against the locked list in section D.

## A. Project hygiene
- `.env` = exactly 5 lines: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_PLATFORM_API_HOST=https://app.pierceworks.co`, `VITE_CLIENT_SLUG=` (empty), `VITE_SITE_URL=` (empty + the warning comment). Extra/missing/repurposed lines = finding (the API-host-overwrite mistake is real — happened 2026-07-27).
- `package.json` → `overrides.seroval` present (`^1.5.2`+).
- Filename ban: any path matching `*.client.*` = finding (SSR strips → publish crash).
- `grep -rn "@tanstack/react-start/server" src/` → hits ONLY inside route files using `server: { handlers:` (robots/sitemap pattern). Anything in `src/lib/**` = finding (build-breaker).
- `grep -rin "turnstile" src/` = zero. `grep -rin "service_role" src/` = zero. No `supabase/` backend dir, no migrations, no auth code.

## B. Connection resilience (remix-survival)
- BOTH `src/lib/client-data.tsx` AND `src/lib/content-pages.ts` carry non-empty hardcoded fallbacks: `|| "https://onbhnkylzadyldpziapo.supabase.co"`, an `|| "eyJ…"` anon key, and `|| "https://app.pierceworks.co"`. Either file missing any of the three = finding (content-pages missing them shipped as a real bug once).
- `grep -rn "export const SITE_URL" src/` = zero. `src/lib/site-url.ts`: resolveSiteUrl = env → `window.location.origin` → constant; `isIndexableOrigin` false when `VITE_SITE_URL` unset OR host ends `.lovable.app`.
- RPC wiring exact: `get_client_public` with `{ _slug }`; `get_client_pages` `{ _slug }`; `get_client_page` `{ _slug, _page_slug }`; failure paths return demoClient (grep the catch/`?? demoClient` paths).
- `getClientCached` exists (~60_000 TTL) and route `head()`s consume loader data from it. `grep -rn "demo-client" src/routes/` = zero imports.

## C. Data-driven purity
- `grep -rn "<DEMO BUSINESS NAME>" src/ --exclude=demo-client.ts` = zero (case-sensitive). Same for the demo phone digits, street, email, and the DEMO NICHE word (case-sensitive proper-noun greps; beware legitimate lowercase collisions — the "evergreen the plant vs Evergreen the business" false-alarm).
- Restyle builds: repeat for the PREVIOUS demo business name + niche = zero everywhere including meta/alt/schema.
- `index.tsx`: title fallback chain present (`{segment} in {area} | {business}` → segment → name; no "Welcome"/"Home" literal).

## D. Route registry + page-type layering ⭐ (highest-weight section — the cross-system contract)
- Exact route files: `__root.tsx, index.tsx, about.tsx, services.index.tsx, services.$slug.tsx, locations.tsx, service-area.$slug.tsx, $slug.tsx, gallery.tsx, contact.tsx, get-your-discount.tsx, review.index.tsx, review.$token.tsx, thank-you.tsx, terms.tsx, privacy.tsx, sms-program.tsx, robots[.]txt.tsx, sitemap[.]xml.tsx`. Missing/renamed/extra public routes = finding.
- Type bindings (read each loader): `services.$slug` → notFound unless `type === "category" || "service"`; `service-area.$slug` → geo only; `$slug` → supporting only. A renderer accepting a wrong type = CRITICAL (breaks the AI-writer link vocabulary for every client).
- `review.$token` → immediate redirect, target literally `https://reviewbatch.com/api/public/r/` + token; no UI.
- `locations.tsx` links `/service-area/{slug}` for published geo rows; empty-state present.
- Discount unlinked: `grep -rn "get-your-discount" src/` → hits only its own route file (+ the form). Header/Footer/sitemap = zero.
- Labels: read Header/Footer nav labels → each ∈ its page's `allowed_display_labels` (website-structure registry); compliance labels exact.

## E. SEO / head / indexability
- `robots[.]txt.tsx`: server handler, origin from `new URL(request.url).origin`, Allow only when indexable, absolute `Sitemap:` line; no `public/robots.txt` file exists.
- `sitemap[.]xml.tsx`: request-origin; statics = `/, /services, /locations, /about, /contact, /gallery`; published+index-robots content pages mapped home→`/`, category|service→`/services/`, geo→`/service-area/`, supporting→`/{slug}`; discount/thank-you/review/compliance absent.
- `pageHeadMeta`: forces `noindex,follow` when `!isIndexableOrigin` (a stored index,follow must not win).
- One layout-owned h1; duplicate-leading-h1/h2 strip present. JSON-LD builders use resolved siteUrl; telephone E.164. Maps embed gated on non-blank address. og:image = original object URL (`grep "render/image"` inside og/meta builders = zero).

## F. Image pipeline
- `img.ts`: object→render swap; non-Supabase passthrough (imgUrl) and `""` (srcSet); naturalWidth cap with single-capped-candidate behavior.
- `SiteImage`: omits srcSet+sizes when `""`; priority→eager+fetchPriority; decoding async; width/height emitted; focal→objectPosition.
- ContentPageView: `h-[52vh] min-h-[380px]` hero box; `aspect-[16/9] overflow-hidden` figures + onError-hide; hero widths 640–2048 `sizes="100vw"` eager; inline 480–1024 lazy.
- site_slots chains verbatim (about g[1]→g[0]→work_examples[1]→defaults; team→staff→names; gallery→galleryUrls→work_examples→defaults); lander hero NOT from site_slots.
- `grep -rn "<img" src/ | grep -v SiteImage | grep -v Logo` → remaining raw imgs justified (logo/icons only).

## G. Forms + bot shield
- Payload keys byte-exact per form (intake: `first_name,last_name?,phone_e164,email?,notes?,website,pow_token`; discount adds `your_message?,consent`; chat/optin: `consent: true` path). `grep client_id|source` in POST bodies = zero.
- Phone: required, `^\+[1-9]\d{6,14}$` client-side, label "Mobile phone". Lead consent checkbox: unchecked, optional, NOT in payload. Discount/chat consent: required, gates submit.
- Shield: challenge POST includes `{ slug }` body; Worker-solved; `challenge.sig.nonce`; TTL refresh; honeypot `website` positioned off-screen (`grep "display:none"` near it = zero); fail-soft (no throw path reaches render); demo-mode no-op toast, zero network.
- All hosts via `getPlatformHost()`; `grep -rn "supabase.co/api/public"` = zero.

## H. Compliance byte-parity
- Extract text from the three compliance components (strip JSX) and diff against `docs/a2p-compliance-copy-source-of-truth.md` §A/§B/§D: whole-document presence (section headers, numbered clauses, TCPA/CTIA line), spot-diff ≥3 sentences per page verbatim.
- `grep -n "[""'']" src/components/compliance/` = zero curly quotes. `grep dangerouslySetInnerHTML` in compliance = zero. Token audit: every `{token}` used has a template_vars source; none can render literally.
- `/review` page: CTA to `client.review_link`; zero intake POST.

## I. Copy system
- `default-copy.ts`: exactly the 8 slots; resolver = content-override → buildDefault, no raw tier. `grep -rn "about_us" src/routes/ src/components/site/` → only as buildDefault INPUT, never rendered raw.
- Hours render through the tolerant normalizer everywhere hours appear. `grep -rin "licensed|insured|certified|award|years of experience|since 19|since 20" src/components src/routes --exclude-dir=compliance` = zero invented-claim literals (compliance pages legitimately contain some terms — excluded).

## J. External probe (published preview, curl)
- `GET /` → 200; SSR `<title>` carries the DEMO business name; `<meta name="robots">` = `noindex,follow`; canonical present (last-resort constant acceptable while noindexed).
- `GET /robots.txt` → `Disallow: /` + absolute `Sitemap: {preview-origin}/sitemap.xml`. `GET /sitemap.xml` → 200, locs on the preview origin, statics present, no discount/thank-you.
- `GET /review/faketoken` (no redirect-follow) → 302 `Location: https://reviewbatch.com/api/public/r/faketoken`.
- `GET /about`, `/gallery`, `/contact`, `/services`, `/locations`, `/privacy`, `/terms`, `/sms-program` → all 200, demo-rendered, compliance text present in SSR HTML.
- Platform endpoints (from any origin): `POST https://app.pierceworks.co/api/public/challenge` with `{"slug":"<any-active-slug>"}` → signed challenge JSON. (Full PoW lead E2E only in the optional live-slug smoke below.)
- **Optional live-slug smoke (needs operator):** set `VITE_CLIENT_SLUG` to a test client + add the preview origin to that client's allowed_origins + republish → live data renders; Claude solves PoW server-side and lands ONE lead from that Origin → verify contact + enrollment created → DELETE the contact → blank slug + remove origin + republish.

## Delta audit — post-blessing design changes (PROMPT 1-V) or any small template edit
Full A–J is overkill for a targeted change. Instead:
1. `git diff <last-blessed-tag>..origin/main --stat` → the touched-file set must match the change request (+ flagged exceptions). ANY hit on wiring modules, route loaders/head logic, `.env`, `package.json`, form wiring, or compliance components = escalate to the relevant full section.
2. Re-run ONLY the sections owning the touched surfaces (lander touched → C4/E-head/G1-hero-fit + curl `/`; about touched → I1/F4 + curl `/about`; any form surface → G; any image surface → F).
3. Always re-run regardless of scope (cheap + high-value): the demo-purity greps (C), the copy-slot render-or-flagged check (I1), type-check evidence, and a curl of `/` + every changed page on the preview (SSR renders, robots still noindex on preview, no literal `{token}`).
4. Verdict + re-tag/CHANGELOG. Existing clients unchanged until re-remix (snapshot rule) — note in the report which live remixes now diverge from the master.

## Verdict + report
- Output the A–J table (PASS/FAIL + evidence path:line), findings ranked CRITICAL (breaks clients/contracts) → HIGH (breaks this template) → NIT.
- Author ONE consolidated Lovable fix prompt for all fixable findings (file-anchored, same style as this project's fix prompts). Re-audit the diff after it lands.
- Remind the operator of the single human-eyes check: hero lead-form card fits the hero viewport at 1366×768.
- **Bless criteria:** A–J all-PASS + external probe clean + hero-fit confirmed → tag/CHANGELOG, freeze, template may be remixed for clients.
