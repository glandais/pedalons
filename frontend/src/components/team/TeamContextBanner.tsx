import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useTranslation } from 'react-i18next'
import { Group, Paper, Text, UnstyledButton } from '@mantine/core'
import type { MantineSpacing } from '@mantine/core'
import { IconChevronRight } from '@tabler/icons-react'
import type { MediaDto } from '@/api/dto'
import { paths } from '@/config/paths'
import { TeamAvatar } from './TeamAvatar'
import classes from './TeamContextBanner.module.css'

export interface TeamContextBannerProps {
  team: {
    slug: string
    name: string
    about: MediaDto
  }
  /** Bottom margin, so pages can match their own spacing scale. */
  mb?: MantineSpacing
}

/**
 * Clickable team banner shown at the top of detail pages (ride, post, trip, ad, route).
 *
 * These pages are not mounted inside `TeamLayout` — they would lose their two-column layout —
 * so without this banner a visitor arriving from the home feed has no path back to the team.
 * Visually it mirrors `CardTeamLink`, the equivalent affordance inside cards.
 */
export function TeamContextBanner({ team, mb = 'lg' }: TeamContextBannerProps) {
  const { t } = useTranslation()

  return (
    <Paper withBorder radius="md" p="xs" mb={mb}>
      <UnstyledButton
        component={PrefetchLink}
        to={paths.team(team.slug)}
        aria-label={t('teams.contextBanner.goToTeam', { name: team.name })}
        w="100%"
        className={classes.link}
      >
        <Group gap="sm" wrap="nowrap">
          <TeamAvatar team={team} size="sm" />
          <Text size="sm" fw={500} lineClamp={1} style={{ flex: 1, minWidth: 0 }}>
            {team.name}
          </Text>
          <IconChevronRight size={16} color="var(--mantine-color-dimmed)" />
        </Group>
      </UnstyledButton>
    </Paper>
  )
}
