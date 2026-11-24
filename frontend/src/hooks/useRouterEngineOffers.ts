import { useQuery } from '@tanstack/react-query'
import type { RouterEngineOffer } from '@/api/dto'
import { getRouterEnginesQueryKey } from '@/api/endpoints/router/router'
import { CLIENT_ONLY_QUERY } from '@/lib/prefetchAudit'
import { plannerTransport } from '@/lib/plannerTransport'

const FIVE_MINUTES = 5 * 60 * 1000

/**
 * The routing engines on offer to the planner (`GET /api/router/engines`), through the planner's
 * transport (the mobile app's bridge as much as the site's client). Undefined while it loads and
 * when the call fails: the planner then offers Stadia alone, silently.
 */
export function useRouterEngineOffers(teamSlug?: string): RouterEngineOffer[] | undefined {
  const { data } = useQuery({
    queryKey: getRouterEnginesQueryKey(teamSlug ? { teamSlug } : undefined),
    queryFn: ({ signal }) => plannerTransport().engines(teamSlug, signal),
    staleTime: FIVE_MINUTES,
    gcTime: 30 * 60 * 1000,
    retry: false,
    refetchOnWindowFocus: false,
    // Deliberately not prefetched server-side: only the planner reads it, a lazy client-only
    // editor that may not even mount (`route-edit` opens it on a single track of a planner team),
    // and through the planner's transport — the mobile app's bridge in the embed. Until it lands
    // the planner offers Stadia alone, as when the call fails.
    meta: { [CLIENT_ONLY_QUERY]: true },
  })
  return data?.engines
}
