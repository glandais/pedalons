import { useEffect, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import type { RouteRetouchRequest } from '@/api/dto'
import { retouchRoute } from '@/api/endpoints/route-generator/route-generator'
import { CLIENT_ONLY_QUERY } from '@/lib/prefetchAudit'

/** Seconds after which the call is said to be slow (a long route takes a few more). */
export const RETOUCH_SLOW_HINT_MS = 4000

/** Two requests equal but for the seed: « Autres propositions » keeps the previous cards meanwhile. */
function sameButSeed(a: unknown, b: RouteRetouchRequest): boolean {
  if (!a || typeof a !== 'object') return false
  return (
    JSON.stringify({ ...(a as RouteRetouchRequest), seed: 0 }) === JSON.stringify({ ...b, seed: 0 })
  )
}

/**
 * The proposals of one retouch (ledger `API-212`). A `useQuery` over a POST on purpose, like the
 * generator's: the answer is a pure function of the request for a given track and map, so caching
 * it makes a return to an earlier seed free under a rate limit of 30 requests per 15 minutes.
 * Client only; nothing is sent while `request` is undefined.
 */
export function useRouteRetouch(
  teamSlug: string,
  routeSlug: string,
  request: RouteRetouchRequest | undefined,
  /** A mark of the saved track (its last change): a cached answer never outlives an edit of it. */
  trackMark = ''
) {
  const query = useQuery({
    queryKey: ['routeRetouch', teamSlug, routeSlug, request, trackMark] as const,
    queryFn: ({ signal }) =>
      retouchRoute(teamSlug, routeSlug, request!, { skipErrorToast: true }, signal),
    enabled: request !== undefined,
    staleTime: Infinity,
    gcTime: 30 * 60_000,
    retry: false,
    refetchOnWindowFocus: false,
    placeholderData: (previous, previousQuery) =>
      request && previousQuery && sameButSeed(previousQuery.queryKey[3], request)
        ? previous
        : undefined,
    meta: { [CLIENT_ONLY_QUERY]: true },
  })

  const active = request !== undefined
  const isFetching = active && query.isFetching
  const [slow, setSlow] = useState(false)
  useEffect(() => {
    if (!isFetching) {
      setSlow(false)
      return
    }
    const timer = setTimeout(() => setSlow(true), RETOUCH_SLOW_HINT_MS)
    return () => clearTimeout(timer)
  }, [isFetching])

  return {
    data: active ? query.data : undefined,
    error: active ? query.error : null,
    isFetching,
    /** The cards on screen are the previous seed's, the new ones are on their way. */
    isPlaceholder: active && query.isPlaceholderData,
    slow,
    refetch: query.refetch,
  }
}
