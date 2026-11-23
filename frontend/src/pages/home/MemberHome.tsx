import { useTranslation } from 'react-i18next'
import { formatInTimeZone } from 'date-fns-tz'
import { fr } from 'date-fns/locale/fr'
import { enUS } from 'date-fns/locale/en-US'
import { Box, Button, Grid, Group, Paper, Skeleton, Stack, Text, Title } from '@mantine/core'
import { IconBike, IconCalendar } from '@tabler/icons-react'
import type { RideDto } from '../../api/dto'
import { EmptyState } from '../../components/common/EmptyState'
import { PrefetchLink } from '../../components/common/PrefetchLink'
import { HomeFeedSection } from '../../components/home/HomeFeedSection'
import { NextRideCard } from '../../components/home/NextRideCard'
import { WeekAgenda } from '../../components/home/WeekAgenda'
import { MyTeamsCard } from '../../components/home/MyTeamsCard'
import { QuickActions } from '../../components/home/QuickActions'
import { NoTeamWelcome } from '../../components/home/NoTeamWelcome'
import { PendingInvitationsBanner } from '../../components/team/PendingInvitationsBanner'
import { useWeekSummary } from '../../components/home/memberHomeHelpers'
import { paths } from '../../config/paths'
import { useAuth } from '../../hooks/useAuth'
import { useEffectiveTimezone } from '../../utils/dateFormat'
import { useHomeFeedData, useMemberHomeData } from './homeFeedData'

const NEXT_RIDE_HEADING_ID = 'home-next-ride-title'

/**
 * The home of a signed-in member: greeting, organizer shortcuts, « Ma prochaine sortie », the
 * week and their teams aside, then the feed. Without any team, one welcome block replaces those
 * three cards (`NoTeamWelcome`, docs/LEDGER_*.md WEB-194).
 */
export function MemberHome() {
  const { t, i18n } = useTranslation()
  const { user } = useAuth()
  const { timezone } = useEffectiveTimezone()
  const feed = useHomeFeedData()
  const { week, teams } = useMemberHomeData(feed.nowIso)
  const summary = useWeekSummary(week.data?.events)
  // Known to be no team, not merely not loaded yet: while loading or on error the usual cards say so.
  const noTeam = teams.isSuccess && teams.data.teams.length === 0
  // Without a team, « Ma prochaine sortie » and the week only show when they hold something — a
  // public ride of another team the person signed up to; empty, they were the dead ends WEB-194
  // replaced with the welcome block.
  const hasWeekEvents = (week.data?.events?.length ?? 0) > 0

  // Registered rides only: the participations window also holds trips and watched rides.
  const participations = feed.participations
  const nextRide = participations.data?.publications?.find(
    (p): p is RideDto => p.type === 'RIDE' && (p as RideDto).registered
  )
  const showAgenda = !noTeam || nextRide !== undefined || hasWeekEvents

  const today = formatInTimeZone(new Date(), timezone, t('home.member.dateFormat'), {
    locale: i18n.language === 'fr' ? fr : enUS,
  })

  // Outside the card (loading, error, nothing booked) the section keeps its heading all the same.
  const nextRideHeading = (
    <Title id={NEXT_RIDE_HEADING_ID} order={2} size="h5" c="dimmed" tt="uppercase">
      {t('home.nextRide.title')}
    </Title>
  )

  const header = (
    <Group justify="space-between" align="flex-end" gap="md">
      <Box>
        <Text c="dimmed" size="sm" suppressHydrationWarning>
          {today}
        </Text>
        <Title order={1}>
          {user?.displayName
            ? t('home.member.greeting', { name: user.displayName })
            : t('home.member.greetingAnonymous')}
        </Title>
        {summary && (
          <Text c="dimmed" mt={4}>
            {summary}
          </Text>
        )}
      </Box>
      <QuickActions teams={teams.data?.teams} />
    </Group>
  )

  return (
    <Stack>
      {header}
      {/* An invitee lands here after signing up: the invitation is the first thing to do (WEB-193).
          Without a team, the welcome block holds the invitations itself. */}
      {!noTeam && <PendingInvitationsBanner />}
      <Stack gap="xl">
        {noTeam && <NoTeamWelcome />}
        {showAgenda && (
          <Grid gap="lg">
            <Grid.Col span={{ base: 12, md: 7, lg: 8 }}>
              <Box component="section" aria-labelledby={NEXT_RIDE_HEADING_ID}>
                {nextRide ? (
                  <NextRideCard ride={nextRide} headingId={NEXT_RIDE_HEADING_ID} />
                ) : participations.isLoading ? (
                  <Paper withBorder radius="md" p="md">
                    <Stack>
                      {nextRideHeading}
                      <Skeleton h={24} w="40%" />
                      <Skeleton h={160} />
                      <Skeleton h={36} w="60%" />
                    </Stack>
                  </Paper>
                ) : participations.isError ? (
                  <Paper withBorder radius="md" p="md">
                    <Stack gap="xs">
                      {nextRideHeading}
                      <Text size="sm" c="dimmed">
                        {t('error.loading')}
                      </Text>
                    </Stack>
                  </Paper>
                ) : (
                  <Stack gap="xs">
                    {nextRideHeading}
                    <EmptyState
                      icon={<IconBike size={48} />}
                      title={t('home.nextRide.empty.title')}
                      description={t('home.nextRide.empty.description')}
                      actions={
                        <Button
                          component={PrefetchLink}
                          to={paths.calendar()}
                          variant="light"
                          leftSection={<IconCalendar size={16} />}
                        >
                          {t('home.week.calendarLink')}
                        </Button>
                      }
                    />
                  </Stack>
                )}
              </Box>
            </Grid.Col>
            <Grid.Col span={{ base: 12, md: 5, lg: 4 }}>
              <Stack gap="lg">
                <WeekAgenda
                  nowIso={feed.nowIso}
                  events={week.data?.events}
                  isLoading={week.isLoading}
                  isError={week.isError}
                  nextRide={
                    nextRide ? { teamSlug: nextRide.team.slug, slug: nextRide.slug } : undefined
                  }
                />
                {!noTeam && (
                  <MyTeamsCard
                    teams={teams.data?.teams}
                    total={teams.data?.total}
                    isLoading={teams.isLoading}
                    isError={teams.isError}
                  />
                )}
              </Stack>
            </Grid.Col>
          </Grid>
        )}

        <HomeFeedSection feed={feed} title={t('home.feed.title')} />
      </Stack>
    </Stack>
  )
}
