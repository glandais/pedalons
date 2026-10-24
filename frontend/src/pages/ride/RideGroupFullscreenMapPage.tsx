import { useEffect } from 'react'
import { Navigate, useLocation, useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { MapColorFullscreenView } from '@/components/route/MapColorFullscreenView'
import { LoadingPage } from '@/components/common/LoadingSpinner'
import { paths } from '@/config/paths'
import { useAppName } from '@/hooks/useAppName'
import { useCanonicalPath } from '@/hooks/useCanonicalPath'
import { groupWindLeg, rideGroupMapLeavesTo, useRideGroupData } from './rideGroupData'

/**
 * A ride group's map in full screen (`…/groups/{groupId}/map`, ledger WEB-117, plan
 * 2026-10-24-weather-on-map.md §5 palier 3): the route viewer of a route or a stage, plus the
 * group's Météo mode — the line by the wind, the forecast's badges and their popups, the legend and
 * the credit — when its page would offer it (`groupWindLeg`). Bare layout, so it owns its
 * `document.title`.
 *
 * The mode arrives in the URL (`?color=wind`, `MapColorFullscreenView`), which the group's page
 * writes on its fullscreen button: a shared link shows the same map. Without it, the grade; a mode
 * the map cannot offer (no forecast, a finished ride, no surface) reads as the grade too. A switch
 * here rewrites the URL in place.
 *
 * Its data is the group's page's (`rideGroupData.ts`), under the same keys. A ride with at most one
 * group has no group page (WEB-79), so none of its maps either: a solo ride's map is the ride's own
 * (`rideMap`, WEB-118, the mode kept), a ride without groups goes to its page
 * (`rideGroupMapLeavesTo`) — the route's loader does it, and this page when it could not. A group
 * or a route it lacks sends back to the group's page, which says what is missing.
 */
export function RideGroupFullscreenMapPage() {
  const { teamSlug, rideSlug, groupId } = useParams<{
    teamSlug: string
    rideSlug: string
    groupId: string
  }>()
  const { t } = useTranslation()
  const appName = useAppName()
  const { search } = useLocation()

  const {
    team: { data: team, isLoading: isLoadingTeam },
    ride: { data: ride, isLoading: isLoadingRide },
    weather,
    routes,
    routesBySlug,
    group,
    leg,
  } = useRideGroupData(teamSlug, rideSlug, groupId)

  const leaveTo = ride && teamSlug ? rideGroupMapLeavesTo(ride, teamSlug, search) : undefined
  const leave = !!leaveTo
  const routeSlug = group ? (group.routeSlug ?? ride?.routeSlug) : undefined
  const route = routeSlug ? routesBySlug.get(routeSlug) : undefined

  useCanonicalPath(
    team && ride && groupId && !leave
      ? paths.rideGroupMap(team.slug, ride.slug, groupId)
      : undefined
  )

  const title =
    ride && group ? t('rides.group.mapTitle', { ride: ride.name, name: group.name }) : ''
  useEffect(() => {
    if (title) {
      document.title = appName ? `${title} — ${appName}` : title
    }
  }, [title, appName])

  if (isLoadingTeam || isLoadingRide || (routeSlug && routes.isLoading)) {
    return <LoadingPage message={t('loading')} />
  }

  if (leaveTo) {
    return <Navigate to={leaveTo} replace />
  }
  // No team, no ride, a group the ride no longer has, or no route to draw: the group's page says so
  if (!team || !ride || !group || !route) {
    return <Navigate to={paths.rideGroup(teamSlug!, rideSlug!, groupId!)} replace />
  }

  const windLeg = groupWindLeg(ride, leg)

  return (
    <MapColorFullscreenView
      route={route}
      title={title}
      backTo={paths.rideGroup(team.slug, ride.slug, group.id)}
      windLeg={windLeg}
      windAttribution={windLeg ? weather.data?.attribution : undefined}
      timezone={ride.timezone}
    />
  )
}
