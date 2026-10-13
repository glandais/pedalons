import { lazy, Suspense, useCallback, useEffect, useRef, type ReactNode } from 'react'
import { useLocation, useNavigate, useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import {
  IconArrowLeft,
  IconArrowsMaximize,
  IconArrowUp,
  IconBolt,
  IconClock,
  IconShieldCheck,
  IconUsersGroup,
} from '@tabler/icons-react'
import {
  Alert,
  Anchor,
  Badge,
  Box,
  Button,
  Container,
  Group,
  Paper,
  Progress,
  SegmentedControl,
  Select,
  SimpleGrid,
  Skeleton,
  Stack,
  Text,
  Title,
} from '@mantine/core'
import type { RideDto, RideGroupDto } from '@/api/dto'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { QueryStateBoundary } from '@/components/common/QueryStateBoundary'
import { DetailPageSkeleton } from '@/components/common/DetailPageSkeleton'
import { EmptyState } from '@/components/common/EmptyState'
import { ErrorBoundary } from '@/components/common/ErrorBoundary'
import { Rendezvous } from '@/components/common/Rendezvous'
import { ShareButton } from '@/components/common/ShareButton'
import { UserAvatar } from '@/components/common/UserAvatar'
import { ParticipantList } from '@/components/ride/ParticipantList'
import { RideGroupRouteActions } from '@/components/ride/RideGroupRouteActions'
import { GroupWeatherSection } from '@/components/weather'
import { hasForecast } from '@/components/weather/weatherDisplay'
import { paths } from '@/config/paths'
import { useAuth } from '@/hooks/useAuth'
import { useCanonicalPath } from '@/hooks/useCanonicalPath'
import { useDebouncedSearch } from '@/hooks/useDebouncedSearch'
import { useRendezvousFormat } from '@/hooks/useRendezvousFormat'
import { useRideGroupMembership } from '@/hooks/useRideGroupMembership'
import { useUnits } from '@/hooks/useUnits'
import { useUrlFilters } from '@/hooks/useUrlFilters'
import {
  groupParticipantFiltersAlias,
  groupParticipantFiltersSchema,
} from '@/hooks/filters/groupParticipantFilters'
import { groupStartRelation } from '@/utils/groupStart'
import { groupAction, useRideGroupData } from './rideGroupData'

// Lazy: the map pulls in map-vendor (~1 MB) and the elevation chart chart-vendor.
const RouteMapView = lazy(() =>
  import('@/components/route/RouteMapView').then((m) => ({ default: m.RouteMapView }))
)

/** Up to this many groups pick from a segmented control; beyond, a select keeps the row short. */
const SEGMENTED_MAX_GROUPS = 4

/** The anchor of the weather section: the ride's cards and the mobile app link to it. */
const WEATHER_ANCHOR = 'meteo'

/**
 * One group of a ride, on a page of its own (ledger WEB-77): who leads it, when it leaves and at
 * what pace, its places, its whole weather — the departure and its route, point by point — and
 * everyone riding with it. The ride page keeps the departure weather and one card per group,
 * which links here.
 *
 * Its data is the ride page's (`rideGroupData.ts`): moving between the ride and its groups reads
 * nothing twice. No comments here: the thread is the ride's.
 */
export function RideGroupPage() {
  const { t } = useTranslation()
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

  const { filters, setFilters } = useUrlFilters({
    schema: groupParticipantFiltersSchema,
    alias: groupParticipantFiltersAlias,
  })
  const commitSearch = useCallback(
    (value: string) => setFilters({ search: value || undefined }),
    [setFilters]
  )
  const [searchInput, setSearchInput] = useDebouncedSearch(filters.search ?? '', commitSearch)

  useCanonicalPath(
    team && ride && groupId ? paths.rideGroup(team.slug, ride.slug, groupId) : undefined
  )

  // `#meteo` (a card's link, the app's « Météo » tab shared): the section only exists once the
  // ride is read, after the browser gave up looking for it.
  const scrolledRef = useRef(false)
  const ready = !!group && !weather.isLoading
  useEffect(() => {
    if (scrolledRef.current || !ready || location.hash !== `#${WEATHER_ANCHOR}`) return
    scrolledRef.current = true
    document.getElementById(WEATHER_ANCHOR)?.scrollIntoView({ block: 'start' })
  }, [ready, location.hash])

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

  // A group the ride no longer has: an old link, after an edit dropped it.
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

  const isMember = !!team.role
  const canEdit = team.role === 'ADMIN' || team.role === 'ORGANIZER'
  const action = groupAction(ride, group, isMember)
  const groups = ride.groups ?? []
  const otherGroup =
    action === 'registeredElsewhere'
      ? groups.find((g) => g.id === ride.registeredGroupId)
      : undefined
  const routeSlug = group.routeSlug ?? ride.routeSlug
  const route = routeSlug ? routesBySlug.get(routeSlug) : undefined
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
              </Group>
            </Stack>
            <Group gap="xs" wrap="nowrap">
              {action === 'join' && (
                <Button onClick={() => membership.join(group.id)} disabled={membership.isPending}>
                  {t('rides.detail.groups.join')}
                </Button>
              )}
              {action === 'leave' && (
                <Button
                  variant="outline"
                  onClick={() => membership.leave(group.id)}
                  disabled={membership.isPending}
                >
                  {t('rides.detail.groups.leave')}
                </Button>
              )}
              <ShareButton title={t('rides.group.title', { name: group.name })} />
            </Group>
          </Group>

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
          />

          {/* The leader — only when one is designated, never the ride's creator */}
          {group.leader && (
            <Paper withBorder p="md" data-testid="group-leader">
              <Group gap="sm" wrap="nowrap">
                <UserAvatar user={group.leader} size="md" />
                <Text fw={500} truncate>
                  {group.leader.displayName}
                </Text>
                <Badge
                  variant="light"
                  leftSection={<IconShieldCheck size={12} aria-hidden />}
                  style={{ flexShrink: 0 }}
                >
                  {t('rides.detail.groups.leader')}
                </Badge>
              </Group>
            </Paper>
          )}

          <Box id={WEATHER_ANCHOR} style={{ scrollMarginTop: 'var(--app-shell-header-height)' }}>
            <ErrorBoundary variant="inline">
              <GroupWeatherSection
                ride={ride}
                weather={weather.data}
                leg={leg}
                isLoading={weather.isLoading}
                isFetching={weather.isFetching}
                onRetry={() => void weather.refetch()}
                canEdit={canEdit}
              />
            </ErrorBoundary>
          </Box>

          <Paper withBorder p="lg" component="section" aria-labelledby="group-participants-title">
            <Stack gap="md">
              <Group justify="space-between" wrap="wrap" gap="xs">
                <Title order={3} size="h4" id="group-participants-title">
                  {t('rides.group.participantsTitle')}
                </Title>
                <Text size="sm" c="dimmed">
                  {t('rides.detail.groups.participantsNoMax', {
                    current: group.countParticipants,
                  })}
                </Text>
              </Group>
              <ParticipantList
                source={{
                  kind: 'ride',
                  teamSlug: team.slug,
                  rideSlug: ride.slug,
                  groupId: group.id,
                }}
                count={group.countParticipants}
                leaderId={group.leader?.id}
                search={filters.search}
                page={filters.page}
                searchInput={searchInput}
                onSearchInputChange={setSearchInput}
                onPageChange={(page) => setFilters({ page })}
                searchPlaceholder={t('participants.searchByName')}
                noMatch={t('participants.noMatchGeneric')}
              />
            </Stack>
          </Paper>
        </Stack>

        {/* The group's route: the map with its profile, then what to do with it */}
        <Box className="detail-map">
          {routeSlug && (
            <Stack gap="md">
              <ErrorBoundary variant="inline">
                {route ? (
                  <Suspense fallback={<Skeleton height={500} radius="md" />}>
                    <RouteMapView
                      route={route}
                      fullscreenPath={paths.routeMap(team.slug, routeSlug)}
                    />
                  </Suspense>
                ) : (
                  <Skeleton height={500} radius="md" />
                )}
              </ErrorBoundary>
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
            </Stack>
          )}
        </Box>
      </SimpleGrid>
    </Container>
  )
}

