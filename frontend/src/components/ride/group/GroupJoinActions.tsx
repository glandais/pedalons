import { useTranslation } from 'react-i18next'
import { Button } from '@mantine/core'
import type { RideGroupDto } from '@/api/dto'
import type { GroupAction } from '@/pages/ride/rideGroupData'
import { groupTitle } from '@/utils/groupTitle'

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
  canSwitch = false,
}: {
  action: GroupAction
  group: RideGroupDto
  membership: {
    join: (groupId: string) => void
    switchTo?: (groupId: string) => void
    isPending: boolean
  }
  size?: 'xs' | 'sm'
  /**
   * A member registered in another group may move to this one (`canSwitchTo`): « Changer pour »,
   * as on the ride's group card (API-171, WEB-188).
   */
  canSwitch?: boolean
}) {
  const { t } = useTranslation()
  if (canSwitch && membership.switchTo) {
    const switchTo = membership.switchTo
    return (
      <Button size={size} onClick={() => switchTo(group.id)} disabled={membership.isPending}>
        {t('rides.detail.groups.switchTo', { group: groupTitle(group.name, t) })}
      </Button>
    )
  }
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
