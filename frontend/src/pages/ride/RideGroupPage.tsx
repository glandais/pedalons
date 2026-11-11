import { useEffect } from 'react'
import { useLocation, useNavigate, useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { IconPencil, IconUsersGroup } from '@tabler/icons-react'
import { Alert, Anchor, Badge, Button, Container, Stack, Text } from '@mantine/core'
import { startFor } from '@/utils/groupStart'
import { DepartureBlock } from '@/components/common/DepartureBlock'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { QueryStateBoundary } from '@/components/common/QueryStateBoundary'
import { DetailPageSkeleton } from '@/components/common/DetailPageSkeleton'
import { EmptyState } from '@/components/common/EmptyState'
import { ErrorBoundary } from '@/components/common/ErrorBoundary'
import { ShareButton } from '@/components/common/ShareButton'
import { ChildDetailShell } from '@/components/publication/ChildDetailShell'
import { RouteCard } from '@/components/publication/RouteCard'
import { PlacesLine } from '@/components/publication/PlacesLine'
import { CHILD_WEATHER_ANCHOR, useWeatherFocus } from '@/components/publication/useWeatherFocus'
import { GroupJoinActions } from '@/components/ride/group/GroupJoinActions'
import { GroupLeader } from '@/components/ride/group/GroupLeader'
import { GroupParticipantsSection } from '@/components/ride/group/GroupParticipantsSection'
import { GroupPlaces } from '@/components/ride/group/GroupPlaces'
import { RouteMapPanel } from '@/components/route/RouteMapPanel'
import { GroupStats } from '@/components/ride/group/GroupStats'
import { GroupWeatherSection } from '@/components/weather'
import { hasForecast } from '@/components/weather/weatherDisplay'
import { paths } from '@/config/paths'
import { withMapColor } from '@/hooks/filters/mapColorFilters'
import { useAuth } from '@/hooks/useAuth'
import { useCanonicalPath } from '@/hooks/useCanonicalPath'
import { useRideGroupMembership } from '@/hooks/useRideGroupMembership'
import { useScrollToAnchor } from '@/hooks/useScrollToAnchor'
import { leavesGroupPage } from './rideDetailData'
import { groupAction, groupWindLeg, useRideGroupData } from './rideGroupData'

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
    ride: { data: ride, isLoading: isLoadingRide, error, refetch },
    weather,
    routesBySlug,
    group,
    leg,
  } = useRideGroupData(teamSlug, rideSlug, groupId)
  const membership = useRideGroupMembership(teamSlug!, rideSlug!)
  const weatherFocus = useWeatherFocus(groupId, leg)

  // A ride with at most one group: its page is the group's (WEB-79), the URL is replaced.
  // Not through `useCanonicalPath`, which checks once: a ride read with two groups then refetched
  // with one would otherwise leave this page on its skeleton for good. The ride's page fixes a stale
  // team slug itself.
  // The ride's embedded team: no `GET team` for a page a private team's public ride opens by link
  // (docs/LEDGER_*.md WEB-166).
  const team = ride?.team
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
  useScrollToAnchor(CHILD_WEATHER_ANCHOR, !!group && !leave && !weather.isLoading)

  if (isLoadingRide || error || !ride || !team || leave) {
    return (
      <Container size="xl" py="xl">
        <QueryStateBoundary
          isLoading={isLoadingRide || leave}
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

  // The backend's answers for this ride (docs/LEDGER_*.md WEB-166, decision D7).
  const canEdit = ride.permissions.canEdit
  const isMember = !!ride.permissions.canSeeParticipants
  const action = groupAction(ride, group)
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

  const siblings = groups.map((g) => ({
    id: g.id,
    href: paths.rideGroup(team.slug, ride.slug, g.id),
    label: g.maxParticipants
      ? t('rides.group.option', {
          name: g.name,
          current: g.countParticipants,
          max: g.maxParticipants,
        })
      : t('rides.group.optionNoMax', { name: g.name, current: g.countParticipants }),
  }))
  const title = t('rides.group.title', { name: group.name })

  return (
    <ChildDetailShell
      backTo={paths.ride(team.slug, ride.slug)}
      backLabel={t('rides.group.backToRide')}
      parentName={ride.name}
      siblings={siblings}
      currentId={group.id}
      siblingLabel={t('rides.group.selector')}
      title={title}
      badges={
        <>
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
          {/* Beside the title, not with the join actions: signed out there are none, and the
              button sat alone on its own line. */}
          <ShareButton title={title} />
        </>
      }
      actions={
        <>
          <GroupJoinActions action={action} group={group} membership={membership} />
          {canEdit && (
            <Button
              component={PrefetchLink}
              to={paths.rideEdit(team.slug, ride.slug)}
              variant="outline"
              leftSection={<IconPencil size={16} />}
            >
              {t('actions.edit')}
            </Button>
          )}
        </>
      }
      departure={
        <Stack gap="sm">
          {/* The group's own time, and where everyone meets (docs/BRANDING.md §7.8). */}
          <DepartureBlock
            date={startFor(ride, group)}
            zone={ride.timezone}
            place={ride.startPlace}
          />
          <PlacesLine end={ride.endPlace} />
          <GroupPlaces group={group} />
        </Stack>
      }
      notices={
        <>
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
                {t('rides.detail.nonMember.message')}
                {team.accessible && (
                  <>
                    {' '}
                    <Anchor component={PrefetchLink} to={paths.team(team.slug)} fw={500}>
                      {t('rides.detail.nonMember.viewTeam')}
                    </Anchor>
                  </>
                )}
              </Text>
            </Alert>
          )}
        </>
      }
      error={groupError}
      side={
        <>
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
            canSeeParticipants={isMember}
          />

          {/* What to do with the route, beside the map rather than under it: the map column fills
              the visible height (docs/LEDGER_*.md WEB-134) */}
          {routeSlug && (
            <RouteCard
              title={route?.name ?? t('rides.group.routeTitle')}
              teamSlug={team.slug}
              routeSlug={routeSlug}
              route={route}
            />
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
            timezone={ride.timezone}
            selectedCheckpoint={weatherFocus.open}
            onSelectCheckpoint={weatherFocus.selectFromMap}
            // Its own fullscreen map, in the mode the line is in (WEB-117)
            fullscreenPath={(colorBy) =>
              withMapColor(paths.rideGroupMap(team.slug, ride.slug, group.id), colorBy)
            }
            withActions={false}
            heightVariant="sticky"
          />
        ) : null
      }
      weather={
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
            onSelectionChange={weatherFocus.selectFromTable}
          />
        </ErrorBoundary>
      }
    />
  )
}