/** « Sortie du samedi · samedi 10 octobre 2026, départ 08:00 », in the ride's zone. */
function RideHeaderLine({ ride }: { ride: RideDto }) {
  const { t } = useTranslation()
  const rendezvous = useRendezvousFormat(ride.timezone)
  return (
    <Text size="sm" c="dimmed" suppressHydrationWarning={rendezvous.isGuessedText}>
      {t('rides.group.header', {
        ride: ride.name,
        date: rendezvous.formatDate(ride.dateTime),
        time: rendezvous.formatTime(ride.dateTime),
      })}
    </Text>
  )
}

/** The places bar: « 11/12 participants », « 1 place restante ». No max, no bar. */
function GroupPlaces({ group }: { group: RideGroupDto }) {
  const { t } = useTranslation()
  if (!group.maxParticipants) {
    return (
      <Text size="sm" c="dimmed">
        {t('rides.detail.groups.participantsNoMax', { current: group.countParticipants })}
      </Text>
    )
  }
  const max = group.maxParticipants
  const left = Math.max(0, max - group.countParticipants)
  return (
    <Stack gap={4} data-testid="group-places">
      <Group justify="space-between" gap="xs">
        <Text size="sm" fw={500}>
          {t('rides.detail.groups.participants', { current: group.countParticipants, max })}
        </Text>
        <Text size="sm" c="dimmed">
          {t('rides.group.placesLeft', { count: left })}
        </Text>
      </Group>
      <Progress
        value={Math.min(100, (group.countParticipants / max) * 100)}
        color={left === 0 ? 'gray' : 'primary'}
        aria-label={t('rides.detail.groups.participants', {
          current: group.countParticipants,
          max,
        })}
      />
    </Stack>
  )
}

