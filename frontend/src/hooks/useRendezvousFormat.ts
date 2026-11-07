import { useTranslation } from 'react-i18next'
import {
  formatDate,
  formatDateTime,
  formatDeparture,
  formatDepartureDay,
  formatLongDay,
  formatPattern,
  formatRelativeDay,
  formatTime,
  relativeDay,
  useEffectiveTimezone,
} from '@/utils/dateFormat'
import { rendezvousMention, type RendezvousMention } from '@/utils/rendezvous'
import { supportedZone } from '@/utils/zoneLabel'

type DateInput = Date | string | null | undefined

/**
 * Formatters for a rendezvous (docs/LEDGER_*.md API-60, plan §7): a departure, an estimated
 * return, a trip's dates, a scheduled publication — read in `zone`, the entity's own, so the
 * organiser's « 08:00 » reads 08:00 wherever the reader is. Timestamps keep `useFormattedDate`
 * (the reader's zone).
 *
 * The entity-zone text is identical on the server and the client; only `mention` depends on the
 * reader's zone, so only the mention needs `suppressHydrationWarning={isGuessedTimezone}`. A
 * missing `zone` (a fixture, an older payload) or one this browser's `Intl` does not know (the
 * JDK's tz database can be ahead of it) falls back to the reader's zone, without mention — the
 * mobile rule. While the reader's zone is the server's placeholder (SSR, hydration render), there
 * is no mention: it would describe the placeholder's clock, not the reader's.
 */
export function useRendezvousFormat(zone: string | null | undefined) {
  const { t, i18n } = useTranslation()
  const language = i18n.language
  const { timezone: readerZone, isGuessed, isPlaceholder } = useEffectiveTimezone()
  const knownZone = supportedZone(zone)
  const entityZone = knownZone || readerZone

  return {
    /** The zone the text is rendered in. */
    zone: entityZone,
    formatDate: (date: DateInput) => formatDate(date, language, entityZone),
    formatDateTime: (date: DateInput) => formatDateTime(date, language, entityZone),
    formatTime: (date: DateInput) => formatTime(date, language, entityZone),
    formatPattern: (date: DateInput, pattern: string) =>
      formatPattern(date, pattern, language, entityZone),
    /**
     * The departure in its one format (ledger `BRAND-8`): « sam. 12 avr. · 09:00 », « Demain ·
     * 09:00 » — today and tomorrow judged in the zone. `relative: false` keeps the absolute day.
     */
    formatDeparture: (date: DateInput, options?: { relative?: boolean }) =>
      formatDeparture(date, language, entityZone, t, options),
    /** « sam. 12 avr. » (the year outside the current one), in the zone. */
    formatDepartureDay: (date: DateInput) => formatDepartureDay(date, language, entityZone, t),
    /** « samedi 12 avril » (the year outside the current one), in the zone. */
    formatLongDay: (date: DateInput) => formatLongDay(date, language, entityZone, t),
    /** « Aujourd'hui » / « Demain » in the zone, else `null`. */
    formatRelativeDay: (date: DateInput) => formatRelativeDay(date, entityZone, t),
    /** `'today'` / `'tomorrow'` in the zone, else `null`. */
    relativeDay: (date: DateInput) => relativeDay(date, entityZone),
    /** Whether two instants fall on the same calendar day (or month, with `'yyyy-MM'`) in the zone. */
    samePeriod: (a: DateInput, b: DateInput, pattern: string = 'yyyy-MM-dd') =>
      formatPattern(a, pattern, language, entityZone) ===
      formatPattern(b, pattern, language, entityZone),
    /** « heure de Tokyo (ven. 01:00 chez vous) » at `instant`, or `null` with the reader's offset. */
    mention: (instant: DateInput): RendezvousMention | null =>
      rendezvousMention(instant, knownZone, isPlaceholder ? null : readerZone, language, t),
    /** True when the entity text itself may differ between server and client (no usable zone). */
    isGuessedText: !knownZone && isGuessed,
    isGuessedTimezone: isGuessed,
  }
}
