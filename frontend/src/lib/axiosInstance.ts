import Axios, { AxiosRequestConfig, AxiosError, InternalAxiosRequestConfig } from 'axios'
import { useAuthStore } from '../store/authStore'
import { notifications } from '@mantine/notifications'
import i18next from 'i18next'
import type { ErrorResponse } from '../api/dto'
import { ApiClientError, parseRetryAfter } from './apiError'
import { refreshesOn401 } from './authRefresh'
import { getSSRAuth, getSSRHeaders } from './ssrContext'
import { logEntry, pathOnly } from './feedback/clientLog'

const isServer = typeof window === 'undefined'

declare module 'axios' {
  interface AxiosRequestConfig {
    /**
     * Suppresses the global error toast for this call. For screens that render the API error
     * themselves (inline Alert), where the toast would say the same thing twice — or contradict it.
     * Pass it through an orval hook's `request` option.
     */
    skipErrorToast?: boolean
  }
}

// Create axios instance with credentials support for cookies.
// On the server, read API_BASE_URL at runtime (not baked at build time via Vite define).
export const AXIOS_INSTANCE = Axios.create({
  withCredentials: true,
  // Axios's built-in serializer defaults array query params to `key[]=a&key[]=b` (`indexes:
  // false`). JAX-RS `@QueryParam List<String>` (e.g. routes/bulk's `slug`) only binds the plain
  // repeated form `key=a&key=b` — `indexes: null` selects that form for every array param.
  paramsSerializer: { indexes: null },
  ...(isServer ? { baseURL: process.env.API_BASE_URL || 'http://localhost:8080' } : {}),
})

// Track if we're currently refreshing to avoid multiple refresh calls
let isRefreshing = false
let failedQueue: Array<{
  resolve: (value: unknown) => void
  reject: (error: unknown) => void
  config: InternalAxiosRequestConfig
}> = []

const processQueue = (error: unknown | null, token: string | null = null) => {
  failedQueue.forEach(({ resolve, reject, config }) => {
    if (error) {
      reject(error)
    } else {
      if (token) {
        config.headers.Authorization = `Bearer ${token}`
      }
      resolve(AXIOS_INSTANCE(config))
    }
  })
  failedQueue = []
}

// Request interceptor: on server, forward tenant-routing and language headers plus the bearer token
// minted for THIS request, all read from the per-request store (ssrContext) — never from the
// Zustand/i18next singletons, which are shared across concurrent renders. The raw Cookie header is
// deliberately not relayed: the backend's cookie fallback only covers @PermitAll endpoints, whereas
// a bearer token authenticates every endpoint exactly as the browser does, so the server and the
// client see identical DTOs. On client, attach JWT and Accept-Language.
AXIOS_INSTANCE.interceptors.request.use(
  (config) => {
    if (isServer) {
      const reqHeaders = getSSRHeaders()
      if (reqHeaders) {
        const host = reqHeaders['x-forwarded-host'] || reqHeaders['host']
        if (host) config.headers['X-Forwarded-Host'] = host
        const proto = reqHeaders['x-forwarded-proto']
        if (proto) config.headers['X-Forwarded-Proto'] = proto
        const lang = reqHeaders['accept-language']
        if (lang) config.headers['Accept-Language'] = lang
      }
      const ssrAuth = getSSRAuth()
      if (ssrAuth && ssrAuth.accessToken) {
        config.headers.Authorization = `Bearer ${ssrAuth.accessToken}`
      }
      return config
    }

    const token = useAuthStore.getState().getToken()
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }
    config.headers['Accept-Language'] = i18next.language
    return config
  },
  (error) => Promise.reject(error)
)

