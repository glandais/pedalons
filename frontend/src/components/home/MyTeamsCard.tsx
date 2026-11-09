import { useTranslation } from 'react-i18next'
import {
  Anchor,
  Button,
  Group,
  Paper,
  Skeleton,
  Stack,
  Text,
  Title,
  UnstyledButton,
} from '@mantine/core'
import { IconSearch } from '@tabler/icons-react'
import type { TeamDetailDto } from '@/api/dto'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { RoleBadge } from '@/components/card/common'
import { TeamAvatar } from '@/components/team/TeamAvatar'
import { isSingleTeam } from '@/config/appConfig'
import { paths } from '@/config/paths'
import classes from './Home.module.css'
import { useTeamActivity } from './memberHomeHelpers'

interface MyTeamsCardProps {
  teams: TeamDetailDto[] | undefined
  /** `total` of the listing — more teams than the rows shown get a « see all » link. */
  total: number | undefined
  isLoading: boolean
  /** The listing failed: say so rather than claim the member has no team. */
  isError?: boolean
}

/** « Mes équipes » on the member home: each team, its activity, and the member's role in it. */
export function MyTeamsCard({ teams, total, isLoading, isError }: MyTeamsCardProps) {
  const { t } = useTranslation()
  const activity = useTeamActivity()
  const singleTeam = isSingleTeam()
  // Spelled out: the list otherwise opens on the member's own teams (`useMembershipDefault`).
  const findTeamHref = `${paths.teams()}?role=all`

  return (
    <Paper withBorder radius="md" p="md" component="section" aria-labelledby="home-teams-title">
      <Group justify="space-between" mb="sm">
        <Title id="home-teams-title" order={2} size="h4">
          {t('home.teams.title')}
        </Title>
        {!singleTeam && (teams?.length ?? 0) > 0 && (
          <Anchor component={PrefetchLink} to={findTeamHref} size="sm">
            {t('home.teams.find')}
          </Anchor>
        )}
      </Group>

      {isLoading ? (
        <Stack gap="xs">
          {[0, 1].map((i) => (
            <Skeleton key={i} h={44} radius="md" />
          ))}
        </Stack>
      ) : isError ? (
        <Text size="sm" c="dimmed">
          {t('error.loading')}
        </Text>
      ) : !teams || teams.length === 0 ? (
        <Stack gap="sm" align="flex-start">
          <Text size="sm" c="dimmed">
            {t('home.teams.empty')}
          </Text>
          {!singleTeam && (
            <Button
              component={PrefetchLink}
              to={findTeamHref}
              variant="light"
              size="xs"
              leftSection={<IconSearch size={14} />}
            >
              {t('home.teams.find')}
            </Button>
          )}
        </Stack>
      ) : (
        <Stack gap={4}>
          {teams.map((team) => (
            <UnstyledButton
              key={team.id}
              component={PrefetchLink}
              to={paths.team(team.slug)}
              p={6}
              className={classes.row}
            >
              <Group gap="sm" wrap="nowrap">
                <TeamAvatar team={team} size="md" />
                <Stack gap={0} style={{ flex: 1, minWidth: 0 }}>
                  <Text size="sm" fw={600} truncate>
                    {team.name}
                  </Text>
                  <Text size="xs" c="dimmed" truncate>
                    {activity(team)}
                  </Text>
                </Stack>
                {team.role && <RoleBadge role={team.role}>{t(`roles.${team.role}`)}</RoleBadge>}
              </Group>
            </UnstyledButton>
          ))}
          {total !== undefined && total > teams.length && !singleTeam && (
            <Anchor component={PrefetchLink} to={paths.teams()} size="sm" mt={4}>
              {t('home.teams.seeAll', { count: total })}
            </Anchor>
          )}
        </Stack>
      )}
    </Paper>
  )
}
