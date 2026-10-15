import { useEffect, useRef, type ReactNode } from 'react'
import { RouterProvider, createBrowserRouter, UNSAFE_createRouter } from 'react-router-dom'
import { useQueryClient, type QueryClient } from '@tanstack/react-query'
import { getGetConfigQueryKey, useGetConfig } from './api/endpoints/configuration/configuration'
import { ErrorBoundary } from './components/common/ErrorBoundary'
import { FeedbackModal } from './components/feedback/FeedbackModal'
import { buildRoutes } from './config/RouteGenerator'
import { useAuthStore, wasHydratedFromSSR } from './store/authStore'
import { useAuth } from './hooks/useAuth'
import { prefetchCommonRoutes } from './lib/prefetch'
import { installPrefetchAudit } from './lib/prefetchAudit'
import { getPinnedHistory } from './config/pinnedHistory'
import { refreshWebPush } from './lib/push/webPush'
import { installPageViewCounter } from './lib/analytics'

const isServer = typeof window === 'undefined'

type AppRouter = ReturnType<typeof createBrowserRouter>

// Module singleton: the router is created once for the lifetime of the client session.
let router: AppRouter | undefined

/**
 * Lazily create the client data router. On a pinned single-team host it wraps the hidden-prefix
 * history (built by getPinnedHistory) with UNSAFE_createRouter — which requires an explicit
 * initialize() — otherwise a plain browser router. Server code must use buildRoutes() directly via
 * entry-server.tsx and never reach this.
 */
function getRouter(queryClient: QueryClient): AppRouter {
  if (isServer) {
    throw new Error(
      '[SSR] getRouter() must not be called on the server — use buildRoutes() in entry-server.tsx'
    )
  }
  if (!router) {
    const routes = buildRoutes(queryClient)
    const pinned = getPinnedHistory()
    // hydrationData (injected by StaticRouterProvider) marks the router as initialized so the
    // very first render shows the routes instead of waiting for loaders — required for hydration.
    const hydrationData = window.__staticRouterHydrationData
    router = pinned
      ? UNSAFE_createRouter({ routes, history: pinned, hydrationData }).initialize()
      : createBrowserRouter(routes, { hydrationData })
    if (__PREFETCH_AUDIT_ENABLED__) {
      installPrefetchAudit(queryClient, router)
    }
    // Page views, from the matched route's template only — never the URL, the title or the session
    // (docs/LEDGER_*.md WEB-90). Off unless /api/config carries `analytics`.
    installPageViewCounter(router)
  }
  return router
}

/**
 * Structure shared by both entries between the providers and the router. Server and client must
 * render the same component tree for useId-based hydration to line up — see AppProviders.
 */
export function AppFrame({ children }: { children: ReactNode }) {
  return (
    <>
      <ErrorBoundary>
        <AuthEffects />
        <WebPushEffects />
        {children}
      </ErrorBoundary>
      {/* Outside the boundary: its error screen opens this modal. */}
      <FeedbackModal />
    </>
  )
}

/**
 * Effects-only companion to the router. Initializes auth and warms common routes once auth settles.
 * Renders nothing: the router (and hence the app shell) renders immediately, unblocked by auth —
 * authenticated-only content resolves client-side after hydration.
 */
function AuthEffects() {
  const isInitialized = useAuthStore((state) => state.isInitialized)
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated)
  const initialize = useAuthStore((state) => state.initialize)
  const queryClient = useQueryClient()
  const revalidatedRef = useRef(false)
  // useAuth triggers the /me query so auth state is populated for the rest of the tree.
  const { isLoading } = useAuth()

  useEffect(() => {
    initialize()
  }, [initialize])

  // Repair pass for the case where the session only becomes known AFTER the first paint: the
  // dehydrated cache was then rendered anonymously and client queries that fired during hydration
  // raced the /api/auth/refresh round-trip. Both land in the cache as fresh (staleTime 3 min), so
  // member-only fields would stay missing long after the session is known — a route's `team.role`
  // (no Edit/Delete buttons), a preview's `owned`, and so on.
  //
  // It does NOT run when the server already rendered with the session: the cache then holds the
  // authenticated view from the start, and invalidating would throw away every prefetch the SSR
  // just paid for. That skip is the main reason SSR became session-aware at all.
  useEffect(() => {
    if (!isInitialized || !isAuthenticated || revalidatedRef.current) return
    revalidatedRef.current = true
    if (wasHydratedFromSSR()) return
    const configKey = getGetConfigQueryKey()
    void queryClient.invalidateQueries({
      // The domain config is auth-independent and is seeded synchronously at bootstrap — refetching
      // it would only add a request.
      predicate: (query) => query.queryKey[0] !== configKey[0],
    })
  }, [isInitialized, isAuthenticated, queryClient])

  useEffect(() => {
    if (isInitialized && !isLoading) {
      prefetchCommonRoutes()
    }
  }, [isInitialized, isLoading])

  return null
}

/**
 * Re-registers this browser's push subscription once per visit, for a member who turned it on:
 * FCM rotates tokens, and a stale one would stop the notifications silently. Renders nothing.
 */
function WebPushEffects() {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated)
  const { data: config } = useGetConfig()
  const webPush = config?.webPush
  const refreshedRef = useRef(false)

  useEffect(() => {
    if (!isAuthenticated || !webPush || refreshedRef.current) return
    refreshedRef.current = true
    refreshWebPush(webPush).catch((error: unknown) => {
      console.warn('Web push refresh failed', error)
    })
  }, [isAuthenticated, webPush])

  return null
}

export default function App({ queryClient }: { queryClient: QueryClient }) {
  return (
    <AppFrame>
      <RouterProvider router={getRouter(queryClient)} />
    </AppFrame>
  )
}
