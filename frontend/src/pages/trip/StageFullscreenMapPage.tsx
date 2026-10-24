import { useEffect } from 'react'
import { Navigate, useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { MapColorFullscreenView } from '@/components/route/MapColorFullscreenView'
import { LoadingPage } from '@/components/common/LoadingSpinner'
import { paths } from '@/config/paths'
import { useAppName } from '@/hooks/useAppName'
import { useCanonicalPath } from '@/hooks/useCanonicalPath'
import { stageWindLeg } from '@/lib/tripWeatherOnMap'
import { useStageMapData } from './stageMapData'

/**
 * Fullscreen map for a trip stage's route (`.../map`). Bare layout (no AppShell), so it owns its own
 * `document.title`. Mirrors {@link StageDetailPage}'s data flow (`useGetTrip` → stage → `useGetRoute`);
 * a stage with no route falls back to the stage detail page.
 *
 * With the stage's forecast, the Météo mode of its page (ledger WEB-118, `stageWindLeg`: not for a
 * stage gone, nor on a trip over or cancelled): the line by the wind, the badges and their popups,
 * the legend and the credit. The mode arrives in the URL (`?color=wind`, `MapColorFullscreenView`),
 * which the stage's page writes on its fullscreen button; without it, the grade.
 */
export function StageFullscreenMapPage() {
  const { teamSlug, tripSlug, stageSlug } = useParams<{
    teamSlug: string
    tripSlug: string
    stageSlug: string
  }>()
  const { t } = useTranslation()
  const appName = useAppName()

  const {
    team: { data: team },
    trip: { data: trip, isLoading: isLoadingTrip },
    route: { data: route, isLoading: isLoadingRoute },
    routeSlug,
    weather,
  } = useStageMapData(teamSlug, tripSlug, stageSlug)

  const stage = trip?.stages?.find((s) => s.slug === stageSlug)

  useCanonicalPath(
    team && trip && stageSlug ? paths.stageMap(team.slug, trip.slug, stageSlug) : undefined
  )

  const title = stage?.name ?? route?.name ?? ''
  useEffect(() => {
    if (title) {
      document.title = appName ? `${title} — ${appName}` : title
    }
  }, [title, appName])

  if (isLoadingTrip || (routeSlug && isLoadingRoute)) {
    return <LoadingPage message={t('loading')} />
  }

  // No trip, no stage, or a stage without a route → back to the stage detail page.
  if (!team || !trip || !stage || !route) {
    return <Navigate to={paths.stage(teamSlug!, tripSlug!, stageSlug!)} replace />
  }

  const windLeg = stageWindLeg(trip, weather.data, stage.id)

  return (
    <MapColorFullscreenView
      route={route}
      title={title}
      backTo={paths.stage(team.slug, trip.slug, stageSlug!)}
      windLeg={windLeg}
      windAttribution={windLeg ? weather.data?.attribution : undefined}
      windSubject="stage"
      timezone={stage.timezone}
    />
  )
}
