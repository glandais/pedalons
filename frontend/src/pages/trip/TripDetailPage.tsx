import { useState, useMemo } from 'react'
import { useParams, Navigate } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { paths } from '../../config/paths'
import { Box, Button, Container, Stack, Title, Text } from '@mantine/core'
import { useTripDetailData } from './tripDetailData'
import { ReportTargetType, Status } from '@/api/dto'
import { useAuth } from '../../hooks/useAuth'
import { QueryStateBoundary } from '../../components/common/QueryStateBoundary'
import { DetailPageSkeleton } from '../../components/common/DetailPageSkeleton'
import { TripStageCard } from '../../components/trip/TripStageCard'
import { TeamContextBanner } from '../../components/team/TeamContextBanner'

import type { MapRouteItem } from '../../components/route/RoutesMapView'
import { formatPublicationSpan } from '../../utils/publicationTiming'
import { useEffectiveTimezone } from '../../utils/dateFormat'
import { DepartureBlock } from '../../components/common/DepartureBlock'
import { CommentSection } from '../../components/comment'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { TripOverviewMap } from '@/components/trip/TripOverviewMap'
import { ErrorBoundary } from '@/components/common/ErrorBoundary'
import { RouteWeatherSection } from '@/components/weather/RouteWeatherSection'
import { tripOffersWind } from '@/lib/tripWeatherOnMap'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'
import { useTripMembership } from '@/hooks/useTripMembership'
import { AccessAlerts } from '@/components/publication/AccessAlerts'
import { InstructionsBlock } from '@/components/publication/InstructionsBlock'
import { ParticipantsSection } from '@/components/publication/ParticipantsSection'
import { FactsStrip } from '@/components/publication/FactsStrip'
import { PublicationHeader } from '@/components/publication/PublicationHeader'
import { tripFacts } from '@/components/publication/publicationFacts'
import { usePublicationStatusActions } from '@/components/publication/usePublicationStatusActions'

