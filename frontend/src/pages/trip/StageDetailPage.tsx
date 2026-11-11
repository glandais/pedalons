import { useParams, Navigate } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { Badge, Box, Button, Container, Stack } from '@mantine/core'
import { IconPencil } from '@tabler/icons-react'
import { useStageDetailData } from './stageDetailData'
import { paths } from '../../config/paths'
import { useAuth } from '../../hooks/useAuth'
import { QueryStateBoundary } from '../../components/common/QueryStateBoundary'
import { DetailPageSkeleton } from '../../components/common/DetailPageSkeleton'
import { DepartureBlock } from '../../components/common/DepartureBlock'
import { PrefetchLink } from '../../components/common/PrefetchLink'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useScrollToAnchor } from '../../hooks/useScrollToAnchor'
import { ShareButton } from '../../components/common/ShareButton'
import { CommentSection } from '../../components/comment'
import { ErrorBoundary } from '@/components/common/ErrorBoundary'
import { AccessAlerts } from '@/components/publication/AccessAlerts'
import { ChildDetailShell } from '@/components/publication/ChildDetailShell'
import { InstructionsBlock } from '@/components/publication/InstructionsBlock'
import { PlacesLine } from '@/components/publication/PlacesLine'
import { RouteCard } from '@/components/publication/RouteCard'
import { StatsCard } from '@/components/publication/StatsCard'
import { CHILD_WEATHER_ANCHOR, useWeatherFocus } from '@/components/publication/useWeatherFocus'
import { RouteMapPanel } from '@/components/route/RouteMapPanel'
import { RouteWeatherSection } from '@/components/weather/RouteWeatherSection'
import { hasForecast } from '@/components/weather/weatherDisplay'
import { withMapColor } from '@/hooks/filters/mapColorFilters'
import { stageWindLeg, tripOffersWind } from '@/lib/tripWeatherOnMap'

/**
 * One stage of a trip, on the page every child of a publication shares with a ride's groups
 * (docs/LEDGER_*.md WEB-155, `ChildDetailShell`): the way back to the trip, the other stages either
 * side, its departure and places; its figures, its instructions and its route beside the sticky
 * map; the route's weather full width, the map's badges and the table sharing their point
 * (WEB-117); then its own comment thread, apart from the trip's.
 *
 * Its route is read on its own (`useStageDetailData`, polled while its elevation is refined), not in
 * the trip's bulk read. Nothing of the people: one joins the trip, not a stage.
 */
