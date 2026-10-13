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

/**
 * Hook to fetch entity names for breadcrumbs
 * Only fetches data for entities present in params
 */
export function useBreadcrumbData(params: RouteParams): Record<EntityType, EntityData> {
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

  // Fetch team - needed for all team-related breadcrumbs
  const { data: team, isLoading: isLoadingTeam } = useGetTeam(teamSlug!, {
    query: { enabled: onlyIfNotFailed(!!teamSlug) },
  })

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

  // A group's name comes from its ride's groups — « Groupe Rapide », as its page titles it
  const group = groupId ? ride?.groups?.find((g) => g.id === groupId) : undefined

  // Stage name comes from trip's stages array
  const stage = stageSlug ? trip?.stages?.find((s) => s.slug === stageSlug) : undefined

  return {
    team: { name: team?.name, isLoading: isLoadingTeam },
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
