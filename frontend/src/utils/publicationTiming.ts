import type { PublicationDto, RideDto, TripDto } from '@/api/dto'
import type { TFunction } from 'i18next'
import { formatDeparture, formatDepartureDay, formatPattern, formatTime } from './dateFormat'
import { startFor } from './groupStart'
import { tripEndZone } from './rendezvous'
import { supportedZone } from './zoneLabel'

/** A ride or a trip: the publications that have a start and an end (API-85). */
export type DatedPublication = RideDto | TripDto

/**
 * Where a ride's or a trip's span starts for the reader: a ride's, at their registered group's
 * departure when they joined one (docs/LEDGER_*.md WEB-136 — list rows carry `registeredGroup`),
 * else the publication's `dateTime`.
 */
export function spanStart(publication: DatedPublication): string {
  return publication.type === 'RIDE' ? startFor(publication) : publication.dateTime
}

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
 * The span of a ride or a trip — a rendezvous, read in the entity's zone (docs/LEDGER_*.md API-60,
 * plan §7), in the one format of docs/BRANDING.md §8.3 (ledger `WEB-138`): a ride « 08:30 » in its zone; a trip « ven. 16 → dim. 18 oct. », its first day in the trip's zone
 * (its first stage's) and its last in its last stage's when the stages are known (`tripEndZone`).
 * Same day and same month are judged on those wall clocks, not the reader's; the year is said only
 * outside the current one.
 *
 * `mode` `full` leads a ride with its day (« sam. 11 oct. · 08:30 »), `time` (a line whose day
 * box says the day) does not. A trip reads the same in both.
 */
export function formatPublicationSpan(
  publication: DatedPublication,
  mode: 'full' | 'time',
  language: string,
  t: TFunction,
  /** For a payload without `timezone` (fixtures) or in a zone `Intl` lacks: the reader's zone. */
  fallbackZone: string = 'UTC',
  now: Date = new Date()
): string {
  const startZone = supportedZone(publication.timezone) || fallbackZone
  const endZone = publication.type === 'TRIP' ? tripEndZone(publication) || fallbackZone : startZone
  const start = spanStart(publication)
  const end = publication.endDateTime
  const inStart = (pattern: string) => formatPattern(start, pattern, language, startZone)
  const inEnd = (pattern: string) => formatPattern(end, pattern, language, endZone)
  const sameDay = inStart('yyyy-MM-dd') === inEnd('yyyy-MM-dd')

  if (publication.type === 'TRIP') {
    if (sameDay) return formatDepartureDay(start, language, startZone, t, now)
    const firstDay =
      inStart('yyyy-MM') === inEnd('yyyy-MM')
        ? inStart(t('dateFormats.weekdayDay'))
        : formatDepartureDay(start, language, startZone, t, now)
    return `${firstDay} → ${formatDepartureDay(end, language, endZone, t, now)}`
  }
  return mode === 'full'
    ? formatDeparture(start, language, startZone, t, { now, relative: false })
    : formatTime(start, language, startZone)
}
