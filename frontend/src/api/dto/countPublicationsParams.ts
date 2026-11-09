import type { PublicationType } from './publicationType.ts'
import type { PublicationWhen } from './publicationWhen.ts'
import type { Status } from './status.ts'

export type CountPublicationsParams = {
  /** Start date filter (ISO format) */
  from?: string
  /** Only publications the current user is registered to (rides and trips). Yields zero for an anonymous visitor. */
  participating?: boolean
  /** Search by name/markdown */
  search?: string
  /** Only publications with this status. Narrows the visibility rules, never widens them. */
  status?: Status
  /** Only the publications carrying at least one of these tags — ids (TSID) of the team's tags of kind 'type', comma-separated or repeated. Honoured with a 'type' only: the mixed feed has no tag filter and ignores it. Unknown ids are ignored; a filter left with no known id filters nothing. */
  tags?: string[]
  /** End date filter (ISO format) */
  to?: string
  /** Type */
  type?: PublicationType
  /** Which side of now, judged by the end of a ride or a trip rather than its start: UPCOMING is what is not over yet (end >= now — an outing under way included), PAST what is over (end < now). Keeps rides and trips only: a post has no end. Sets the order too — UPCOMING soonest departure first, PAST latest first — unless sortDir is given. With participating=true, UPCOMING is « Je participe ». Omitted: no such filter. */
  when?: PublicationWhen
  /** Only the rides with at least one group at capacity (maxParticipants reached). Every other type of publication is left out. */
  withFullGroup?: boolean
  /** Only the rides routed nowhere: neither the ride nor any of its groups has a route. Every other type of publication is left out. */
  withoutRoute?: boolean
}
