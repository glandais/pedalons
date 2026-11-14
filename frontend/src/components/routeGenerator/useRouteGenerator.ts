import { useEffect, useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import type { GeoPoint, RouteGeneratorRequest, TeamDetailDto } from '@/api/dto'
import { generateRoutes } from '@/api/endpoints/route-generator/route-generator'
import { useGeneratorTypeCounts } from '@/pages/route/routeGeneratorData'
import { CLIENT_ONLY_QUERY } from '@/lib/prefetchAudit'
import {
  dominantGeneratorType,
  isEndFar,
  pointFromParam,
  routeGeneratorRequest,
  type GeneratorParams,
} from '@/lib/routeGenerator'

/** Seconds after which the generation is said to be building the team's graph (a cold cache). */
export const SLOW_HINT_MS = 4000

/** Why « Générer » is disabled, in the order the controls are laid out. */
export type GenerateBlocker = 'noStart' | 'noEnd' | 'typePending' | null

export interface GeneratorParamsWithGo extends GeneratorParams {
  /** « Générer » was pressed for these parameters. */
  go: boolean
  /** True while the end is « Ailleurs » and no point was picked yet. */
  endPending?: boolean
}

function teamPoint(team: TeamDetailDto): GeoPoint | undefined {
  const coordinates = team.geometry?.coordinates
  if (!coordinates || coordinates.length < 2) return undefined
  return { lng: coordinates[0], lat: coordinates[1] }
}

/** Two requests equal but for the seed: « Autres propositions » keeps the previous cards meanwhile. */
function sameButSeed(a: unknown, b: RouteGeneratorRequest): boolean {
  if (!a || typeof a !== 'object') return false
  return (
    JSON.stringify({ ...(a as RouteGeneratorRequest), seed: 0 }) ===
    JSON.stringify({ ...b, seed: 0 })
  )
}

/**
 * The generator's derived state and its query (ledger `WEB-179`).
 *
 * The call is a `useQuery` over a POST on purpose: the answer is a pure function of the request for
 * a given network (same seed, same routes), so caching it makes back-navigation and a return to an
 * earlier seed free under a rate limit of 30 requests per 15 minutes. Client-only: never prefetched.
 */
export function useRouteGenerator(team: TeamDetailDto, params: GeneratorParamsWithGo) {
  const { counts, isPending: typePending } = useGeneratorTypeCounts(team.slug)
  const dominantType = dominantGeneratorType(counts)
  const type = params.type ?? dominantType
  const teamStart = teamPoint(team)
  const start = pointFromParam(params.start) ?? teamStart
  const end = pointFromParam(params.end)
  const far = isEndFar(start, end, params.distanceKm)

  const blocker: GenerateBlocker = !start
    ? 'noStart'
    : params.endPending
      ? 'noEnd'
      : params.type === undefined && typePending
        ? 'typePending'
        : null
  const canGenerate = blocker === null

  const request = useMemo(
    () => routeGeneratorRequest(params, type, teamStart),
    [params, type, teamStart]
  )

  const query = useQuery({
    queryKey: ['routeGenerator', team.slug, request] as const,
    queryFn: ({ signal }) => generateRoutes(team.slug, request, { skipErrorToast: true }, signal),
    enabled: params.go && canGenerate,
    staleTime: Infinity,
    gcTime: 30 * 60_000,
    retry: false,
    refetchOnWindowFocus: false,
    placeholderData: (previous, previousQuery) =>
      previousQuery && sameButSeed(previousQuery.queryKey[2], request) ? previous : undefined,
    meta: { [CLIENT_ONLY_QUERY]: true },
  })

  // Nothing is shown for parameters « Générer » was not pressed for
  const active = params.go && canGenerate
  const isFetching = active && query.isFetching

  const [slow, setSlow] = useState(false)
  useEffect(() => {
    if (!isFetching) {
      setSlow(false)
      return
    }
    const timer = setTimeout(() => setSlow(true), SLOW_HINT_MS)
    return () => clearTimeout(timer)
  }, [isFetching])

  return {
    type,
    dominantType,
    typePending,
    start,
    end,
    far,
    blocker,
    canGenerate,
    request,
    data: active ? query.data : undefined,
    error: active ? query.error : null,
    isFetching,
    /** The cards on screen are the previous seed's, the new ones are on their way. */
    isPlaceholder: active && query.isPlaceholderData,
    slow,
    refetch: query.refetch,
  }
}
