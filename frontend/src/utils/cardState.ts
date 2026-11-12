import type { Status } from '@/api/dto'

/**
 * The one state a card or a list row says, after its type and before « J'y vais » (docs/LEDGER_*.md
 * WEB-167, R1; KIT §9 « Badges d'état »): cancelled, draft, under way or over — never « Publié »,
 * the ordinary case, which says nothing. The app's order (`publication_card.dart`): a cancelled or a
 * draft content is that before anything else, then a dated one is under way or over.
 */
export type CardState = 'CANCELLED' | 'DRAFT' | 'UNDER_WAY' | 'FINISHED'

interface StateInput {
  status: Status
  /** When it leaves (a ride, a trip, a stage); absent for what is not dated (a post, an ad). */
  start?: string
  /** When it is over: `endDateTime`, the end the server stores (API-85). */
  end?: string
}

export function cardState(
  { status, start, end }: StateInput,
  now: number = Date.now()
): CardState | undefined {
  if (status === 'CANCELLED') return 'CANCELLED'
  if (status === 'DRAFT') return 'DRAFT'
  const endAt = end ? Date.parse(end) : NaN
  if (!Number.isFinite(endAt)) return undefined
  if (now >= endAt) return 'FINISHED'
  const startAt = start ? Date.parse(start) : NaN
  return Number.isFinite(startAt) && startAt <= now ? 'UNDER_WAY' : undefined
}

/**
 * A calendar event's state (the « 7 prochains jours » rows, the calendar's phone view): its `end`
 * when it has one, else the server's `finished` — which, on an event, says its end has passed.
 */
export function eventState(
  event: { status: Status; start: string; end?: string; finished: boolean },
  now: number = Date.now()
): CardState | undefined {
  const state = cardState({ status: event.status, start: event.start, end: event.end }, now)
  if (state || event.end) return state
  return event.finished ? 'FINISHED' : undefined
}