// Response interceptor for token refresh
AXIOS_INSTANCE.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    // On server, skip all client-only response handling (token refresh, redirect) and reject
    // immediately — the module-level isRefreshing/failedQueue machinery must never run during SSR.
    if (isServer) {
      return Promise.reject(error)
    }

    const originalRequest = error.config as InternalAxiosRequestConfig & { _retry?: boolean }

    // Only try to refresh on 401 errors
    if (error.response?.status !== 401 || !originalRequest || originalRequest._retry) {
      return Promise.reject(error)
    }

    // Nor on the public auth endpoints: a 401 there is a refused sign-in, not an expired token
    if (!refreshesOn401(originalRequest.url)) {
      return Promise.reject(error)
    }

    // Anonymous users have no session to refresh. A 401 on a public page
    // (e.g. an endpoint that requires auth called while browsing anonymously)
    // must not trigger a redirect to login — just propagate the error.
    if (!useAuthStore.getState().isAuthenticated) {
      return Promise.reject(error)
    }

    if (isRefreshing) {
      // If already refreshing, queue this request
      return new Promise((resolve, reject) => {
        failedQueue.push({ resolve, reject, config: originalRequest })
      })
    }

    originalRequest._retry = true
    isRefreshing = true

    try {
      const response = await fetch('/api/auth/refresh', {
        method: 'POST',
        credentials: 'include',
      })

      if (response.ok) {
        const data = await response.json()
        useAuthStore.getState().setAccessToken(data.accessToken)
        useAuthStore.getState().setUser(data.user)

        // Retry original request with new token
        originalRequest.headers.Authorization = `Bearer ${data.accessToken}`
        processQueue(null, data.accessToken)
        return AXIOS_INSTANCE(originalRequest)
      } else {
        // Refresh failed, clear auth state and redirect to login
        processQueue(error)
        useAuthStore.getState().setUser(null)
        useAuthStore.getState().setAccessToken(null)
        window.location.href = loginAndBack()
        return Promise.reject(error)
      }
    } catch (refreshError) {
      processQueue(refreshError)
      useAuthStore.getState().setUser(null)
      useAuthStore.getState().setAccessToken(null)
      window.location.href = loginAndBack()
      return Promise.reject(refreshError)
    } finally {
      isRefreshing = false
    }
  }
)

/** The sign-in page, bringing the visitor back to where the session ended once signed in again. */
function loginAndBack(): string {
  const { pathname, search } = window.location
  return `/login?next=${encodeURIComponent(pathname + search)}`
}

/**
 * A failed call, in the bug-report log: method, path without its query, status and business code —
 * never a body. The feedback endpoints are left out, or a failing report would log itself.
 */
function recordHttpFailure(error: AxiosError, code: string | undefined) {
  const path = pathOnly(error.config?.url ?? '')
  if (path.startsWith('/api/feedback')) return
  const status = error.response?.status ?? error.code ?? 'network'
  logEntry(
    'WARN',
    'http',
    `${(error.config?.method ?? 'get').toUpperCase()} ${path} ${status}${code ? ' ' + code : ''}`
  )
}

// Orval mutator function - returns unwrapped data (T, not AxiosResponse<T>)
export const axiosMutator = <T>(
  config: AxiosRequestConfig,
  options?: AxiosRequestConfig
): Promise<T> => {
  return AXIOS_INSTANCE({ ...config, ...options })
    .then(({ data }) => data)
    .catch((error) => {
      // Don't show toast for cancelled requests (e.g., component unmount)
      if (Axios.isCancel(error)) {
        throw error
      }

      if (Axios.isAxiosError(error)) {
        const axiosError = error as AxiosError
        const errorData = axiosError.response?.data as ErrorResponse | undefined
        if (!isServer) {
          recordHttpFailure(axiosError, errorData?.code)
        }

        // Don't show toast for 401 errors (handled by interceptor)
        if (axiosError.response?.status === 401) {
          throw error
        }

        if (errorData?.code) {
          const apiError = new ApiClientError(
            axiosError.status || 500,
            errorData,
            parseRetryAfter(axiosError.response?.headers?.['retry-after'])
          )
          // A read that finds nothing is the page's to say — its « introuvable » state already
          // does. A toast on top of it only repeats it, once per query the page makes.
          const isMissingRead =
            (config.method ?? 'get').toLowerCase() === 'get' && axiosError.response?.status === 404
          if (!isServer && !isMissingRead && !options?.skipErrorToast && !config.skipErrorToast) {
            notifications.show({
              message: i18next.t(`errors.api.${errorData.code}`, { ...errorData.errorDetails }),
              color: 'red',
            })
          }
          throw apiError
        }
      }
      throw error
    })
}

export type ErrorType<ApiClientError> = AxiosError<ApiClientError>
export type BodyType<BodyData> = BodyData
