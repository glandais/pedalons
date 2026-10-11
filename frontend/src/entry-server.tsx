import React from 'react'
import { prerenderToNodeStream } from 'react-dom/static'
import {
  createStaticHandler,
  createStaticRouter,
  StaticRouterProvider,
  parsePath,
  createPath,
} from 'react-router-dom'
import { dehydrate } from '@tanstack/react-query'
import { AppProviders } from './AppProviders'
import { AppFrame } from './App'
import { buildRoutes } from './config/RouteGenerator'
import { makeQueryClient } from './lib/queryClient'
import { createServerI18n, languageFromCookieHeader, supportedLanguages } from './i18n'
import { requestContext, type SsrRequestStore } from './lib/requestContext'
import { setStoreGetter } from './lib/ssrContext'
import { resolveSsrSession } from './lib/ssrSession'
import { getConfig, getGetConfigQueryKey } from './api/endpoints/configuration/configuration'
import { getVersion, getGetVersionQueryKey } from './api/endpoints/server-version/server-version'
import { getGetMeQueryKey } from './api/endpoints/users/users'
import { prefetchCountMyUnreadNotificationsQuery } from './api/endpoints/notifications/notifications'
import { getGetTeamQueryKey } from './api/endpoints/teams/teams'
import type { TeamDetailDto } from './api/dto'
import { ApiClientError } from './lib/apiError'
import { getPinnedTeamSlug } from './config/appConfig'
import { toRouter, toBrowser } from './config/pinnedHistory'
import type { Locale } from './config/paths'
import { buildMetaTags, type RouteMeta, type RouteMetaContext, type RouteMetaFn } from './lib/seo'
import { withIndexing } from './config/routeMeta'
import type { RouteParams } from './config/routes.types'
import { mapThemePreference } from './lib/theme'
import { getSitemap } from './api/endpoints/sitemap/sitemap'
import { buildSitemapXml } from './lib/sitemap'
import { listTeams } from './api/endpoints/teams/teams'
import { TeamSortBy, SortDirection } from './api/dto'
import { buildLlmsTxt } from './lib/llmsTxt'

// Bridge the SSR per-request store (AsyncLocalStorage) to the client-safe getter used by
// axiosInstance / appConfig / locale-context. Called once at module load.
setStoreGetter(() => requestContext.getStore())

