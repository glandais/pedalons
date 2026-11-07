import { Fragment, useState, useMemo, lazy, Suspense } from 'react'
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
  Box,
  Alert,
  Anchor,
  Skeleton,
  Loader,
  Divider,
} from '@mantine/core'
import {
  useUpdateRide,
  useDeleteRide,
  useUndeleteRide,
  getGetRideQueryKey,
} from '../../api/endpoints/rides/rides'
import { getListPublicationsQueryKey } from '../../api/endpoints/publications/publications'
import { invalidateRideWeather, rideRouteSlugs, useRideDetailData } from './rideDetailData'
import { groupAction, groupsRegisteredFirst, groupWindLeg } from './rideGroupData'
import { rideStatusRequest } from './rideFormData'
import { ReportTargetType, Status, type MediaDto } from '@/api/dto'
import { useAuth } from '../../hooks/useAuth'
import { EmptyState } from '../../components/common/EmptyState'
import { QueryStateBoundary } from '../../components/common/QueryStateBoundary'
import { DetailPageSkeleton } from '../../components/common/DetailPageSkeleton'
import { RideGroupCard } from '../../components/ride/RideGroupCard'
import { TeamContextBanner } from '../../components/team/TeamContextBanner'
import { rideMapRoutes } from './rideMapRoutes'
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
import { hasForecast } from '@/components/weather/weatherDisplay'
import { RideSoloGroupPanel } from '@/components/ride/RideSoloGroupPanel'
import { GroupParticipantsSection } from '@/components/ride/group/GroupParticipantsSection'
import { GroupRouteMap } from '@/components/ride/group/GroupRouteMap'
import { GroupStats } from '@/components/ride/group/GroupStats'
import { useScrollToAnchor } from '@/hooks/useScrollToAnchor'
import { withMapColor } from '@/hooks/filters/mapColorFilters'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'

/** The map fills the visible height beside the column on md+ (`.detail-map--fill`, WEB-134); its
 *  skeleton takes the same height so nothing shifts when the map bundle arrives. */
const STICKY_MAP_HEIGHT = 'var(--detail-map-height, 500px)'

/** The anchor of the weather block, as on a group's page: a former group link's `#meteo` lands here. */
const WEATHER_ANCHOR = 'meteo'

/**
 * Whether the « Consignes » block would draw anything: a text or an attachment. Images do not count
 * on their own — MediaDisplay only draws those the text references.
 */
function hasMediaContent(media: MediaDto): boolean {
  return media.markdown.trim() !== '' || media.assets.attachments.length > 0
}

/** The instructions' column is at most 440 px on md+ (`.ride-detail-layout`): no 960 px picture. */
const INSTRUCTIONS_IMAGE_SIZES = '(min-width: 64em) 440px, 100vw'

/** Below md the map, its profile and the pictures load above `#meteo` after the first scroll. */
const WEATHER_ANCHOR_SETTLE_MS = 4000