export function StageDetailPage() {
  const { t } = useTranslation()
  const { teamSlug, tripSlug, stageSlug } = useParams<{
    teamSlug: string
    tripSlug: string
    stageSlug: string
  }>()
  const { isAuthenticated } = useAuth()

  const {
    team: { data: fullTeam, isLoading: isLoadingTeam },
    trip: { data: trip, isLoading: isLoadingTrip, error, refetch },
    route: { data: route, isLoading: isLoadingRoute },
    routeSlug,
    weather,
  } = useStageDetailData(teamSlug, tripSlug, stageSlug)

  // Found in the trip already in cache, before the early returns: the weather focus is a hook.
  const stage = trip?.stages?.find((s) => s.slug === stageSlug)
  // The trip's embedded team: the page renders from it; the team itself, read only when the trip
  // says it answers the reader, decides the features redirect (docs/LEDGER_*.md WEB-166).
  const team = trip?.team
  const stageWeather = stage ? weather.data?.stages.find((w) => w.stageId === stage.id) : undefined
  const leg = stageWeather?.leg
  const weatherFocus = useWeatherFocus(stage?.id, leg)

  useCanonicalPath(
    team && trip && stageSlug ? paths.stage(team.slug, trip.slug, stageSlug) : undefined
  )
  // `#meteo` (the app's « Météo » tab shared): the section only exists once the trip is read.
  useScrollToAnchor(CHILD_WEATHER_ANCHOR, !!stage && !weather.isLoading)

  const isLoading = isLoadingTeam || isLoadingTrip || !!(routeSlug && isLoadingRoute)

  if (fullTeam && (!fullTeam.enableTrips || !fullTeam.enableRoutes)) {
    return <Navigate to={paths.team(teamSlug!)} replace />
  }

  if (isLoading || error || !trip || !team) {
    return (
      <Container size="xl" py="xl">
        <QueryStateBoundary
          isLoading={isLoading}
          isError={!!error}
          error={error}
          isNotFound={!trip}
          onRetry={() => void refetch()}
          skeleton={<DetailPageSkeleton />}
          notFound={{
            title: t('trips.detail.notFound.title'),
            message: t('trips.detail.notFound.message'),
            backTo: paths.team(teamSlug!),
            backLabel: t('trips.detail.notFound.backToTrips'),
          }}
        >
          {null}
        </QueryStateBoundary>
      </Container>
    )
  }

  if (!stage) {
    return (
      <Container size="xl" py="xl">
        <QueryStateBoundary
          isLoading={false}
          isNotFound
          notFound={{
            title: t('trips.stage.notFound.title'),
            message: t('trips.stage.notFound.message'),
            backTo: paths.trip(teamSlug!, tripSlug!),
            backLabel: t('trips.stage.notFound.backToTrip'),
          }}
        >
          {null}
        </QueryStateBoundary>
      </Container>
    )
  }

  // The backend's answers (docs/LEDGER_*.md WEB-166, decision D7): the stage's own block — editing
  // it is editing its trip, its thread is its own — and the trip's for who belongs.
  const canEdit = stage.permissions.canEdit
  const canReadComments = !!stage.permissions.canComment
  const isMember = !!trip.permissions.canSeeParticipants
  const stages = trip.stages ?? []
  const stageIndex = stages.findIndex((s) => s.id === stage.id)
  // The stage's Météo mode on its map, and on its fullscreen map (WEB-118)
  const windLeg = stageWindLeg(trip, weather.data, stage.id)
  const routeName = route?.name ?? stage.route?.name

  return (
    <ChildDetailShell
      backTo={paths.trip(team.slug, trip.slug)}
      backLabel={t('trips.stage.backToTrip')}
      parentName={t('trips.stage.parent', {
        trip: trip.name,
        index: stageIndex + 1,
        total: stages.length,
      })}
      siblings={stages.map((s, i) => ({
        id: s.id,
        href: paths.stage(team.slug, trip.slug, s.slug),
        label: t('trips.stage.option', { index: i + 1, name: s.name }),
      }))}
      currentId={stage.id}
      siblingLabel={t('trips.stage.selector')}
      title={stage.name}
      badges={
        <>
          {trip.registered && (
            <Badge color="primary" variant="light">
              {t('rides.detail.groups.joined')}
            </Badge>
          )}
          <ShareButton title={stage.name} />
        </>
      }
      actions={
        canEdit && (
          <Button
            component={PrefetchLink}
            to={paths.tripEdit(team.slug, trip.slug)}
            variant="outline"
            leftSection={<IconPencil size={16} />}
          >
            {t('actions.edit')}
          </Button>
        )
      }
      departure={
        <Stack gap="sm">
          <DepartureBlock date={stage.dateTime} zone={stage.timezone} place={stage.startPlace} />
          <PlacesLine end={stage.endPlace} />
        </Stack>
      }
      notices={
        <AccessAlerts
          kind="trip"
          teamSlug={team.slug}
          isAuthenticated={isAuthenticated}
          isMember={isMember}
          teamAccessible={team.accessible}
        />
      }
      side={
        <>
          <StatsCard
            timezone={stage.timezone}
            averageSpeed={stage.averageSpeed}
            distance={stage.route?.distance}
            elevationGain={stage.route?.elevationGain}
            arrival={leg && hasForecast(leg.status) ? leg.arrivalTime : undefined}
            testId="stage-stats"
          />
          <InstructionsBlock media={stage.media} testId="stage-instructions" />
          {routeSlug && routeName && (
            <RouteCard title={routeName} teamSlug={team.slug} routeSlug={routeSlug} route={route} />
          )}
        </>
      }
      map={
        routeSlug ? (
          <RouteMapPanel
            teamSlug={team.slug}
            routeSlug={routeSlug}
            route={route}
            leg={windLeg}
            attribution={windLeg ? weather.data?.attribution : undefined}
            timezone={stage.timezone}
            selectedCheckpoint={weatherFocus.open}
            onSelectCheckpoint={weatherFocus.selectFromMap}
            fullscreenPath={(colorBy) =>
              withMapColor(paths.stageMap(team.slug, trip.slug, stage.slug), colorBy)
            }
            withActions={false}
            heightVariant="sticky"
            subject="stage"
          />
        ) : null
      }
      weather={
        <ErrorBoundary variant="inline">
          <RouteWeatherSection
            subject="stage"
            // A stage the forecast no longer lists draws nothing, as before (API-76)
            offered={tripOffersWind(trip) && !(weather.data && !stageWeather)}
            status={leg?.status}
            availableFrom={leg?.availableFrom}
            attribution={weather.data?.attribution}
            fetchedAt={leg?.fetchedAt}
            departure={stageWeather?.departure}
            departureTime={stage.dateTime}
            leg={leg}
            timezone={stage.timezone}
            isLoading={weather.isLoading}
            isFetching={weather.isFetching}
            onRetry={() => void weather.refetch()}
            canEdit={canEdit}
            selection={weatherFocus.selection}
            onSelectionChange={weatherFocus.selectFromTable}
            titleId="stage-weather-title"
          />
        </ErrorBoundary>
      }
    >
      {/* The stage's own thread, apart from the trip's — members only, like every thread */}
      {canReadComments && (
        <Box>
          <CommentSection
            teamSlug={team.slug}
            teamName={team.name}
            entityType="stages"
            entitySlug={stage.slug}
            isOrganizer={canEdit}
          />
        </Box>
      )}
    </ChildDetailShell>
  )
}
