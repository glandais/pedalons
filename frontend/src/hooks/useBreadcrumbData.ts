import { useTranslation } from 'react-i18next'
import { useGetTeam } from '../api/endpoints/teams/teams'
import { useGetRide } from '../api/endpoints/rides/rides'
import { useGetTrip } from '../api/endpoints/trips/trips'
import { useGetRoute } from '../api/endpoints/routes/routes'
import { useGetTemplate } from '../api/endpoints/ride-templates/ride-templates'
import { useGetAd } from '../api/endpoints/ads/ads'
import { useGetPost } from '../api/endpoints/posts/posts'
import { useGetPage } from '../api/endpoints/team-pages/team-pages'
import type { RouteParams, EntityType } from '../config/routes.types'
import type { TeamDetailDto, TeamPublicationDto } from '../api/dto'

interface EntityData {
  name: string | undefined
  isLoading: boolean
}

/**
 * The breadcrumb reads the entities the page reads, through observers that stay mounted across
 * navigations and only change their key. That path (`setOptions`) ignores `retryOnMount`: an
 * entity the route's loader just failed to read was read again, right behind the page — a 404
 * twice, a 500 through a second round of retries while the page went back to its skeleton. The
 * page owns the error and its retry; the breadcrumb waits for data instead of asking again.
 */
export function onlyIfNotFailed(wanted: boolean) {
  return (query: { state: { status: string } }) => wanted && query.state.status !== 'error'
}

/** The breadcrumb's entity names, and what it knows of the team they belong to. */
export type BreadcrumbData = Record<EntityType, EntityData> & {
  /** The team, when it was read — never for a team the page's entity says is closed. */
  teamDetail: TeamDetailDto | undefined
  /**
   * The page's entity says its team does not answer the reader (`team.accessible` false: a private
   * team's public content, read by link): the team's crumbs are named, never linked
   * (docs/LEDGER_*.md WEB-166).
   */
  teamClosed: boolean
}

/**
 * The team an entity page belongs to, as the entity embeds it: the first of the entities in the
 * params that has been read, `undefined` while none is. Ads and ride templates are left out — they
 * are members-only, their team is always open to whoever reads them.
 */
export function entityTeamSummary(
  ...summaries: (Pick<TeamPublicationDto, 'accessible' | 'name'> | undefined)[]
): Pick<TeamPublicationDto, 'accessible' | 'name'> | undefined {
  return summaries.find((summary) => !!summary)
}

/**
 * Hook to fetch entity names for breadcrumbs
 * Only fetches data for entities present in params
 */
export function useBreadcrumbData(params: RouteParams): BreadcrumbData {
  const {
    teamSlug,
    rideSlug,
    postSlug,
    tripSlug,
    stageSlug,
    routeSlug,
    templateSlug,
    adSlug,
    pageSlug,
    groupId,
  } = params
  const { t } = useTranslation()

  // Fetch entities conditionally based on params
  const { data: ride, isLoading: isLoadingRide } = useGetRide(teamSlug!, rideSlug!, {
    query: { enabled: onlyIfNotFailed(!!teamSlug && !!rideSlug) },
  })
  const { data: post, isLoading: isLoadingPost } = useGetPost(teamSlug!, postSlug!, {
    query: { enabled: onlyIfNotFailed(!!teamSlug && !!postSlug) },
  })
  const { data: trip, isLoading: isLoadingTrip } = useGetTrip(teamSlug!, tripSlug!, {
    query: { enabled: onlyIfNotFailed(!!teamSlug && !!tripSlug) },
  })
  const { data: route, isLoading: isLoadingRoute } = useGetRoute(teamSlug!, routeSlug!, {
    query: { enabled: onlyIfNotFailed(!!teamSlug && !!routeSlug) },
  })
  const { data: rideTemplate, isLoading: isLoadingTemplate } = useGetTemplate(
    teamSlug!,
    templateSlug!,
    { query: { enabled: onlyIfNotFailed(!!teamSlug && !!templateSlug) } }
  )
  const { data: ad, isLoading: isLoadingAd } = useGetAd(teamSlug!, adSlug!, {
    query: { enabled: onlyIfNotFailed(!!teamSlug && !!adSlug) },
  })
  const { data: teamPage, isLoading: isLoadingTeamPage } = useGetPage(teamSlug!, pageSlug!, {
    query: { enabled: onlyIfNotFailed(!!teamSlug && !!pageSlug) },
  })

  // On a page of an entity that carries its team (a ride, a post, a trip, a route, a page), the team
  // waits for it: read only once the entity says the team answers the reader (docs/LEDGER_*.md
  // WEB-166) — a private team's public content is read by link, `GET team` would answer 404.
  const withEntity = !!(rideSlug || postSlug || tripSlug || routeSlug || pageSlug)
  const summary = entityTeamSummary(ride?.team, post?.team, trip?.team, route?.team, teamPage?.team)
  const teamWanted = !!teamSlug && (!withEntity || !!summary?.accessible)
  const { data: team, isLoading: isLoadingTeam } = useGetTeam(teamSlug!, {
    query: { enabled: onlyIfNotFailed(teamWanted) },
  })
  const teamClosed = summary?.accessible === false

  // A group's name comes from its ride's groups — « Groupe Rapide », as its page titles it
  const group = groupId ? ride?.groups?.find((g) => g.id === groupId) : undefined

  // Stage name comes from trip's stages array
  const stage = stageSlug ? trip?.stages?.find((s) => s.slug === stageSlug) : undefined

  return {
    team: { name: team?.name ?? summary?.name, isLoading: isLoadingTeam },
    teamDetail: team,
    teamClosed,
    ride: { name: ride?.name, isLoading: isLoadingRide },
    rideGroup: {
      name: group && t('rides.group.title', { name: group.name }),
      isLoading: isLoadingRide,
    },
    post: { name: post?.name, isLoading: isLoadingPost },
    trip: { name: trip?.name, isLoading: isLoadingTrip },
    stage: { name: stage?.name, isLoading: isLoadingTrip },
    route: { name: route?.name, isLoading: isLoadingRoute },
    rideTemplate: { name: rideTemplate?.name, isLoading: isLoadingTemplate },
    ad: { name: ad?.name, isLoading: isLoadingAd },
    teamPage: { name: teamPage?.title, isLoading: isLoadingTeamPage },
  }
}
