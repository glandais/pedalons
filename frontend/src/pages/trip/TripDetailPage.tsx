import { useState, useMemo } from 'react'
import { getGetTeamDashboardQueryKey } from '@/api/endpoints/teams/teams'
import { useLocation, useParams, Navigate, useNavigate } from 'react-router-dom'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import { paths } from '../../config/paths'
import { UserAvatarGroup } from '../../components/common/UserAvatar'
import { ParticipantListModal } from '../../components/ride/ParticipantListModal'
import { useUnits } from '../../hooks/useUnits'
import {
  IconCalendar,
  IconUsers,
  IconPencil,
  IconStack2,
  IconArrowsMaximize,
  IconArrowUp,
  IconCalendarCheck,
  IconChevronDown,
} from '@tabler/icons-react'
import {
  Box,
  Button,
  Menu,
  Container,
  Paper,
  Group,
  SimpleGrid,
  Stack,
  Title,
  Text,
  Badge,
  UnstyledButton,
  Alert,
  Anchor,
  Loader,
} from '@mantine/core'
import {
  useUpdateTrip,
  useDeleteTrip,
  useUndeleteTrip,
  useJoinTrip,
  useLeaveTrip,
  getGetTripQueryKey,
} from '../../api/endpoints/trips/trips'
import { invalidateTripWeather, useTripDetailData } from './tripDetailData'
import { tripStatusRequest } from './tripFormData'
import { getListPublicationsQueryKey } from '../../api/endpoints/publications/publications'
import { ReportTargetType, Status } from '@/api/dto'
import { useAuth } from '../../hooks/useAuth'
import { QueryStateBoundary } from '../../components/common/QueryStateBoundary'
import { DetailPageSkeleton } from '../../components/common/DetailPageSkeleton'
import { TripStageCard } from '../../components/trip/TripStageCard'
import { TripLayout } from '../../components/trip/TripLayout'
import { TeamContextBanner } from '../../components/team/TeamContextBanner'
import { ConfirmDialog } from '../../components/common/ConfirmDialog'

import type { MapRouteItem } from '../../components/route/RoutesMapView'
import { Rendezvous } from '../../components/common/Rendezvous'
import { tripEndZone } from '../../utils/rendezvous'
import { MediaDisplay } from '../../components/common/MediaDisplay'
import { EntityLogo } from '../../components/common/EntityLogo'
import { ContentActionsMenu } from '../../components/moderation/ContentActionsMenu'
import { ShareButton } from '../../components/common/ShareButton'
import { CommentSection } from '../../components/comment'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { STATUS_COLORS } from '@/lib/badgeColors.generated'
import { TagList } from '@/components/tag'
import { TripOverviewMap } from '@/components/trip/TripOverviewMap'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'

