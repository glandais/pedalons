import { Fragment, useState, useMemo, lazy, Suspense } from 'react'
import { useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { IconUsersGroup } from '@tabler/icons-react'
import { Container, Stack, Title, Box, Skeleton, Divider } from '@mantine/core'
import { rideRouteSlugs, useRideDetailData } from './rideDetailData'
import { canSwitchTo, groupAction, groupsRegisteredFirst, groupWindLeg } from './rideGroupData'
import { ReportTargetType } from '@/api/dto'
import { useAuth } from '../../hooks/useAuth'
import { EmptyState } from '../../components/common/EmptyState'
import { QueryStateBoundary } from '../../components/common/QueryStateBoundary'
import { DetailPageSkeleton } from '../../components/common/DetailPageSkeleton'
import { RideGroupCard } from '../../components/ride/RideGroupCard'
import { TeamContextBanner } from '../../components/team/TeamContextBanner'
import { rideMapRoutes } from './rideMapRoutes'

// Lazy load the map component (pulls in map-vendor ~1MB and chart-vendor ~150KB)
const RoutesMapView = lazy(() =>
  import('../../components/route/RoutesMapView').then((m) => ({ default: m.RoutesMapView }))
)
import { DepartureBlock } from '../../components/common/DepartureBlock'
import {
  groupLeavesAtOwnTime,
  registeredGroupOf,
  someGroupLeavesAtOwnTime,
} from '@/utils/groupStart'
import { CommentSection } from '../../components/comment'
import { paths } from '@/config/paths'
import { useRideGroupMembership } from '@/hooks/useRideGroupMembership'
import { ErrorBoundary } from '../../components/common/ErrorBoundary'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { GroupWeatherSection, RideWeatherSection } from '@/components/weather'
import { useWeatherFocus } from '@/components/publication/useWeatherFocus'
import { hasForecast } from '@/components/weather/weatherDisplay'
import { RideSoloGroupPanel } from '@/components/ride/RideSoloGroupPanel'
import { GroupParticipantsSection } from '@/components/ride/group/GroupParticipantsSection'
import { RouteMapPanel } from '@/components/route/RouteMapPanel'
import { GroupStats } from '@/components/ride/group/GroupStats'
import { useScrollToAnchor } from '@/hooks/useScrollToAnchor'
import { withMapColor } from '@/hooks/filters/mapColorFilters'
import { AccessAlerts } from '@/components/publication/AccessAlerts'
import { InstructionsBlock } from '@/components/publication/InstructionsBlock'
import { FactsStrip } from '@/components/publication/FactsStrip'
import { PlacesLine } from '@/components/publication/PlacesLine'
import { PublicationHeader } from '@/components/publication/PublicationHeader'
import { rideFacts } from '@/components/publication/publicationFacts'
import { usePublicationStatusActions } from '@/components/publication/usePublicationStatusActions'

/** The map fills the visible height beside the column on md+ (`.detail-map--fill`, WEB-134); its
 *  skeleton takes the same height so nothing shifts when the map bundle arrives. */
const STICKY_MAP_HEIGHT = 'var(--detail-map-height, 500px)'

/** The anchor of the weather block, as on a group's page: a former group link's `#meteo` lands here. */
const WEATHER_ANCHOR = 'meteo'

/** Below md the map, its profile and the pictures load above `#meteo` after the first scroll. */
const WEATHER_ANCHOR_SETTLE_MS = 4000

export function RideDetailPage() {
  const { t } = useTranslation()
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

  // No `GET team` here: the ride embeds its team's summary, and the reader of a private team's
  // public ride by link does not get the team (docs/LEDGER_*.md WEB-166).
  const {
    ride: { data: ride, isLoading: isLoadingRide, error, refetch },
    weather,
    routesBySlug: groupRoutesBySlug,
    soloGroup: solo,
    soloLeg,
  } = useRideDetailData(teamSlug, rideSlug)

  const statusActions = usePublicationStatusActions(
    teamSlug!,
    'ride',
    ride ? { kind: 'ride', dto: ride } : null
  )
  // A solo ride's map and its « Heure par heure » share their point (WEB-117).
  const weatherFocus = useWeatherFocus(solo?.id, soloLeg)
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

  const team = ride?.team
  useCanonicalPath(team && ride ? paths.ride(team.slug, ride.slug) : undefined)

  // `#meteo`: a solo ride's former group link (WEB-79), or a shared one.
  useScrollToAnchor(WEATHER_ANCHOR, !!ride && !!team && !weather.isLoading, {
    settleMs: WEATHER_ANCHOR_SETTLE_MS,
  })

  if (isLoadingRide || error || !ride || !team) {
    return (
      <Container size="xl" py="xl">
        <QueryStateBoundary
          isLoading={isLoadingRide}
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

  // What the reader may do, as the backend computes it (docs/LEDGER_*.md WEB-166, decision D7):
  // never re-derived from the team's visibility or the reader's role.
  const { permissions } = ride
  const canEdit = permissions.canEdit
  const canReadComments = !!permissions.canComment
  const canSeeParticipants = !!permissions.canSeeParticipants
  // `canRegister` is exact on a detail: published, the reader a member, not every group gone. A
  // member already registered moves group from the other cards instead (« Changer pour », API-171).
  // `ride.full` is deliberately left out: each card already withholds its Join button when its own
  // group is full, and gating the whole zone on it hid every « Complet » badge once all groups filled.
  const canJoinRide = !!permissions.canRegister && !ride.registered
  // Who belongs (the join banner, the group action): the reader who may see the participants — a
  // member, or a platform admin moderating.
  const isMember = canSeeParticipants
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

  // The reader's group, beside the ride's departure when it leaves at a time of its own (WEB-137).
  const registeredGroup = registeredGroupOf(ride)
  const ownTimeGroup =
    registeredGroup && groupLeavesAtOwnTime(registeredGroup.startAt, ride.dateTime)
      ? registeredGroup
      : null

  const handleJoinGroup = membership.join
  const handleLeaveGroup = membership.leave

  return (
    <Container size="xl" py="xl">
      {/* Way back to the team: this page is not mounted inside TeamLayout */}
      <TeamContextBanner team={team} />

      <PublicationHeader
        kind="ride"
        publication={ride}
        reportTargetType={ReportTargetType.RIDE}
        statusActions={canEdit ? statusActions : null}
        editPath={paths.rideEdit(teamSlug!, rideSlug!)}
      >
        {/* The departure, a primary piece of information: under the title, before everything the
            organiser wrote (docs/BRANDING.md §7.8, docs/LEDGER_*.md WEB-137). The ride's own time,
            its reader's group's beside it when that group leaves at another. */}
        <Stack gap="sm">
          <DepartureBlock
            date={ride.dateTime}
            zone={ride.timezone}
            place={ride.startPlace}
            group={ownTimeGroup}
          />
          {/* The start place is in the departure block; the end place, when there is one, here. */}
          <PlacesLine end={ride.endPlace} />
          <FactsStrip kind="ride" facts={rideFacts(ride)} />
        </Stack>
      </PublicationHeader>

      {/* Variant A (docs/LEDGER_*.md WEB-134): the map in a column of its own, sticky on md+, so the
          organiser's free text, however long, never pushes it down. Stacked below md, map first. */}
      <Box
        className={hasMap ? 'detail-layout' : 'detail-layout detail-layout--no-map'}
        mb={{ base: 'md', sm: 'lg' }}
      >
        <Stack className="detail-side" gap="lg">
          {/* The organiser's instructions, only when there are some */}
          <InstructionsBlock media={ride.media} testId="ride-instructions" />

          {/* Groups list — or, for a solo ride, its one group in full (WEB-79) */}
          <Box data-testid="ride-groups">
            {solo ? (
              <Stack gap="md">
                <RideSoloGroupPanel
                  teamSlug={teamSlug!}
                  ride={ride}
                  group={solo}
                  action={groupAction(ride, solo)}
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
                  canSeeParticipants={canSeeParticipants}
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
                              showStartTime={someGroupLeavesAtOwnTime(ride.groups, ride.dateTime)}
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
                              canLeave={groupAction(ride, group) === 'leave'}
                              canSwitch={canSwitchTo(ride, group)}
                              canSeeParticipants={canSeeParticipants}
                              onJoin={() => handleJoinGroup(group.id)}
                              onLeave={() => handleLeaveGroup(group.id)}
                              onSwitch={() => membership.switchTo(group.id)}
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
                {/* Everyone on the ride, under its groups — the solo ride's section, ride-wide. */}
                {ride.groups && ride.groups.length > 0 && (
                  <Box mt="lg">
                    <GroupParticipantsSection
                      teamSlug={teamSlug!}
                      ride={ride}
                      titleId="ride-participants-title"
                      canSeeParticipants={canSeeParticipants}
                    />
                  </Box>
                )}
              </>
            )}
          </Box>

          {/* Weather at the meeting point; each group's route is on the group's own page (WEB-77).
              A solo ride has its group's « Météo du parcours » instead, full width below. */}
          {!solo && (
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
          )}
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
              <RouteMapPanel
                teamSlug={teamSlug!}
                routeSlug={soloRouteSlug}
                route={groupRoutesBySlug.get(soloRouteSlug)}
                leg={soloWindLeg}
                attribution={soloWindLeg ? weather.data?.attribution : undefined}
                timezone={ride.timezone}
                // The point shared with the « Heure par heure » below, as on a group's page (WEB-117)
                selectedCheckpoint={weatherFocus.open}
                onSelectCheckpoint={weatherFocus.selectFromMap}
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
                    kmMarkers={mapItems.length === 1}
                  />
                </Suspense>
              </ErrorBoundary>
            )}
          </Box>
        )}
      </Box>

      {/* A solo ride's page is its group's (WEB-79): its whole route weather, full width under the
          column and the map — its timeline needs the room —, before the comments. No « Météo au
          départ » then: the verdicts already give the departure. */}
      {solo && (
        <Box
          id={WEATHER_ANCHOR}
          mb="lg"
          style={{ scrollMarginTop: 'var(--app-shell-header-height)' }}
        >
          <ErrorBoundary variant="inline">
            <GroupWeatherSection
              ride={ride}
              weather={weather.data}
              leg={soloLeg}
              isLoading={weather.isLoading}
              isFetching={weather.isFetching}
              onRetry={() => void weather.refetch()}
              canEdit={canEdit}
              selection={weatherFocus.selection}
              onSelectionChange={weatherFocus.selectFromTable}
            />
          </ErrorBoundary>
        </Box>
      )}

      <Box mb="lg">
        <AccessAlerts
          kind="ride"
          teamSlug={teamSlug!}
          isAuthenticated={isAuthenticated}
          isMember={isMember}
          teamAccessible={team.accessible}
        />
      </Box>

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

      {statusActions.dialogs}
    </Container>
  )
}
