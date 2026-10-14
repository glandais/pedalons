# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

See also the root `../CLAUDE.md` for full-stack context (backend, mobile, karoo, garmin, multi-tenancy, contract-first workflow).

## Commands

```bash
pnpm dev                           # SPA dev server (localhost:5173, proxies /api to $VITE_API_TARGET,
                                    # default https://staging.pedalons.fr — set VITE_API_TARGET=http://localhost:8080
                                    # in frontend/.env for a local backend)
pnpm dev:ssr                       # SSR dev server (node server.js, localhost:3000, Vite middleware mode)
                                    # proxies /api to $API_BASE_URL (default localhost:8080) — if no
                                    # local backend is running, start it with
                                    # API_BASE_URL=https://staging.pedalons.fr pnpm dev:ssr
pnpm build                         # Dual build: dist/client (browser) + dist/server (entry-server.js), no type checking
pnpm typecheck                     # tsc -b — TypeScript 7's native compiler (typescript-go)
pnpm generate-api                  # Regenerate API client from ../contracts/openapi.json
pnpm generate-routes               # Regenerate path builders + deeplinks from ../contracts/routes.yaml
pnpm generate-brand-colors         # Regenerate src/lib/badgeColors.generated.ts (+ mobile) from ../contracts/brand-colors.yaml
pnpm lint                          # oxlint (includes i18next/no-literal-string via jsPlugins)
pnpm lint:fix                      # oxlint with auto-fix
pnpm format                        # i18next-cli extract (sorts the catalogues, scaffolds new keys) + Prettier
pnpm test                          # Vitest (watch mode)
pnpm e2e                           # Playwright against the e2e stack (scripts/e2e.sh up first) — see e2e/README.md
pnpm i18n:check                    # extract --ci (sorted, nothing missing) + i18n:lint + i18n:status — in CI and `pnpm check`
pnpm i18n:lint                     # Interpolation params of each t() call vs the French string (+ hardcoded strings)
pnpm i18n:status                   # English vs French, key by key
```

## Stack

TypeScript 7 (native `tsgo` compiler, via the `typescript` package), React 19, Vite, Mantine UI 9, React Router 7, TanStack React Query 5, Zustand 5, Zod 4, Orval (API codegen), i18next, MapLibre GL, Tiptap (rich text), Chart.js, `@mantine/schedule` (calendar).

## Architecture

```
src/
├── api/              # Generated from Orval (pnpm generate-api)
│   ├── dto/          # Generated DTOs
│   ├── endpoints/    # Generated API functions
│   └── zod/          # Generated Zod schemas
├── components/       # By domain (common/, team/, ride/, route/, post/, trip/, etc.)
├── config/           # paths.ts (re-export), paths.generated.ts, locale-context.ts, routes.config.ts, appConfig.ts
├── hooks/            # React Query wrappers
├── lib/              # axiosInstance.ts, apiUtils.ts
├── locales/{en,fr}/  # i18n (French default)
├── pages/            # Route-level components
├── store/            # Zustand stores
├── types/            # TypeScript type definitions
└── utils/            # Utility functions
```

### API Layer (generated — do not edit `src/api/`)

Orval generates from `../contracts/openapi.json`:
- `src/api/endpoints/` — React Query hooks per OpenAPI tag (`useGetRide`, `useCreateRide`, etc.)
- `src/api/dto/` — TypeScript types
- `src/api/zod/` — Zod schemas for form validation

Custom axios mutator in `lib/axiosInstance.ts` handles: JWT bearer tokens from authStore, `Accept-Language` header, 401 token refresh with request queuing, error notifications via Mantine.

### Routing (config-driven)

