import { z } from 'zod'
import { ListViewMode, PublicationType, PublicationWhen } from '@/api/dto'
import { COMMON_ALIAS, pageField, searchField, sizeField } from './common'

export const PUBLICATION_PAGE_SIZE = 12

export type PublicationFilterValue = 'all' | 'ride' | 'post' | 'trip'

/**
 * The feed's period, « Tout / Je participe » (RL15, docs/LEDGER_*.md WEB-175). `me` is
 * authenticated-only — the contract says `participating` "yields nothing for an anonymous visitor".
 * There is no « À venir » any more: « Tout » is ordered upcoming first, in two sections.
 */
export type PublicationScopeValue = 'all' | 'me'

export const publicationFilterToType: Record<PublicationFilterValue, PublicationType | undefined> =
  {
    all: undefined,
    ride: PublicationType.RIDE,
    post: PublicationType.POST,
    trip: PublicationType.TRIP,
  }

/**
 * Whether a feed of this kind is read in two sections, « À venir » then « Plus tôt » (RL15): any
 * kind that holds rides or trips. The posts alone have nothing ahead, hence no sections.
 */
export function publicationFeedHasSections(filter: PublicationFilterValue): boolean {
  return filter !== 'post'
}

/**
 * Projects the period and the kind onto `when` / `participating`. A feed that holds rides or trips
 * is `when=UPCOMING_FIRST` (API-185): what is not over yet, soonest first — a ride under way
 * included — then everything else, latest first, the posts at their publication date. « Je
 * participe » is `participating`, over the same two sections.
 */
export function publicationScopeToParams(
  scope: PublicationScopeValue,
  filter: PublicationFilterValue
): { when?: PublicationWhen; participating?: boolean } {
  return {
    ...(publicationFeedHasSections(filter) ? { when: PublicationWhen.UPCOMING_FIRST } : {}),
    ...(scope === 'me' ? { participating: true } : {}),
  }
}

/**
 * `filter` holds the page's own value, not `PublicationType`, so the URL stays readable. A former
 * link keeps working: `?w=upcoming`, a period the feed no longer has, falls back to « Tout » — its
 * upcoming rides are the first section.
 */
export const publicationFiltersSchema = z.object({
  search: searchField,
  filter: z.enum(['all', 'ride', 'post', 'trip']).default('all').catch('all'),
  scope: z.enum(['all', 'me']).default('all').catch('all'),
  page: pageField,
  size: sizeField(PUBLICATION_PAGE_SIZE),
})

export const publicationFiltersAlias = { ...COMMON_ALIAS, filter: 'type', scope: 'w' } as const

/**
 * Projects the home feed's filters onto the list endpoint's params — the one place the page and
 * its route `prefetch` both go through. A team's lists have their own: the agenda
 * (`agendaFilters.ts`) and the posts (`teamPostFilters.ts`, ledger WEB-68).
 *
 * It exists because the prefetch has to produce a **byte-identical query key**, and it used to
 * rebuild the params by hand: `{ minRole, page, size, view }`. That worked only as long as the
 * defaults happened to project to nothing extra — the SSR cache silently missing on the two most
 * visited routes of the app, with nothing failing anywhere, the day they did not.
 *
 * `view` is always COMPACT here: a feed card draws a title, an excerpt and a picture, never the
 * markdown body or the attachments of twelve publications.
 */
export function publicationApiParams(filters: z.infer<typeof publicationFiltersSchema>) {
  return {
    search: filters.search,
    page: filters.page,
    size: filters.size,
    type: publicationFilterToType[filters.filter],
    ...publicationScopeToParams(filters.scope, filters.filter),
    view: ListViewMode.COMPACT,
  }
}

/** The params a bare URL produces — what a route `prefetch` must fill the cache with. */
export function defaultPublicationApiParams() {
  return publicationApiParams(publicationFiltersSchema.parse({}))
}
