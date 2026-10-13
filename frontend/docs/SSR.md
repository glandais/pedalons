# SSR — architecture and hard-won findings

How the frontend is server-rendered, and the non-obvious problems hit while building it
(2026-07). Read this before touching `server.js`, the entry files, or anything they eagerly
import. The short invariants live in [CLAUDE.md](../CLAUDE.md#ssr-server-side-rendering); this
file explains the *why* behind them.

## Architecture in one paragraph

`server.js` (Express 5) serves static assets and calls `render(url, headers)` from
`src/entry-server.tsx` for every page request. The render runs React Router in **library
mode** (`createStaticHandler` → `handler.query()` → `StaticRouterProvider`) inside a
per-request `AsyncLocalStorage` scope, prefetches route data into a per-request
`QueryClient` (Orval-generated `prefetchXxxQuery` declared as `prefetch` in
`routes.config.ts`, each wrapped into a React Router loader by `RouteGenerator.tsx`'s
`makeLoader`), renders with React's **static prerender API**, and returns
`{ html, dehydratedState, auth, statusCode, lang }`. `server.js` injects those into
`index.html` (`<!--ssr-outlet-->`, `<!--ssr-state-->`, `<!--ssr-auth-->`, `<html lang>`).
`src/entry-client.tsx` hydrates the query cache, adopts the session, seeds the app config,
and calls `hydrateRoot`. SSR is **session-aware** — see the next section.

Deliberate non-choices: React Router framework mode (no retrofit path for a declarative
SPA), TanStack Start (full router migration), Vike (replaces a working ~150-line server),
streaming (complicates React Query dehydration for no SEO gain), Vite Environment API
(still experimental; we use `ssrLoadModule`).

## Session-aware SSR

SSR used to be strictly anonymous. It no longer is: a document request carrying a
`refresh_token` cookie is rendered as that visitor — correct header and nav on the first
paint, and prefetched data already filtered by their rights, instead of an anonymous page
that gets thrown away and refetched wholesale after hydration.

How one request flows:

1. `server.js` passes all single-value request headers, cookie included, to `render()`.
2. `resolveSsrSession()` (`lib/ssrSession.ts`) exchanges the cookie for a 15-minute access
   token via **one** `POST /api/auth/refresh`, run concurrently with the `/api/config`
   prefetch so it costs no serial round-trip. 3 s timeout. Two failures, never confused
   (docs/LEDGER_*.md WEB-39): **no session** (no cookie, or a 401/403) yields the anonymous
   snapshot `ANONYMOUS`, which the client is told about and trusts; **session unknown**
   (timeout, network, any other status) yields `undefined`: the page renders anonymously, but
   without `__AUTH_STATE__`, so the client makes its own refresh after hydration, and a team the
   API refused is not turned into a 404. A refresh abandoned at the timeout loses nothing: its
   rotation, if the backend finished it, is honoured again from the old token (`API-94`).
3. The result lands in `SsrRequestStore.auth`, i.e. in AsyncLocalStorage.
4. `axiosInstance`'s server branch attaches `Authorization: Bearer` from there, so every
   prefetch is authenticated **exactly like the browser's**. The raw cookie is deliberately
   *not* relayed: the backend's cookie fallback only covers `@PermitAll` endpoints, so
   server-rendered DTOs would differ from the client's on anything stricter.
5. `useAuthStore` reads the same store on the server (see the next paragraph), so `Layout`,
   `useNavItems` and every `isAuthenticated` branch render the real state.
6. `server.js` serialises the session to `window.__AUTH_STATE__`; `entry-client` calls
   `hydrateAuthFromSSR()` **before** `hydrateRoot`, so the first client render matches the
   markup. `AuthEffects` then skips both the boot `/api/auth/refresh` and the global
   post-login `invalidateQueries` — skipping that invalidation is the whole point.

**The Zustand store is a module singleton shared by every concurrent render.** Writing a
session into it on the server would serve that session to whoever else is mid-render at the
same instant. So `useAuthStore` is a wrapper: on the server it applies the selector to a
snapshot built from `getSSRAuth()`, and `setState` throws. Any new module-level mutable
state reachable during SSR reintroduces the same hazard —
`scripts/ssr-session-isolation.mjs` is the check that catches it.

Consequences worth knowing:

- **The HTML is per-visitor.** The response is `Cache-Control: no-store` + `Vary: Cookie`,
  and that is now a security requirement, not a convenience. Never add HTML caching.
- **The access token ships in the markup.** Same token that already crosses the wire in
  `/auth/refresh`'s JSON body, and an XSS could fetch one anyway — but it is a real widening
  of where it lives, and it is why the cache headers above are non-negotiable.
- **Anonymous renders are byte-identical to before**, so bots, SEO and link previews are
  untouched.
- **Guarded routes**: with no session the store keeps `isLoading: true`, so `ProtectedRoute`
  stays on its loading branch exactly as it used to — no server-side redirect to `/login`.
  With a session, `authenticated` routes now render for real. One rough edge: a logged-in
  visitor loading `/login` gets an empty route outlet (`<Navigate>` is a no-op under a static
  router) until hydration redirects them; today's behaviour was a loading page.
- **Migration**: sessions issued before the cookie moved to `path=/` are invisible to SSR.
  The client's own `/api/auth/refresh` re-issues the cookie on the new path, so those
  sessions start rendering server-side from the next navigation. No reconnection.

Backend side: `RefreshTokenCookieFactory` owns the cookie (`path=/`, `SameSite=Lax`), and
`CrossSiteRequestFilter` compensates for the loss of `SameSite=Strict` as a CSRF defence.

## Finding 1 — `renderToString` renders every lazy page as its fallback

All route pages are `React.lazy`. `renderToString` flushes synchronously: a lazy component
is always pending on that first (and only) pass, so **every page SSR'd as the route-level
`<Loader/>`** — HTML looked plausible, dehydrated state was correct, but no content.
Nothing failed loudly; only `curl | grep` for actual content caught it.

The escalation path that ended at the right API:

1. `renderToPipeableStream` + `onAllReady` waits for lazy chunks and suspended data — but
   completed Suspense boundaries **larger than `progressiveChunkSize` (~12 KB) are
   "outlined"**: emitted as a `<template>` placeholder + hidden segment + inline `$RC`
   relocation script. Content is in the document but not inline — fine for JS-executing
   crawlers, wrong for anything reading raw HTML.
2. Final: `prerenderToNodeStream` from **`react-dom/static`** (React 19's prerender API,
   built for exactly this) with `progressiveChunkSize: Number.MAX_SAFE_INTEGER` so
   everything is inlined. A 10 s `AbortController` guard degrades still-pending boundaries
   to their fallbacks instead of hanging the request.

See `renderAppToString()` in `entry-server.tsx`.

## Finding 2 — a Suspense boundary can swallow a crash and render as "loading"

While diagnosing Finding 1, pages *still* rendered the fallback after the prerender switch.
Root cause was unrelated: `utils/dateFormat.ts` reads its date pattern via the **global**
i18next instance (`i18n.t('dateFormats.dateTime', …)`), which was uninitialized on the
server — `t()` returned `undefined`, `date-fns.format()` threw, and the error surfaced as…
the same Suspense fallback (boundary error → client-render marker `<!--$!-->`), with
**nothing in the server log** under the production React build. Two different root causes,
one identical symptom.

Fixes and rules that came out of this:

- ~15 modules legitimately call global `t()` at render time, so the **global i18next
  instance is now initialized on the server** (`i18n/index.ts`): pinned `lng: 'fr'`,
  `initAsync: false` (synchronous init — note the option is `initAsync` in i18next ≥ 24,
  not `initImmediate`), and **never mutated**. Per-request language lives only in the
  `createServerI18n()` instances passed through `I18nextProvider`. Call sites that need the
  request language must pass `{ lng }` explicitly (as `useFormattedDate` does).
- When a page SSRs as a spinner, **test in dev mode** (`node server.js` without
  `NODE_ENV=production`): the development React build prints the real error with a
  component stack; the production build stays silent.
- The distinct boundary markers in SSR output are diagnostic gold: `<!--$-->` complete,
  `<!--$?-->` pending/outlined, `<!--$!-->` errored (will client-render).

## Finding 3 — server and client must render the *same component tree*, not just the same HTML

Hydration produced page-wide mismatches on every Mantine `id` (`mantine-_R_7_` vs
`mantine-_R_3b_`). React's `useId` derives ids from **tree position**, so any server-only
or client-only wrapper — even a context provider or a component that renders `null` —
shifts every generated id below it. We had three such asymmetries: `I18nextProvider`
(server only), `<Notifications/>` (client only), `ErrorBoundary`/`AuthEffects` (client
only).

Fix: both entries render the exact same structure through shared components —
`src/AppProviders.tsx` (I18next → Mantine → Notifications → QueryClient) and `AppFrame` in
`src/App.tsx` (ErrorBoundary → AuthEffects → router provider). **Any structural change to
the provider stack must go through these two components.** The client router is also
created with `window.__staticRouterHydrationData` (injected by `StaticRouterProvider`) so
it starts initialized instead of rendering a pre-init state that differs from the server.

## Finding 4 — client-persisted state must not influence the first client render

The color-scheme toggle rendered sun vs moon from `useComputedColorScheme`. The server
doesn't know the user's stored scheme, so any user with `mantine-color-scheme-value: dark`
in localStorage got a hydration mismatch. Two traps inside the trap:

- `useComputedColorScheme('light', { getInitialValueInEffect: true })` does **not** help
  when a concrete scheme is stored: the option only defers `matchMedia` resolution of
  `'auto'`; a stored `'dark'` is read synchronously on the first render.
- The classic `const [mounted, setMounted] = useState(false); useEffect(() => setMounted(true))`
  gate is rejected by our lint (`react-hooks/set-state-in-effect`).

For a pure CSS-hidden icon swap (nothing else differs), `lightHidden`/`darkHidden` props
sidestep the whole problem — they compile to `[data-mantine-color-scheme]` selectors, so the
browser applies the right one the instant `index.html`'s pre-hydration script (or `server.js`,
for a signed-in visitor's explicit theme) sets that attribute, before React ever mounts.

For anything else that needs the resolved scheme *as a JS value* — a different asset URL, a
computed color, a conditional className — use **`useResolvedColorScheme()`**
(`src/hooks/useResolvedColorScheme.ts`) instead of `useComputedColorScheme` **and** instead of
`useMantineColorScheme().colorScheme`. That second one looks safe for a concrete (non-`'auto'`)
value — no `matchMedia`/effect involved — but it isn't: Mantine's own state initializes from
`localStorage` synchronously on the client's first render, so a visitor with an explicit stored
theme already has the real value on their *first hydration render*, before React's own snapshot
machinery gets a say. That's a genuine hydration mismatch against the server (which always
assumes `'light'` for an anonymous/`'auto'` visitor) — and React's hydration commit deliberately
does **not** patch a mismatched `src`/`href` (only warns, to avoid an unwanted refetch). Nothing
else then forces a second, *non-hydration* render, so the wrong asset sticks forever — not a
brief flash, a permanent wrong thumbnail/basemap/color for exactly the visitors this fix targets.
Confirmed live: an anonymous visitor with `mantine-color-scheme-value: dark` in `localStorage`
got the light route thumbnail on every reload, forever, until this hook stopped trusting
`ctx.colorScheme` and routed every case — `'auto'` or concrete — through
`useSyncExternalStore` reading the DOM attribute instead. Its server snapshot (`'light'`) makes
the first hydration render deliberately match what the server assumed (nothing to skip), and its
built-in mismatch check then schedules a genuine follow-up **update** shortly after mount, which
does patch `src` correctly. A signed-in visitor whose server-rendered theme was already right
just pays one harmless extra render with the same value. `useComputedColorScheme` and
`useMantineColorScheme().colorScheme` should not appear anywhere outside this hook and
`ColorSchemeSwitcher.tsx` itself.

