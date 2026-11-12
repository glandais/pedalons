import { useTranslation } from 'react-i18next'
import { Button } from '@mantine/core'
import type { RideGroupDto } from '@/api/dto'
import type { GroupAction } from '@/pages/ride/rideGroupData'

/**
 * The filled control beside a group's name, as `groupAction` decides (the server's rules at join):
 * « Rejoindre », or « Complet » disabled in its place — also to a reader registered in another group
 * (docs/LEDGER_*.md WEB-167, R6). Never « Quitter »: the reader's own group says « J'y vais » and
 * takes its red « Quitter le groupe » link at the foot (`LeaveGroupLink`).
 */
export function GroupJoinActions({
  action,
  group,
  membership,
  size,
}: {
  action: GroupAction
  group: RideGroupDto
  membership: {
    join: (groupId: string) => void
    isPending: boolean
  }
  size?: 'xs' | 'sm'
}) {
  const { t } = useTranslation()
  if (action === 'join') {
    return (
      <Button size={size} onClick={() => membership.join(group.id)} disabled={membership.isPending}>
        {t('rides.detail.groups.join')}
      </Button>
    )
  }
  if (action === 'full') {
    return (
      <Button size={size} variant="default" disabled data-testid="group-full">
        {t('rides.detail.groups.full')}
      </Button>
    )
  }
  return null
}