- Routes declared in `config/routes.config.ts` with metadata (auth requirements, breadcrumbs, `parentId` hierarchy, `subRouteIds` for tab nav)
- Each config entry carries `paths: Record<Locale, string>` from `pathVariants.xxx()` — all locale variants
- `RouteGenerator.tsx` emits one `<Route>` per unique variant, so any language of a URL matches the same page
- `routeUtils.findMatchingRoute` iterates all variants; `routeUtils.buildRoutePath` resolves against the current locale for breadcrumb links
- Auth guards: `<AuthenticatedRoute>`, `<UnauthenticatedRoute>`, or public
- Breadcrumbs auto-built from `parentId` chain

### State Management

- **Server state**: React Query (generated hooks from Orval)
- **Global client state**: Zustand — only `authStore` (JWT, user), `preferencesStore` (unit system, persisted to localStorage) and `mapStyleStore` (remembered basemap, terrain and hillshade toggles, localStorage)
- **List page filters/search/pagination**: the query string, via `useUrlFilters` — never `useState`. See [docs/URL_FILTERS.md](docs/URL_FILTERS.md).
- Auth initializes by calling `/api/auth/refresh` on mount; `useAuth` hook fetches `/api/users/me`

### Path Management

`config/paths.ts` re-exports from `config/paths.generated.ts` (generated by `scripts/generate-routes.mjs` from `contracts/routes.yaml`). Two APIs:

- `paths.xxx(...)` — returns the URL in the current locale (reads `i18next.language` via `locale-context.ts`). Use for navigation, share links, `<Link to={paths.ride(...)}>`.
- `pathVariants.xxx(...)` — returns `Record<Locale, string>` with every locale variant. Use in `routes.config.ts` to register all variants in React Router.

`routes.yaml` is the source of truth — never edit `paths.generated.ts` by hand. After editing YAML, run `pnpm generate-routes`.

### i18n