## Finding 5 — assorted sharp edges

- **Express 5 catch-all**: `app.use('*', …)` throws (`path-to-regexp` v8). Use a named
  wildcard (`'*splat'` / `'/{*splat}'`).
- **404s**: the `'*'` catch-all *matches*, so the static handler reports 200 for unknown
  URLs. `entry-server` maps a leaf match of `path: '*'` to `statusCode: 404`.
- **Server `QueryClient` `gcTime` must not be 0** (TanStack-documented dehydration
  footgun) — we use 2000 ms (`lib/queryClient.ts`).
- **Prefetch params must byte-match the page hook's query key**, or the dehydrated entry is dead
  weight and the page refetches — silently, since nothing errors. So **derive them, never copy
  them**: a `prefetch` that spells out `{ page: 0, size: 12, view: 'COMPACT' }` is correct exactly
  until someone edits the page, and no test fails when it stops being. Each list already has a
  single source of truth to call instead — its filter schema (`placeFiltersSchema.parse({})` is
  literally what `useUrlFilters` seeds itself with), a shared params builder
  (`publicationApiParams`, `placeAutocompleteParams`) or a shared constant (`COMMENT_LIST_OPTIONS`,
  `NEXT_RIDE_PARAMS`, `PARTICIPATION_COUNT_PARAMS`). When one has to live in its own tiny module,
  it is because `routes.config.ts` is eagerly imported by both entries and must not drag a lazy
  page component into the main bundle. A screen with more than one thing to share (a derivation, a
  filter schema/alias pair, a multi-phase sequence) gets a **data companion module** instead —
  the pattern, its rules and how to verify it are in
  [SSR-data-loading.md](SSR-data-loading.md).
  Verify with `e2e/routes-render.e2e.ts` (`pnpm e2e routes-render -g '<routeId> /'` on the e2e
  stack) rather than the network tab: its prefetch audit reports the exact query keys that were
  fetched after hydration.
