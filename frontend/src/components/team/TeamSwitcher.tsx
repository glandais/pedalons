import { useTranslation } from 'react-i18next'
import { Group, Menu, Title, UnstyledButton } from '@mantine/core'
import { IconCheck, IconChevronDown } from '@tabler/icons-react'
import type { TeamDetailDto } from '@/api/dto'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { paths } from '@/config/paths'
import { teamSwitchPath } from '@/hooks/useNavItems'
import { TeamAvatar } from './TeamAvatar'
import { useTeamSwitcherTeams } from './teamSwitcherData'

interface TeamSwitcherProps {
  team: TeamDetailDto
  /** TeamLayout's section, undefined on a custom page: where the other teams' links lead, when they have it. */
  section: string | undefined
}

/**
 * The team header's name, a « Mes équipes » menu when the reader belongs to another team than this
 * one (docs/LEDGER_*.md WEB-111): their teams in the server's order (by name), this one checked when
 * they belong to it, then « Toutes les équipes ». Otherwise — logged out, single-team site, member
 * of this team only, still loading — the name stays a plain title. The listing is the home's
 * (teamSwitcherData.ts), so they share one cache entry.
 */
export function TeamSwitcher({ team, section }: TeamSwitcherProps) {
  const { t } = useTranslation()
  const { data } = useTeamSwitcherTeams()
  const myTeams = data?.teams ?? []
  const hasOthers = myTeams.some((other) => other.id !== team.id)

  if (!hasOthers) {
    return (
      <Title order={1} lineClamp={1}>
        {team.name}
      </Title>
    )
  }

  // The button sits inside the heading, not around it, and keeps the name as its own: the heading
  // is still named after the team, and the menu button says so too.
  return (
    <Menu position="bottom-start">
      <Title order={1} lineClamp={1}>
        <Menu.Target>
          <UnstyledButton
            title={t('teams.switcher.open')}
            style={{ font: 'inherit', maxWidth: '100%' }}
          >
            <Group gap={6} wrap="nowrap">
              <span style={{ overflow: 'hidden', textOverflow: 'ellipsis' }}>{team.name}</span>
              <IconChevronDown size={20} aria-hidden style={{ flexShrink: 0 }} />
            </Group>
          </UnstyledButton>
        </Menu.Target>
      </Title>
      <Menu.Dropdown>
        <Menu.Label>{t('teams.switcher.title')}</Menu.Label>
        {myTeams.map((other) =>
          other.id === team.id ? (
            <Menu.Item
              key={other.id}
              leftSection={<TeamAvatar team={other} size="xs" />}
              rightSection={<IconCheck size={16} aria-hidden />}
              aria-current="true"
            >
              {other.name}
            </Menu.Item>
          ) : (
            <Menu.Item
              key={other.id}
              component={PrefetchLink}
              to={teamSwitchPath(other, section, t)}
              leftSection={<TeamAvatar team={other} size="xs" />}
            >
              {other.name}
            </Menu.Item>
          )
        )}
        <Menu.Divider />
        <Menu.Item component={PrefetchLink} to={paths.teams()}>
          {t('teams.switcher.allTeams')}
        </Menu.Item>
      </Menu.Dropdown>
    </Menu>
  )
}
