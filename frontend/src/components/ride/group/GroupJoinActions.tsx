import { useTranslation } from 'react-i18next'
import { Badge, Button } from '@mantine/core'
import type { RideGroupDto } from '@/api/dto'
import type { GroupAction } from '@/pages/ride/rideGroupData'

/**
 * « Rejoindre » or « Quitter », as `groupAction` decides (the server's rules at join). `showFull`
 * adds the « Complet » badge where no title badge already says it (a solo ride's group panel).
 */
export function GroupJoinActions({
  action,
  group,
  membership,
  showFull = false,
  size,
}: {
  action: GroupAction
  group: RideGroupDto
  membership: {
    join: (groupId: string) => void
    leave: (groupId: string) => void
    isPending: boolean
  }
  showFull?: boolean
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
  if (action === 'leave') {
    return (
      <Button
        size={size}
        variant="outline"
        onClick={() => membership.leave(group.id)}
        disabled={membership.isPending}
      >
        {t('rides.detail.groups.leave')}
      </Button>
    )
  }
  if (showFull && group.full) {
    return (
      <Badge color="gray" variant="light">
        {t('rides.detail.groups.full')}
      </Badge>
    )
  }
  return null
}