- **`node:async_hooks` must not leak into the client bundle**: `lib/requestContext.ts`
  (SSR-only) is bridged through the client-safe `lib/ssrContext.ts` getters
  (`getSSRHeaders/getSSRLocale/getSSRConfig/getSSRAuth`); only `entry-server.tsx` and
  `lib/ssrSession.ts` may import `requestContext` for anything but its types. Verify with
  `grep -rl async_hooks dist/client/` → no match.
- **i18next option rename**: synchronous init is `initAsync: false`, not
  `initImmediate: false` (typecheck catches it).
- **Third-party libs that read `window` at module load crash the route's boundary**: first
  real case was `chartjs-plugin-zoom` → `hammerjs` (hit when develop's fullscreen map pages
  landed). Fix pattern: dynamic-`import()` the library client-side when the feature is
  actually used (see `useZoomPlugin` in `ElevationChart.tsx`). Any new dependency reachable
  from a public route's chunk can reintroduce this — the curl sweep below catches it.

## Finding 6 — `navigate()` during render is a silent no-op, then an infinite loop

A redirect written the obvious way never redirects on the server, and melts down on the
client:

```tsx
if (team.role !== 'ADMIN') {
  navigate(paths.team(teamSlug!), { replace: true })   // ← in the component body
  return null
}
```

