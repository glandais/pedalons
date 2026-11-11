import { useTranslation } from 'react-i18next'
import { Anchor, Text } from '@mantine/core'
import type { TeamDetailDto } from '@/api/dto'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { paths } from '@/config/paths'

/**
 * Whether a free team has used up its member places. `memberLimit` is null on an unlocked team,
 * and the backend refuses a join, an addition or an invitation at the cap with
 * TEAM_MEMBER_LIMIT_REACHED (docs/LEDGER_*.md BILL-10). Pending invitations also count against
 * the cap when inviting; the server stays the authority on that, this only spares the obvious case.
 */
export function isTeamFull(team: Pick<TeamDetailDto, 'memberLimit' | 'memberCount'>): boolean {
  return team.memberLimit != null && team.memberCount >= team.memberLimit
}

interface TeamFullNoticeProps {
  limit: number
  /** A team administrator gets the way to lift the limit; everyone else is sent to them. */
  canContact: boolean
}

/** Why nobody more can come in: the team is on the free plan (plan BILL-10 §3.3). */
export function TeamFullNotice({ limit, canContact }: TeamFullNoticeProps) {
  const { t } = useTranslation()
  if (!canContact) {
    return (
      <Text size="sm" c="dimmed">
        {t('teams.memberLimit.fullAskAdmin', { limit })}
      </Text>
    )
  }
  return (
    <Text size="sm">
      {t('teams.memberLimit.full', { limit })}{' '}
      <Anchor component={PrefetchLink} to={paths.support()} size="sm">
        {t('teams.memberLimit.contact')}
      </Anchor>
    </Text>
  )
}
