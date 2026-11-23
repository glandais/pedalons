import { useQuery } from '@tanstack/react-query'
import type { RouterEngineOffer } from '@/api/dto'
import { getRouterEnginesQueryKey } from '@/api/endpoints/router/router'
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
  })
  return data?.engines
}
