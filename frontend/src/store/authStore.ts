import { create, type StoreApi } from 'zustand'
import type { UserDto } from '@/api/dto'
import { paths } from '@/config/paths'
import { getSSRAuth } from '@/lib/ssrContext'
import type { SsrAuthSnapshot } from '@/lib/requestContext'
import { ssrAuthState as readSsrSession } from '@/lib/ssrState'

const isServer = typeof window === 'undefined'

export interface AuthState {
  user: UserDto | null
  accessToken: string | null
  hasPasskeys: boolean
  isAuthenticated: boolean
  isInitialized: boolean
  isInitializing: boolean
  isLoading: boolean
  error: string | null
}

export interface AuthActions {
  initialize: () => Promise<void>
  setAccessToken: (token: string | null) => void
  setUser: (user: UserDto | null) => void
  setHasPasskeys: (hasPasskeys: boolean) => void
  setLoading: (isLoading: boolean) => void
  setError: (error: string | null) => void
  clearError: () => void
  getToken: () => string | null
  /**
   * Revokes the session, then reloads on `redirectTo` (the login page by default). A full reload,
   * not a client navigation: it is what drops every piece of the signed-out user's in-memory state.
   */
  logout: (options?: { redirectTo?: string }) => Promise<void>
  /**
   * Revokes every session of the member, this one included, then reloads on the login page.
   * **Throws if the server refuses**, and the session then stays open: announcing that every
   * device is signed out when the others are not would be worse than an error.
   */
  logoutAll: () => Promise<void>
  redirectToLogin: () => void
}

export type AuthStore = AuthState & AuthActions

const defaultState: AuthState = {
  user: null,
  accessToken: null,
  hasPasskeys: false,
  isAuthenticated: false,
  isInitialized: false,
  isInitializing: false,
  isLoading: true,
  error: null,
}

function authStateFromSnapshot(snapshot: SsrAuthSnapshot) {
  const isAuthenticated = snapshot.accessToken !== null
  return {
    accessToken: snapshot.accessToken,
    user: snapshot.user,
    hasPasskeys: snapshot.hasPasskeys,
    isAuthenticated,
    isInitialized: true,
    isLoading: false,
  }
}

/**
 * Zustand's `useSyncExternalStore` server-snapshot is `getInitialState()` — frozen to whatever was
 * passed to `create()` below, forever, regardless of any later `setState()` call. React reads it
 * (not `getState()`) specifically for the first client render during hydration, so by the time
 * `hydrateAuthFromSSR()` used to run (an imperative `setState()` early in entry-client.tsx, but
 * still after this module evaluates), it was already too late for that first render: the store's
 * frozen `getInitialState()` was still the anonymous default, producing a hydration mismatch on
 * every authenticated visit. The session must be in the state passed to `create()` itself — read
 * here, synchronously, at module load. The session is the `#ssr-auth-state` data block server.js
 * writes into the body (`readSsrSession()`), and a module script runs once the document is parsed,
 * so it is already there by the time this (imported, hence deferred-module-executed) code runs.
 */
const ssrSession = isServer ? undefined : readSsrSession()
const initialState: AuthState = ssrSession
  ? { ...defaultState, ...authStateFromSnapshot(ssrSession) }
  : defaultState

const authStore = create<AuthStore>()((set, get) => ({
  ...initialState,

  initialize: async () => {
    if (get().isInitialized || get().isInitializing) {
      return
    }

    set({ isInitializing: true, isLoading: true })

    try {
      // Try to refresh token on startup (will work if refresh_token cookie exists)
      const response = await fetch('/api/auth/refresh', {
        method: 'POST',
        credentials: 'include',
      })

      if (response.ok) {
        const data = await response.json()
        set({
          accessToken: data.accessToken,
          user: data.user,
          hasPasskeys: data.hasPasskeys ?? false,
          isAuthenticated: true,
          isInitialized: true,
          isInitializing: false,
          isLoading: false,
        })
      } else {
        // No valid session, but initialization succeeded
        set({
          isAuthenticated: false,
          isInitialized: true,
          isInitializing: false,
          isLoading: false,
        })
      }
    } catch (error) {
      console.error('Auth initialization failed:', error)
      set({
        isAuthenticated: false,
        isInitialized: true,
        isInitializing: false,
        isLoading: false,
      })
    }
  },

  setAccessToken: (token) => set({ accessToken: token }),

  setUser: (user) =>
    set({
      user,
      isAuthenticated: user !== null,
      isLoading: false,
    }),

  setHasPasskeys: (hasPasskeys) => set({ hasPasskeys }),

  setLoading: (isLoading) => set({ isLoading }),

  setError: (error) => set({ error, isLoading: false }),

  clearError: () => set({ error: null }),

  getToken: () => get().accessToken,

  logout: async (options) => {
    // While the session is still valid: unregistering the browser is an authenticated call. A
    // shared computer must stop receiving this member's notifications once they have left.
    try {
      const { disableWebPush } = await import('@/lib/push/webPush')
      await disableWebPush()
    } catch (error) {
      console.error('Web push unregistration failed:', error)
    }
    try {
      await fetch('/api/auth/logout', {
        method: 'POST',
        credentials: 'include',
      })
    } catch (error) {
      console.error('Logout failed:', error)
    }

    set({ ...defaultState, isInitialized: true, isLoading: false })
    window.location.href = options?.redirectTo ?? paths.login()
  },

  logoutAll: async () => {
    // Like logout: the browser's push registration goes first, while the session is still valid.
    // logout-all revokes the sessions, not the push registrations of the other devices.
    try {
      const { disableWebPush } = await import('@/lib/push/webPush')
      await disableWebPush()
    } catch (error) {
      console.error('Web push unregistration failed:', error)
    }
    // Through the authenticated client (a dynamic import: it imports this store): it sets the
    // bearer token logout-all requires, and refreshes it on a 401.
    // Its error is the page's to say, in terms of sessions still open: no generic toast on top.
    const { logoutAll } = await import('@/api/endpoints/authentication/authentication')
    await logoutAll({ skipErrorToast: true })

    set({ ...defaultState, isInitialized: true, isLoading: false })
    window.location.href = paths.login()
  },

  redirectToLogin: () => {
    window.location.href = paths.login()
  },
}))

