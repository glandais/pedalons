import { useEffect, useState } from 'react'
import type { QueryClient } from '@tanstack/react-query'
import type { GpxPreviewDto, RideWeatherDto } from '@/api/dto'
import { WeatherStatus } from '@/api/dto'
import {
  getGetPreviewQueryKey,
  prefetchGetPreviewQuery,
  prefetchGetPreviewWeatherQuery,
  useGetPreview,
  useGetPreviewWeather,
} from '@/api/endpoints/gpx-previews/gpx-previews'
import { prefetchGetAvailableServicesQuery } from '@/api/endpoints/gps-services/gps-services'
import { useElevationRefetchInterval } from '@/hooks/useElevationRefetchInterval'
import { hasWindForecast } from '@/lib/weatherOnRoute'
import { useAuthStore } from '@/store/authStore'

/**
 * The one description of what a GPX preview screen reads, consumed two ways: `GpxPreviewPage` and
 * `GpxPreviewFullscreenMapPage` both call {@link useGpxPreviewData} for the query result, the
 * `gpx-tools-view` and `gpx-tools-map` routes in `routes.config.ts` call {@link prefetchGpxPreview}
 * for the same data server-side. There is only one call on each side — no derivation, no params
 * builder — but the module still exists so the two sides can't drift: the pages are identical
 * consumers of the same preview, and keeping the fetch and its prefetch declared once, next to the
 * page, is the point (not the amount of code it saves).
 *
 * Its own module rather than exports of either page: `routes.config.ts` is imported eagerly and
 * must not pull a page out of its lazy chunk (same contract as `pages/ride/rideDetailData.ts`).
 *
 * Neither route is `teamScopedPrefetch`-wrapped: the link is public and shareable — holding the
 * unguessable preview id is enough to view it, there is no team or auth gate to resolve first.
 *
 * `gpx-tools-view` (not `gpx-tools-map`) also mounts `GpxPreviewView`, which calls
 * `useGpsConnections()` — `useGetAvailableServices({ query: { enabled: isAuthenticated } })`, the
 * same gate `route-detail` prefetches behind in `pages/route/routeDetailData.ts`. The fullscreen
 * map (`RouteFullscreenView`) never mounts that component, so {@link prefetchGpxPreview} stays a
 * subset and {@link prefetchGpxPreviewView} is the one that covers it — asymmetric on purpose, not
 * a divergence.
 */
export function useGpxPreviewData(previewId?: string) {
  const refetchInterval = useElevationRefetchInterval()
  // Re-read while the HD elevation is still being computed (WEB-102).
  return useGetPreview(previewId!, { query: { enabled: !!previewId, refetchInterval } })
}

const POLL_MS = 15_000
const GIVE_UP_MS = 3 * 60_000
const WEATHER_REQUEST = { skipErrorToast: true } as const

/** A forecast on its way: the cache is empty, or a long track is arriving in rounds of the worker. */
const arriving = (status: string | undefined) =>
  status === WeatherStatus.UNAVAILABLE || status === WeatherStatus.STALE

/**
 * The weather of a preview that has a departure date: read from the server's cache only, which the
 * planner fills in the background. While nothing is there yet (`UNAVAILABLE`) or the track is only
 * partly there (`STALE`) it asks again every 15 s, for 3 minutes at most — the worker runs every
 * minute — then leaves the retry to the person (`retry` reopens the window). `polling` is true only
 * while waiting on an empty cache: a `STALE` forecast already has something to show.
 */
export function useGpxPreviewWeather(preview: GpxPreviewDto | undefined) {
  // The waiting window, reopened by `retry`
  const [waiting, setWaiting] = useState(true)
  useEffect(() => {
    if (!waiting) return
    const id = setTimeout(() => setWaiting(false), GIVE_UP_MS)
    return () => clearTimeout(id)
  }, [waiting])
  const weather = useGetPreviewWeather(preview?.id ?? '', {
    query: {
      enabled: !!preview?.departureTime,
      refetchInterval: (query) => (waiting && arriving(query.state.data?.status) ? POLL_MS : false),
    },
    request: WEATHER_REQUEST,
  })
  // A date cleared on save leaves the old forecast in the query cache (the query is only disabled):
  // without a date there is no forecast to show, to colour the map by or to poll for.
  const dated = !!preview?.departureTime
  const shown = dated ? weather : { ...weather, data: undefined }
  return {
    weather: shown,
    polling: waiting && dated && weather.data?.status === WeatherStatus.UNAVAILABLE,
    retry: () => {
      setWaiting(true)
      void weather.refetch()
    },
  }
}

/** The leg whose wind the map can colour by, undefined without a forecast. */
export function previewWindLeg(weather: RideWeatherDto | undefined) {
  const leg = weather?.legs[0]
  return hasWindForecast(leg) ? leg : undefined
}

/**
 * Server-side counterpart of {@link useGpxPreviewData}, in two steps: the weather is only worth
 * asking once the preview is known to have a departure. Safe to prefetch: the endpoint reads the
 * server's cache and never calls the provider. Shared by both routes: the detail page and its
 * fullscreen map read the exact same preview and its weather.
 */
export async function prefetchGpxPreview(
  queryClient: QueryClient,
  previewId: string
): Promise<void> {
  await prefetchGetPreviewQuery(queryClient, previewId)
  await prefetchPreviewWeather(queryClient, previewId)
}

async function prefetchPreviewWeather(queryClient: QueryClient, previewId: string): Promise<void> {
  const preview = queryClient.getQueryData<GpxPreviewDto>(getGetPreviewQueryKey(previewId))
  if (!preview?.departureTime) return
  await prefetchGetPreviewWeatherQuery(queryClient, previewId, { request: WEATHER_REQUEST })
}

/**
 * Server-side counterpart of what `GpxPreviewPage` actually renders: the preview plus the GPS
 * services `GpxPreviewView` reads through `useGpsConnections`, gated the same way — see the
 * docblock above.
 */
export async function prefetchGpxPreviewView(
  queryClient: QueryClient,
  previewId: string
): Promise<void> {
  await Promise.all([
    prefetchGpxPreview(queryClient, previewId),
    useAuthStore.getState().isAuthenticated
      ? prefetchGetAvailableServicesQuery(queryClient)
      : Promise.resolve(queryClient),
  ])
}
