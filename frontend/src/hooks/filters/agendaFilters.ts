import { z } from 'zod'
import { ListViewMode, PublicationType, PublicationWhen } from '@/api/dto'
import { COMMON_ALIAS, pageField, searchField, sizeField, tagIdsField } from './common'

export const AGENDA_PAGE_SIZE = 12

/** The kinds of the agenda: its rides and trips, never its posts (plan 2026-10-06 §2). */
export type AgendaTypeValue = 'all' | 'ride' | 'trip'

/**
 * The agenda's period (RL15): « Toutes les dates » (the default), read in two sections, « À venir »
 * then « Plus tôt », « Je participe », over the same two sections, and « Plus tôt » (`earlier`),
 * the second section alone — what is over, latest first, one list. `me` is signed-in only —
 * `participating` yields nothing for an anonymous visitor.
 */
export type AgendaScopeValue = 'all' | 'me' | 'earlier'

export const agendaTypeToPublicationType: Record<AgendaTypeValue, PublicationType | undefined> = {
  all: undefined,
  ride: PublicationType.RIDE,
  trip: PublicationType.TRIP,
}

/**
 * The agenda's filters, as its URL carries them. « Plus tôt » is `?w=earlier`. A former link keeps
 * working: `?w=upcoming`, a period the agenda no longer has, falls back to « Toutes les dates » —
 * the list that holds it — and `?type=post` to « Tout »; the route's loader rewrites the address
 * (`teamAgendaRedirect`), `?w=past` becoming `?w=earlier`, its exact equivalent.
 */
export const agendaFiltersSchema = z.object({
  search: searchField,
  filter: z.enum(['all', 'ride', 'trip']).default('all').catch('all'),
  scope: z.enum(['all', 'me', 'earlier']).default('all').catch('all'),
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
 * Always `when=UPCOMING_FIRST&dated=true` (API-185): what is not over yet — a ride under way
 * included — soonest first, then what is over, latest first, and `upcomingTotal` says where the
 * first section ends. `dated=true` keeps the list to rides and trips whatever the kind — the
 * team's posts never reach « Plus tôt » — and `total` and `upcomingTotal` count only them.
 * « Je participe » adds `participating`. « Plus tôt » is `when=PAST&dated=true`: what is over,
 * latest first, one list. No clock in the key. Tags only go with a kind: each kind has its own
 * vocabulary (plan D3), and the API ignores them without `type`.
 */
export function agendaApiParams(filters: AgendaFilters) {
  const type = agendaTypeToPublicationType[filters.filter]
  return {
    search: filters.search,
    page: filters.page,
    size: filters.size,
    type,
    when: filters.scope === 'earlier' ? PublicationWhen.PAST : PublicationWhen.UPCOMING_FIRST,
    dated: true,
    ...(filters.scope === 'me' ? { participating: true } : {}),
    ...(type && filters.tags ? { tags: filters.tags } : {}),
    view: ListViewMode.COMPACT,
  }
}
