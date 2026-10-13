# Link previews (Open Graph / Twitter) — findings and implementation

How shareable pages unfurl into rich cards on social/messaging platforms, and the research
that shaped the design (2026-07). The short invariants live in
[CLAUDE.md](../CLAUDE.md#link-previews-open-graph--twitter); this file explains the *why*.

This builds directly on SSR — read [SSR.md](SSR.md) first. Link previews only work because
the tags are in the **server-rendered initial HTML**; a client-injected tag is invisible to
every unfurl crawler.

## Architecture in one paragraph

Each public route may declare an optional `meta(ctx)` builder in `routes.config.ts`.
`RouteGenerator` attaches it to the route's `handle`. During SSR, `entry-server.tsx` runs
the route's `prefetch` (populating the per-request `QueryClient`), then calls the matched
leaf's `meta()` — which only **reads** the cache the prefetch just filled, so it costs zero
extra fetches. The returned `RouteMeta` is serialised by `src/lib/seo.ts` (`buildMetaTags`)
into an HTML `<head>` string and returned as `head` alongside `html`/`dehydratedState`.
`server.js` injects it at the `<!--ssr-head-->` placeholder (early in `<head>`) and strips
the static fallback `<title>` so exactly one, dynamic title survives. Client-side navigation
deliberately does **not** update these tags — crawlers don't run JS, and real users get the
tab title from `Layout`.

```
routes.config.ts  meta: rideMeta          ← declare per route
        │
RouteGenerator    handle = { meta }        ← carried on the matched RouteObject
        │
entry-server.tsx  prefetch() → meta(ctx) → buildMetaTags() → { head }
        │
server.js         index.html <!--ssr-head--> ← injected; static <title> stripped
        │
crawler           reads OG/Twitter tags from raw HTML (no JS)
```

## Key files

| File | Role |
|---|---|
| `src/lib/seo.ts` | The engine: `RouteMeta`/`RouteMetaContext` types, `buildMetaTags`, HTML escaping, word-boundary `truncate`, server-safe `stripMarkdown`, imgproxy URL resolution, accurate image-dimension math, `defaultImage`. No page-specific logic. |
| `src/config/routeMeta.ts` | The per-route `meta()` builders (one per resource). Only read the per-request cache; never throw; return `undefined` to fall back to site defaults. |
| `src/config/routes.config.ts` | Wires `meta: xxxMeta` onto each public route (+ a `prefetch` for anything the builder reads). |
| `src/config/RouteGenerator.tsx` | Copies `config.meta` onto each emitted `RouteObject.handle`. |
| `src/entry-server.tsx` | Builds `RouteMetaContext`, invokes the leaf's `meta()`, returns `head`. |
| `server.js` | Injects `head` at `<!--ssr-head-->`; strips the fallback `<title>`. |
| `index.html` | Holds the `<!--ssr-head-->` placeholder + a static fallback `<title>` (JS-less dev SPA only). |
| `public/og-image.png` | Site-wide default card (1200×630). Built from `assets/icon.svg` — see "The default image". |

## Page coverage

Rich previews are emitted only for **public, canonical, shareable** resources. Auth-gated,
admin, edit, and transient utility routes carry no `meta` and unfurl with site-wide defaults.

| Page | `og:type` | Image (first available wins) |
|---|---|---|
| home / teams list / apps (`/applications`) | `website` | default |
| team detail / about | `website` | team logo → first team image → default |
| team page | `article` | page image → team logo → default |
| post | `article` | first post image → team logo → default |
| ride | `article` | route map thumbnail → post image → team logo → default |
| ride group | `article` | the ride's chain (« Groupe X · <sortie> », departure, pace, distance; a group gone falls back to the ride's preview) |
| trip | `article` | trip map thumbnail → trip image → team logo → default |
| stage | `article` | stage route thumbnail → stage image → trip thumbnail → default |
| route / route map (carte) | `website` | route map thumbnail → team logo → default |
| gpx tools preview | `website` | rendered map thumbnail → default (dynamic stats in title/description) |

**Ads carry no preview**, deliberately: the ad API is `@RolesAllowed("user")` and `ads`/`ad-detail`
are `auth: 'authenticated'`, so an anonymous crawler's prefetch answers 401 and there would be
nothing in the cache for a builder to read. An `adMeta` builder existed until it was removed for
exactly that reason — don't reinstate one without opening the endpoint first.

## Findings that shaped the design (2026)

1. **No unfurl crawler runs JavaScript.** facebookexternalhit, Twitterbot, LinkedInBot,
   Slackbot, Discordbot, WhatsApp, TelegramBot, Bluesky Cardyb, Mastodon, Signal — all read
   raw HTML. Only Googlebot/Applebot render, and neither is the preview path. ⇒ tags **must**
   be server-rendered. This is the whole reason the feature lives in the SSR path.

