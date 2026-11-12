import { useTranslation } from 'react-i18next'
import { Progress } from '@mantine/core'
import type { RideDto } from '@/api/dto'

interface PublicationCardProgressProps {
  ride: RideDto
}

/**
 * The places bar of a ride in the feed: primary, red once full — no green, no orange
 * (docs/LEDGER_*.md WEB-167, R5). The count is the card's « 8/12 personnes », beside the groups;
 * the bar repeats it to assistive tech only.
 */
export function PublicationCardProgress({ ride }: PublicationCardProgressProps) {
  const { t } = useTranslation()

  // The ride's capacity comes from the server (docs/LEDGER_*.md API-5): a list row carries no
  // `groups`, so summing them here always gave nothing. Null when a group is uncapped — the ride
  // then has no overall limit, and no bar is drawn.
  const totalMax = ride.maxParticipants
  if (totalMax === undefined || totalMax === null || totalMax === 0) {
    return null
  }

  const current = ride.participantCount
  return (
    <Progress
      value={Math.min((current / totalMax) * 100, 100)}
      color={ride.full ? 'red' : 'primary'}
      size="sm"
      style={{ flex: 1, minWidth: 60 }}
      aria-label={t('rides.detail.groups.participants', { current, count: totalMax })}
    />
  )
}
