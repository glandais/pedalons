import { useTranslation } from 'react-i18next'
import { Badge } from '@mantine/core'
import { IconCheck } from '@tabler/icons-react'

/**
 * « J'y vais »: the reader takes part — read from the server's `registered`, never recomputed. Last
 * of a card's badges (docs/LEDGER_*.md WEB-167, R1).
 */
export function RegisteredBadge() {
  const { t } = useTranslation()
  return (
    <Badge
      size="sm"
      color="primary"
      variant="light"
      leftSection={<IconCheck size={12} />}
      style={{ flexShrink: 0 }}
    >
      {t('publications.registered')}
    </Badge>
  )
}
