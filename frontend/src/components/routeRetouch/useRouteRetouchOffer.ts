import { useGetRouteRetouchOffer } from '@/api/endpoints/route-generator/route-generator'
import { CLIENT_ONLY_QUERY } from '@/lib/prefetchAudit'

/**
 * Whether the route can be retouched by the reader, and within which bounds (ledger `API-212`).
 * Asked of a signed-in reader on a route that is not deleted; client only, never prefetched: the
 * answer depends on the engine's capabilities and on a heavy document. A failure shows nothing and
 * no toast: the action is a bonus, never a reason to bother the page.
 */
export function useRouteRetouchOffer(
  teamSlug: string | undefined,
  routeSlug: string | undefined,
  enabled: boolean
) {
  return useGetRouteRetouchOffer(teamSlug ?? '', routeSlug ?? '', {
    query: {
      enabled: enabled && !!teamSlug && !!routeSlug,
      staleTime: 5 * 60_000,
      retry: false,
      refetchOnWindowFocus: false,
      meta: { [CLIENT_ONLY_QUERY]: true },
    },
    request: { skipErrorToast: true },
  })
}
