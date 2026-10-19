import type { QueryClient } from '@tanstack/react-query'
import {
  useGetPreview,
  useGetPreviewPlannerState,
  prefetchGetPreviewQuery,
} from '@/api/endpoints/gpx-previews/gpx-previews'
import { useAuthStore } from '@/store/authStore'

/**
 * The one description of what `EditGpxPreviewPage` reads, consumed two ways: the page calls
 * {@link useGpxPreviewFormData} for the query result, the `gpx-tools-edit` route in
 * `routes.config.ts` calls {@link prefetchGpxPreviewForm} for the same data server-side. Same
 * contract as `pages/gpxtool/gpxPreviewData.ts` (which serves the sibling view/map routes) — kept
 * as its own module rather than an export of that file, since a sibling change there shouldn't have
 * to touch this route's wiring, and rather than an export of the page, since `routes.config.ts`
 * imports companions eagerly and must not pull the page out of its lazy chunk.
 *
 * Editing is owner-only, gated in the page itself (`!preview.owned` redirects to the read view) —
 * the query is the same `getPreview` the public view/map routes prefetch, just reached through an
 * authenticated route. The prefetch gates on `useAuthStore.getState().isAuthenticated` (the server
 * has no hook — see `pages/auth/profileData.ts`) so an anonymous visitor hitting the URL directly
 * doesn't prefetch anything the auth guard will redirect away from anyway.
 */
export function useGpxPreviewFormData(previewId?: string) {
  return useGetPreview(previewId!, { query: { enabled: !!previewId } })
}

/**
 * The editing state saved with a preview (control points, pieces), readable by its creator only.
 * `enabled` is the page's call (owner, planner open on the domain, a single track). Not prefetched
 * server-side, never served from the cache: same reasons as `useEditRouteFormData`'s.
 */
export function useGpxPreviewPlannerState(previewId: string | undefined, enabled: boolean) {
  return useGetPreviewPlannerState(previewId!, {
    query: {
      enabled: enabled && !!previewId,
      staleTime: 0,
      gcTime: 0,
      retry: false,
      refetchOnWindowFocus: false,
    },
    request: { skipErrorToast: true },
  })
}

/** Server-side counterpart of {@link useGpxPreviewFormData}. */
export async function prefetchGpxPreviewForm(
  queryClient: QueryClient,
  previewId: string
): Promise<void> {
  if (!useAuthStore.getState().isAuthenticated) return
  await prefetchGetPreviewQuery(queryClient, previewId)
}
