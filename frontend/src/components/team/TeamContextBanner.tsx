import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useTranslation } from 'react-i18next'
import { Avatar, Group, Paper, Text, UnstyledButton } from '@mantine/core'
import type { MantineSpacing } from '@mantine/core'
import { IconChevronRight } from '@tabler/icons-react'
import type { TeamPublicationDto } from '@/api/dto'
import { paths } from '@/config/paths'
import { getColorFromName, getInitials } from './teamInitials'
import classes from './TeamContextBanner.module.css'

export interface TeamContextBannerProps {
  /**
   * The team summary the entity embeds (`RideDto.team`, `PostDto.team`…): the banner never needs
   * `GET team`, which a reader of a private team's public content by link does not get
   * (docs/LEDGER_*.md WEB-166).
   */
  team: Pick<TeamPublicationDto, 'slug' | 'name' | 'logoUrl' | 'accessible'>
  /** Bottom margin, so pages can match their own spacing scale. */
  mb?: MantineSpacing
}

/**
 * Team banner shown at the top of detail pages (ride, post, trip, ad, route).
 *
 * These pages are not mounted inside `TeamLayout` — they would lose their two-column layout —
 * so without this banner a visitor arriving from the home feed has no path back to the team.
 * Visually it mirrors `CardTeamLink`, the equivalent affordance inside cards.
 *
 * A team the reader cannot open (`accessible` false: the public content of a private team, read by
 * link) is named, not linked; its logo is shown only when the summary carries one — the backend
 * leaves it out when the team keeps it closed — and no initials stand in for it.
 */
export function TeamContextBanner({ team, mb = 'lg' }: TeamContextBannerProps) {
  const { t } = useTranslation()
  const logo = team.logoUrl?.replace('{size}', String(128))

  const content = (
    <Group gap="sm" wrap="nowrap">
      {(team.accessible || logo) && (
        <Avatar
          src={logo}
          // Decorative: the team's name is written right beside it (and is the link's own label).
          alt=""
          size="sm"
          radius="xl"
          color={getColorFromName(team.name)}
        >
          {getInitials(team.name)}
        </Avatar>
      )}
      <Text size="sm" fw={500} lineClamp={1} style={{ flex: 1, minWidth: 0 }}>
        {team.name}
      </Text>
      {team.accessible && <IconChevronRight size={16} color="var(--mantine-color-dimmed)" />}
    </Group>
  )

  return (
    <Paper withBorder radius="md" p="xs" mb={mb} data-testid="team-context-banner">
      {team.accessible ? (
        <UnstyledButton
          component={PrefetchLink}
          to={paths.team(team.slug)}
          aria-label={t('teams.contextBanner.goToTeam', { name: team.name })}
          w="100%"
          className={classes.link}
        >
          {content}
        </UnstyledButton>
      ) : (
        content
      )}
    </Paper>
  )
}