export function TripDetailPage() {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const { teamSlug, tripSlug } = useParams<{ teamSlug: string; tripSlug: string }>()
  const { isAuthenticated, user } = useAuth()
  const [highlightedStageId, setHighlightedStageId] = useState<string | null>(null)
  const [showUnpublishConfirm, setShowUnpublishConfirm] = useState(false)
  const [showCancelConfirm, setShowCancelConfirm] = useState(false)
  const [showUncancelConfirm, setShowUncancelConfirm] = useState(false)
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)
  const [showParticipants, setShowParticipants] = useState(false)
  const { distance, elevation } = useUnits()

  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const location = useLocation()
  const {
    team: teamQuery,
    trip: tripQuery,
    weather: weatherQuery,
  } = useTripDetailData(teamSlug, tripSlug)
  const { data: team, isLoading: isLoadingTeam } = teamQuery
  const { data: trip, isLoading: isLoadingTrip, error, refetch } = tripQuery

  const updateMutation = useUpdateTrip()
  const deleteMutation = useDeleteTrip()
  const undeleteMutation = useUndeleteTrip()
  const joinMutation = useJoinTrip()
  const leaveMutation = useLeaveTrip()

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
  const canJoinTrip = isMember && trip.status === Status.PUBLISHED && !hasJoined

  // Rendezvous (docs/LEDGER_*.md API-60): the start in the trip's zone (its first stage's), the end
  // in its last stage's.
  const formattedDate = <Rendezvous date={trip.dateTime} zone={trip.timezone} variant="detail" />

  const handlePublish = () => {
    updateMutation.mutate(
      {
        teamSlug: teamSlug!,
        tripSlug: tripSlug!,
        data: tripStatusRequest(trip, Status.PUBLISHED),
      },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: getGetTripQueryKey(teamSlug!, tripSlug!) })
          void invalidateTripWeather(queryClient, teamSlug!, tripSlug!)
          queryClient.invalidateQueries({ queryKey: getListPublicationsQueryKey(teamSlug!) })
          notifications.show({ message: t('trips.notifications.published'), color: 'green' })
        },
      }
    )
  }

  const handleUnpublish = () => {
    updateMutation.mutate(
      {
        teamSlug: teamSlug!,
        tripSlug: tripSlug!,
        data: tripStatusRequest(trip, Status.DRAFT),
      },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: getGetTripQueryKey(teamSlug!, tripSlug!) })
          void invalidateTripWeather(queryClient, teamSlug!, tripSlug!)
          queryClient.invalidateQueries({ queryKey: getListPublicationsQueryKey(teamSlug!) })
          notifications.show({ message: t('trips.notifications.unpublished'), color: 'green' })
        },
      }
    )
    setShowUnpublishConfirm(false)
  }

  const handleCancel = () => {
    updateMutation.mutate(
      {
        teamSlug: teamSlug!,
        tripSlug: tripSlug!,
        data: tripStatusRequest(trip, Status.CANCELLED),
      },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: getGetTripQueryKey(teamSlug!, tripSlug!) })
          void invalidateTripWeather(queryClient, teamSlug!, tripSlug!)
          queryClient.invalidateQueries({ queryKey: getListPublicationsQueryKey(teamSlug!) })
          notifications.show({ message: t('trips.notifications.cancelled'), color: 'green' })
        },
      }
    )
    setShowCancelConfirm(false)
  }

  const handleUncancel = () => {
    updateMutation.mutate(
      {
        teamSlug: teamSlug!,
        tripSlug: tripSlug!,
        data: tripStatusRequest(trip, Status.DRAFT),
      },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: getGetTripQueryKey(teamSlug!, tripSlug!) })
          void invalidateTripWeather(queryClient, teamSlug!, tripSlug!)
          queryClient.invalidateQueries({ queryKey: getListPublicationsQueryKey(teamSlug!) })
          notifications.show({ message: t('trips.notifications.uncancelled'), color: 'green' })
        },
      }
    )
    setShowUncancelConfirm(false)
  }

  const handleDelete = () => {
    deleteMutation.mutate(
      { teamSlug: teamSlug!, tripSlug: tripSlug! },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: getListPublicationsQueryKey(teamSlug!) })
          queryClient.invalidateQueries({ queryKey: getGetTeamDashboardQueryKey(teamSlug!) })
          notifications.show({ message: t('trips.notifications.deleted'), color: 'green' })
          // Back to the feed, not the dashboard: the reader was managing publications.
          navigate(paths.teamAgenda(teamSlug!))
        },
      }
    )
    setShowDeleteConfirm(false)
  }

  const handleRestore = () => {
    undeleteMutation.mutate(
      { teamSlug: teamSlug!, tripSlug: tripSlug! },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: getGetTripQueryKey(teamSlug!, tripSlug!) })
          void invalidateTripWeather(queryClient, teamSlug!, tripSlug!)
          queryClient.invalidateQueries({ queryKey: getListPublicationsQueryKey(teamSlug!) })
          notifications.show({ message: t('trips.notifications.restored'), color: 'green' })
        },
      }
    )
  }

  const handleJoin = () => {
    joinMutation.mutate(
      { teamSlug: teamSlug!, tripSlug: tripSlug! },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: getGetTripQueryKey(teamSlug!, tripSlug!) })
          void invalidateTripWeather(queryClient, teamSlug!, tripSlug!)
          notifications.show({ message: t('trips.notifications.joined'), color: 'green' })
        },
      }
    )
  }

  const handleLeave = () => {
    leaveMutation.mutate(
      { teamSlug: teamSlug!, tripSlug: tripSlug! },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: getGetTripQueryKey(teamSlug!, tripSlug!) })
          void invalidateTripWeather(queryClient, teamSlug!, tripSlug!)
          notifications.show({ message: t('trips.notifications.left'), color: 'green' })
        },
      }
    )
  }

  return (
    <Container size="xl" py="xl">
      {/* Way back to the team: this page is not mounted inside TeamLayout */}
      {team && <TeamContextBanner team={team} />}

      {/* Header */}
      <Paper withBorder p="lg" mb="lg">
        <Group justify="space-between" align="flex-start" wrap="wrap">
          <Group style={{ minWidth: 0 }}>
            <EntityLogo logo={trip.media.assets.logo} alt={trip.name} size="lg" />
            <Title order={2} lineClamp={1}>
              {trip.name}
            </Title>
            <Badge color={STATUS_COLORS[trip.status]}>
              {t(`status.${trip.status satisfies 'DRAFT' | 'PUBLISHED' | 'CANCELLED'}`)}
            </Badge>
          </Group>

          <Group gap="sm" wrap="wrap">
            {/* Join/Leave button for members */}
            {canJoinTrip && (
              <Button onClick={handleJoin} loading={joinMutation.isPending}>
                {t('trips.detail.actions.join')}
              </Button>
            )}
            {hasJoined && (
              <Button variant="outline" onClick={handleLeave} loading={leaveMutation.isPending}>
                {t('trips.detail.actions.leave')}
              </Button>
            )}

            <Group gap="xs" wrap="nowrap">
              {canEdit && (
                <Button.Group>
                  <Button
                    component={PrefetchLink}
                    to={paths.tripEdit(teamSlug!, tripSlug!)}
                    variant="outline"
                    leftSection={<IconPencil size={16} />}
                  >
                    {t('actions.edit')}
                  </Button>
                  <Menu position="bottom-end">
                    <Menu.Target>
                      <Button variant="outline" px="xs" aria-label={t('aria.manageActions')}>
                        <IconChevronDown size={16} />
                      </Button>
                    </Menu.Target>
                    <Menu.Dropdown>
                      {trip.status === Status.DRAFT && (
                        <Menu.Item
                          onClick={handlePublish}
                          disabled={updateMutation.isPending}
                          color="success"
                          leftSection={updateMutation.isPending ? <Loader size="sm" /> : undefined}
                        >
                          {t('actions.publish')}
                        </Menu.Item>
                      )}
                      {trip.status === Status.PUBLISHED && (
                        <>
                          <Menu.Item onClick={() => setShowUnpublishConfirm(true)} color="warning">
                            {t('actions.unpublish')}
                          </Menu.Item>
                          <Menu.Item onClick={() => setShowCancelConfirm(true)} color="warning">
                            {t('trips.detail.actions.cancel')}
                          </Menu.Item>
                        </>
                      )}
                      {trip.status === Status.CANCELLED && (
                        <Menu.Item onClick={() => setShowUncancelConfirm(true)} color="green">
                          {t('trips.detail.actions.uncancel')}
                        </Menu.Item>
                      )}
                      {trip.deleted && (
                        <Menu.Item
                          onClick={handleRestore}
                          color="green"
                          disabled={undeleteMutation.isPending}
                        >
                          {t('actions.restore')}
                        </Menu.Item>
                      )}
                      <Menu.Divider />
                      <Menu.Item onClick={() => setShowDeleteConfirm(true)} color="danger">
                        {t('actions.delete')}
                      </Menu.Item>
                    </Menu.Dropdown>
                  </Menu>
                </Button.Group>
              )}
              <ShareButton title={trip.name} />
              <ContentActionsMenu
                teamSlug={trip.team.slug}
                teamName={trip.team.name}
                targetType={ReportTargetType.TRIP}
                targetId={trip.id}
                onReported={() => navigate(paths.team(trip.team.slug))}
              />
            </Group>
          </Group>
        </Group>

        <Box mt="md">
          <MediaDisplay media={trip.media} />
        </Box>
        {trip.status === Status.DRAFT && trip.publishAt && (
          <Group mt="sm" gap="xs">
            <IconCalendar size={16} color="var(--mantine-color-yellow-text)" />
            <Text size="sm" c="var(--mantine-color-yellow-text)">
              <Rendezvous
                date={trip.publishAt}
                zone={trip.timezone}
                variant="detail"
                template={(date) => t('trips.detail.scheduledPublish', { date })}
              />
            </Text>
          </Group>
        )}
        <Group mt="md">
          <Group gap="xs">
            <IconCalendar size={16} />
            <Text size="sm" c="dimmed">
              {formattedDate}
            </Text>
          </Group>
          <Group gap="xs">
            <IconUsers size={16} />
            <Text size="sm" c="dimmed">
              {t('participantCount', { count: trip.participantCount })}
            </Text>
          </Group>
          <Group gap="xs">
            <IconStack2 size={16} />
            <Text size="sm" c="dimmed">
              {t('trips.card.stageCount', { count: trip.stageCount })}
            </Text>
          </Group>
          {trip.totalDistance !== undefined && (
            <Group gap="xs">
              <IconArrowsMaximize size={16} />
              <Text size="sm" c="dimmed">
                {distance(trip.totalDistance)}
              </Text>
            </Group>
          )}
          {trip.totalElevationGain !== undefined && (
            <Group gap="xs">
              <IconArrowUp size={16} />
              <Text size="sm" c="dimmed">
                {elevation(trip.totalElevationGain)}
              </Text>
            </Group>
          )}
          {trip.endDate && (
            <Group gap="xs">
              <IconCalendarCheck size={16} />
              <Text size="sm" c="dimmed">
                <Rendezvous
                  date={trip.endDate}
                  zone={tripEndZone(trip)}
                  variant="detail"
                  template={(date) => t('trips.detail.endDate', { date })}
                />
              </Text>
            </Group>
          )}
        </Group>
        {/* The team tags, every one of them (cards show the first three). */}
        <TagList tags={trip.tags} mt="md" />
      </Paper>

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
            </Paper>
          )}

          {/* Info for non-members */}
          {!isMember && isAuthenticated && (
            <Alert color="yellow" variant="light">
              <Text>
                {t('trips.detail.nonMember.message')}{' '}
                <Anchor component={PrefetchLink} to={paths.team(teamSlug!)} fw={500}>
                  {t('trips.detail.nonMember.viewTeam')}
                </Anchor>
              </Text>
            </Alert>
          )}

          {!isAuthenticated && (
            <Alert color="blue" variant="light">
              <Text>
                {t('trips.detail.notAuthenticated.message')}{' '}
                <Anchor
                  component={PrefetchLink}
                  to={paths.login()}
                  state={{ from: location }}
                  fw={500}
                >
                  {t('trips.detail.notAuthenticated.signIn')}
                </Anchor>
              </Text>
            </Alert>
          )}

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
      <ParticipantListModal
        isOpen={showParticipants}
        onClose={() => setShowParticipants(false)}
        source={{ kind: 'trip', teamSlug: teamSlug!, tripSlug: trip.slug }}
        count={trip.participantCount}
        groupName={trip.name}
      />

      <ConfirmDialog
        isOpen={showUnpublishConfirm}
        onClose={() => setShowUnpublishConfirm(false)}
        onConfirm={handleUnpublish}
        title={t('actions.unpublish')}
        message={t('trips.detail.confirmations.unpublish')}
        confirmText={t('actions.unpublish')}
        variant="warning"
        isLoading={updateMutation.isPending}
      />
      <ConfirmDialog
        isOpen={showCancelConfirm}
        onClose={() => setShowCancelConfirm(false)}
        onConfirm={handleCancel}
        title={t('trips.detail.actions.cancel')}
        message={t('trips.detail.confirmations.cancel')}
        confirmText={t('trips.detail.actions.cancel')}
        variant="warning"
        isLoading={updateMutation.isPending}
      />
      <ConfirmDialog
        isOpen={showUncancelConfirm}
        onClose={() => setShowUncancelConfirm(false)}
        onConfirm={handleUncancel}
        title={t('trips.detail.actions.uncancel')}
        message={t('trips.detail.confirmations.uncancel')}
        confirmText={t('trips.detail.actions.uncancel')}
        variant="info"
        isLoading={updateMutation.isPending}
      />
      <ConfirmDialog
        isOpen={showDeleteConfirm}
        onClose={() => setShowDeleteConfirm(false)}
        onConfirm={handleDelete}
        title={t('actions.delete')}
        message={t('trips.detail.confirmations.delete')}
        confirmText={t('actions.delete')}
        variant="danger"
        isLoading={deleteMutation.isPending}
      />
    </Container>
  )
}
