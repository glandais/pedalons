import { useTranslation } from 'react-i18next'
import { useEffectiveTimezone } from '@/utils/dateFormat'
import { zoneCityOf, sameOffsetAt } from '@/utils/zoneLabel'
import { wallTimeToInstant, type WallTime } from '@/utils/wallTime'

/**
 * « heure de Tokyo » when `zone` — the zone an event's wall times are read in — does not have the
 * reader's offset at `wall` (or now), `null` otherwise (docs/LEDGER_*.md API-60, plan §7): offsets,
 * not identifiers, so Paris read from Brussels says nothing.
 *
 * The reader's zone is `useEffectiveTimezone`'s, UTC on the hydration render: the mention may
 * show on the server and vanish right after hydration, never the other way round in the markup.
 */
export function useZoneMention(zone: string, wall?: WallTime | null): string | null {
  const { t, i18n } = useTranslation()
  const { timezone: readerZone } = useEffectiveTimezone()
  let instant = new Date()
  if (wall) {
    const parsed = wallTimeToInstant(wall, zone)
    if (!Number.isNaN(parsed.getTime())) instant = parsed
  }
  if (sameOffsetAt(instant, zone, readerZone)) return null
  return t('timezone.zoneMention', { ofCity: zoneCityOf(zone, i18n.language) })
}
