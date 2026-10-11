import type { TFunction } from 'i18next'
import { formatPattern } from './dateFormat'
import { isSupportedZone, sameOffsetAt, supportedZone, zoneCityName, zoneCityOf } from './zoneLabel'

/**
 * The mention a rendezvous carries when its zone does not have the reader's offset
 * (docs/LEDGER_*.md API-60, plan §7): « heure de Tokyo (ven. 01:00 chez vous) ».
 *
 * A rendezvous — a ride, group or stage departure, an estimated return, a trip's dates, a
 * scheduled publication — reads in its entity's zone; a timestamp (creation, comment, « il y a
 * 2 h ») stays in the reader's, without mention.
 */
export interface RendezvousMention {
  /** « heure de Tokyo » / « Tokyo time ». */
  label: string
  /** « ven. 01:00 chez vous »: the reader's wall clock, its day only when it differs. */
  readerEquivalent: string
  /** « heure de Tokyo (ven. 01:00 chez vous) ». */
  full: string
}

/**
 * The mention for `instant` read in `zone` by a reader in `readerZone`, or `null` when both zones
 * have the same offset at that instant (offsets, not identifiers: Paris read from Brussels says
 * nothing). The reader's equivalent follows the language's 12/24 h rule (`p`), prefixed with the
 * short day when the reader's calendar day is not the entity's.
 *
 * No mention either when `readerZone` is `null` — the reader's zone is not known yet (the server's
 * placeholder, `useEffectiveTimezone().isPlaceholder`): a mention computed against it would state
 * something false about the reader's own clock — or when this runtime does not know `zone`
 * (`isSupportedZone`), whose rendezvous then reads in the reader's zone.
 */
export function rendezvousMention(
  instant: Date | string | null | undefined,
  zone: string | null | undefined,
  readerZone: string | null,
  language: string,
  t: TFunction
): RendezvousMention | null {
  if (!instant || !readerZone || !isSupportedZone(zone)) return null
  const date = instant instanceof Date ? instant : new Date(instant)
  if (Number.isNaN(date.getTime())) return null
  if (sameOffsetAt(date, zone, readerZone)) return null
  const sameDay =
    formatPattern(date, 'yyyy-MM-dd', language, zone) ===
    formatPattern(date, 'yyyy-MM-dd', language, readerZone)
  const time = formatPattern(date, sameDay ? 'p' : 'EEE p', language, readerZone)
  const label = t('timezone.zoneMention', {
    city: zoneCityName(zone, language),
    ofCity: zoneCityOf(zone, language),
  })
  const readerEquivalent = t('timezone.readerEquivalent', { time })
  return {
    label,
    readerEquivalent,
    full: t('timezone.rendezvousMention', { zone: label, equivalent: readerEquivalent }),
  }
}

/**
 * The zone a trip's last days read in (plan §7): a multi-zone trip takes its first stage's days in
 * that stage's zone (`trip.timezone`) and its last stage's in its own. List rows carry no stages:
 * they fall back to the trip's zone, in which the contract documents `endDate`. A zone this
 * runtime does not know is skipped (`isSupportedZone`).
 */
export function tripEndZone(trip: {
  timezone?: string
  stages?: ReadonlyArray<{ dateTime: string; timezone?: string }>
}): string | undefined {
  let last: { dateTime: string; timezone?: string } | undefined
  for (const stage of trip.stages ?? []) {
    if (!last || Date.parse(stage.dateTime) >= Date.parse(last.dateTime)) last = stage
  }
  return supportedZone(last?.timezone) || supportedZone(trip.timezone)
}
