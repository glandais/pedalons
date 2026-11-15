/**
 * The site's route planner — its touch fullscreen editor — for the mobile app to show in a
 * WebView (docs/LEDGER_*.md WEB-183, MOB-170; plan `2026-11-15-planificateur-parcours-mobile.md`).
 *
 * Built by `pnpm build:mobile-planner` into `mobile/assets/planner/`. The planner is the site's
 * own (`useRoutePlanner`, `RoutePlanner`, `PlannerTouchFullscreen`, `lib/planner*.ts`): nothing of
 * it is ported to Dart, and the request fragment the app saves is computed by the site's
 * `plannerSubmit.ts`.
 *
 * The page is loaded from the app's assets (`file://`, origin `null`): it holds no token, no
 * cookie and no URL of ours. Flutter drives it through `window.pedalonsPlanner` and hears back on
 * the `PedalonsBridge` JavaScript channel; every API call is a message the app sends itself.
 * README.md describes the protocol.
 */
import './storageShim'
import { createRoot, type Root } from 'react-dom/client'
import { I18nextProvider } from 'react-i18next'
import { MantineProvider } from '@mantine/core'
import { Notifications } from '@mantine/notifications'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { AxiosError } from 'axios'
import { setWorkerUrl } from 'maplibre-gl'
import '@/index.css'
import './planner.css'
import { getGetConfigQueryKey } from '@/api/endpoints/configuration/configuration'
import i18n, { i18nReady, supportedLanguages } from '@/i18n'
import { AXIOS_INSTANCE } from '@/lib/axiosInstance'
import { setPlannerTransport } from '@/lib/plannerTransport'
import { cssVariablesResolver, theme } from '@/lib/theme'
import { usePreferencesStore } from '@/store/preferencesStore'
import {
  bridgeTransport,
  emitGpx,
  emitPosition,
  fileFromBase64,
  post,
  settleResponse,
  type BridgeResponse,
  type PlannerLoad,
} from './bridge'
import { PlannerApp } from './PlannerApp'
import { toMapConfig } from './styles'

interface PedalonsPlannerApi {
  /** Opens the planner. A second call starts over, on a fresh state. */
  load(input: PlannerLoad): void
  /** Answers a `request`. */
  response(response: BridgeResponse): void
  /** Answers `pickGpx`: the file picked, null when the picker was left. */
  gpx(file: { name: string; base64: string } | null): void
  /** Answers `locate`: the position, null when the app has none to give. */
  position(position: { lng: number; lat: number } | null): void
}

declare global {
  interface Window {
    pedalonsPlanner: PedalonsPlannerApi
    /** The source of MapLibre's worker, set by `worker-src.js` before this script. */
    __maplibreWorkerSource?: string
  }
}

// A failure nobody caught is the app's to know: a blank WebView says nothing.
window.addEventListener('error', (event) => post({ type: 'error', message: event.message }))
window.addEventListener('unhandledrejection', (event) =>
  post({ type: 'error', message: String(event.reason) })
)

// The planner's three calls go through the app. Anything else the site's client would send from
// here has nowhere to go (no origin, no session): refused before it leaves, should a shared
// component ever try.
setPlannerTransport(bridgeTransport)
AXIOS_INSTANCE.defaults.adapter = (config) =>
  Promise.reject(
    new AxiosError(`the embedded planner has no network: ${config.url}`, AxiosError.ERR_NETWORK)
  )

// What the site reads from `GET /api/config` is put in the cache by `load`, and stays there.
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: Infinity,
      gcTime: Infinity,
      retry: false,
      refetchOnWindowFocus: false,
      refetchOnReconnect: false,
    },
  },
})

let root: Root | undefined
let loads = 0

async function load(input: PlannerLoad): Promise<void> {
  await i18nReady
  const locale = (supportedLanguages as readonly string[]).includes(input.locale)
    ? input.locale
    : 'fr'
  if (i18n.language !== locale) await i18n.changeLanguage(locale)
  usePreferencesStore.setState({ unitSystem: input.units === 'IMPERIAL' ? 'IMPERIAL' : 'METRIC' })
  queryClient.setQueryData(getGetConfigQueryKey(), toMapConfig(input))

  const container = document.getElementById('planner')
  if (!container) throw new Error('#planner is missing')
  root ??= createRoot(container)
  loads += 1
  root.render(
    <I18nextProvider i18n={i18n}>
      <MantineProvider
        theme={theme}
        cssVariablesResolver={cssVariablesResolver}
        forceColorScheme={input.theme === 'dark' ? 'dark' : 'light'}
      >
        <Notifications position="top-center" />
        <QueryClientProvider client={queryClient}>
          <PlannerApp key={loads} load={input} />
        </QueryClientProvider>
      </MantineProvider>
    </I18nextProvider>
  )
}

window.pedalonsPlanner = {
  load: (input) => {
    load(input).catch((error: unknown) => post({ type: 'error', message: String(error) }))
  },
  response: settleResponse,
  gpx: (file) => emitGpx(file ? fileFromBase64(file.name, file.base64) : null),
  position: emitPosition,
}

// A worker cannot be loaded by URL from `file://`: its source comes as a string, turned into a
// Blob. Set here, after every module has run: `setupMaplibreWorker` (imported by the map) points
// MapLibre at the emitted file when it loads, and the last call wins.
if (window.__maplibreWorkerSource) {
  setWorkerUrl(
    URL.createObjectURL(new Blob([window.__maplibreWorkerSource], { type: 'text/javascript' }))
  )
}

void i18nReady.then(() => post({ type: 'ready' }))
