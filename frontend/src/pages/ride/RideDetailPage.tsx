import { useState, useMemo, lazy, Suspense } from 'react'
import { getGetTeamDashboardQueryKey } from '@/api/endpoints/teams/teams'
import { useLocation, useParams, useNavigate } from 'react-router-dom'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import {
  IconCalendar,
  IconUsers,
  IconPencil,
  IconMapPin,
  IconChevronDown,
  IconUsersGroup,
} from '@tabler/icons-react'
import {
  Container,
  Paper,
  Group,
  Stack,
  Title,
  Text,
  Button,
  Menu,
  Badge,
  SimpleGrid,
  Box,
  Alert,
  Anchor,
  Skeleton,
  Loader,
} from '@mantine/core'
import {
  useUpdateRide,
  useDeleteRide,
  useUndeleteRide,
  getGetRideQueryKey,
} from '../../api/endpoints/rides/rides'
import { getListPublicationsQueryKey } from '../../api/endpoints/publications/publications'
import { invalidateRideWeather, useRideDetailData } from './rideDetailData'
import { rideStatusRequest } from './rideFormData'
import { ReportTargetType, Status } from '@/api/dto'
import { useAuth } from '../../hooks/useAuth'
import { EmptyState } from '../../components/common/EmptyState'
import { QueryStateBoundary } from '../../components/common/QueryStateBoundary'
import { DetailPageSkeleton } from '../../components/common/DetailPageSkeleton'
import { RideGroupCard } from '../../components/ride/RideGroupCard'
import { TeamContextBanner } from '../../components/team/TeamContextBanner'
import type { MapRouteItem } from '../../components/route/RoutesMapView'
import { ConfirmDialog } from '../../components/common/ConfirmDialog'

// Lazy load the map component (pulls in map-vendor ~1MB and chart-vendor ~150KB)
const RoutesMapView = lazy(() =>
  import('../../components/route/RoutesMapView').then((m) => ({ default: m.RoutesMapView }))
)
import { Rendezvous } from '../../components/common/Rendezvous'
import { MediaDisplay } from '../../components/common/MediaDisplay'
import { EntityLogo } from '../../components/common/EntityLogo'
import { ContentActionsMenu } from '../../components/moderation/ContentActionsMenu'
import { ShareButton } from '../../components/common/ShareButton'
import { CommentSection } from '../../components/comment'
import { paths } from '@/config/paths'
import { useRideGroupMembership } from '@/hooks/useRideGroupMembership'
import { ErrorBoundary } from '../../components/common/ErrorBoundary'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { STATUS_COLORS } from '@/lib/badgeColors.generated'
import { TagList } from '@/components/tag'
import { RideWeatherSection } from '@/components/weather'