export function RideDetailPage() {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const { teamSlug, rideSlug } = useParams<{ teamSlug: string; rideSlug: string }>()
  const { isAuthenticated } = useAuth()
  // The hovered route, and the one chosen by a click on its trace — map item ids, one per distinct
  // route (`rideMapRoutes`). The choice stays lit on the map and on the cards of every group that
  // rides it, until a card's hover replaces it: the map stays on the last route hovered.
  const [highlightedItemId, setHighlightedItemId] = useState<string | null>(null)
  const [selectedItemId, setSelectedItemId] = useState<string | null>(null)
  const litItemId = highlightedItemId ?? selectedItemId
  // A choice drops a hover the map may have left behind (it re-asserts its clicked trace on leave).
  const chooseItem = (itemId: string) => {
    setSelectedItemId(itemId)
    setHighlightedItemId(null)
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
    soloGroup: solo,
    soloLeg,
  } = useRideDetailData(teamSlug, rideSlug)

  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const location = useLocation()
  const updateMutation = useUpdateRide()
  const deleteMutation = useDeleteRide()
  const undeleteMutation = useUndeleteRide()
  const membership = useRideGroupMembership(teamSlug!, rideSlug!)
  const groupError = membership.error

  // One layer per distinct route, not per group: groups on the same route share its trace and its
  // colour, the bar in front of their names. Must be before early returns to maintain hook order.
  const mainRouteLabel = t('rides.detail.mainRoute')
  const {
    items: mapItems,
    itemIdByGroupId,
    colorByGroupId: trackColors,
  } = useMemo(() => rideMapRoutes(ride, mainRouteLabel), [ride, mainRouteLabel])
  // Hovering a group's card lights its whole route, so the cards of the groups that share it too.
  const hoverGroup = (groupId: string | null) => {
    const itemId = groupId ? (itemIdByGroupId.get(groupId) ?? null) : null
    setHighlightedItemId(itemId)
    if (itemId) setSelectedItemId(null)
  }
  const isGroupLit = (groupId: string) => !!litItemId && itemIdByGroupId.get(groupId) === litItemId

  useCanonicalPath(team && ride ? paths.ride(team.slug, ride.slug) : undefined)

  // `#meteo`: a solo ride's former group link (WEB-79), or a shared one.
  useScrollToAnchor(WEATHER_ANCHOR, !!ride && !!team && !weather.isLoading, {
    settleMs: WEATHER_ANCHOR_SETTLE_MS,
  })

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

  // Registering and the join banner follow the real membership; editing and the comment thread
  // (moderation), the rights a platform admin holds in every team (docs/LEDGER_*.md API-137).
  const { isMember, isOrganizer: canEdit } = teamAccess(team, isPlatformAdmin)
  const canReadComments = isMember || isPlatformAdmin
  // A ride that has already happened is not joinable — `canJoinRide` used to ignore the date
  // entirely, so last year's rides kept a live "Join" button.
  // Said by the server (docs/LEDGER_*.md API-16), not derived from the clock of whoever renders.
  const isPast = ride.finished
  // `ride.full` is deliberately left out: each card already withholds its Join button when its own
  // group is full, and gating the whole zone on it hid every « Complet » badge once all groups filled.
  const canJoinRide = isMember && ride.status === Status.PUBLISHED && !ride.registered && !isPast
  // The member's own group heads the list, set apart from the others.
  const isRegisteredInGroup = !!ride.groups?.some((g) => g.id === ride.registeredGroupId)

  // A solo ride whose ride and group share one route: the group page's single-route map (WEB-79).
  // Two different routes (the ride's and its group's) keep the multi-route map.
  const routeSlugs = rideRouteSlugs(ride)
  const soloRouteSlug = solo && routeSlugs.length === 1 ? routeSlugs[0] : undefined
  // Its group's Météo mode on that map, on the group page's own terms (WEB-118)
  const soloWindLeg = groupWindLeg(ride, soloLeg)
  // No map at all (no route): the left column takes the full width.
  const hasMap = !!soloRouteSlug || mapItems.length > 0

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

      {/* Variant A (docs/LEDGER_*.md WEB-134): the map in a column of its own, sticky on md+, so the
          organiser's free text, however long, never pushes it down. Stacked below md, map first. */}
      <Box
        className={hasMap ? 'ride-detail-layout' : 'ride-detail-layout ride-detail-layout--no-map'}
        mb={{ base: 'md', sm: 'lg' }}
      >
        <Stack className="ride-detail-side" gap="lg">
          {/* The organiser's instructions, only when there are some */}
          {hasMediaContent(ride.media) && (
            <Paper
              withBorder
              p="lg"
              component="section"
              aria-labelledby="ride-instructions-title"
              data-testid="ride-instructions"
            >
              <Title id="ride-instructions-title" order={3} size="h4" mb="md">
                {t('rides.detail.instructions.title')}
              </Title>
              <MediaDisplay media={ride.media} imageSizes={INSTRUCTIONS_IMAGE_SIZES} />
            </Paper>
          )}

          {/* Groups list — or, for a solo ride, its one group in full (WEB-79) */}
          <Box data-testid="ride-groups">
            {solo ? (
              <Stack gap="md">
                <RideSoloGroupPanel
                  teamSlug={teamSlug!}
                  ride={ride}
                  group={solo}
                  action={groupAction(ride, solo, isMember)}
                  membership={membership}
                  routesBySlug={groupRoutesBySlug}
                  // On its single-route map (graded, not a coloured trace) the bar would match nothing.
                  trackColor={soloRouteSlug ? undefined : trackColors.get(solo.id)}
                  error={groupError?.groupId === solo.id ? groupError.message : undefined}
                />
                <GroupStats
                  ride={ride}
                  group={solo}
                  arrival={soloLeg && hasForecast(soloLeg.status) ? soloLeg.arrivalTime : undefined}
                />
                <GroupParticipantsSection
                  teamSlug={teamSlug!}
                  ride={ride}
                  group={solo}
                  titleId="ride-participants-title"
                  canSeeParticipants={canReadComments}
                />
              </Stack>
            ) : (
              <>
                <Title order={3} size="h4" mb="md">
                  {t('rides.detail.groups.title')}
                </Title>
                {ride.groups && ride.groups.length > 0 ? (
                  <Stack gap="sm">
                    {groupsRegisteredFirst(ride.groups, ride.registeredGroupId).map(
                      (group, index) => {
                        return (
                          <Fragment key={group.id}>
                            {index === 1 && isRegisteredInGroup && (
                              <Divider
                                label={t('rides.detail.groups.others')}
                                labelPosition="left"
                                mt="xs"
                              />
                            )}
                            <RideGroupCard
                              group={group}
                              rideTimezone={ride.timezone}
                              rideDateTime={ride.dateTime}
                              teamSlug={teamSlug!}
                              rideSlug={ride.slug}
                              rideRouteSlug={ride.routeSlug}
                              routesBySlug={groupRoutesBySlug}
                              trackColor={trackColors.get(group.id)}
                              weatherLeg={
                                weather.data && hasForecast(weather.data.status)
                                  ? weather.data.legs.find((leg) => leg.groupId === group.id)
                                  : undefined
                              }
                              canJoin={canJoinRide}
                              canSeeParticipants={canReadComments}
                              onJoin={() => handleJoinGroup(group.id)}
                              onLeave={() => handleLeaveGroup(group.id)}
                              onHover={hoverGroup}
                              isHighlighted={isGroupLit(group.id)}
                              isLoading={membership.isPending}
                              error={
                                groupError?.groupId === group.id ? groupError.message : undefined
                              }
                            />
                          </Fragment>
                        )
                      }
                    )}
                  </Stack>
                ) : (
                  <EmptyState
                    icon={<IconUsersGroup size={48} />}
                    title={t('rides.detail.groups.emptyTitle')}
                    description={t('rides.detail.groups.empty')}
                  />
                )}
              </>
            )}
          </Box>

          {/* Weather at the meeting point; each group's route is on the group's own page (WEB-77),
              except a solo ride's, whose page is its group's (WEB-79) */}
          <Box id={WEATHER_ANCHOR} style={{ scrollMarginTop: 'var(--app-shell-header-height)' }}>
            <ErrorBoundary variant="inline">
              <RideWeatherSection
                ride={ride}
                weather={weather.data}
                isLoading={weather.isLoading}
                isFetching={weather.isFetching}
                onRetry={() => void weather.refetch()}
                canEdit={canEdit}
              />
            </ErrorBoundary>
          </Box>
        </Stack>

        {/* Map: the right column, sticky (via .detail-map); after the column in the DOM so focus and
            reading follow the visual order, moved first below md by the grid areas */}
        {hasMap && (
          <Box
            className={
              soloRouteSlug
                ? 'detail-map detail-map--fill detail-map--solo'
                : 'detail-map detail-map--fill'
            }
          >
            {soloRouteSlug ? (
              // A solo ride on one route: the group page's map, its profile, its Météo mode, and the
              // ride's own fullscreen map in the mode the line is in (WEB-118).
              <GroupRouteMap
                teamSlug={teamSlug!}
                routeSlug={soloRouteSlug}
                route={groupRoutesBySlug.get(soloRouteSlug)}
                leg={soloWindLeg}
                attribution={soloWindLeg ? weather.data?.attribution : undefined}
                timezone={ride.timezone}
                fullscreenPath={(colorBy) =>
                  withMapColor(paths.rideMap(team.slug, ride.slug), colorBy)
                }
                withActions={false}
                heightVariant="sticky"
              />
            ) : (
              <ErrorBoundary variant="inline">
                <Suspense fallback={<Skeleton height={STICKY_MAP_HEIGHT} radius="md" />}>
                  <RoutesMapView
                    variant="sticky"
                    items={mapItems}
                    teamSlug={teamSlug!}
                    highlightedItemId={litItemId}
                    onItemHover={setHighlightedItemId}
                    selectedItemId={selectedItemId}
                    onItemSelect={chooseItem}
                  />
                </Suspense>
              </ErrorBoundary>
            )}
          </Box>
        )}
      </Box>

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
      {canReadComments && (
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
