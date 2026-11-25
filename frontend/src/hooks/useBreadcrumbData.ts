import { useTranslation } from 'react-i18next'
import { useGetTeam } from '../api/endpoints/teams/teams'
import { useGetRide } from '../api/endpoints/rides/rides'
import { useGetTrip } from '../api/endpoints/trips/trips'
import { useGetRoute } from '../api/endpoints/routes/routes'
import { useGetTemplate } from '../api/endpoints/ride-templates/ride-templates'
import { useGetAd } from '../api/endpoints/ads/ads'
import { useGetPost } from '../api/endpoints/posts/posts'
import { useGetPage } from '../api/endpoints/team-pages/team-pages'
import { useGetPreview } from '../api/endpoints/gpx-previews/gpx-previews'
import type { RouteParams } from '../config/routes.types'
import { entityNames, entityTeamSummary, type EntityNames } from '../config/breadcrumbNames'
import type { TeamDetailDto } from '../api/dto'

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
export interface BreadcrumbData {
  names: EntityNames
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
 * Hook to fetch entity names for breadcrumbs
 * Only fetches data for entities present in params
 */
export function useBreadcrumbData(params: RouteParams): BreadcrumbData {
  const {
    teamSlug,
    rideSlug,
    postSlug,
    tripSlug,
    routeSlug,
    templateSlug,
    adSlug,
    pageSlug,
    previewId,
  } = params
  const { t } = useTranslation()

  // Fetch entities conditionally based on params
  const { data: ride } = useGetRide(teamSlug!, rideSlug!, {
    query: { enabled: onlyIfNotFailed(!!teamSlug && !!rideSlug) },
  })
  const { data: post } = useGetPost(teamSlug!, postSlug!, {
    query: { enabled: onlyIfNotFailed(!!teamSlug && !!postSlug) },
  })
  const { data: trip } = useGetTrip(teamSlug!, tripSlug!, {
    query: { enabled: onlyIfNotFailed(!!teamSlug && !!tripSlug) },
  })
  const { data: route } = useGetRoute(teamSlug!, routeSlug!, {
    query: { enabled: onlyIfNotFailed(!!teamSlug && !!routeSlug) },
  })
  const { data: rideTemplate } = useGetTemplate(teamSlug!, templateSlug!, {
    query: { enabled: onlyIfNotFailed(!!teamSlug && !!templateSlug) },
  })
  const { data: ad } = useGetAd(teamSlug!, adSlug!, {
    query: { enabled: onlyIfNotFailed(!!teamSlug && !!adSlug) },
  })
  const { data: teamPage } = useGetPage(teamSlug!, pageSlug!, {
    query: { enabled: onlyIfNotFailed(!!teamSlug && !!pageSlug) },
  })

  // The same key as the page and its prefetches: no request of its own (the file's tab title, WEB-205).
  const { data: gpxPreview } = useGetPreview(previewId!, {
    query: { enabled: onlyIfNotFailed(!!previewId) },
  })

  // On a page of an entity that carries its team (a ride, a post, a trip, a route, a page), the team
  // waits for it: read only once the entity says the team answers the reader (docs/LEDGER_*.md
  // WEB-166) — a private team's public content is read by link, `GET team` would answer 404.
  const withEntity = !!(rideSlug || postSlug || tripSlug || routeSlug || pageSlug)
  const summary = entityTeamSummary(ride?.team, post?.team, trip?.team, route?.team, teamPage?.team)
  const teamWanted = !!teamSlug && (!withEntity || !!summary?.accessible)
  const { data: team } = useGetTeam(teamSlug!, {
    query: { enabled: onlyIfNotFailed(teamWanted) },
  })
  const teamClosed = summary?.accessible === false

  return {
    names: entityNames(
      { team, ride, post, trip, route, rideTemplate, ad, teamPage, gpxPreview },
      params,
      t
    ),
    teamDetail: team,
    teamClosed,
  }
}