export function RideDetailPage() {
  const { t } = useTranslation()
  const { teamSlug, rideSlug } = useParams<{ teamSlug: string; rideSlug: string }>()
  const { isAuthenticated } = useAuth()
  // The hovered group, and the one chosen — in the weather block, or by a click on its trace. The
  // hover wins while it lasts; the choice stays lit on the map and among the cards.
  const [highlightedGroupId, setHighlightedGroupId] = useState<string | null>(null)
  const [selectedGroupId, setSelectedGroupId] = useState<string | null>(null)
  const litGroupId = highlightedGroupId ?? selectedGroupId
  // A choice drops a hover the map may have left behind (it re-asserts its clicked trace on leave).
  const chooseGroup = (groupId: string) => {
    setSelectedGroupId(groupId)
    setHighlightedGroupId(null)
  }
  const [showUnpublishConfirm, setShowUnpublishConfirm] = useState(false)
  const [showCancelConfirm, setShowCancelConfirm] = useState(false)
  const [showUncancelConfirm, setShowUncancelConfirm] = useState(false)
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)

  const {
    team: { data: team, isLoading: isLoadingTeam },
    ride: { data: ride, isLoading: isLoadingRide, error, refetch },
    weather,
    routesBySlug: groupRoutesBySlug,
  } = useRideDetailData(teamSlug, rideSlug)

  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const location = useLocation()
  const updateMutation = useUpdateRide()
  const deleteMutation = useDeleteRide()
  const undeleteMutation = useUndeleteRide()
  const membership = useRideGroupMembership(teamSlug!, rideSlug!)
  const groupError = membership.error

  // Combine ride's main route with group routes for map display
  // Must be before early returns to maintain hook order
  const mapItems = useMemo(() => {
    if (!ride) return []
    const items: MapRouteItem[] = []

    // Add ride's main route if it exists
    if (ride.routeSlug) {
      items.push({
        id: 'ride-main-route',
        name: t('rides.detail.mainRoute'),
        routeSlug: ride.routeSlug,
      })
    }

    // Add all groups
    if (ride.groups) {
      items.push(...ride.groups)
    }

    return items
  }, [ride, t])

  useCanonicalPath(team && ride ? paths.ride(team.slug, ride.slug) : undefined)

  if (isLoadingTeam || isLoadingRide || error || !ride || !team) {
    return (
      <Container size="xl" py="xl">
        <QueryStateBoundary
          isLoading={isLoadingTeam || isLoadingRide}
          isError={!!error}
          error={error}
          isNotFound={!ride || !team}
          onRetry={() => void refetch()}
          skeleton={<DetailPageSkeleton />}
          notFound={{
            title: t('rides.detail.notFound.title'),
            message: t('rides.detail.notFound.message'),
            backTo: paths.team(teamSlug!),
            backLabel: t('rides.detail.notFound.backToRides'),
          }}
        >
          {null}
        </QueryStateBoundary>
      </Container>
    )
  }

  const isMember = !!team?.role
  const isAdmin = team?.role === 'ADMIN'
  const isOrganizer = team?.role === 'ORGANIZER'
  const canEdit = isAdmin || isOrganizer
  // A ride that has already happened is not joinable — `canJoinRide` used to ignore the date
  // entirely, so last year's rides kept a live "Join" button.
  // Said by the server (docs/LEDGER_*.md API-16), not derived from the clock of whoever renders.
  const isPast = ride.finished
  // `ride.full` is deliberately left out: each card already withholds its Join button when its own
  // group is full, and gating the whole zone on it hid every « Complet » badge once all groups filled.
  const canJoinRide = isMember && ride.status === Status.PUBLISHED && !ride.registered && !isPast

  // A rendezvous, in the ride's zone (docs/LEDGER_*.md API-60).
  const formattedDate = <Rendezvous date={ride.dateTime} zone={ride.timezone} variant="detail" />

  // The ride, the feed it shows in, and its forecast (its own query key, not a prefix of the ride's).
  const invalidateRideQueries = () => {
    queryClient.invalidateQueries({ queryKey: getGetRideQueryKey(teamSlug!, rideSlug!) })
    queryClient.invalidateQueries({ queryKey: getListPublicationsQueryKey(teamSlug!) })
    void invalidateRideWeather(queryClient, teamSlug!, rideSlug!)
  }

  const handlePublish = () => {
    updateMutation.mutate(
      {
        teamSlug: teamSlug!,
        rideSlug: rideSlug!,
        data: rideStatusRequest(ride, Status.PUBLISHED),
      },
      {
        onSuccess: () => {
          invalidateRideQueries()
          notifications.show({ message: t('rides.notifications.published'), color: 'green' })
        },
      }
    )
  }

  const handleUnpublish = () => {
    updateMutation.mutate(
      {
        teamSlug: teamSlug!,
        rideSlug: rideSlug!,
        data: rideStatusRequest(ride, Status.DRAFT),
      },
      {
        onSuccess: () => {
          invalidateRideQueries()
          notifications.show({ message: t('rides.notifications.unpublished'), color: 'green' })
        },
      }
    )
    setShowUnpublishConfirm(false)
  }

  const handleCancel = () => {
    updateMutation.mutate(
      {
        teamSlug: teamSlug!,
        rideSlug: rideSlug!,
        data: rideStatusRequest(ride, Status.CANCELLED),
      },
      {
        onSuccess: () => {
          invalidateRideQueries()
          notifications.show({ message: t('rides.notifications.cancelled'), color: 'green' })
        },
      }
    )
    setShowCancelConfirm(false)
  }

  const handleUncancel = () => {
    updateMutation.mutate(
      {
        teamSlug: teamSlug!,
        rideSlug: rideSlug!,
        data: rideStatusRequest(ride, Status.DRAFT),
      },
      {
        onSuccess: () => {
          invalidateRideQueries()
          notifications.show({ message: t('rides.notifications.uncancelled'), color: 'green' })
        },
      }
    )
    setShowUncancelConfirm(false)
  }

  const handleDelete = () => {
    deleteMutation.mutate(
      { teamSlug: teamSlug!, rideSlug: rideSlug! },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: getListPublicationsQueryKey(teamSlug!) })
          queryClient.invalidateQueries({ queryKey: getGetTeamDashboardQueryKey(teamSlug!) })
          notifications.show({ message: t('rides.notifications.deleted'), color: 'green' })
          // Back to the feed, not the dashboard: the reader was managing publications.
          navigate(paths.teamAgenda(teamSlug!))
        },
      }
    )
    setShowDeleteConfirm(false)
  }

  const handleRestore = () => {
    undeleteMutation.mutate(
      { teamSlug: teamSlug!, rideSlug: rideSlug! },
      {
        onSuccess: () => {
          invalidateRideQueries()
          notifications.show({ message: t('rides.notifications.restored'), color: 'green' })
        },
      }
    )
  }

  const handleJoinGroup = membership.join
  const handleLeaveGroup = membership.leave

  return (
    <Container size="xl" py="xl">
      {/* Way back to the team: this page is not mounted inside TeamLayout */}
      <TeamContextBanner team={team} />

      {/* Header */}
      <Paper shadow="xs" p="lg" mb="lg" withBorder>
        <Group justify="space-between" wrap="wrap">
          <Group gap="sm" style={{ minWidth: 0 }}>
            <EntityLogo logo={ride.media.assets.logo} alt={ride.name} size="lg" />
            <Title
              order={2}
              style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}
            >
              {ride.name}
            </Title>
            <Badge color={STATUS_COLORS[ride.status]} variant="light">
              {t(`status.${ride.status satisfies 'DRAFT' | 'PUBLISHED' | 'CANCELLED'}`)}
            </Badge>
            {isPast && (
              <Badge color="gray" variant="light">
                {t('rides.detail.finished')}
              </Badge>
            )}
          </Group>

          <Group gap="xs" wrap="nowrap">
            {canEdit && (
              <Button.Group>
                <Button
                  component={PrefetchLink}
                  to={paths.rideEdit(teamSlug!, rideSlug!)}
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
                    {ride.status === Status.DRAFT && (
                      <Menu.Item
                        onClick={handlePublish}
                        disabled={updateMutation.isPending}
                        color="success"
                      >
                        {updateMutation.isPending && <Loader size="sm" />}
                        {t('actions.publish')}
                      </Menu.Item>
                    )}
                    {ride.status === Status.PUBLISHED && (
                      <>
                        <Menu.Item onClick={() => setShowUnpublishConfirm(true)} color="warning">
                          {t('actions.unpublish')}
                        </Menu.Item>
                        <Menu.Item onClick={() => setShowCancelConfirm(true)} color="warning">
                          {t('rides.detail.actions.cancel')}
                        </Menu.Item>
                      </>
                    )}
                    {ride.status === Status.CANCELLED && (
                      <Menu.Item onClick={() => setShowUncancelConfirm(true)} color="green">
                        {t('rides.detail.actions.uncancel')}
                      </Menu.Item>
                    )}
                    {ride.deleted && (
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
            <ShareButton title={ride.name} />
            <ContentActionsMenu
              teamSlug={ride.team.slug}
              teamName={ride.team.name}
              targetType={ReportTargetType.RIDE}
              targetId={ride.id}
              onReported={() => navigate(paths.team(ride.team.slug))}
            />
          </Group>
        </Group>

        <Box mt="md">
          <MediaDisplay media={ride.media} />
        </Box>
        {ride.status === Status.DRAFT && ride.publishAt && (
          <Group mt="xs" gap="xs">
            <IconCalendar size={16} color="var(--mantine-color-yellow-text)" />
            <Text size="sm" c="var(--mantine-color-yellow-text)">
              <Rendezvous
                date={ride.publishAt}
                zone={ride.timezone}
                variant="detail"
                template={(date) => t('rides.detail.scheduledPublish', { date })}
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
              {t('participantCount', { count: ride.participantCount })}
            </Text>
          </Group>
        </Group>
        {/* Start and End Places */}
        {(ride.startPlace || ride.endPlace) && (
          <Group mt="sm" wrap="wrap">
            {ride.startPlace && (
              <Group gap="xs">
                <IconMapPin size={16} color="var(--mantine-color-green-text)" />
                <Text size="sm" fw={500} c="var(--mantine-color-green-text)">
                  {t('startPlace')}:
                </Text>
                <Text size="sm">
                  {ride.startPlace.name}
                  {ride.startPlace.address && (
                    <Text span c="dimmed">
                      {' '}
                      ({ride.startPlace.address})
                    </Text>
                  )}
                </Text>
              </Group>
            )}
            {ride.endPlace && (
              <Group gap="xs">
                <IconMapPin size={16} color="var(--mantine-color-red-text)" />
                <Text size="sm" fw={500} c="var(--mantine-color-red-text)">
                  {t('endPlace')}:
                </Text>
                <Text size="sm">
                  {ride.endPlace.name}
                  {ride.endPlace.address && (
                    <Text span c="dimmed">
                      {' '}
                      ({ride.endPlace.address})
                    </Text>
                  )}
                </Text>
              </Group>
            )}
          </Group>
        )}
        {/* The team tags, every one of them (cards show the first three). */}
        <TagList tags={ride.tags} mt="md" />
      </Paper>

      {/* Weather: the meeting point, then one group's route (the reader's own by default) */}
      <ErrorBoundary variant="inline">
        <RideWeatherSection
          ride={ride}
          weather={weather.data}
          isLoading={weather.isLoading}
          isFetching={weather.isFetching}
          onRetry={() => void weather.refetch()}
          canEdit={canEdit}
          selectedGroupId={selectedGroupId}
          onSelectGroup={chooseGroup}
        />
      </ErrorBoundary>

      {/* Map and Groups */}
      <SimpleGrid
        cols={{ base: 1, md: 2, xl: 3 }}
        spacing={{ base: 'md', sm: 'lg' }}
        mb={{ base: 'md', sm: 'lg' }}
      >
        {/* Map - shown first on mobile, spans 2 cols on xl */}
        <Box className="detail-map" style={{ order: 1 }}>
          {mapItems.length > 0 && (
            <ErrorBoundary variant="inline">
              <Suspense fallback={<Skeleton height={500} radius="md" />}>
                <RoutesMapView
                  items={mapItems}
                  teamSlug={teamSlug!}
                  highlightedItemId={litGroupId}
                  onItemHover={setHighlightedGroupId}
                  selectedItemId={selectedGroupId}
                  onItemSelect={chooseGroup}
                />
              </Suspense>
            </ErrorBoundary>
          )}
        </Box>

        {/* Groups list */}
        <Box style={{ order: 2 }}>
          <Title order={4} mb="md">
            {t('rides.detail.groups.title')}
          </Title>
          {ride.groups && ride.groups.length > 0 ? (
            <Stack gap="sm">
              {ride.groups.map((group) => {
                return (
                  <RideGroupCard
                    key={group.id}
                    group={group}
                    rideTimezone={ride.timezone}
                    rideDateTime={ride.dateTime}
                    teamSlug={teamSlug!}
                    rideSlug={ride.slug}
                    rideRouteSlug={ride.routeSlug}
                    routesBySlug={groupRoutesBySlug}
                    canJoin={canJoinRide}
                    onJoin={() => handleJoinGroup(group.id)}
                    onLeave={() => handleLeaveGroup(group.id)}
                    onHover={setHighlightedGroupId}
                    isHighlighted={litGroupId === group.id}
                    isLoading={membership.isPending}
                    error={groupError?.groupId === group.id ? groupError.message : undefined}
                  />
                )
              })}
            </Stack>
          ) : (
            <EmptyState
              icon={<IconUsersGroup size={48} />}
              title={t('rides.detail.groups.emptyTitle')}
              description={t('rides.detail.groups.empty')}
            />
          )}
        </Box>
      </SimpleGrid>

      {/* Info for non-members */}
      {!isMember && isAuthenticated && (
        <Alert color="yellow" variant="light" mb="lg">
          <Text>
            {t('rides.detail.nonMember.message')}{' '}
            <Anchor component={PrefetchLink} to={paths.team(teamSlug!)} fw={500}>
              {t('rides.detail.nonMember.viewTeam')}
            </Anchor>
          </Text>
        </Alert>
      )}

      {!isAuthenticated && (
        <Alert color="blue" variant="light" mb="lg">
          <Text>
            {t('rides.detail.notAuthenticated.message')}{' '}
            <Anchor component={PrefetchLink} to={paths.login()} state={{ from: location }} fw={500}>
              {t('rides.detail.notAuthenticated.signIn')}
            </Anchor>
          </Text>
        </Alert>
      )}

      {/* Comments Section - only visible to team members */}
      {isMember && (
        <Box mt="lg">
          <CommentSection
            teamSlug={teamSlug!}
            teamName={team.name}
            entityType="rides"
            entitySlug={rideSlug!}
            isOrganizer={canEdit}
          />
        </Box>
      )}

      {/* Confirmation Dialogs */}
      <ConfirmDialog
        isOpen={showUnpublishConfirm}
        onClose={() => setShowUnpublishConfirm(false)}
        onConfirm={handleUnpublish}
        title={t('actions.unpublish')}
        message={t('rides.detail.confirmations.unpublish')}
        confirmText={t('actions.unpublish')}
        variant="warning"
        isLoading={updateMutation.isPending}
      />
      <ConfirmDialog
        isOpen={showCancelConfirm}
        onClose={() => setShowCancelConfirm(false)}
        onConfirm={handleCancel}
        title={t('rides.detail.actions.cancel')}
        message={t('rides.detail.confirmations.cancel')}
        confirmText={t('rides.detail.actions.cancel')}
        variant="warning"
        isLoading={updateMutation.isPending}
      />
      <ConfirmDialog
        isOpen={showUncancelConfirm}
        onClose={() => setShowUncancelConfirm(false)}
        onConfirm={handleUncancel}
        title={t('rides.detail.actions.uncancel')}
        message={t('rides.detail.confirmations.uncancel')}
        confirmText={t('rides.detail.actions.uncancel')}
        variant="info"
        isLoading={updateMutation.isPending}
      />
      <ConfirmDialog
        isOpen={showDeleteConfirm}
        onClose={() => setShowDeleteConfirm(false)}
        onConfirm={handleDelete}
        title={t('actions.delete')}
        message={t('rides.detail.confirmations.delete')}
        confirmText={t('actions.delete')}
        variant="danger"
        isLoading={deleteMutation.isPending}
      />
    </Container>
  )
}
