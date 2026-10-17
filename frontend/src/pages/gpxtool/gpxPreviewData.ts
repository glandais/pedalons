import type { QueryClient } from '@tanstack/react-query'
import { useGetPreview, prefetchGetPreviewQuery } from '@/api/endpoints/gpx-previews/gpx-previews'
import { prefetchGetAvailableServicesQuery } from '@/api/endpoints/gps-services/gps-services'
import { useElevationRefetchInterval } from '@/hooks/useElevationRefetchInterval'
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

/**
 * Server-side counterpart of {@link useGpxPreviewData}. Shared by both routes: the detail page and
 * its fullscreen map read the exact same preview, nothing more.
 */
export async function prefetchGpxPreview(
  queryClient: QueryClient,
  previewId: string
): Promise<void> {
  await prefetchGetPreviewQuery(queryClient, previewId)
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
    prefetchGetPreviewQuery(queryClient, previewId),
    useAuthStore.getState().isAuthenticated
      ? prefetchGetAvailableServicesQuery(queryClient)
      : Promise.resolve(queryClient),
  ])
}
