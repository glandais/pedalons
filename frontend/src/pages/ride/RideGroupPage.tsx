import { useEffect } from 'react'
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
import type { RideDto } from '@/api/dto'
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
import { GroupRouteMap } from '@/components/ride/group/GroupRouteMap'
import { GroupStats } from '@/components/ride/group/GroupStats'
import { GroupWeatherSection } from '@/components/weather'
import { hasForecast } from '@/components/weather/weatherDisplay'
import { paths } from '@/config/paths'
import { useAuth } from '@/hooks/useAuth'
import { useCanonicalPath } from '@/hooks/useCanonicalPath'
import { useRendezvousFormat } from '@/hooks/useRendezvousFormat'
import { useRideGroupMembership } from '@/hooks/useRideGroupMembership'
import { useScrollToAnchor } from '@/hooks/useScrollToAnchor'
import { leavesGroupPage } from './rideDetailData'
import { groupAction, useRideGroupData } from './rideGroupData'

/** Up to this many groups pick from a segmented control; beyond, a select keeps the row short. */
const SEGMENTED_MAX_GROUPS = 4

/** The anchor of the weather section: the ride's cards and the mobile app link to it. */
const WEATHER_ANCHOR = 'meteo'

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
              <GroupJoinActions action={action} group={group} membership={membership} />
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
          <GroupLeader group={group} />

          <GroupParticipantsSection teamSlug={team.slug} ride={ride} group={group} />
        </Stack>

        {/* The group's route: the map with its profile, then what to do with it */}
        <Box className="detail-map">
          {routeSlug && <GroupRouteMap teamSlug={team.slug} routeSlug={routeSlug} route={route} />}
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
          />
        </ErrorBoundary>
      </Box>
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
