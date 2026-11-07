import { useTranslation } from 'react-i18next'
import { useEffectiveTimezone } from '@/utils/dateFormat'
import { formatPublicationSpan, spanStart, type DatedPublication } from '@/utils/publicationTiming'
import { rendezvousMention } from '@/utils/rendezvous'
import { isSupportedZone } from '@/utils/zoneLabel'
import { ZoneMentionIcon } from '@/components/common/Rendezvous'

interface PublicationTimeSpanProps {
  publication: DatedPublication
  /**
   * `full` (a card): the date, then the times — « 11 oct. 2026 à 08:30 → retour vers 14:10 ».
   * `time` (a row, whose day box already says the day): « 08:30 → retour vers 14:10 ».
   */
  mode?: 'full' | 'time'
}

/**
 * When a ride or a trip starts and ends, from `dateTime` — the registered group's departure for a ride (WEB-136) — and the stored
 * `endDateTime` (API-85). A
 * ride reads « 08:30 → retour vers 14:10 » — « vers », the end being an estimate from its
 * groups' distance and pace; a trip, which spans days, « ven. 16 → dim. 18 oct. ». A ride back
 * on another day names that day.
 *
 * A rendezvous (docs/LEDGER_*.md API-60): read in the entity's zone, with one zone indicator for
 * the whole span, its mention taken at the start.
 */
export function PublicationTimeSpan({ publication, mode = 'full' }: PublicationTimeSpanProps) {
  const { t, i18n } = useTranslation()
  const { timezone: readerZone, isGuessed, isPlaceholder } = useEffectiveTimezone()
  const text = formatPublicationSpan(publication, mode, i18n.language, t, readerZone)
  const mention = rendezvousMention(
    spanStart(publication),
    publication.timezone,
    isPlaceholder ? null : readerZone,
    i18n.language,
    t
  )
  return (
    <>
      <span suppressHydrationWarning={!isSupportedZone(publication.timezone) && isGuessed}>
        {text}
      </span>
      <ZoneMentionIcon mention={mention} isGuessed={isGuessed} />
    </>
  )
}
