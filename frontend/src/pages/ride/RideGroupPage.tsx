import { useEffect, useRef, useState } from 'react'
import { useLocation, useNavigate, useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { IconArrowLeft, IconUsersGroup } from '@tabler/icons-react'
import {
  Alert,
  Anchor,
  Badge,
  Box,
  Button,
  Container,
  Group,
  Paper,
  SegmentedControl,
  Select,
  SimpleGrid,
  Stack,
  Text,
  Title,
} from '@mantine/core'
import type { RideDto, RideGroupDto } from '@/api/dto'
import { startFor } from '@/utils/groupStart'
import { DepartureBlock } from '@/components/common/DepartureBlock'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { QueryStateBoundary } from '@/components/common/QueryStateBoundary'
import { DetailPageSkeleton } from '@/components/common/DetailPageSkeleton'
import { EmptyState } from '@/components/common/EmptyState'
import { ErrorBoundary } from '@/components/common/ErrorBoundary'
import { ShareButton } from '@/components/common/ShareButton'
import { GroupJoinActions } from '@/components/ride/group/GroupJoinActions'
import { GroupLeader } from '@/components/ride/group/GroupLeader'
import { GroupParticipantsSection } from '@/components/ride/group/GroupParticipantsSection'
import { GroupPlaces } from '@/components/ride/group/GroupPlaces'
import { RideGroupRouteActions } from '@/components/ride/RideGroupRouteActions'
import { RouteMapPanel } from '@/components/route/RouteMapPanel'
import { GroupStats } from '@/components/ride/group/GroupStats'
import { GroupWeatherSection, type RouteWeatherSelection } from '@/components/weather'
import { hasForecast } from '@/components/weather/weatherDisplay'
import { paths } from '@/config/paths'
import { withMapColor } from '@/hooks/filters/mapColorFilters'
import { useAuth } from '@/hooks/useAuth'
import { useCanonicalPath } from '@/hooks/useCanonicalPath'
import { useRideGroupMembership } from '@/hooks/useRideGroupMembership'
import { useScrollToAnchor } from '@/hooks/useScrollToAnchor'
import { leavesGroupPage } from './rideDetailData'
import { groupAction, groupWindLeg, useRideGroupData } from './rideGroupData'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'

/** Up to this many groups pick from a segmented control; beyond, a select keeps the row short. */
const SEGMENTED_MAX_GROUPS = 4

/** The anchor of the weather section: the ride's cards and the mobile app link to it. */
const WEATHER_ANCHOR = 'meteo'

/**
 * The forecast point the map and the « Heure par heure » table share (ledger WEB-117): the row
 * selected in the table, and the checkpoint (its `index`) whose badge is lit and popup open on the
 * map in the Météo mode — closing the popup leaves the row selected. Held for one group: another
 * group's page (the same component, its id changed) starts afresh.
 */
interface WeatherFocus {
  groupId?: string
  selection: RouteWeatherSelection
  open: number | null
}

/** The table starts on its first point, no popup open. */
const NO_WEATHER_FOCUS: WeatherFocus = { selection: { position: 0 }, open: null }

/**
 * One group of a ride, on a page of its own (ledger WEB-77): who leads it, when it leaves and at
 * what pace, its places, everyone riding with it, and — full width under them — its whole
 * weather, its route point by point. The ride page keeps the departure weather and one card per group,
 * which links here.
 *
 * Its data is the ride page's (`rideGroupData.ts`): moving between the ride and its groups reads
 * nothing twice. No comments here: the thread is the ride's.
 *
 * Only for a ride with several groups: a ride with at most one has no group page (ledger WEB-79) —
 * the route's loader redirects to the ride (`rideGroupDataRedirect`), and when it could not (no
 * ride in the cache: a private team rendered anonymously), this page replaces its URL with the
 * ride's, query string and `#meteo` kept, showing only its skeleton meanwhile.
 */
export function RideGroupPage() {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const { teamSlug, rideSlug, groupId } = useParams<{
    teamSlug: string
    rideSlug: string
    groupId: string
  }>()
  const { isAuthenticated } = useAuth()
  const location = useLocation()
  const navigate = useNavigate()

  const {
    team: { data: team, isLoading: isLoadingTeam },
    ride: { data: ride, isLoading: isLoadingRide, error, refetch },
    weather,
    routesBySlug,
    group,
    leg,
  } = useRideGroupData(teamSlug, rideSlug, groupId)
  const membership = useRideGroupMembership(teamSlug!, rideSlug!)
  // The Select's input keeps the focus after a pick, and iOS Safari then offers to AutoFill it
  // (« Remplir »): drop the focus once the choice is made.
  const groupSelectRef = useRef<HTMLInputElement>(null)
  const [heldFocus, setWeatherFocus] = useState<WeatherFocus>(NO_WEATHER_FOCUS)
  const weatherFocus = heldFocus.groupId === groupId ? heldFocus : NO_WEATHER_FOCUS
  // A row of the table (a column, a phase, the slider): its point lights up on the map. The camera
  // stays where it is, and the mode does not switch to Météo by itself.
  const selectFromTable = (selection: RouteWeatherSelection) =>
    setWeatherFocus({
      groupId,
      selection,
      open: leg?.checkpoints[selection.position]?.index ?? null,
    })
  // A badge of the map: its row is selected, the page does not scroll. Its popup closed: the row
  // stays.
  const selectFromMap = (index: number | null) => {
    const position =
      index === null ? -1 : (leg?.checkpoints.findIndex((c) => c.index === index) ?? -1)
    setWeatherFocus({
      groupId,
      selection: position >= 0 ? { position, fromMap: true } : weatherFocus.selection,
      open: index,
    })
  }

  // A ride with at most one group: its page is the group's (WEB-79), the URL is replaced.
  // Not through `useCanonicalPath`, which checks once: a ride read with two groups then refetched
  // with one would otherwise leave this page on its skeleton for good. The ride's page fixes a stale
  // team slug itself.
  const leave = ride ? leavesGroupPage(ride) : false
  const leaveTo = ride && leave ? paths.ride(teamSlug!, ride.slug) : undefined
  useEffect(() => {
    if (leaveTo) navigate(leaveTo + location.search + location.hash, { replace: true })
  }, [leaveTo, navigate, location.search, location.hash])
  useCanonicalPath(
    team && ride && groupId && !leave ? paths.rideGroup(team.slug, ride.slug, groupId) : undefined
  )

  // `#meteo` (a card's link, the app's « Météo » tab shared): the section only exists once the
  // ride is read, after the browser gave up looking for it.
  useScrollToAnchor(WEATHER_ANCHOR, !!group && !leave && !weather.isLoading)

  if (isLoadingTeam || isLoadingRide || error || !ride || !team || leave) {
    return (
      <Container size="xl" py="xl">
        <QueryStateBoundary
          isLoading={isLoadingTeam || isLoadingRide || leave}
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

  const backToRide = (
    <Anchor
      component={PrefetchLink}
      to={paths.ride(team.slug, ride.slug)}
      size="sm"
      c="dimmed"
      underline="hover"
    >
      <Group gap={4} wrap="nowrap">
        <IconArrowLeft size={16} aria-hidden />
        {t('rides.group.backToRide')}
      </Group>
    </Anchor>
  )

  // A group the ride no longer has: an old link, after an edit dropped it (several groups left).
  if (!group) {
    return (
      <Container size="xl" py="xl">
        <EmptyState
          icon={<IconUsersGroup size={48} />}
          title={t('rides.group.notFound.title')}
          description={t('rides.group.notFound.description')}
          actions={
            <Button component={PrefetchLink} to={paths.ride(team.slug, ride.slug)}>
              {t('rides.group.backToRide')}
            </Button>
          }
        />
      </Container>
    )
  }

  // Registering follows the real membership; editing, a platform admin's right too
  // (docs/LEDGER_*.md API-137).
  const { isMember, isOrganizer: canEdit } = teamAccess(team, isPlatformAdmin)
  const action = groupAction(ride, group, isMember)
  const groups = ride.groups ?? []
  const otherGroup =
    action === 'registeredElsewhere'
      ? groups.find((g) => g.id === ride.registeredGroupId)
      : undefined
  const routeSlug = group.routeSlug ?? ride.routeSlug
  const route = routeSlug ? routesBySlug.get(routeSlug) : undefined
  // The wind on the map (WEB-115): a leg with a forecast, on a ride neither finished nor cancelled.
  const windLeg = groupWindLeg(ride, leg)
  const groupError = membership.error?.groupId === group.id ? membership.error.message : undefined

  const groupOptions = groups.map((g) => ({
    value: g.id,
    label: g.maxParticipants
      ? t('rides.group.option', {
          name: g.name,
          current: g.countParticipants,
          max: g.maxParticipants,
        })
      : t('rides.group.optionNoMax', { name: g.name, current: g.countParticipants }),
  }))
  const chooseGroup = (id: string | null) => {
    groupSelectRef.current?.blur()
    if (id && id !== group.id) navigate(paths.rideGroup(team.slug, ride.slug, id))
  }

  return (
    <Container size="xl" py="xl">
      <Box mb="md">{backToRide}</Box>

      {/* Header: the ride, the group, its places and what the reader can do */}
      <Paper shadow="xs" p="lg" mb="lg" withBorder>
        <Stack gap="md">
          {groups.length > 1 &&
            (groups.length <= SEGMENTED_MAX_GROUPS ? (
              <SegmentedControl
                data={groupOptions}
                value={group.id}
                onChange={chooseGroup}
                aria-label={t('rides.group.selector')}
                fullWidth
              />
            ) : (
              <Select
                ref={groupSelectRef}
                data={groupOptions}
                value={group.id}
                onChange={chooseGroup}
                label={t('rides.group.selector')}
                allowDeselect={false}
                maxDropdownHeight={400}
                maw={360}
              />
            ))}

          <Group justify="space-between" wrap="wrap" align="flex-start">
            <Stack gap={4} style={{ minWidth: 0 }}>
              <RideHeaderLine ride={ride} />
              <Group gap="sm" wrap="wrap">
                <Title order={1} size="h2">
                  {t('rides.group.title', { name: group.name })}
                </Title>
                {group.registered ? (
                  <Badge color="primary" variant="light">
                    {t('rides.detail.groups.joined')}
                  </Badge>
                ) : (
                  group.full && (
                    <Badge color="gray" variant="light">
                      {t('rides.detail.groups.full')}
                    </Badge>
                  )
                )}
                {/* Beside the title, not with the join actions: signed out there are none, and
                    the button sat alone on its own line. */}
                <ShareButton title={t('rides.group.title', { name: group.name })} />
              </Group>
            </Stack>
            <GroupJoinActions action={action} group={group} membership={membership} />
          </Group>

          <GroupDepartureBlock ride={ride} group={group} />

          <GroupPlaces group={group} />

          {otherGroup && (
            <Text size="sm" data-testid="registered-elsewhere">
              {t('rides.group.registeredElsewhere', { group: otherGroup.name })}{' '}
              <Anchor
                component={PrefetchLink}
                to={paths.rideGroup(team.slug, ride.slug, otherGroup.id)}
                fw={500}
              >
                {t('rides.group.view')}
              </Anchor>
            </Text>
          )}

          {groupError && (
            <Alert color="red" variant="light">
              {groupError}
            </Alert>
          )}

          {!isAuthenticated && (
            <Alert color="blue" variant="light">
              <Text size="sm">
                {t('rides.group.signInToJoin')}{' '}
                <Anchor
                  component={PrefetchLink}
                  to={paths.login()}
                  state={{ from: location }}
                  fw={500}
                >
                  {t('rides.detail.notAuthenticated.signIn')}
                </Anchor>
              </Text>
            </Alert>
          )}
          {isAuthenticated && !isMember && (
            <Alert color="yellow" variant="light">
              <Text size="sm">
                {t('rides.detail.nonMember.message')}{' '}
                <Anchor component={PrefetchLink} to={paths.team(team.slug)} fw={500}>
                  {t('rides.detail.nonMember.viewTeam')}
                </Anchor>
              </Text>
            </Alert>
          )}
        </Stack>
      </Paper>

      <SimpleGrid cols={{ base: 1, md: 2, xl: 3 }} spacing={{ base: 'md', sm: 'lg' }}>
        <Stack gap="lg">
          <GroupStats
            ride={ride}
            group={group}
            arrival={leg && hasForecast(leg.status) ? leg.arrivalTime : undefined}
            showDeparture={false}
          />

          {/* The leader — only when one is designated, never the ride's creator */}
          <GroupLeader group={group} />

          <GroupParticipantsSection
            teamSlug={team.slug}
            ride={ride}
            group={group}
            canSeeParticipants={isMember || isPlatformAdmin}
          />

          {/* What to do with the route, beside the map rather than under it: the map column fills
              the visible height (docs/LEDGER_*.md WEB-134) */}
          {routeSlug && (
            <Paper withBorder p="md">
              <Stack gap="xs">
                <Title order={3} size="h5">
                  {t('rides.group.routeTitle')}
                </Title>
                <RideGroupRouteActions
                  teamSlug={team.slug}
                  routeSlug={routeSlug}
                  route={route}
                  size="sm"
                />
              </Stack>
            </Paper>
          )}
        </Stack>

        {/* The group's route: the map with its profile, sticky and filling the visible height */}
        <Box className="detail-map detail-map--fill detail-map--solo">
          {routeSlug && (
            <RouteMapPanel
              teamSlug={team.slug}
              routeSlug={routeSlug}
              route={route}
              leg={windLeg}
              attribution={windLeg ? weather.data?.attribution : undefined}
              timezone={ride.timezone}
              selectedCheckpoint={weatherFocus.open}
              onSelectCheckpoint={selectFromMap}
              // Its own fullscreen map, in the mode the line is in (WEB-117)
              fullscreenPath={(colorBy) =>
                withMapColor(paths.rideGroupMap(team.slug, ride.slug, group.id), colorBy)
              }
              withActions={false}
              heightVariant="sticky"
            />
          )}
        </Box>
      </SimpleGrid>

      {/* The group's weather, full width under the stats and the map: its timeline needs the room */}
      <Box
        id={WEATHER_ANCHOR}
        mt={{ base: 'md', sm: 'lg' }}
        style={{ scrollMarginTop: 'var(--app-shell-header-height)' }}
      >
        <ErrorBoundary variant="inline">
          <GroupWeatherSection
            ride={ride}
            weather={weather.data}
            leg={leg}
            isLoading={weather.isLoading}
            isFetching={weather.isFetching}
            onRetry={() => void weather.refetch()}
            canEdit={canEdit}
            selection={weatherFocus.selection}
            onSelectionChange={selectFromTable}
          />
        </ErrorBoundary>
      </Box>
    </Container>
  )
}

/**
 * The ride's name above the group's title. The departure itself is the block under the title
 * (docs/BRANDING.md §7.8): the group's time, its date, and how it sits against the ride's.
 */
function RideHeaderLine({ ride }: { ride: RideDto }) {
  return (
    <Text size="sm" c="dimmed">
      {ride.name}
    </Text>
  )
}

/** The group's departure block: its own time. */
function GroupDepartureBlock({ ride, group }: { ride: RideDto; group: RideGroupDto }) {
  return <DepartureBlock date={startFor(ride, group)} zone={ride.timezone} />
}
