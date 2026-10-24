import type { PublicationDto, RideDto, TripDto } from '@/api/dto'
import type { TFunction } from 'i18next'
import { formatDateTime, formatPattern, formatTime } from './dateFormat'
import { tripEndZone } from './rendezvous'
import { supportedZone } from './zoneLabel'

/** A ride or a trip: the publications that have a start and an end (API-85). */
export type DatedPublication = RideDto | TripDto

export function isDated(publication: PublicationDto): publication is DatedPublication {
  return publication.type === 'RIDE' || publication.type === 'TRIP'
}

/**
 * « En cours »: a ride or a trip that has started and is not over yet — `dateTime <= now <
 * endDateTime`, the end the server stores (API-85). A state derived on the client, like
 * « J'y vais »: the API's `finished` only says the start has passed. A cancelled one is never under
 * way. Such a ride keeps its place in the agenda's « À venir » (`when=UPCOMING` reads the same
 * end).
 */
export function isUnderWay(publication: PublicationDto, now: number = Date.now()): boolean {
  if (!isDated(publication) || publication.status === 'CANCELLED') return false
  const start = Date.parse(publication.dateTime)
  const end = Date.parse(publication.endDateTime)
  return Number.isFinite(start) && Number.isFinite(end) && start <= now && now < end
}

/**
 * The span of a ride or a trip, as `PublicationTimeSpan` prints it — a rendezvous, read in the
 * entity's zone (docs/LEDGER_*.md API-60, plan §7): a ride « 08:30 → retour vers 14:10 » in its
 * zone; a trip « ven. 16 → dim. 18 oct. », its first day in the trip's zone (its first stage's)
 * and its last in its last stage's when the stages are known (`tripEndZone`). Same day and same
 * month are judged on those wall clocks, not the reader's.
 *
 * `mode` `full` (a card) leads with the date, `time` (a row, whose day box says the day) does not.
 */
export function formatPublicationSpan(
  publication: DatedPublication,
  mode: 'full' | 'time',
  language: string,
  t: TFunction,
  /** For a payload without `timezone` (fixtures) or in a zone `Intl` lacks: the reader's zone. */
  fallbackZone: string = 'UTC'
): string {
  const startZone = supportedZone(publication.timezone) || fallbackZone
  const endZone = publication.type === 'TRIP' ? tripEndZone(publication) || fallbackZone : startZone
  const start = publication.dateTime
  const end = publication.endDateTime
  const inStart = (pattern: string) => formatPattern(start, pattern, language, startZone)
  const inEnd = (pattern: string) => formatPattern(end, pattern, language, endZone)
  const sameDay = inStart('yyyy-MM-dd') === inEnd('yyyy-MM-dd')

  if (publication.type === 'TRIP') {
    const sameMonth = inStart('yyyy-MM') === inEnd('yyyy-MM')
    return sameDay
      ? inStart('EEE d MMM')
      : `${inStart(sameMonth ? 'EEE d' : 'EEE d MMM')} → ${inEnd('EEE d MMM')}`
  }
  const from =
    mode === 'full'
      ? formatDateTime(start, language, startZone)
      : formatTime(start, language, startZone)
  const back = sameDay ? formatTime(end, language, endZone) : inEnd('EEE d MMM p')
  return `${from} → ${t('agenda.returnAround', { time: back })}`
}