/** `url` with the path segment holding the team slug — the first one that matches — replaced. */
function replaceTeamSlug(url: string, from: string, to: string): string {
  const sepIdx = url.search(/[?#]/)
  const pathname = sepIdx === -1 ? url : url.slice(0, sepIdx)
  const suffix = sepIdx === -1 ? '' : url.slice(sepIdx)
  const segments = pathname.split('/')
  const index = segments.findIndex((segment) => decodeURIComponent(segment) === from)
  if (index !== -1) {
    segments[index] = encodeURIComponent(to)
  }
  return segments.join('/') + suffix
}

/**
 * What the render learns that the response must carry even when the render itself fails or
 * redirects: the rotated session cookie (`resolveSsrSession`). Filled as soon as it is known.
 */
export interface RenderSink {
  setCookies?: string[]
}

export async function render(
  url: string,
  headers: Record<string, string> = {},
  sink: RenderSink = {}
) {
  // Resolve the request locale from the explicit choice cookie (LanguageSwitcher), else from
  // Accept-Language (first token, language part only). Both are only the fallback: an
  // authenticated visitor's stored `language` preference (resolved below, once the session is
  // known) takes priority over them. The response depends on the Cookie header either way, which
  // server.js's Cache-Control: no-store / Vary: Cookie already declare.
  const acceptLanguage = headers['accept-language'] || 'fr'
  const requestedLang = acceptLanguage.split(',')[0].split('-')[0].toLowerCase() || 'fr'
  const acceptLocale: Locale = (supportedLanguages as readonly string[]).includes(requestedLang)
    ? (requestedLang as Locale)
    : 'fr'
  const cookieLocale = languageFromCookieHeader(headers['cookie'])
  if (!cookieLocale && acceptLocale !== requestedLang) {
    console.warn(`[SSR] Unsupported language "${requestedLang}", falling back to "fr"`)
  }
  const headerLocale: Locale = cookieLocale ?? acceptLocale

  const store: SsrRequestStore = {
    headers,
    locale: headerLocale,
    config: undefined,
    auth: undefined,
  }

  return requestContext.run(store, async () => {
    const queryClient = makeQueryClient({ isServer: true })
    try {
      // Three independent lookups, run concurrently so the session costs no extra serial round-trip:
      //
      // - the per-request config, tenant-resolved from the forwarded headers. It must land in the
      //   store BEFORE buildRoutes so isSingleTeam()/getPinnedTeamSlug() see it, and in the
      //   dehydrated state so the client reuses it instead of re-fetching.
      // - /api/version, rendered by Layout's footer on every page (not a route-specific
      //   prefetch(), since Layout wraps the whole app rather than one route).
      // - the visitor's session, if the request carried a refresh_token cookie. Everything the
      //   route loaders prefetch below then goes out authenticated. If there is no valid session,
      //   we still populate __AUTH_STATE__ with an anonymous session so the client knows the page
      //   was rendered anonymously and doesn't attempt a fresh /api/auth/refresh. If the session
      //   is unknown — the refresh timed out or failed — __AUTH_STATE__ is left out and the client
      //   makes that refresh itself (docs/LEDGER_*.md WEB-39).
      //
      // The config and version requests go out before the session is known, i.e. anonymously. That
      // is correct: both are auth-independent (App.tsx excludes config from the post-login refetch
      // for exactly that reason). All three failures are non-fatal — a failed fetch simply lets the
      // client refetch after hydration, and a failed session renders the page anonymously.
      const [configResult, , session] = await Promise.all([
        queryClient
          .fetchQuery({ queryKey: getGetConfigQueryKey(), queryFn: () => getConfig() })
          .catch((err) => {
            console.error('[SSR] Failed to load config:', err)
            return undefined
          }),
        queryClient
          .fetchQuery({ queryKey: getGetVersionQueryKey(), queryFn: () => getVersion() })
          .catch((err) => {
            console.error('[SSR] Failed to load version:', err)
          }),
        resolveSsrSession(headers, (cookies) => {
          sink.setCookies = cookies
        }),
      ])
      store.config = configResult
      // Undefined when the session is unknown: rendered as the anonymous default (isLoading on
      // both sides, so hydration still matches) and serialised as no __AUTH_STATE__ at all.
      store.auth = session

      // Prefer the signed-in visitor's stored language over the cookie/Accept-Language, now that the session
      // is known. store.locale is read live by getSSRLocale() (locale-context.ts), so mutating it
      // here — before routing/rendering start — is enough; nothing has consumed it yet.
      const userLanguage = session?.user?.language
      const locale: Locale =
        userLanguage && (supportedLanguages as readonly string[]).includes(userLanguage)
          ? (userLanguage as Locale)
          : headerLocale
      store.locale = locale
      const i18nInstance = await createServerI18n(locale)

      // /api/auth/refresh already returned the user, so seed the /me cache with it rather than
      // letting useAuth() fetch the same record again right after hydration.
      if (session?.user) {
        queryClient.setQueryData(getGetMeQueryKey(), session.user)
      }

      // The header bell's unread badge, on every page of a signed-in visitor — Layout's, like
      // /api/version above, so no route's prefetch() owns it. Started now, with the session, and
      // awaited before the render: it runs alongside the route loaders rather than after them.
      // prefetchQuery never throws; a failure leaves the badge to the client.
      const unreadCount = session?.user
        ? prefetchCountMyUnreadNotificationsQuery(queryClient)
        : Promise.resolve()

      // The signed-in visitor's stored theme, so the very first render (server and client) already
      // matches it instead of the anonymous 'auto' default — see AppProviders.tsx.
      const themePreference = mapThemePreference(session?.user?.theme)

      const routes = buildRoutes(queryClient)
      const handler = createStaticHandler(routes)

      // Reconstruct the origin from proxy headers (set by server.js) so the static handler gets a
      // valid absolute URL.
      const origin = headers['x-forwarded-proto']
        ? `${headers['x-forwarded-proto']}://${headers['x-forwarded-host'] || headers['host'] || 'localhost'}`
        : `http://${headers['host'] || 'localhost'}`

      // Pinned single-team host: the app operates internally on team-prefixed router paths while the
      // browser sees clean, unprefixed ones. Translate the incoming pathname browser→router before
      // the handler runs (mirroring the client's pinned history).
      const pinned = getPinnedTeamSlug()
      const sepIdx = url.search(/[?#]/)
      const pathname = sepIdx === -1 ? url : url.slice(0, sepIdx)
      const suffix = sepIdx === -1 ? '' : url.slice(sepIdx)
      const routerUrl = pinned ? toRouter(pathname) + suffix : url

      const context = await handler.query(
        new Request(`${origin}${routerUrl}`, { headers: new Headers(headers) })
      )

      // A Response means the router wants to redirect. Map its Location back to browser space on a
      // pinned host so the browser follows the clean URL.
      if (context instanceof Response) {
        const location = context.headers.get('Location') || '/'
        const mapped = pinned ? mapPathname(location, toBrowser) : location
        return { redirect: mapped, statusCode: context.status }
      }

      // Pinned host: the links' hrefs are mapped to browser space by PinnedHrefs, at the root of
      // the routes — wrapping router.createHref here did nothing, StaticRouterProvider hands the
      // links a navigator of its own.
      const router = createStaticRouter(handler.dataRoutes, context)

      // The '*' catch-all matches unknown URLs, so the handler reports 200 for them; crawlers
      // must see a real 404 for the NotFound page.
      const leafMatch = context.matches[context.matches.length - 1]
      let statusCode = leafMatch?.route.path === '*' ? 404 : context.statusCode || 200

      // Team-scoped pages: the team the loaders just fetched decides what a crawler must see. The
      // page itself only redirects after hydration (<Navigate>, useCanonicalPath), which a client
      // without JavaScript never runs.
      const teamSlug = leafMatch?.params.teamSlug
      if (teamSlug && !pinned) {
        const teamKey = getGetTeamQueryKey(teamSlug)
        const teamError = queryClient.getQueryState(teamKey)?.error
        const team = queryClient.getQueryData<TeamDetailDto>(teamKey)
        if (
          teamError instanceof ApiClientError &&
          [401, 403, 404].includes(teamError.status) &&
          session
        ) {
          // A private team is not revealed to be private: same answer as a team that never existed.
          // Not when the session is unknown: the team may well be the member's, which the client
          // will find out once its own refresh is through (docs/LEDGER_*.md WEB-39).
          statusCode = 404
        } else if (team && team.slug !== teamSlug) {
          // Reached through a former slug: the API resolved it, the address moves for good.
          return { redirect: replaceTeamSlug(url, teamSlug, team.slug), statusCode: 301 }
        }
      }

      // Build the server-rendered link-preview <head> block. meta() reads the per-request cache the
      // loaders just populated; `pathname` is the browser-space (clean) canonical URL base, so
      // pinned single-team hosts get unprefixed og:url. The block is injected at <!--ssr-head-->.
      const metaCtx: RouteMetaContext = {
        queryClient,
        params: (leafMatch?.params ?? {}) as RouteParams,
        origin,
        path: pathname,
        locale,
        config: store.config,
        t: i18nInstance.t,
      }
      let routeMeta: RouteMeta | undefined
      try {
        const metaFn = (leafMatch?.route.handle as { meta?: RouteMetaFn } | undefined)?.meta
        routeMeta = metaFn?.(metaCtx)
      } catch (metaErr) {
        console.error(`[SSR] meta() failed for ${url}:`, metaErr)
      }
      // noindex for anything not PUBLIC — the content's own visibility (from meta()) or its team's.
      routeMeta = withIndexing(routeMeta, metaCtx)
      const head = buildMetaTags(routeMeta, metaCtx)

      await unreadCount

      const html = await renderAppToString(
        <React.StrictMode>
          <AppProviders
            i18n={i18nInstance}
            queryClient={queryClient}
            defaultColorScheme={themePreference}
          >
            <AppFrame>
              <StaticRouterProvider router={router} context={context} />
            </AppFrame>
          </AppProviders>
        </React.StrictMode>
      )

      const dehydratedState = dehydrate(queryClient)

      // The session travels to the client so its first render matches this markup exactly (and so
      // it can skip the boot-time /api/auth/refresh). server.js serialises it into a response that
      // is Cache-Control: no-store and Vary: Cookie — both are load-bearing, not cosmetic.
      //
      // themePreference also lets server.js set data-mantine-color-scheme on <html> directly: a
      // signed-in visitor's explicit LIGHT/DARK preference is already known here, so the page
      // doesn't need to wait for index.html's pre-hydration script to derive it from
      // localStorage/matchMedia (which know nothing about this visitor and briefly render the
      // wrong scheme before React corrects it on hydration).
      return {
        html,
        dehydratedState,
        auth: store.auth,
        statusCode,
        lang: locale,
        head,
        themePreference,
      }
    } catch (err) {
      console.error(`[SSR] render failed for ${url}:`, err)
      throw err
    } finally {
      queryClient.clear()
    }
  })
}

/** `https://host` of the request, as the public address bar shows it. */
function requestOrigin(headers: Record<string, string>): string {
  return headers['x-forwarded-proto']
    ? `${headers['x-forwarded-proto']}://${headers['x-forwarded-host'] || headers['host'] || 'localhost'}`
    : `http://${headers['host'] || 'localhost'}`
}

/**
 * The `sitemap.xml` of the site the request arrived on, for server.js.
 *
 * Only the host headers go to the API: the list is anonymous by construction, and a visitor's
 * cookie must not reach a response that server.js lets caches keep. The config is needed for the
 * pinned host, whose URLs lose the team prefix like every link of that site.
 */
export async function renderSitemap(headers: Record<string, string> = {}): Promise<string> {
  const hostHeaders: Record<string, string> = {}
  for (const name of ['host', 'x-forwarded-host', 'x-forwarded-proto']) {
    if (headers[name]) hostHeaders[name] = headers[name]
  }
  const store: SsrRequestStore = { headers: hostHeaders, locale: 'fr', config: undefined }
  return requestContext.run(store, async () => {
    const [config, sitemap] = await Promise.all([getConfig(), getSitemap()])
    store.config = config
    return buildSitemapXml(
      sitemap.entries,
      requestOrigin(headers),
      getPinnedTeamSlug() ? toBrowser : undefined
    )
  })
}

/** How many public teams `llms.txt` names; the sitemap lists them all. */
const LLMS_TXT_TEAMS = 200

/**
 * The `llms.txt` of the host the request arrived on (docs/LEDGER_DONE.md WEB-34): its name and its
 * public teams, the largest first. Anonymous like the sitemap — only the host headers go through.
 */
export async function renderLlmsTxt(headers: Record<string, string> = {}): Promise<string> {
  const hostHeaders: Record<string, string> = {}
  for (const name of ['host', 'x-forwarded-host', 'x-forwarded-proto']) {
    if (headers[name]) hostHeaders[name] = headers[name]
  }
  const store: SsrRequestStore = { headers: hostHeaders, locale: 'fr', config: undefined }
  return requestContext.run(store, async () => {
    const config = await getConfig()
    store.config = config
    const teams = await listTeams({
      size: LLMS_TXT_TEAMS,
      sortBy: TeamSortBy.MEMBER_COUNT,
      sortDir: SortDirection.DESC,
    })
    return buildLlmsTxt({
      appName: config.appName,
      origin: requestOrigin(headers),
      teams: teams.teams,
      totalTeams: teams.total,
      toBrowser: getPinnedTeamSlug() ? toBrowser : undefined,
    })
  })
}

/**
 * Render to a complete HTML string, waiting for lazy route chunks and suspended data.
 *
 * renderToString flushes synchronously: React.lazy pages (all our routes are lazy) are still
 * pending at flush time, so every page would emit its Suspense fallback instead of content.
 * The static prerender API waits for the whole tree and inlines all Suspense content — no
 * streaming placeholders or relocation scripts — which is what crawlers should see; the
 * output hydrates with hydrateRoot like any server render. On timeout the render is aborted
 * and still-pending boundaries degrade to their fallbacks (client renders them after hydration).
 */
async function renderAppToString(app: React.ReactElement, timeoutMs = 10_000): Promise<string> {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(new Error('[SSR] render timed out')), timeoutMs)
  try {
    const { prelude } = await prerenderToNodeStream(app, {
      signal: controller.signal,
      // Fizz outlines completed Suspense boundaries larger than this (placeholder + hidden
      // segment + relocation script) so streaming can paint the shell early. We flush once,
      // so outlining only hurts: raise the threshold so all content is emitted inline.
      progressiveChunkSize: Number.MAX_SAFE_INTEGER,
      onError(err) {
        // Boundary-level errors are recoverable (the boundary falls back and hydrates
        // client-side); log and let the render finish.
        console.error('[SSR] render error:', err)
      },
    })
    let html = ''
    for await (const chunk of prelude) {
      html += chunk
    }
    return html
  } finally {
    clearTimeout(timer)
  }
}

/** Map only the pathname portion of a href string, preserving search/hash. */
function mapPathname(href: string, mapFn: (pathname: string) => string): string {
  const parsed = parsePath(href)
  return createPath({ ...parsed, pathname: mapFn(parsed.pathname ?? '/') })
}
