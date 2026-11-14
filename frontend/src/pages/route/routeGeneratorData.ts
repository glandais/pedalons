import type { QueryClient } from '@tanstack/react-query'
import { useGetTeam } from '@/api/endpoints/teams/teams'
import { useCountRoutes, prefetchCountRoutesQuery } from '@/api/endpoints/routes/routes'
import { SurfaceType } from '@/api/dto'

/**
 * The one description of what `RouteGeneratorPage` reads, consumed two ways: the page calls
 * {@link useRouteGeneratorData}, the `route-generate` route in `routes.config.ts` calls
 * {@link prefetchRouteGenerator} (ledger `WEB-179`). The team itself is covered by the
 * `teamScopedPrefetch` wrapper there.
 *
 * <p>The three counts decide the default type of the proposals (the team's most numerous kind of
 * route). The generation itself is a POST under a rate limit: it is client-only, never prefetched
 * (`useRouteGenerator`).
 */

/** The kinds counted, in the order that breaks a tie. `MIXED` is not a kind to generate. */
export const GENERATOR_COUNT_TYPES = [
  SurfaceType.ROAD,
  SurfaceType.GRAVEL,
  SurfaceType.MTB,
] as const

export function useGeneratorTypeCounts(teamSlug?: string) {
  const enabled = { query: { enabled: !!teamSlug } }
  const road = useCountRoutes(teamSlug!, { surfaceType: SurfaceType.ROAD }, enabled)
  const gravel = useCountRoutes(teamSlug!, { surfaceType: SurfaceType.GRAVEL }, enabled)
  const mtb = useCountRoutes(teamSlug!, { surfaceType: SurfaceType.MTB }, enabled)
  return {
    counts: { ROAD: road.data?.total, GRAVEL: gravel.data?.total, MTB: mtb.data?.total },
    // Settled, one way or the other: a failed count leaves ROAD as the default
    isPending: road.isPending || gravel.isPending || mtb.isPending,
  }
}

export function useRouteGeneratorData(teamSlug?: string) {
  const team = useGetTeam(teamSlug!, { query: { enabled: !!teamSlug } })
  const typeCounts = useGeneratorTypeCounts(teamSlug)
  return { team, typeCounts }
}

export async function prefetchRouteGenerator(queryClient: QueryClient, teamSlug: string) {
  await Promise.all(
    GENERATOR_COUNT_TYPES.map((surfaceType) =>
      prefetchCountRoutesQuery(queryClient, teamSlug, { surfaceType })
    )
  )
}
