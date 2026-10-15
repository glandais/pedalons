// First: Zod must not probe for eval before any schema is built (CSP, docs/LEDGER_*.md SEC-31).
import './lib/zodConfig'
import { StrictMode } from 'react'
import { createRoot, hydrateRoot } from 'react-dom/client'
import { hydrate } from '@tanstack/react-query'
import type { HydrationState } from 'react-router-dom'
import App from './App'
import { AppProviders } from './AppProviders'
import { HydrationMarker } from './components/common/HydrationMarker'
import { makeQueryClient } from './lib/queryClient'
import { fetchAppConfig, seedAppConfig } from './config/appConfig'
import { getGetConfigQueryKey } from './api/endpoints/configuration/configuration'
import i18n, { i18nReady } from './i18n'
import type { ConfigDto } from './api/dto'
import { hydrateAuthFromSSR } from './store/authStore'
import { ssrAuthState, ssrQueryState } from './lib/ssrState'
import { mapThemePreference } from './lib/theme'
import { installConsoleCapture } from './lib/feedback/clientLog'
import { installErrorCapture } from './lib/feedback/errorReporter'
import { installStaleChunkReload } from './lib/staleChunk'
import { captureInstallPrompt } from './lib/install/installStore'
import './index.css'

declare global {
  interface Window {
    /** Injected by StaticRouterProvider in the SSR markup (an inline script carrying the CSP nonce). */
    __staticRouterHydrationData?: HydrationState
  }
}

/**
 * Mirrors preferencesStore.ts's `initialUnitSystem`: the SSR session (the `#ssr-auth-state` data
 * block, parsed before this module runs) gives an authenticated visitor's theme here,
 * synchronously, letting the first client render match the server markup. Anonymous visitors keep
 * `'auto'` — the existing localStorage/prefers-color-scheme resolution is unaffected.
 */
const ssrSession = ssrAuthState()
const initialColorScheme = ssrSession?.user ? mapThemePreference(ssrSession.user.theme) : 'auto'

async function bootstrap() {
  // First, so that whatever goes wrong below is in the log of a bug report.
  installConsoleCapture()
  installErrorCapture()
  installStaleChunkReload()
  // Before anything is awaited: Chrome can fire its install prompt before React has mounted.
  captureInstallPrompt()

  // The initial client render must match the server markup, so i18n has to be ready first.
  await i18nReady

  const queryClient = makeQueryClient()
  const dehydratedState = ssrQueryState()

  // Hydrate the server-dehydrated cache BEFORE the router is created: buildRoutes()/getPinnedHistory
  // read config synchronously via getAppConfig(), so the config must already be present here.
  if (dehydratedState) {
    hydrate(queryClient, dehydratedState)
  }

  // The store's initial state is already seeded from the SSR session at module load (see
  // authStore.ts — that's what the first hydration render actually reads). This call just records
  // that fact via wasHydratedFromSSR(), so AuthEffects skips the post-hydration cache invalidation
  // it would otherwise run to repair an anonymous-then-authenticated render.
  if (ssrSession) {
    hydrateAuthFromSSR(ssrSession)
  }

  // The config drives single-team rooting and the pinned-team history, so it must be resolvable
  // synchronously before the first render. Prefer the dehydrated cache; fall back to a fetch.
  try {
    const config =
      queryClient.getQueryData<ConfigDto>(getGetConfigQueryKey()) ?? (await fetchAppConfig())
    seedAppConfig(config)
    queryClient.setQueryData(getGetConfigQueryKey(), config)
  } catch (error) {
    console.error('Failed to load app config', error)
  }

  const root = document.getElementById('root')
  if (!root) {
    throw new Error(
      '[SSR] Fatal: #root element not found in document. Cannot mount React application.'
    )
  }

  const app = (
    <StrictMode>
      <AppProviders i18n={i18n} queryClient={queryClient} defaultColorScheme={initialColorScheme}>
        <App queryClient={queryClient} />
      </AppProviders>
      <HydrationMarker />
    </StrictMode>
  )

  if (dehydratedState) {
    hydrateRoot(root, app, {
      onRecoverableError: (error, errorInfo) => {
        console.error('[hydration] Recoverable error:', error, errorInfo?.componentStack || '')
      },
    })
  } else {
    createRoot(root).render(app)
  }

  registerServiceWorker()
}

/**
 * The service worker makes the site installable and shows web push notifications. It caches
 * nothing (see public/sw.js). Registered once the page has loaded, so it never competes with
 * the page's own requests.
 */
function registerServiceWorker() {
  if (!('serviceWorker' in navigator)) return
  const register = () => {
    navigator.serviceWorker.register('/sw.js').catch((error: unknown) => {
      console.warn('Service worker registration failed', error)
    })
  }
  if (document.readyState === 'complete') register()
  else window.addEventListener('load', register, { once: true })
}

void bootstrap()
