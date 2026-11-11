import type { QueryClient } from '@tanstack/react-query'
import { getGetRideQueryKey } from '@/api/endpoints/rides/rides'
import { getGetTripQueryKey } from '@/api/endpoints/trips/trips'
import { getGetPostQueryKey } from '@/api/endpoints/posts/posts'
import { getGetRouteQueryKey } from '@/api/endpoints/routes/routes'
import { getGetPageQueryKey } from '@/api/endpoints/team-pages/team-pages'
import type { TeamDetailDto, TeamPublicationDto } from '@/api/dto'
import { ApiClientError } from '@/lib/apiError'
import type { RouteParams } from './routes.types'

/** The entity a page shows, as the route's loaders left it in the cache. */
export interface EntityRead {
  /** Its embedded team summary, when the entity was read. */
  team: TeamPublicationDto | undefined
  /** Why it could not be read, when it could not. */
  error: unknown
}

/**
 * The entity a page shows, when the route has one: a ride (and its groups, its maps), a trip (and
 * its stages), a post, a route, a team page. Undefined on a page of the team itself.
 */
export function readEntity(queryClient: QueryClient, params: RouteParams): EntityRead | undefined {
  const { teamSlug, rideSlug, tripSlug, postSlug, routeSlug, pageSlug } = params
  if (!teamSlug) return undefined
  const key = rideSlug
    ? getGetRideQueryKey(teamSlug, rideSlug)
    : tripSlug
      ? getGetTripQueryKey(teamSlug, tripSlug)
      : postSlug
        ? getGetPostQueryKey(teamSlug, postSlug)
        : routeSlug
          ? getGetRouteQueryKey(teamSlug, routeSlug)
          : pageSlug
            ? getGetPageQueryKey(teamSlug, pageSlug)
            : undefined
  if (!key) return undefined
  return {
    team: queryClient.getQueryData<{ team: TeamPublicationDto }>(key)?.team,
    error: queryClient.getQueryState(key)?.error,
  }
}

export type TeamPageStatus = { kind: 'ok' } | { kind: 'notFound' } | { kind: 'moved'; slug: string }

/** A refusal that must read as « nothing here » (a 401, 403 or 404 of the API). */
function refused(error: unknown): boolean {
  return error instanceof ApiClientError && [401, 403, 404].includes(error.status)
}

/**
 * What a crawler must see on a team-scoped page, from what the loaders read (entry-server):
 *
 * - the team read under a former slug: the address moves for good (301);
 * - **an entity read successfully: its page is there**, whatever `GET team` answered — a private
 *   team's public content is read by link with the team closed, and its loaders do not even ask
 *   for the team (docs/LEDGER_*.md WEB-166, plan §5);
 * - an entity refused, or a team refused on a page of the team itself: a 404. A private team is
 *   not revealed to be private, same answer as a team that never existed — and its content no
 *   more than the team. Not when the session is unknown: the team may well be the member's, which
 *   the client finds out once its own refresh is through (docs/LEDGER_*.md WEB-39).
 */
export function teamPageStatus(input: {
  teamSlug: string
  team: TeamDetailDto | undefined
  teamError: unknown
  entity: EntityRead | undefined
  sessionKnown: boolean
}): TeamPageStatus {
  const { teamSlug, team, teamError, entity, sessionKnown } = input
  if (team && team.slug !== teamSlug) return { kind: 'moved', slug: team.slug }
  if (entity?.team) return { kind: 'ok' }
  if (!sessionKnown) return { kind: 'ok' }
  if (refused(entity?.error) || refused(teamError)) return { kind: 'notFound' }
  return { kind: 'ok' }
}