`createStaticRouter`/`StaticRouterProvider` is a **data router**, so `useNavigate()` resolves
to `useNavigateStable()`, which guards on a ref set by a layout effect:

```js
warning(activeRef.current, navigateEffectWarning)   // "You should call navigate() in a
if (!activeRef.current) return                      //  React.useEffect(), not when your
await router.navigate(to, …)                        //  component is first rendered."
```

Effects never run during SSR, so `activeRef` stays `false` and the call **returns before
touching the router**: no redirect, no crash, just that one line in the server log. (The
`getStatelessNavigator()` methods that *do* throw — *"You cannot use navigator.replace() on
the server"* — belong to the non-data `StaticRouter`, which this app doesn't use. And
`warning()` is not gated on `NODE_ENV` in react-router 7, which is why the line shows up on a
production server too.)

The client is where it gets expensive, and it's a delayed fuse: the **first** render no-ops
the same way, the layout effect flips `activeRef` to `true`, and the next re-render — the one
where `useAuth()` finally resolves the user — actually calls `router.navigate()` *from a
render body*. That's `Cannot update a component (RouterProvider) while rendering a different
component`, and each resulting render navigates again: 291 pageerrors before the crawler gave
up, and the page stayed unresponsive long enough to poison the next route it crawled.

Rule: **never call `navigate()` from a render body.** Return `<Navigate to={…} replace />`
instead, which navigates from a `useEffect`.

Consequences of `<Navigate>` worth knowing, both benign here:

- It is a **no-op during SSR** for the same reason — effects don't run, the component renders
  `null`, and the redirect happens after hydration. The server does not emit a 3xx and the
  visitor sees an empty page for one paint. React Router says so itself
  (*"`<Navigate>` must not be used on the initial render in a `<StaticRouter>`. This is a
  no-op"*).
- A **real server-side redirect** comes from `handler.query()` returning a `Response`
  (`entry-server.tsx` maps its `Location` back to browser space), i.e. from a React Router
  *loader*. Every route with a `prefetch` has one (`makeLoader`): a failed prefetch never blocks
  the render, so the prefetch itself is not a redirect channel. Three things do redirect, each
  with a 302 (`replace()`, never permanent): `appOnlyFallbackRoutes()` — deeplinks only the app
  answers (`routes.yaml`, `web: false`) go to their web fallback —, a route's `redirect` (a pure
  function of the URL, checked before the prefetch: the former team feed, ledger `WEB-68`), and
  a route's `dataRedirect` (checked after the prefetch, reading only its cache: a ride group's
  page of a ride with at most one group leaves for the ride, ledger `WEB-79`). A `dataRedirect`
  whose data is missing (an anonymous render of a private team) answers nothing, and the page
  falls back on `useCanonicalPath` after hydration. Guard pages still use `<Navigate>`; moving one
  to a loader redirect is possible, not done.

Found by the SSR crawler (since retired for `e2e/routes-render.e2e.ts`) on a guard page since
removed; open SSR defects are ledger entries (`docs/LEDGER_NEXT.md`, `WEB` prefix).

## Verifying SSR end-to-end

Static checks pass ≠ SSR works — every finding above survived typecheck, lint, tests and
build. The checks that actually catch regressions:

```bash
# against the local prod-replica stack (see repo docs; from a worktree: docker compose -p tribly)
curl -s -H 'Accept-Language: fr' http://localhost:8090/ | grep -c 'mantine-Loader-root'   # 0
curl -s http://localhost:8090/ | grep -c '<!--\$[?!]-->'                                   # 0 (no pending/errored boundaries)
curl -s http://localhost:8090/equipes/<slug> | grep '<title>'                              # real content, not fallback
curl -so /dev/null -w '%{http_code}' http://localhost:8090/nonexistent                     # 404

# Session-aware SSR. A junk cookie must render anonymously and embed no token:
curl -s -H 'Cookie: refresh_token=junk' http://localhost:8090/ | grep -c '"accessToken":null' # 1
# A real one must render the visitor's name into the header, not the login button:
curl -s -H "Cookie: refresh_token=$TOKEN" http://localhost:8090/ | grep -c '__AUTH_STATE__' # 1
# And the response must never be cacheable:
curl -sI http://localhost:8090/ | grep -iE 'cache-control|vary'   # no-store + Vary: Cookie

# The one check static analysis cannot replace — concurrent renders must not cross sessions:
node scripts/ssr-session-isolation.mjs --url http://localhost:8090 \
  --session "$TOKEN_A" --session "$TOKEN_B"
```

Then load `/` in a browser **with a stored dark scheme and a logged-in session** and check
the console for `[hydration]` errors — the worst mismatches only reproduce with
client-persisted state present. On that same load the network tab should show **no**
`POST /api/auth/refresh` at boot and no burst of refetches right after hydration; either
one means the session did not survive into the client.