/**
 * The auth state for the request being rendered, assembled from the per-request AsyncLocalStorage
 * snapshot rather than from the store's own (process-wide) state.
 *
 * The Zustand store is a module singleton: in the Node SSR process it is shared by every concurrent
 * render. Writing a visitor's session into it would serve that session to whoever else is being
 * rendered at the same instant. So the server never writes it — it reads through here instead, and
 * only the actions (which are stateless closures) come from the store itself.
 *
 * With no session the result is byte-for-byte the old anonymous state, including `isLoading: true`.
 * That is deliberate: it keeps `ProtectedRoute` on its loading branch for anonymous visitors, so
 * guarded routes behave exactly as they did before.
 */
function ssrAuthState(): AuthStore {
  const snapshot = getSSRAuth()
  const actions = authStore.getState()
  if (!snapshot) {
    return { ...actions, ...defaultState }
  }
  const isAuthenticated = snapshot.accessToken !== null
  return {
    ...actions,
    ...defaultState,
    accessToken: snapshot.accessToken,
    user: snapshot.user,
    hasPasskeys: snapshot.hasPasskeys,
    isAuthenticated,
    isInitialized: true,
    isLoading: false,
  }
}

function useAuthStoreOnServer(): AuthStore
function useAuthStoreOnServer<T>(selector: (state: AuthStore) => T): T
function useAuthStoreOnServer<T>(selector?: (state: AuthStore) => T): T | AuthStore {
  const state = ssrAuthState()
  return selector ? selector(state) : state
}

type UseAuthStore = typeof useAuthStoreOnServer &
  Pick<StoreApi<AuthStore>, 'getState' | 'setState' | 'subscribe'>

/**
 * Same call signature as the raw Zustand hook — `useAuthStore()` or `useAuthStore(selector)` — but
 * request-scoped on the server. See {@link ssrAuthState}.
 */
function useAuthStoreOnClient(): AuthStore
function useAuthStoreOnClient<T>(selector: (state: AuthStore) => T): T
function useAuthStoreOnClient<T>(selector?: (state: AuthStore) => T): T | AuthStore {
  return selector ? authStore(selector) : authStore()
}

// Assign onto a fresh function, never onto `authStore` itself: overwriting the Zustand store's own
// setState with the wrapper below would make the wrapper call itself.
export const useAuthStore: UseAuthStore = Object.assign(
  isServer ? useAuthStoreOnServer : useAuthStoreOnClient,
  {
    getState: () => (isServer ? ssrAuthState() : authStore.getState()),
    setState: ((...args: Parameters<StoreApi<AuthStore>['setState']>) => {
      if (isServer) {
        throw new Error(
          '[SSR] useAuthStore.setState() must not be called on the server: the store is shared by ' +
            'all concurrent renders. Put the session in the request store (SsrRequestStore.auth).'
        )
      }
      return authStore.setState(...args)
    }) as StoreApi<AuthStore>['setState'],
    subscribe: authStore.subscribe,
  }
)

/**
 * Marks that this client hydrated markup the server already rendered with the session — the store's
 * `initialState` above was seeded from the SSR session (`readSsrSession()`) directly, so by the time this runs
 * the state is already correct. This call is now just a record of that fact for
 * {@link wasHydratedFromSSR}, plus a defensive re-assertion of the same state.
 */
let hydratedFromSSR = false

/**
 * Whether the markup this client hydrated was already rendered with the session. When true there is
 * nothing to repair after login settles — the cache holds the authenticated view already.
 */
export function wasHydratedFromSSR(): boolean {
  return hydratedFromSSR
}

export function hydrateAuthFromSSR(snapshot: SsrAuthSnapshot): void {
  hydratedFromSSR = true
  authStore.setState(authStateFromSnapshot(snapshot))
}

export const selectUser = (state: AuthStore) => state.user
export const selectAccessToken = (state: AuthStore) => state.accessToken
export const selectHasPasskeys = (state: AuthStore) => state.hasPasskeys
export const selectIsAuthenticated = (state: AuthStore) => state.isAuthenticated
export const selectIsInitialized = (state: AuthStore) => state.isInitialized
export const selectIsLoading = (state: AuthStore) => state.isLoading
export const selectError = (state: AuthStore) => state.error
export const selectIsPlatformAdmin = (state: AuthStore) =>
  state.user?.platformRole === 'PLATFORM_ADMIN'
