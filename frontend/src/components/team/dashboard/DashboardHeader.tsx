import { useTranslation } from 'react-i18next'
import { ActionIcon, Button, Group, Text, Tooltip } from '@mantine/core'
import { IconPencilPlus, IconPlus, type Icon } from '@tabler/icons-react'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { RoleBadge } from '@/components/card/common'
import type { TeamDetailDto, TeamRole } from '@/api/dto'
import { paths } from '@/config/paths'
import { useResponsive } from '@/hooks/useResponsive'

/**
 * Under the team's name on the dashboard: the reader's role — a member's only — and the member
 * count.
 */
export function DashboardHeaderMeta({ team, role }: { team: TeamDetailDto; role?: TeamRole }) {
  const { t } = useTranslation()
  return (
    <Group gap="xs" mt={4}>
      {role && (
        <RoleBadge role={role}>
          {t(`roles.${role satisfies 'ADMIN' | 'ORGANIZER' | 'MEMBER'}`)}
        </RoleBadge>
      )}
      <Text size="sm" c="dimmed">
        {t('memberCount', { count: team.memberCount })}
      </Text>
    </Group>
  )
}

/**
 * The dashboard's shortcuts in the team header: the two creations an organizer makes most, each
 * only when the team has that module. Subscribing to the calendar is not one of them: it lives on
 * the agenda and on a trip. Below `sm` they collapse to icon buttons (labelled for assistive tech,
 * with a tooltip) so they don't crowd the team's name in TeamLayout's header.
 */
export function DashboardHeaderActions({ team, role }: { team: TeamDetailDto; role?: TeamRole }) {
  const { t } = useTranslation()
  const { isMobile } = useResponsive()
  const isOrganizer = role === 'ADMIN' || role === 'ORGANIZER'

  return (
    <>
      {isOrganizer && team.enablePosts && (
        <HeaderLinkAction
          to={paths.postNew(team.slug)}
          label={t('posts.create.title')}
          icon={IconPencilPlus}
          variant="default"
          compact={isMobile}
        />
      )}
      {isOrganizer && team.enableRides && team.enableRoutes && (
        <HeaderLinkAction
          to={paths.rideNew(team.slug)}
          label={t('rides.create.title')}
          icon={IconPlus}
          variant="filled"
          compact={isMobile}
        />
      )}
    </>
  )
}

function HeaderLinkAction({
  to,
  label,
  icon: ActionIconGlyph,
  variant,
  compact,
}: {
  to: string
  label: string
  /** Distinct per action: on a phone the icon is all that tells them apart. */
  icon: Icon
  variant: 'default' | 'filled'
  compact: boolean
}) {
  if (compact) {
    return (
      <Tooltip label={label}>
        <ActionIcon component={PrefetchLink} to={to} variant={variant} aria-label={label}>
          <ActionIconGlyph size={18} />
        </ActionIcon>
      </Tooltip>
    )
  }
  return (
    <Button
      component={PrefetchLink}
      to={to}
      variant={variant}
      leftSection={<ActionIconGlyph size={16} />}
    >
      {label}
    </Button>
  )
}
