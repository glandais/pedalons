import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { Anchor } from '@mantine/core'

/**
 * The red link that takes the reader out of their group, at the foot of the card or the block that
 * says they go (docs/LEDGER_*.md WEB-167, R6, as the app's `RideGroupLeaveLink`): never a button in
 * the card's corner, never confirmed — it is undone by joining again (KIT §9). « Quitter le groupe »
 * on a group, « Se désinscrire » on « Ma prochaine sortie » (`label`).
 */
export function LeaveGroupLink({
  onLeave,
  pending = false,
  label,
}: {
  onLeave: () => void
  pending?: boolean
  label?: ReactNode
}) {
  const { t } = useTranslation()
  return (
    <Anchor
      component="button"
      type="button"
      onClick={onLeave}
      disabled={pending}
      size="sm"
      fw={600}
      c={pending ? 'dimmed' : 'red'}
      data-testid="leave-group"
      style={{ cursor: pending ? 'default' : 'pointer' }}
    >
      {pending ? t('rides.detail.groups.leaving') : (label ?? t('rides.detail.groups.leaveGroup'))}
    </Anchor>
  )
}