/** One figure of the group: its label above, its value, an optional line below. */
function StatTile({
  icon,
  label,
  children,
  hint,
}: {
  icon: ReactNode
  label: string
  children: ReactNode
  hint?: ReactNode
}) {
  return (
    <Stack gap={2}>
      <Group gap={4} wrap="nowrap" c="dimmed">
        {icon}
        <Text size="xs" tt="uppercase" fw={600} c="dimmed">
          {label}
        </Text>
      </Group>
      <Text fw={700} size="lg">
        {children}
      </Text>
      {hint && (
        <Text size="xs" c="dimmed">
          {hint}
        </Text>
      )}
    </Stack>
  )
}

/** Departure, pace, distance and climb — each one only when the group has it. */
function GroupStats({
  ride,
  group,
  arrival,
}: {
  ride: RideDto
  group: RideGroupDto
  /** The estimated arrival of the group's leg, when the forecast gives one. */
  arrival: string | undefined
}) {
  const { t } = useTranslation()
  const { speed, distance, elevation } = useUnits()
  const rendezvous = useRendezvousFormat(ride.timezone)
  const relation = groupStartRelation(group.startAt, ride.dateTime)

  return (
    <Paper withBorder p="lg" data-testid="group-stats">
      <SimpleGrid cols={{ base: 2, sm: 4 }} spacing="md">
        {group.startAt && (
          <StatTile
            icon={<IconClock size={14} aria-hidden />}
            label={t('rides.group.stats.departure')}
            hint={t(`rides.group.stats.${relation}`)}
          >
            <Rendezvous date={group.startAt} zone={ride.timezone} format="time" />
          </StatTile>
        )}
        {group.averageSpeed && (
          <StatTile
            icon={<IconBolt size={14} aria-hidden />}
            label={t('rides.group.stats.pace')}
            hint={
              arrival && (
                <span suppressHydrationWarning={rendezvous.isGuessedText}>
                  {t('rides.group.stats.arrival', { time: rendezvous.formatTime(arrival) })}
                </span>
              )
            }
          >
            {speed(group.averageSpeed)}
          </StatTile>
        )}
        {group.distance !== undefined && (
          <StatTile
            icon={<IconArrowsMaximize size={14} aria-hidden />}
            label={t('rides.group.stats.distance')}
          >
            {distance(group.distance)}
          </StatTile>
        )}
        {group.elevationGain !== undefined && (
          <StatTile
            icon={<IconArrowUp size={14} aria-hidden />}
            label={t('rides.group.stats.elevation')}
          >
            {elevation(group.elevationGain)}
          </StatTile>
        )}
      </SimpleGrid>
    </Paper>
  )
}
