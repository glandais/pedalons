import { z } from 'zod'
import { ListViewMode, PublicationType, PublicationWhen } from '@/api/dto'
import { COMMON_ALIAS, pageField, searchField, sizeField, tagIdsField } from './common'

export const AGENDA_PAGE_SIZE = 12

/** The kinds of the agenda: its rides and trips, never its posts (plan 2026-10-06 §2). */
export type AgendaTypeValue = 'all' | 'ride' | 'trip'

/**
 * The agenda's period (RL15): « Toutes les dates » (the default), read in two sections, « À venir »
 * then « Plus tôt », and « Je participe », over the same two sections. There is no « Passées »
 * any more: what is over is the second section. `me` is signed-in only — `participating` yields
 * nothing for an anonymous visitor.
 */
export type AgendaScopeValue = 'all' | 'me'

export const agendaTypeToPublicationType: Record<AgendaTypeValue, PublicationType | undefined> = {
  all: undefined,
  ride: PublicationType.RIDE,
  trip: PublicationType.TRIP,
}

/**
 * The agenda's filters, as its URL carries them. A former link keeps working: `?w=past` and
 * `?w=upcoming`, periods the agenda no longer has, fall back to « Toutes les dates » — the list
 * that holds both — and `?type=post` to « Tout » (the route's loader drops them from the address,
 * `teamAgendaRedirect`).
 */
export const agendaFiltersSchema = z.object({
  search: searchField,
  filter: z.enum(['all', 'ride', 'trip']).default('all').catch('all'),
  scope: z.enum(['all', 'me']).default('all').catch('all'),
  tags: tagIdsField,
  /**
   * « Vignettes » or « Lignes » (`?view=`, ledger `WEB-69`). Presentation only: never sent to the
   * API. The calendar view has its own path (`teamCalendar`).
   */
  density: z.enum(['card', 'row']).optional().catch(undefined),
  page: pageField,
  size: sizeField(AGENDA_PAGE_SIZE),
})

export type AgendaFilters = z.infer<typeof agendaFiltersSchema>

export const agendaFiltersAlias = {
  ...COMMON_ALIAS,
  filter: 'type',
  scope: 'w',
  density: 'view',
} as const

/**
 * Projects the agenda's filters onto `GET /api/teams/{slug}/publications` — the one place the page
 * and its route `prefetch` both go through, so their query keys match byte for byte.
 *
 * Always `when=UPCOMING_FIRST` (API-185): what is not over yet — a ride under way included —
 * soonest first, then what is over, latest first, and `upcomingTotal` says where the first section
 * ends. « Je participe » adds `participating`. No clock in the key. Tags only go with a kind: each
 * kind has its own vocabulary (plan D3), and the API ignores them without `type`.
 */
export function agendaApiParams(filters: AgendaFilters) {
  const type = agendaTypeToPublicationType[filters.filter]
  return {
    search: filters.search,
    page: filters.page,
    size: filters.size,
    type,
    when: PublicationWhen.UPCOMING_FIRST,
    ...(filters.scope === 'me' ? { participating: true } : {}),
    ...(type && filters.tags ? { tags: filters.tags } : {}),
    view: ListViewMode.COMPACT,
  }
}

export type AgendaApiParams = ReturnType<typeof agendaApiParams>

/**
 * Whether `when=UPCOMING_FIRST` alone keeps the agenda to rides and trips. It does with a kind, and
 * with « Je participe » (a post has no participants). « Tout » over « Toutes les dates » does not:
 * `UPCOMING_FIRST` puts the posts in « Plus tôt », and `type` takes one kind — that list is read
 * through `listRidesAndTripsUpcomingFirst` instead.
 */
export function agendaKeepsPostsOut(params: AgendaApiParams): boolean {
  return params.type !== undefined || params.participating === true
}
