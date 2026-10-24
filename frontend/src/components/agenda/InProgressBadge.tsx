import { Badge, Box } from '@mantine/core'
import { useTranslation } from 'react-i18next'

/**
 * « En cours »: a ride or a trip under way (`isUnderWay`, utils/publicationTiming.ts). A state
 * derived on the client, like « J'y vais » — soft green with a dot, so it reads as a live state
 * and not as the publication's status (plan 2026-10-06 §2.2).
 */
export function InProgressBadge() {
  const { t } = useTranslation()
  return (
    <Badge
      size="sm"
      color="green"
      variant="light"
      leftSection={
        <Box
          component="span"
          aria-hidden
          w={6}
          h={6}
          style={{ display: 'block', borderRadius: '50%', background: 'currentColor' }}
        />
      }
    >
      {t('agenda.inProgress')}
    </Badge>
  )
}
