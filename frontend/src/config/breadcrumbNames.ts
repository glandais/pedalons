import type { QueryClient } from '@tanstack/react-query'
import type { TFunction } from 'i18next'
import { groupTitle } from '@/utils/groupTitle'
import { tRegister } from '@/lib/i18nUtils'
import type { TranslationKey } from '@/lib/i18nUtils'
import { getGetTeamQueryKey } from '@/api/endpoints/teams/teams'
import { getGetRideQueryKey } from '@/api/endpoints/rides/rides'
import { getGetPostQueryKey } from '@/api/endpoints/posts/posts'
import { getGetTripQueryKey } from '@/api/endpoints/trips/trips'
import { getGetRouteQueryKey } from '@/api/endpoints/routes/routes'
import { getGetTemplateQueryKey } from '@/api/endpoints/ride-templates/ride-templates'
import { getGetAdQueryKey } from '@/api/endpoints/ads/ads'
import { getGetPageQueryKey } from '@/api/endpoints/team-pages/team-pages'
import { getGetPreviewQueryKey } from '@/api/endpoints/gpx-previews/gpx-previews'
import type { EntityType, RouteParams } from './routes.types'
import type { TeamPublicationDto } from '../api/dto'

/**
 * Pure (no React) computation of the names an entity page carries — shared by the breadcrumb hook,
 * the full-screen pages and the server, which reads them from the query cache its prefetches filled
 * (plan 2026-11-25 D2: client and server write the same tab title).
 */

type TeamSummary = Pick<TeamPublicationDto, 'accessible' | 'name'>

/**
 * The team an entity page belongs to, as the entity embeds it: the first of the entities in the
 * params that has been read, `undefined` while none is. Ads and ride templates are left out — they
 * are members-only, their team is always open to whoever reads them.
 */
export function entityTeamSummary(
  ...summaries: (TeamSummary | undefined)[]
): TeamSummary | undefined {
  return summaries.find((summary) => !!summary)
}

/** What names an entity whose name is unknown (not read yet, private, gone). */
export const ENTITY_PLACEHOLDERS: Record<EntityType, TranslationKey> = {
  team: tRegister('breadcrumb.placeholder.team'),
  ride: tRegister('breadcrumb.placeholder.ride'),
  rideGroup: tRegister('breadcrumb.placeholder.rideGroup'),
  post: tRegister('breadcrumb.placeholder.post'),
  trip: tRegister('breadcrumb.placeholder.trip'),
  stage: tRegister('breadcrumb.placeholder.stage'),
  route: tRegister('breadcrumb.placeholder.route'),
  rideTemplate: tRegister('breadcrumb.placeholder.rideTemplate'),
  ad: tRegister('breadcrumb.placeholder.ad'),
  teamPage: tRegister('breadcrumb.placeholder.teamPage'),
  gpxPreview: tRegister('breadcrumb.placeholder.gpxPreview'),
}

export type EntityNames = Record<EntityType, string | undefined>

export interface BreadcrumbEntities {
  team?: { name?: string }
  ride?: {
    name?: string
    team?: TeamSummary
    groups?: { id?: string; name: string }[]
  }
  post?: { name?: string; team?: TeamSummary }
  trip?: {
    name?: string
    team?: TeamSummary
    stages?: { slug?: string; name?: string }[]
  }
  route?: { name?: string; team?: TeamSummary }
  rideTemplate?: { name?: string }
  ad?: { name?: string }
  teamPage?: { title?: string; team?: TeamSummary }
  gpxPreview?: { name?: string }
}

export function entityNames(e: BreadcrumbEntities, params: RouteParams, t: TFunction): EntityNames {
  const { ride, post, trip, route, teamPage, gpxPreview } = e
  const group = params.groupId ? ride?.groups?.find((g) => g.id === params.groupId) : undefined
  const stage = params.stageSlug
    ? trip?.stages?.find((s) => s.slug === params.stageSlug)
    : undefined
  const summary = entityTeamSummary(ride?.team, post?.team, trip?.team, route?.team, teamPage?.team)
  return {
    team: e.team?.name ?? summary?.name,
    ride: ride?.name,
    rideGroup: group && groupTitle(group.name, t),
    post: post?.name,
    trip: trip?.name,
    stage: stage?.name,
    route: route?.name,
    rideTemplate: e.rideTemplate?.name,
    ad: e.ad?.name,
    teamPage: teamPage?.title,
    gpxPreview: gpxPreview ? gpxPreview.name?.trim() || t('gpxTools.preview.title') : undefined,
  }
}

/** The server's side: the entities the route's prefetch put in the cache, under the hooks' own keys. */
export function entityNamesFromCache(
  queryClient: QueryClient,
  params: RouteParams,
  t: TFunction
): EntityNames {
  const { teamSlug, rideSlug, postSlug, tripSlug, routeSlug, templateSlug, adSlug, pageSlug } =
    params
  const get = <T>(key: readonly unknown[] | undefined): T | undefined =>
    key ? queryClient.getQueryData<T>(key) : undefined
  const forTeam = (
    slug: string | undefined,
    make: (team: string, slug: string) => readonly unknown[]
  ) => (teamSlug && slug ? make(teamSlug, slug) : undefined)
  return entityNames(
    {
      team: get(teamSlug ? getGetTeamQueryKey(teamSlug) : undefined),
      ride: get(forTeam(rideSlug, getGetRideQueryKey)),
      post: get(forTeam(postSlug, getGetPostQueryKey)),
      trip: get(forTeam(tripSlug, getGetTripQueryKey)),
      route: get(forTeam(routeSlug, getGetRouteQueryKey)),
      rideTemplate: get(forTeam(templateSlug, getGetTemplateQueryKey)),
      ad: get(forTeam(adSlug, getGetAdQueryKey)),
      teamPage: get(forTeam(pageSlug, getGetPageQueryKey)),
      gpxPreview: get(params.previewId ? getGetPreviewQueryKey(params.previewId) : undefined),
    },
    params,
    t
  )
}