2. **Open Graph is still the one standard**; platforms do not read JSON-LD for previews. We
   emit the 4 required tags + `og:description`, `og:site_name`, `og:locale`(+`:alternate`),
   `og:image:width/height/alt`, `article:*`/`product:*` where relevant.

3. **X renders image-only.** Setting just `twitter:card=summary_large_image` is enough — X
   falls back to OG for everything else, and commonly shows only the image with the domain
   overlaid. Consequence for us: the image should carry meaning on its own (route map, photo).

4. **One image size fits all: 1200×630, PNG/JPEG, absolute HTTPS, < ~300 KB.** WhatsApp's
   ~300 KB ceiling is the binding constraint; WebP breaks Slack/Signal; AVIF is unsupported;
   animated GIF never animates. The default card is a 70 KB PNG.

5. **Tags must be early in `<head>`.** Slack reads only ~32 KB; WhatsApp needs `<head>` in
   the first ~300 KB. The `<!--ssr-head-->` placeholder sits at the top of `<head>`.

6. **imgproxy already runs** in this stack — the natural way to produce 1200-fit card images
   from existing photos/map thumbnails without a new render service.

## Invariants — keep these when touching link-preview code

- **`meta()` builders only READ the cache and never throw.** They run after `prefetch`; a missing
  entity, or a private one the visitor's session doesn't grant — crawlers and other anonymous SSR
  renders included — returns `undefined` and `buildMetaTags` emits site-wide defaults.
  `entry-server` wraps the call in try/catch as a backstop, but a throwing builder is a bug.
- **Anything a builder reads must be `prefetch`ed on the same route.** No extra fetches in
  `meta()`; if the data isn't in the QueryClient, the card silently degrades to defaults.
- **Never add a `<meta>`/`<title>` React component to the tree.** React 19 would hoist it,
  shifting Mantine `useId` across the server/client boundary (see SSR.md) and duplicating the
  title. All preview tags are string-built in `seo.ts` and injected outside React.
- **Absolute, per-domain URLs.** `og:url`/`og:image` are built from the request `origin`
  (reconstructed from `X-Forwarded-Proto`/`-Host`) so each tenant domain gets correct links.
- **Declare `og:image:width/height` only when accurate.** `seo.ts` scales the source asset's
  real pixel dimensions through imgproxy's `rs:fit` box; template-only image URLs (no source
  dims) omit width/height rather than guess. (The reference project shipped 1200×600 tags for
  a 768×512 image — do not repeat that.)
- **One robots tag per page, and it comes from `seo.ts`.** `index.html` carries none;
  `buildMetaTags` always emits `<meta name="robots">`, `noindex` when `RouteMeta.noindex` is set.
  Builders set it from the content's `visibility`, and `withIndexing` (`routeMeta.ts`, applied by
  `entry-server`) adds it for every page of a team that is not `PUBLIC`: `PUBLIC_UNLISTED` is
  shareable, not indexed (ledger `WEB-4`, `src/config/routeMeta.test.ts`). Never put a static
  robots tag back in `index.html`: it would sit beside the per-page one and contradict it.
- **Respect the resolved SSR locale**, not the browser. Dates, numbers, and `og:locale` use
  `ctx.locale`/`ctx.t` from the per-request i18next instance.

## The default image (`public/og-image.png`)

1200×630, built from the master brand mark `assets/icon.svg` — the full "P"-as-bicycle
(fork + crank + pedal + **handlebar bowl**) on a white tile over the brand-blue gradient,
with the "Pédalons" wordmark. It is regenerated by compositing all four orange paths from
`icon.svg` into an SVG and rasterising with `rsvg-convert -w 1200 -h 630`. Keep it PNG and
under ~300 KB. If you tweak wording/spacing, edit the SVG and re-rasterise — do not hand-crop
the icon (an earlier version dropped the handlebar loop and left only the diagonal fork).

## Testing / debugging

- **Local proof (the check that actually catches regressions):** build and run the prod SSR
  server, then grep the raw HTML — crawlers see exactly this.
  ```bash
  pnpm build && NODE_ENV=production PORT=3123 node server.js &
  curl -s http://localhost:3123/ | grep -iE '<title>|og:|twitter:'
  # expect: exactly one <title>, absolute og:url/og:image, correct og:locale
  ```
  With the backend down, entity fetches fail and pages correctly fall back to defaults —
  a useful test of the degradation path.
- **Platform validators (2026):** Facebook Sharing Debugger and LinkedIn Post Inspector work
  and are the only reliable cache-busters (each caches ~7 days). The X card validator is
  retired — preview in the composer. Bluesky bakes the card at first share and can't be
  refreshed. Generic scrapers (opengraph.xyz, metatags.io) show what a crawler *would* see
  but clear no platform cache.
