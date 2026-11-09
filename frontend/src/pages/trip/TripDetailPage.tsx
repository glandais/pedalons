import { useState, useMemo } from 'react'
import { useParams, Navigate } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { paths } from '../../config/paths'
import { UserAvatarGroup } from '../../components/common/UserAvatar'
import { ParticipantListModal } from '../../components/ride/ParticipantListModal'
import {
  Box,
  Button,
  Container,
  Paper,
  Group,
  SimpleGrid,
  Stack,
  Title,
  Text,
  UnstyledButton,
} from '@mantine/core'
import { useTripDetailData } from './tripDetailData'
import { ReportTargetType, Status } from '@/api/dto'
import { useAuth } from '../../hooks/useAuth'
import { QueryStateBoundary } from '../../components/common/QueryStateBoundary'
import { DetailPageSkeleton } from '../../components/common/DetailPageSkeleton'
import { TripStageCard } from '../../components/trip/TripStageCard'
import { TripLayout } from '../../components/trip/TripLayout'
import { TeamContextBanner } from '../../components/team/TeamContextBanner'

import type { MapRouteItem } from '../../components/route/RoutesMapView'
import { formatPublicationSpan } from '../../utils/publicationTiming'
import { useEffectiveTimezone } from '../../utils/dateFormat'
import { DepartureBlock } from '../../components/common/DepartureBlock'
import { MediaDisplay } from '../../components/common/MediaDisplay'
import { CommentSection } from '../../components/comment'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { TripOverviewMap } from '@/components/trip/TripOverviewMap'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'
import { useTripMembership } from '@/hooks/useTripMembership'
import { AccessAlerts } from '@/components/publication/AccessAlerts'
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
  const [highlightedStageId, setHighlightedStageId] = useState<string | null>(null)
  const [showParticipants, setShowParticipants] = useState(false)
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
        <Box mt="md">
          <MediaDisplay media={trip.media} />
        </Box>
      </PublicationHeader>

      {/* Overview content — no stage-nav sidebar: the stage cards below are the single list */}
      <TripLayout trip={trip} teamSlug={teamSlug!} currentTab="overview" showStageNav={false}>
        <Stack>
          {/* Map + stages, side-by-side on desktop with the map kept sticky while stages scroll */}
          <SimpleGrid cols={{ base: 1, md: 2, xl: 3 }} spacing={{ base: 'md', sm: 'lg' }}>
            {/* Map: global route if defined, otherwise all stage routes. Shown first on mobile,
                spans 2 cols on xl, sticky on md+ (via .detail-map). */}
            <Box className="detail-map" style={{ order: 1 }}>
              {/* With a forecast, its Météo mode: every stage by its own wind (WEB-118) */}
              {mapItems.length > 0 && (
                <TripOverviewMap
                  trip={trip}
                  items={mapItems}
                  teamSlug={teamSlug!}
                  weather={weatherQuery.data}
                  highlightedItemId={highlightedStageId}
                  onItemHover={setHighlightedStageId}
                />
              )}
            </Box>

            {/* Stages list */}
            <Box style={{ order: 2 }}>
              <Title order={3} mb="md">
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
                      onHover={setHighlightedStageId}
                      isHighlighted={highlightedStageId === stage.id}
                      weather={
                        weatherQuery.data?.stages.find((w) => w.stageId === stage.id)?.summary
                      }
                    />
                  ))}
                </Stack>
              ) : (
                <Text c="dimmed">{t('trips.detail.stages.empty')}</Text>
              )}
            </Box>
          </SimpleGrid>

          {/* Participants section */}
          {trip.participantCount > 0 && (
            <Paper withBorder p="lg">
              <Title order={3} mb="md">
                {t('trips.detail.participants.title')}
              </Title>
              {canReadComments ? (
                <UnstyledButton
                  onClick={() => setShowParticipants(true)}
                  aria-label={t('trips.detail.participants.viewAll')}
                >
                  <Group gap="sm">
                    <UserAvatarGroup
                      users={trip.participants}
                      total={trip.participantCount}
                      max={8}
                      size="md"
                    />
                    <Text size="sm" c="dimmed">
                      {t('participantCount', { count: trip.participantCount })}
                    </Text>
                  </Group>
                </UnstyledButton>
              ) : (
                <Text size="sm" c="dimmed">
                  {t('participantCount', { count: trip.participantCount })}
                </Text>
              )}
            </Paper>
          )}

          <AccessAlerts
            kind="trip"
            teamSlug={teamSlug!}
            isAuthenticated={isAuthenticated}
            isMember={isMember}
          />

          {/* Comments Section - only visible to team members */}
          {canReadComments && team && (
            <Box>
              <CommentSection
                teamSlug={teamSlug!}
                teamName={team.name}
                entityType="trips"
                entitySlug={tripSlug!}
                isOrganizer={canEdit}
              />
            </Box>
          )}
        </Stack>
      </TripLayout>

      {/* Confirmation Dialogs */}
      {canReadComments && (
        <ParticipantListModal
          isOpen={showParticipants}
          onClose={() => setShowParticipants(false)}
          source={{ kind: 'trip', teamSlug: teamSlug!, tripSlug: trip.slug }}
          count={trip.participantCount}
          groupName={trip.name}
        />
      )}

      {statusActions.dialogs}
    </Container>
  )
}
