import { useEffect } from 'react'
import { Navigate, useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { MapColorFullscreenView } from '@/components/route/MapColorFullscreenView'
import { LoadingPage } from '@/components/common/LoadingSpinner'
import { paths } from '@/config/paths'
import { useAppName } from '@/hooks/useAppName'
import { useCanonicalPath } from '@/hooks/useCanonicalPath'
import { useRideDetailData } from './rideDetailData'
import { groupWindLeg } from './rideGroupData'

/**
 * A solo ride's map in full screen (`…/rides/{rideSlug}/map`, ledger WEB-118, plan
 * 2026-10-24-weather-on-map.md §5 palier 3 lot B): its one group's route — the URL keeps the id of
 * a group that has no page to itself (WEB-79) —, plus the Météo mode of the ride's page when it
 * offers it (`groupWindLeg`, the group page's own rule). Bare layout, so it owns its
 * `document.title`.
 *
 * The mode arrives in the URL (`?color=wind`, `MapColorFullscreenView`), which the ride's page
 * writes on its fullscreen button. Its data is the ride page's (`rideDetailData.ts`), under the same
 * keys. A ride with no group or several has no such map: the route's loader sends it to the ride
 * (`rideMapDataRedirect`), and this page does when it could not — as it does for a group without a
 * route to draw.
 */
export function RideFullscreenMapPage() {
  const { teamSlug, rideSlug } = useParams<{ teamSlug: string; rideSlug: string }>()
  const { t } = useTranslation()
  const appName = useAppName()

  const {
    team: { data: team, isLoading: isLoadingTeam },
    ride: { data: ride, isLoading: isLoadingRide },
    weather,
    routes,
    routesBySlug,
    soloGroup: solo,
    soloLeg,
  } = useRideDetailData(teamSlug, rideSlug)

  const routeSlug = solo ? (solo.routeSlug ?? ride?.routeSlug) : undefined
  const route = routeSlug ? routesBySlug.get(routeSlug) : undefined

  useCanonicalPath(team && ride && solo ? paths.rideMap(team.slug, ride.slug) : undefined)

  const title = ride?.name ?? ''
  useEffect(() => {
    if (title) {
      document.title = appName ? `${title} — ${appName}` : title
    }
  }, [title, appName])

  if (isLoadingTeam || isLoadingRide || (routeSlug && routes.isLoading)) {
    return <LoadingPage message={t('loading')} />
  }

  // No team, no ride, no group or several, or no route to draw: the ride's page says what it has
  if (!team || !ride || !solo || !route) {
    return <Navigate to={paths.ride(teamSlug!, ride?.slug ?? rideSlug!)} replace />
  }

  const windLeg = groupWindLeg(ride, soloLeg)

  return (
    <MapColorFullscreenView
      route={route}
      title={title}
      backTo={paths.ride(team.slug, ride.slug)}
      windLeg={windLeg}
      windAttribution={windLeg ? weather.data?.attribution : undefined}
      timezone={ride.timezone}
    />
  )
}
