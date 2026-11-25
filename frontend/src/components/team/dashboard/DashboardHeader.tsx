import { useTeamAccess } from '@/lib/teamAccess'
import { useTeamCreateActions } from './useTeamCreateActions'
import { useTranslation } from 'react-i18next'
import { Group, Text } from '@mantine/core'
import { CreateSplitButton } from '@/components/common/CreateSplitButton'
import { RoleBadge } from '@/components/card/common'
import type { TeamDetailDto, TeamRole } from '@/api/dto'
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
 * The dashboard's create button in the team header, shaped like the agenda's: « Créer une sortie »
 * with every other creation behind the chevron (see `useTeamCreateActions`). Below `sm` it spans its
 * own row under the header (TeamLayout), as in the app.
 */
export function DashboardHeaderActions({ team, role }: { team: TeamDetailDto; role?: TeamRole }) {
  const { isMobile } = useResponsive()
  // A right, not the badge: a platform admin creates in any team (docs/LEDGER_*.md API-137).
  const { isOrganizer } = useTeamAccess({ role })
  const actions = useTeamCreateActions(team)
  if (!isOrganizer) return null
  return <CreateSplitButton actions={actions} fullWidth={isMobile} />
}
