import { ErrorBoundary } from '@/components/common/ErrorBoundary'
import { Navigate, redirect, replace, type RouteObject } from 'react-router-dom'
import type { QueryClient } from '@tanstack/react-query'
import { routesConfig } from './routes.config'
import { runRoutePrefetch } from './runRoutePrefetch'
import type { RouteConfig, RouteParams, AuthRequirement } from './routes.types'
import { AuthenticatedRoute, UnauthenticatedRoute } from '../components/auth/ProtectedRoute'
import { Layout } from '../components/common/Layout'
import { NotFoundPage } from '../pages/NotFoundPage'
import { paths } from './paths'
import { appOnlyFallbacks } from './paths.generated'
import { getPinnedTeamSlug, isSingleTeam } from './appConfig'
import { PinnedHrefs } from './PinnedHrefs'

function wrapWithAuth(element: React.ReactNode, auth: AuthRequirement): React.ReactNode {
  switch (auth) {
    case 'authenticated':
      return <AuthenticatedRoute>{element}</AuthenticatedRoute>
    case 'unauthenticated':
      return <UnauthenticatedRoute>{element}</UnauthenticatedRoute>
    case 'public':
    default:
      return element
  }
}

/**
 * Wrap a route's prefetch into a React Router loader. The running and the error handling live in
 * `runRoutePrefetch`, shared with the hover path (`lib/prefetch.ts`) so a link and the navigation it
 * leads to fetch exactly the same thing. The loader resolves to null — a failed prefetch never
 * blocks the render — unless `redirect` (before the prefetch) or `dataRedirect` (after it) names
 * another address, which it throws as a `replace()`.
 */
export function makeLoader(config: RouteConfig, queryClient: QueryClient) {
  return async ({
    request,
    params,
  }: {
    request: Request
    params: Record<string, string | undefined>
  }) => {
    const url = new URL(request.url)
    // A former address: leave it before fetching anything for a page that will not render.
    const target = config.redirect?.(params as RouteParams, url)
    if (target) throw replace(target)
    await runRoutePrefetch(config, queryClient, params, url, 'loader')
    // A page its data sends elsewhere (a solo ride's group, WEB-79): read from the cache just filled.
    const moved = config.dataRedirect?.(queryClient, params as RouteParams, url)
    if (moved) throw replace(moved)
    return null
  }
}

/**
 * Emit one RouteObject per locale variant so any URL matches the same component regardless of the
 * user's current language. Used by BOTH the client data router (App.tsx) and the server static
 * handler (entry-server.tsx).
 */
function buildRoutesForConfig(config: RouteConfig, queryClient: QueryClient): RouteObject[] {
  const gated = Boolean(config.hideWhenSingleTeam && isSingleTeam())

  const Component = config.component
  const element = gated ? (
    <Navigate to={paths.home()} replace />
  ) : (
    wrapWithAuth(
      // Per-route boundary: a crash in one page shows an error block instead of a blank app.
      <ErrorBoundary>
        <Component />
      </ErrorBoundary>,
      config.auth
    )
  )

  // Gated redirects carry no prefetch: the component never renders here.
  const loader =
    (config.prefetch || config.redirect || config.dataRedirect) && !gated
      ? makeLoader(config, queryClient)
      : undefined

  // Expose the route's SSR meta() (link previews) on `handle` so the static handler's matched leaf
  // carries it — entry-server reads leafMatch.route.handle.meta after the loaders have run. `routeId`
  // rides along the same mechanism to identify the matched route (routes.config.ts's own `id`,
  // stable across locale variants — RouteObject.id itself can't be reused for that, React Router
  // requires it unique per object and each locale variant is a separate object). Gated redirects
  // render no page, so they carry no handle.
  const handle = gated
    ? undefined
    : { routeId: config.id, ...(config.meta && { meta: config.meta }) }

  if (config.index) {
    return [{ index: true, element, loader, handle }]
  }

  const uniquePaths = [...new Set(Object.values(config.paths))]
  return uniquePaths.map((path) => ({ path, element, loader, handle }))
}

/**
 * The deeplinks only the app answers (contracts/routes.yaml, web: false): opened in a browser — no
 * app installed, a desktop — they redirect to their web fallback instead of a 404. A loader, so the
 * server answers a real redirect too. Being static, they also rank above `/equipes/:teamSlug`:
 * `/equipes/decouvrir` is not read as a team.
 */
export function appOnlyFallbackRoutes(): RouteObject[] {
  return appOnlyFallbacks.flatMap(({ patterns, fallback }) =>
    patterns.map((path) => ({
      path,
      // The fallback's params are a subset of the link's (checked by the generator): teamSlug at most.
      loader: ({ params }: { params: Record<string, string | undefined> }) =>
        redirect((paths[fallback] as (teamSlug?: string) => string)(params.teamSlug)),
      element: null,
    }))
  )
}

export function buildRoutes(queryClient: QueryClient): RouteObject[] {
  // `layout: 'bare'` routes render outside the shared <Layout> AppShell (no header/footer/
  // breadcrumbs), as siblings of the "/" branch. Auth wrapping still applies via
  // buildRoutesForConfig.
  const bareConfigs = routesConfig.filter((config) => config.layout === 'bare')
  const appConfigs = routesConfig.filter((config) => config.layout !== 'bare')

  const routes: RouteObject[] = [
    ...appOnlyFallbackRoutes(),
    ...bareConfigs.flatMap((config) => buildRoutesForConfig(config, queryClient)),
    {
      path: '/',
      element: <Layout />,
      children: [
        ...appConfigs.flatMap((config) => buildRoutesForConfig(config, queryClient)),
        { path: '*', element: <NotFoundPage /> },
      ],
    },
  ]
  // Pinned host: links in browser space on the server too (see PinnedHrefs). Both renders build
  // their routes here, so the component trees stay identical for hydration.
  if (!getPinnedTeamSlug()) return routes
  return routes.map((route) => ({ ...route, element: <PinnedHrefs>{route.element}</PinnedHrefs> }))
}
