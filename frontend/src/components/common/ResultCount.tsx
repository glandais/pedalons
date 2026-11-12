import { Text } from '@mantine/core'
import { useTranslation } from 'react-i18next'
import { formatNumber } from '@/utils/unitFormat'

/**
 * Resources whose list pages show a total. One plural key pair per entry. The agenda's say what
 * the list holds, by period and kind — « 5 sorties et voyages à venir » (ledger `WEB-68`).
 */
export type CountedResource =
  | 'agendaUpcoming'
  | 'agendaUpcomingRides'
  | 'agendaUpcomingTrips'
  | 'agendaMine'
  | 'agendaMineRides'
  | 'agendaMineTrips'
  | 'agendaPast'
  | 'agendaPastRides'
  | 'agendaPastTrips'
  | 'publications'
  | 'rides'
  | 'trips'
  | 'routes'
  | 'ads'
  | 'teams'
  | 'participations'
  | 'notifications'
  | 'members'
  | 'templates'

interface ResultCountProps {
  /** `total` of the list response, or a `CountResponse.total`. Undefined while loading. */
  total: number | undefined
  resource: CountedResource
  /** The order the list is in, said beside the count — « triées par nom » (RL5). */
  order?: string
}

/**
 * The total under a list's bar, left of its view switch — "2 585 parcours" (RL8). Under a filter it
 * is the filtered total alone. Renders nothing until the count is known, so the header does not
 * flicker between a wrong number and the right one, and nothing at zero either: the empty state
 * below says it (docs/LEDGER_*.md WEB-175).
 */
export function ResultCount({ total, resource, order }: ResultCountProps) {
  const { t, i18n } = useTranslation()

  if (total === undefined || total === 0) return null

  const count = t(`list.count.${resource satisfies CountedResource}`, {
    count: total,
    formatted: formatNumber(total, i18n.language),
  })
  return (
    <Text size="sm" c="dimmed">
      {order ? `${count} · ${order}` : count}
    </Text>
  )
}