export function TripDetailPage() {
  const { t, i18n } = useTranslation()
  // The fallback zone of the span for a trip whose zone this browser lacks (API-60).
  const { timezone: readerZone } = useEffectiveTimezone()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const { teamSlug, tripSlug } = useParams<{ teamSlug: string; tripSlug: string }>()
  const { isAuthenticated, user } = useAuth()
  // The hovered stage, and the one chosen by a click on its trace — lit on the map and on its card
  // until a card's hover replaces it, as on a ride (docs/LEDGER_*.md WEB-155).
  const [highlightedStageId, setHighlightedStageId] = useState<string | null>(null)
  const [selectedStageId, setSelectedStageId] = useState<string | null>(null)
  const litStageId = highlightedStageId ?? selectedStageId
  const chooseStage = (stageId: string) => {
    setSelectedStageId(stageId)
    setHighlightedStageId(null)
  }
  const hoverStage = (stageId: string | null) => {
    setHighlightedStageId(stageId)
    if (stageId) setSelectedStageId(null)
  }
  const {
    team: teamQuery,
    trip: tripQuery,
    weather: weatherQuery,
  } = useTripDetailData(teamSlug, tripSlug)
  const { data: team, isLoading: isLoadingTeam } = teamQuery
  const { data: trip, isLoading: isLoadingTrip, error, refetch } = tripQuery

  const statusActions = usePublicationStatusActions(
    teamSlug!,
    'trip',
    trip ? { kind: 'trip', dto: trip } : null
  )
  const membership = useTripMembership(teamSlug!, tripSlug!)

  useCanonicalPath(team && trip ? paths.trip(team.slug, trip.slug) : undefined)

  // Stable reference so hovering a stage (which re-renders this page) doesn't re-trigger the
  // map's route-loading effect — that would refetch every route and refit the map on each hover.
  const mapItems: MapRouteItem[] = useMemo(() => {
    if (!trip) return []
    if (trip.routeSlug) {
      return [{ id: trip.id, name: trip.name, routeSlug: trip.routeSlug }]
    }
    return (trip.stages ?? []).map((stage) => ({
      id: stage.id,
      name: stage.name,
      routeSlug: stage.route?.slug,
    }))
  }, [trip])

  if (!isLoadingTeam && !team) {
    return <Navigate to={paths.teams()} replace />
  }

  if (team && (!team.enableTrips || !team.enableRoutes)) {
    return <Navigate to={paths.team(teamSlug!)} replace />
  }

  if (isLoadingTeam || isLoadingTrip || error || !trip) {
    return (
      <Container size="xl" py="xl">
        <QueryStateBoundary
          isLoading={isLoadingTeam || isLoadingTrip}
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

  // Registering and the join banner follow the real membership; editing and the comment thread
  // (moderation), the rights a platform admin holds in every team (docs/LEDGER_*.md API-137).
  const { isMember, isOrganizer: canEdit } = teamAccess(team, isPlatformAdmin)
  const canReadComments = isMember || isPlatformAdmin
  // Told by the server: `participants` is only a preview of the first few (ledger API-12).
  const hasJoined = !!user && trip.registered
  // Not once it is over: the server refuses it (TRIP_FINISHED, docs/LEDGER_*.md API-161), as a ride
  // that has left (RIDE_PAST). Leaving stays open.
  // One leg in all: the trip's only stage, or the trip's own route without stages.
  const stageCount = trip.stages?.length ?? 0
  const onlyStage = stageCount === 1 ? trip.stages[0] : undefined
  const singleLeg =
    stageCount <= 1 && weatherQuery.data?.stages.length === 1
      ? weatherQuery.data.stages[0]
      : undefined
  const canJoinTrip = isMember && trip.status === Status.PUBLISHED && !hasJoined && !trip.finished

  return (
    <Container size="xl" py="xl">
      {/* Way back to the team: this page is not mounted inside TeamLayout */}
      {team && <TeamContextBanner team={team} />}

      <PublicationHeader
        kind="trip"
        publication={trip}
        reportTargetType={ReportTargetType.TRIP}
        statusActions={canEdit ? statusActions : null}
        editPath={paths.tripEdit(teamSlug!, tripSlug!)}
        error={membership.error}
        joinActions={
          <>
            {canJoinTrip && (
              <Button onClick={membership.join} disabled={membership.isPending}>
                {t('trips.detail.actions.join')}
              </Button>
            )}
            {hasJoined && (
              <Button variant="outline" onClick={membership.leave} disabled={membership.isPending}>
                {t('trips.detail.actions.leave')}
              </Button>
            )}
          </>
        }
      >
        {/* The departure, under the title, before the description (docs/BRANDING.md §7.8,
            docs/LEDGER_*.md WEB-137): the first stage's day and time, the trip's span, its end. */}
        <Stack gap="sm">
          <DepartureBlock
            date={trip.dateTime}
            zone={trip.timezone}
            tone="teal"
            dayLine={formatPublicationSpan(trip, 'full', i18n.language, t, readerZone)}
          />
          <FactsStrip kind="trip" facts={tripFacts(trip)} />
        </Stack>
      </PublicationHeader>

      {/* Variant A (docs/LEDGER_*.md WEB-134), the ride page's (WEB-155): the instructions, the
          stages and who takes part in the side column, the map sticky beside it on md+, filling
          the visible height; stacked below md, map first. */}
      <Box
        className={mapItems.length > 0 ? 'detail-layout' : 'detail-layout detail-layout--no-map'}
        mb={{ base: 'md', sm: 'lg' }}
      >
        <Stack className="detail-side" gap="lg">
          <InstructionsBlock media={trip.media} testId="trip-instructions" />

          <Box data-testid="trip-stages">
            <Title order={3} size="h4" mb="md">
              {t('trips.detail.stages.title')}
            </Title>
            {trip.stages && trip.stages.length > 0 ? (
              <Stack gap="sm">
                {trip.stages.map((stage, index) => (
                  <TripStageCard
                    key={stage.id}
                    stage={stage}
                    index={index}
                    teamSlug={teamSlug!}
                    tripSlug={trip.slug}
                    onHover={hoverStage}
                    isHighlighted={litStageId === stage.id}
                    weather={weatherQuery.data?.stages.find((w) => w.stageId === stage.id)?.summary}
                  />
                ))}
              </Stack>
            ) : (
              <Text c="dimmed">{t('trips.detail.stages.empty')}</Text>
            )}
          </Box>

          {trip.participantCount > 0 && (
            <ParticipantsSection
              source={{ kind: 'trip', teamSlug: teamSlug!, tripSlug: trip.slug }}
              count={trip.participantCount}
              titleId="trip-participants-title"
              canSeeParticipants={canReadComments}
            />
          )}
        </Stack>

        {/* With a forecast, its Météo mode: every stage by its own wind (WEB-118). The map's
            controls sit under it: the --solo height keeps room for them. */}
        {mapItems.length > 0 && (
          <Box className="detail-map detail-map--fill detail-map--solo">
            <TripOverviewMap
              trip={trip}
              items={mapItems}
              teamSlug={teamSlug!}
              weather={weatherQuery.data}
              highlightedItemId={litStageId}
              onItemHover={setHighlightedStageId}
              selectedItemId={selectedStageId}
              onItemSelect={chooseStage}
            />
          </Box>
        )}
      </Box>

      {/* A trip of one stage — or of none, riding its own route — unrolls that leg's whole weather
          here, full width before the comments, as a solo ride does its group's (WEB-155). Its
          stage page keeps the same section. */}
      {singleLeg && (
        <Box id="meteo" mb="lg" style={{ scrollMarginTop: 'var(--app-shell-header-height)' }}>
          <ErrorBoundary variant="inline">
            <RouteWeatherSection
              subject="stage"
              offered={tripOffersWind(trip)}
              status={singleLeg.leg.status}
              availableFrom={singleLeg.leg.availableFrom}
              attribution={weatherQuery.data?.attribution}
              fetchedAt={singleLeg.leg.fetchedAt}
              departure={singleLeg.departure}
              departureTime={onlyStage?.dateTime ?? trip.dateTime}
              leg={singleLeg.leg}
              timezone={onlyStage?.timezone ?? trip.timezone}
              isLoading={weatherQuery.isLoading}
              isFetching={weatherQuery.isFetching}
              onRetry={() => void weatherQuery.refetch()}
              canEdit={canEdit}
              titleId="trip-weather-title"
            />
          </ErrorBoundary>
        </Box>
      )}

      <Box mb="lg">
        <AccessAlerts
          kind="trip"
          teamSlug={teamSlug!}
          isAuthenticated={isAuthenticated}
          isMember={isMember}
        />
      </Box>

      {/* Comments Section - only visible to team members */}
      {canReadComments && team && (
        <Box mt="lg">
          <CommentSection
            teamSlug={teamSlug!}
            teamName={team.name}
            entityType="trips"
            entitySlug={tripSlug!}
            isOrganizer={canEdit}
          />
        </Box>
      )}

      {statusActions.dialogs}
    </Container>
  )
}
