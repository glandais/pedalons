import { Navigate, useParams } from 'react-router-dom'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useTranslation } from 'react-i18next'
import { IconUsers, IconCalendar, IconBike, IconMap } from '@tabler/icons-react'
import { Box, Group, Paper, SimpleGrid, Stack, Text, Title, UnstyledButton } from '@mantine/core'
import { paths } from '../../config/paths'
import { useTeamAboutData } from './teamAboutData'
import { LoadingPage } from '../../components/common/LoadingSpinner'
import { TeamLayout } from '../../components/team/TeamLayout'
import { MediaDisplay } from '../../components/common/MediaDisplay'
import { FormattedDate } from '../../components/common/FormattedDate'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'

export function TeamAboutPage() {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const { teamSlug } = useParams<{ teamSlug: string }>()

  const { data: team, isLoading } = useTeamAboutData(teamSlug)

  useCanonicalPath(team ? paths.teamAbout(team.slug) : undefined)

  if (isLoading) {
    return <LoadingPage message={t('loading')} />
  }

  if (!team) {
    return <Navigate to={paths.teams()} replace />
  }

  // Organisers and admins read the directory whatever the team decided; a member needs the team to
  // have opened it (API-39, UserTeamAccessChecker). Same rule as the mobile's members chip: a link
  // that always leads to a 403 is worse than no link.
  // A platform admin reads every directory (docs/LEDGER_*.md API-137).
  const { isMember, isOrganizer } = teamAccess(team, isPlatformAdmin)
  const canSeeMembers = isOrganizer || (isMember && team.enableMemberDirectory)

  const membersStat = (
    <Group gap="sm">
      <Box style={{ flexShrink: 0 }}>
        <IconUsers size={20} color="var(--mantine-color-dimmed)" />
      </Box>
      <Stack gap={0}>
        <Text size="sm" c="dimmed">
          {t('teams.detail.about.members')}
        </Text>
        <Text size="lg" fw={500}>
          {t('memberCount', { count: team.memberCount })}
        </Text>
      </Stack>
    </Group>
  )

  return (
    <TeamLayout team={team} currentTab="about">
      <Box py="md">
        <Paper p="lg" withBorder>
          <Title order={2} mb="md">
            {t('teams.detail.about.title')}
          </Title>

          {/* Description */}
          <Box mb="lg">
            <MediaDisplay media={team.about} />
            {!team.about?.markdown && (
              <Text c="dimmed" fs="italic">
                {t('teams.detail.about.noDescription')}
              </Text>
            )}
          </Box>

          {/* Stats */}
          <Box pt="md" style={{ borderTop: '1px solid var(--mantine-color-default-border)' }}>
            <SimpleGrid cols={{ base: 2, sm: 4 }} spacing="md">
              {canSeeMembers ? (
                <UnstyledButton component={PrefetchLink} to={paths.teamMembers(team.slug)}>
                  {membersStat}
                </UnstyledButton>
              ) : (
                membersStat
              )}

              <UnstyledButton component={PrefetchLink} to={paths.team(team.slug)}>
                <Group gap="sm">
                  <Box style={{ flexShrink: 0 }}>
                    <IconBike size={20} color="var(--mantine-color-dimmed)" />
                  </Box>
                  <Stack gap={0}>
                    <Text size="sm" c="dimmed">
                      {t('teams.detail.about.upcomingRides')}
                    </Text>
                    <Text size="lg" fw={500}>
                      {team.upcomingRideCount}
                    </Text>
                  </Stack>
                </Group>
              </UnstyledButton>

              <UnstyledButton component={PrefetchLink} to={paths.routes(team.slug)}>
                <Group gap="sm">
                  <Box style={{ flexShrink: 0 }}>
                    <IconMap size={20} color="var(--mantine-color-dimmed)" />
                  </Box>
                  <Stack gap={0}>
                    <Text size="sm" c="dimmed">
                      {t('teams.detail.about.routes')}
                    </Text>
                    <Text size="lg" fw={500}>
                      {team.routeCount}
                    </Text>
                  </Stack>
                </Group>
              </UnstyledButton>

              {team.createdAt && (
                <Group gap="sm">
                  <Box style={{ flexShrink: 0 }}>
                    <IconCalendar size={20} color="var(--mantine-color-dimmed)" />
                  </Box>
                  <Stack gap={0}>
                    <Text size="sm" c="dimmed">
                      {t('teams.detail.about.created')}
                    </Text>
                    <Text size="lg" fw={500}>
                      <FormattedDate date={team.createdAt} />
                    </Text>
                  </Stack>
                </Group>
              )}
            </SimpleGrid>
          </Box>
        </Paper>
      </Box>
    </TeamLayout>
  )
}
