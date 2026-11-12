import { useTranslation } from 'react-i18next'
import { Badge } from '@mantine/core'
import { InProgressBadge } from '@/components/agenda/InProgressBadge'
import type { CardState } from '@/utils/cardState'
import { StatusBadge } from './Badge'

interface StateBadgeProps {
  state: CardState | undefined
  /** A trip is « Terminé »; a ride, a stage « Terminée ». */
  subject?: 'ride' | 'trip'
}

/**
 * The one state badge of a card or a list row (`cardState`, docs/LEDGER_*.md WEB-167 R1): « Annulé »,
 * « Brouillon », « En cours » or « Terminée » — in grey, as the app's (SYNTHESE §6.2). Nothing for
 * the ordinary case: never « Publié ».
 */
export function StateBadge({ state, subject = 'ride' }: StateBadgeProps) {
  const { t } = useTranslation()
  switch (state) {
    case 'CANCELLED':
      return <StatusBadge status="CANCELLED">{t('status.CANCELLED')}</StatusBadge>
    case 'DRAFT':
      return <StatusBadge status="DRAFT">{t('status.DRAFT')}</StatusBadge>
    case 'UNDER_WAY':
      return <InProgressBadge />
    case 'FINISHED':
      return (
        <Badge
          size="sm"
          color="gray"
          variant="light"
          style={{ flexShrink: 0 }}
          data-testid="finished-badge"
        >
          {subject === 'trip' ? t('trips.detail.finished') : t('rides.detail.finished')}
        </Badge>
      )
    default:
      return null
  }
}