- i18next with browser language detection. **French is the default/fallback language.**
- **The SSR server picks the language**, in order: the signed-in user's `language` preference, the `lang` cookie (written by `LanguageSwitcher` via `persistLanguageChoice`), then `Accept-Language`. The client only follows `<html lang>` and caches nothing from detection — so an explicit choice must go through `persistLanguageChoice`, never localStorage, or it is lost on reload (a client-side override would mismatch the hydration).
- Single `common` namespace per language: `locales/fr/common.json`, `locales/en/common.json`
- **Keys are stored FLAT with dots** — `"map.tooltip.climb": "…"`, *not* nested `{ "map": { "tooltip": … } }` objects (`keySeparator: false`, in i18next-cli's config and in the types). Adding a nested object is a silent trap — it "works" but breaks the file's convention, and `catalogues.test.ts` rejects it.
- **The catalogues are sorted** by i18next-cli (alphabetically, plural forms in CLDR order). Add a key anywhere and run `pnpm format` (or `./format.sh frontend`), which sorts it into place; `pnpm i18n:check` fails on an unsorted file.

**What checks what** — every check below runs in CI:

| Check | Catches |
|---|---|
| `pnpm typecheck` (`src/i18n/i18next.d.ts`, ledger `WEB-73`) | A `t()` key absent from `fr/common.json` — literal, or built from a typed value |
| `src/i18n/catalogues.test.ts` | A key in French but not English (or the reverse); a plural missing a form of its language or carrying one it lacks; a `___MISSING_TRANSLATION___` left in; a non-string value |
| `pnpm i18n:check` | An unsorted catalogue or a key used in code but absent (`extract --ci`); a `t()` call whose params don't match the French string (`lint`); English behind French (`status`) |
| `pnpm lint` (oxlint `i18next/no-literal-string`, a **warning**) | Hardcoded user-facing JSX text |

**Rules:**

- **Never let a key travel as a `string`.** A key held in a variable, a field or a config is a `TranslationKey` (`src/lib/i18nUtils.ts`) — `tRegister(key)` marks and types one stored for later (route config, nav items). An API error code is an `ErrorCode`, so a backend code without a translation breaks the typecheck. Never cast a key (`as Parameters<typeof t>[0]`, `as any`) to get past the typecheck: add the key.
- **A key built from a value interpolates a typed value** — `` t(`status.${dto.status}`) ``, `` t(`notifications.typeLabel.${type}`) ``: the typecheck checks every member of the union, Orval enums included, and fails on the one without a key. `satisfies` adds nothing to that check; `.toLowerCase() as Lowercase<X>` keeps it.
- **`defaultValue` switches the check off** for that call (any string key is accepted): use it only for a real fallback to an existing key (`errors.api.<code>` then a generic message), never to silence the typecheck. Never build a key from an Orval enum when only some values have it: i18next-cli ≥ 1.75 expands the whole enum and `pnpm format` would write every missing key — list the few values in a typed table instead (`AUTH_ERROR_KEYS` in `LoginForm`, ledger `WEB-84`).
- **Add every key to both files**, translated. `pnpm format` scaffolds a key used in code but absent with `___MISSING_TRANSLATION___` — that value satisfies the typecheck, and only `catalogues.test.ts` (and `i18n:status`) catches it: replace it before committing.
- **Plurals**: `_one`/`_other` suffixes + a `count` param, **and `_many` in French** (`Intl.PluralRules('fr')` puts a million there; same text as `_other`). `_zero` is optional (i18next reads it for 0 in any language). English has no `_many`. **`count` is reserved for plurals**: i18next looks for `key_one`/`key_other` as soon as `count` is passed, so a plain counter takes another name (`{{length}} / {{max}}`, `{{index}} sur {{total}}`).
- **Interpolation**: `{{var}}` placeholders passed as `t('key', { var })`. Every param a call passes must appear in the French string, and every placeholder be passed (`i18n:lint`). Where languages need different words, compute one value that fits all of them rather than passing one param per language: the zone mention passes `ofCity` (« de Tokyo » in French, « Tokyo » in English, `zoneCityOf`), never `city` plus `ofCity`.
- **A helper that translates takes a `TFunction`** (from `i18next`), not a hand-written `(key: string) => string`; its test reads a real instance (`await createServerI18n('fr')`), not a stub mimicking interpolation.
- **Never remove a key on i18next-cli's say-so**: it resolves keys built from an Orval enum since 1.75, but not every built key, which is why `removeUnusedKeys` is `false` (ledger `WEB-62`). A key is dead when no literal *and* no built key (`` `prefix.${…}` ``) can produce it — then delete it from both files.
- oxlint's `i18next/no-literal-string` is a warning: prefer `t()` even where lint wouldn't block.

### List and detail page shells

Three components carry the state hierarchy across every list and detail page. Use them rather than
re-deriving loading/error/empty branches inline:

- **`QueryStateBoundary`** — loading, *recoverable* error, and empty, in one place. A detail page
  distinguishes **404 from error**: a missing entity is not a failure to retry.
- **`EmptyState`** — the single empty-state component. It distinguishes **absolute empty** ("this
  team has no rides") from **filtered empty** ("no ride matches these filters"), and the filtered
  variant must offer a way out — a dead-end empty state with no action is the defect it exists to
  prevent.
- **`ResultCount`** — the total at the head of a list, from the API's `total`, never
  `items.length`.
- **`ErrorBoundary`** per section, so one failing block doesn't blank the page.

Lists request `view=COMPACT` where they only need `excerpt` + `thumbnailUrl`; in that mode
`media.markdown` comes back `""` and `media.assets` shrinks — present but empty, never absent.

### Forms

- Mantine `useForm` + Zod validation via `zodFormValidator` wrapper using generated Zod schemas
- Pattern: `XxxForm` reusable component (with `create` prop) + separate `CreateXxxPage`/`EditXxxPage` pages
- Submit via generated React Query mutation hooks → invalidate queries → show notification → navigate

### Build

- Path alias: `@/` → `src/`
- Manual chunk splitting in `vite.config.ts` (map-vendor, editor-vendor, mantine-vendor, etc.)
- Dev proxy: `/api` → `VITE_API_TARGET` (default `https://staging.pedalons.fr`), with `X-Forwarded-Host` forced to the target's host so `DomainResolver` finds its tenant
- **Dual build output**: `pnpm build` runs Vite twice — client bundle → `dist/client/` (with `index.html` containing `<!--ssr-outlet-->` / `<!--ssr-state-->` placeholders), SSR bundle → `dist/server/entry-server.js`. The Docker runtime image runs `node server.js` (Express) and serves both. There is no separate nginx step.
- **MapLibre worker**: `src/components/map/setupMaplibreWorker.ts` calls `setWorkerUrl()` with a `maplibre-gl/dist/maplibre-gl-worker.mjs?worker&url` import, and every component that constructs a `Map` imports it for its side effect. maplibre-gl otherwise resolves its worker via `new URL('./maplibre-gl-worker.mjs', import.meta.url)` *inside its own bundled module* — a dynamic expression Rollup can't trace, and one that points at the wrong place once bundled into `map-vendor` anyway. `?worker&url` is Vite's documented fix: it bundles the worker (and the sibling `maplibre-gl-shared.mjs` it imports) into one self-contained chunk. Don't reach for `optimizeDeps.exclude` or a manual copy-the-worker-file plugin instead — both were tried and failed (dev-only fix, or a 404 on the untracked sibling file).

### SSR (server-side rendering)

`server.js` (Express) renders public pages on the server via the static prerender API (`react-dom/static`, NOT `renderToString` — lazy route pages would render as their Suspense fallback) and hydrates on the client. Entry points: `src/entry-server.tsx` (`render(url, headers)`) and `src/entry-client.tsx` (hydrate). React Router runs in **library mode** (`createStaticHandler`/`createStaticRouter`, not framework mode); Vite uses `ssrLoadModule` in dev (no Environment API).

The SSR check is `e2e/routes-render.e2e.ts`, nightly on the e2e stack: every web route, six roles, failing on a hydration error, an uncaught page error or a prefetch gap (`pnpm e2e routes-render -g '<routeId> /'` re-checks one route, see [e2e/README.md](e2e/README.md)). Open or deliberately accepted SSR defects are ledger entries (`docs/LEDGER_NEXT.md`, `WEB` prefix) — check there before reporting one.

**Before changing SSR-reachable code, read [docs/SSR.md](docs/SSR.md)** — it documents the architecture and the non-obvious failure modes (lazy pages vs renderToString, silent Suspense-swallowed crashes, useId tree parity via `AppProviders`/`AppFrame`, localStorage-derived render state, and the curl checks that actually catch regressions).

**Before adding or editing a route's `prefetch`, read [docs/SSR-data-loading.md](docs/SSR-data-loading.md)** — a screen's data is declared once, in a companion module next to the page (`pages/ride/rideDetailData.ts`, `pages/route/routeListData.ts`), read as hooks by the page and as a `Promise.all` by `routes.config.ts`. Describing it twice doesn't break anything visibly: it just yields a different query key, so the client refetches after hydration and only the prefetch audit notices — `e2e/routes-render.e2e.ts` fails on it.

Hard invariants — keep these when touching SSR-reachable code:

- **Session-aware, but nothing shared between requests**: a document request carrying a `refresh_token` cookie is rendered as that visitor (one `POST /api/auth/refresh`, then `Authorization: Bearer` on every prefetch — the raw cookie is never relayed). The session lives *only* in `SsrRequestStore.auth`; `useAuthStore.setState()` throws on the server because the Zustand store is a module singleton shared by all concurrent renders. Reading auth server-side goes through `getSSRAuth()`.
- **The rendered HTML is per-visitor**: `Cache-Control: no-store` + `Vary: Cookie`, and it embeds a 15-minute access token. Never introduce HTML caching. Failure to resolve a session is non-fatal and renders the page anonymously, byte-identical to before.
- **Per-request isolation**: per-request `QueryClient`, per-request i18next instance (`createServerI18n`), request data threaded via `AsyncLocalStorage` (`lib/requestContext`). No module-level mutable per-request state reachable during SSR — `scripts/ssr-session-isolation.mjs` is the check that this still holds.
- **No module-top-level browser globals** in code eagerly imported by `entry-server` (config/, lib/, i18n/, stores, Layout). Guard any `window`/`document`/`localStorage`/`navigator` at module scope with `typeof window === 'undefined'`. Inside functions/hooks/effects is fine (runs client-side only). Lazy chunks (maps/GPX) are only a concern if a public prefetched route imports them.

### Installable site (PWA) and web push

- **`public/sw.js` caches nothing and has no `fetch` handler — keep it that way.** The SSR HTML is per-visitor and embeds an access token; a caching worker would serve one member's page to the next. It only makes the site installable and shows web push notifications. `server.js` serves it `no-cache` on its own route (`express.static` would cache it 31 days).
- **The manifest is per domain**: `GET /manifest.webmanifest` is built by `server.js` from `/api/config` (the installed app carries the site's name). Don't add a static `manifest.json` to `public/`.
- **`/robots.txt`, `/sitemap.xml` and `/llms.txt` are per host too**, served by `server.js`: the rules stay in `public/robots.txt` and the `Sitemap:` line is appended for the request's host; the sitemap comes from `GET /api/sitemap` through `renderSitemap` (`entry-server.tsx`, French paths, stripped on a pinned host). It never lists ads, routes or map pages (docs/LEDGER_DONE.md WEB-31). `/llms.txt` (`renderLlmsTxt`, `lib/llmsTxt.ts`) names the host and its public teams, then points at the sitemap — nothing the sitemap does not already expose (docs/LEDGER_DONE.md WEB-34).
- Install offers (`lib/install/useInstallOffer`) and the web push status (`lib/push/webPush`) are **null/unknown on the first render** and computed in effects: they depend on the user agent, `beforeinstallprompt` and localStorage, none of which SSR knows.
- Firebase is only ever imported dynamically, from `lib/push/webPush.ts`, and has its own chunk (`firebase-vendor` in `vite.config.ts`) so it never rides along with a page.

### Link previews (Open Graph / Twitter)

Public pages unfurl into rich social/messaging cards via server-rendered OG/Twitter tags. A route declares an optional `meta(ctx)` in `routes.config.ts`; `entry-server` runs it after `prefetch`, `src/lib/seo.ts` (`buildMetaTags`) serialises the result, and `server.js` injects it at the `<!--ssr-head-->` placeholder. Because no unfurl crawler runs JavaScript, the tags **must** be in the initial HTML — this rides on SSR, not client injection.

**Before adding or changing link previews, read [docs/LINK_PREVIEW.md](docs/LINK_PREVIEW.md)** — architecture, per-page coverage, the 2026 platform findings, invariants, and the curl check that verifies tags render server-side.

- **`meta()` builders only READ the per-request cache and never throw** — data must be `prefetch`ed on the same route; a missing entity returns `undefined` and falls back to site-wide defaults.
- **Never add a `<meta>`/`<title>` React component** — React 19 hoisting shifts `useId` and duplicates the title. Tags are string-built in `seo.ts`, outside the React tree.
- `og:image` is 1200×630 PNG/JPEG, absolute per-domain HTTPS, < ~300 KB; the default is `public/og-image.png` (rebuilt from `assets/icon.svg`).

## Key Rules

- **Never hold list filters, search or pagination in `useState`** — they belong in the query string via `useUrlFilters`, so they survive back-navigation and are shareable. See [docs/URL_FILTERS.md](docs/URL_FILTERS.md).
- **Never describe a screen's data twice** — the page's hooks and the route's `prefetch` share one companion module (`pages/<domain>/<screen>Data.ts`); derive params, never copy them. See [docs/SSR-data-loading.md](docs/SSR-data-loading.md).
- **Never edit `src/api/`** — it's generated. Run `pnpm generate-api` after backend OpenAPI changes.
- **Never edit `paths.generated.ts`** — edit `../contracts/routes.yaml` and run `pnpm generate-routes`. See [docs/APP_LINKS.md](../docs/APP_LINKS.md).
- **Never hard-code links** — use `paths.xxx()` from `config/paths.ts` (locale-aware).
- **Never import `Link` from `react-router-dom`** — use `<PrefetchLink>` (`components/common/PrefetchLink.tsx`), including as `component={PrefetchLink}` on Mantine's polymorphic components. On hover/focus it warms both the destination's chunk *and* the `prefetch()` its route declares, through the same `runRoutePrefetch` the router loader uses — React Router's own `prefetch` prop is a silent no-op in library mode. Pass `prefetch="viewport"` (chunk only) or `"none"` where intent prefetching isn't wanted.
- **Never set link-preview tags via a React component** — add a `meta()` to `routes.config.ts` instead. See [docs/LINK_PREVIEW.md](docs/LINK_PREVIEW.md).
- **Never use `confirm()` or custom modals for confirmations** — use `ConfirmDialog`.
- **Never use `useComputedColorScheme` outside `ColorSchemeSwitcher.tsx`** — for a themed asset URL, computed color, or conditional className, use `useResolvedColorScheme()` (`src/hooks/useResolvedColorScheme.ts`) instead; it resolves correctly at hydration time for anonymous/auto-theme visitors instead of after a delayed post-mount effect. See docs/SSR.md Finding 4.
- **Never format a date with a raw `new Date(...).toLocaleDateString()`/`toLocaleString()`/`Intl.DateTimeFormat`** — go through `useFormattedDate()` (`src/utils/dateFormat.ts`), or the `<FormattedDate>`/`<FormattedDateTime>` components when the result renders as its own text node (they add the right `suppressHydrationWarning`). A raw call defaults to the *server process's* timezone during SSR, not the visitor's, and ignores the signed-in user's `timezone` preference on the client.
- **A rendezvous reads in its entity's zone, a timestamp in the reader's** (docs/LEDGER_*.md API-60, plan `archive/2026-10-06-event-timezones.md` §7). A departure (ride, group via `startAt`, stage), an estimated return, a trip's dates, a scheduled publication and a post's date go through `useRendezvousFormat(entity.timezone)` or `<Rendezvous date zone variant>` (`components/common/Rendezvous.tsx`), which add the « heure de Tokyo (sam. 23:00 chez vous) » mention only when the offsets differ at that instant. Creation dates, comments, « il y a 2 h », the calendar grid, « aujourd'hui » and day grouping stay on `useFormattedDate()`. Never print a group's raw `time` (« 08:30:00 »): format its `startAt`.
- **Never use SVG for icons** — use `@tabler/icons-react`. **Never pass it `title`**: the icon renders a `<title>` inside its `<svg>`, React 19 hoists it out of the server HTML, and the page fails to hydrate (#418). Name it with `aria-label`; a hover hint goes on a wrapping element.
- **Mantine UI exclusively** — check https://mantine.dev/llms.txt for docs.
- **A calendar event's `color` is a Mantine palette *name*, never a hex** (`components/calendar/CalendarView.tsx`) — `@mantine/schedule` runs it through `theme.variantColorResolver`, which resolves a name to the scheme-aware `--mantine-color-<name>-light` pair and can only blend a raw hex into `rgba(hex, 0.1)` over white. A hex looks right in light mode and renders the event unreadable in dark. Same reflex for any Mantine `color` prop.
- **An i18n key never travels as a `string`** — a templated key interpolates a typed value, a stored key is a `TranslationKey`, an error code an `ErrorCode` (see i18n above).
- **Frontend config comes from `/api/config` endpoint**, not `.env` files.
- **Logos**: `TeamAvatar` (with initials fallback) vs `EntityLogo` (no fallback).
- **`MediaEditor` needs `teamSlug` prop** for uploads (hidden during team creation).
- **A group's leader is `RideGroupDto.leader` and nothing else** — nullable, and null is the *common* case: render no badge. **Never fall back to `createdBy`**, which is the *ride's* creator and so identical across all its groups; the fallback would be wrong almost everywhere while looking plausible. Don't extend the badge to the feed or the calendar either — the leader is a property of the **group**, and neither `PublicationCard` nor `CalendarEventDto` carries one.
- **An ad's position renders as a sector, never a pin** — `AdDto.locationGeometry` is the centre of a ~1 km cell. `components/ad/AdLocationMap.tsx` is the one rendering: a GeoJSON circle polygon of 500 m, framed on its own bounds, non-interactive, captioned as approximate. A `Marker` would claim a precision the data doesn't have.
- **The notification UI reads a real API — never mock it** — the header bell (`components/notification/NotificationBell.tsx`), the `/notifications` page and the type × channel table of `/profil/notifications` (`components/profile/NotificationPreferences.tsx`, families in `notificationFamilies.ts`) all come from `/api/notifications*`. Two rules hold there: **the API carries no rendered text**, so wording, icon and destination are the client's (`components/notification/notificationDisplay.ts`, keyed on `type` and `subjectType`); and **only the channels `NotificationPreferencesDto.channels` lists get a column** — `IN_APP` is never configurable and `PUSH` is only listed when the server has an FCM account, so an empty list hides the matrix (and the digest switch, which needs `EMAIL`) — but the per-team mute switches (`teams`) still show, since muting also keeps a team's announcements out of the inbox. The team webhook (`components/team/TeamWebhookSettings.tsx`) never shows more of its URL than `maskedUrl`: the URL is a secret. See §12 of `../docs/plans/archive/2026-09-18-notifications.md`.
- **Never replace query-string pagination with infinite scroll** — filters and pagination live in the URL so views are shareable and back-navigation restores state, and `usePaginatedQuery` already prefetches the next *and* previous page.
- **User preferences**: `preferencesStore` is local-first, but for a signed-in user `PATCH /api/users/me/preferences` is the source of truth (`useUpdateMyPreferences`; `UserDto` carries `theme`, `language`, `contactableByMembers`). `localStorage` remains the anonymous fallback and first-render cache — and must not be read at module scope (SSR). `preferencesStore.ts` mirrors `authStore`'s SSR split for exactly this reason: the store is a module singleton shared by every concurrent render, so the server derives `unitSystem` per-request from `getSSRAuth()` (never from the store itself) while the client seeds its module-load state from `window.__AUTH_STATE__` for an authenticated first render, and only applies an anonymous visitor's `localStorage` preference in a post-hydration effect (`hydrateAnonymousPreferences()`, called from `useAuth.ts`) — reading it any earlier would mismatch the anonymous server markup (always `METRIC`).

## Where the design decisions live

The July 2026 port of the mobile v2 ideas is documented in
[`../docs/plans/archive/2026-07-26-web-portage-mobile-v2.md`](../docs/plans/archive/2026-07-26-web-portage-mobile-v2.md),
whose §4 ("what not to port") explains why touch layouts, `--pdl-*` tokens, a derived dark mode and
infinite scroll were all declined. What's left to do is in
[`../docs/LEDGER_NEXT.md`](../docs/LEDGER_NEXT.md); what was delivered — T5.4 (the member directory,
its web page last, ledger `WEB-1`), T5.5 (the ads alignment on mobile) and T3.5 (abandoned then settled the other way), with their
reasoning — is in [`../docs/LEDGER_DONE.md`](../docs/LEDGER_DONE.md).
