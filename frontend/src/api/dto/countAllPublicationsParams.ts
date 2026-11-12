import type { MinRole } from './minRole.ts'
import type { PublicationType } from './publicationType.ts'
import type { PublicationWhen } from './publicationWhen.ts'
import type { Status } from './status.ts'

export type CountAllPublicationsParams = {
  /** Start date filter (ISO format) */
  from?: string
  /** Only publications from teams where the user has at least this role. Yields zero for an anonymous visitor. */
  minRole?: MinRole
  /** Only publications the current user is registered to (rides and trips). Yields zero for an anonymous visitor. */
  participating?: boolean
  /** Search by name/markdown */
  search?: string
  /** Only publications with this status. Narrows the visibility rules, never widens them. */
  status?: Status
  /** End date filter (ISO format) */
  to?: string
  /** Types */
  type?: PublicationType
  /** Which side of now, judged by the end of a ride or a trip rather than its start: UPCOMING is what is not over yet (end >= now — an outing under way included), PAST what is over (end < now). Keeps rides and trips only: a post has no end. Sets the order too — UPCOMING soonest departure first, PAST latest first — unless sortDir is given. With participating=true, UPCOMING is « Je participe ». UPCOMING_FIRST filters nothing and orders the list in two sections (rule RL15): first what UPCOMING keeps, soonest departure first, then everything else — the rides and trips over and the posts — latest first; the id ends each section's key, so the order is total. The listing then fills upcomingTotal, the size of the first section; sortDir is ignored. On a count endpoint UPCOMING_FIRST counts the whole list, as omitting when does. Omitted: no such filter, newest first. */
  when?: PublicationWhen
}
