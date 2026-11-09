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
  /** Which side of now, judged by the end of a ride or a trip rather than its start: UPCOMING is what is not over yet (end >= now — an outing under way included), PAST what is over (end < now). Keeps rides and trips only: a post has no end. Sets the order too — UPCOMING soonest departure first, PAST latest first — unless sortDir is given. With participating=true, UPCOMING is « Je participe ». Omitted: no such filter. */
  when?: PublicationWhen
}
