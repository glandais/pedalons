import { z } from 'zod'
import { SortDirection, TeamSortBy } from '@/api/dto'
import { COMMON_ALIAS, pageField, searchField, sizeField } from './common'
import {
  MEMBERSHIP_ALIAS,
  MEMBERSHIP_ALWAYS_SERIALIZE,
  membershipField,
  membershipToMinRole,
  type MembershipFilterValue,
} from './membership'

export const TEAM_PAGE_SIZE = 12

export const makeTeamFiltersSchema = (defaultMembership: MembershipFilterValue) =>
  z.object({
    search: searchField,
    membership: membershipField(defaultMembership),
    /**
     * « Ouvertes à l'adhésion » (RL3, `joinable=true`): offered, and sent, under « Toutes les
     * équipes » only — one's own teams have nothing to join.
     */
    joinable: z
      .union([z.literal('true'), z.literal('false')])
      .transform((value) => value === 'true')
      .default(false)
      .catch(false),
    page: pageField,
    size: sizeField(TEAM_PAGE_SIZE),
  })

export const teamFiltersAlias = { ...COMMON_ALIAS, ...MEMBERSHIP_ALIAS, joinable: 'open' } as const

export const teamFiltersAlwaysSerialize = MEMBERSHIP_ALWAYS_SERIALIZE

export type TeamFilters = z.infer<ReturnType<typeof makeTeamFiltersSchema>>

/**
 * The order of the team list follows its scope (docs/LEDGER_*.md WEB-175, RL5): one's own teams
 * read as an address book, by name; all the teams as a discovery, the largest first — as the app's
 * « Découvrir ». The page says which beside its count.
 */
export function teamListOrder(membership: MembershipFilterValue) {
  return membership === 'all'
    ? ({ sortBy: TeamSortBy.MEMBER_COUNT, sortDir: SortDirection.DESC } as const)
    : ({ sortBy: TeamSortBy.NAME, sortDir: SortDirection.ASC } as const)
}

/**
 * Projects the team list's filters onto the endpoint's params — `membership` is the page's own
 * value, the API wants a MinRole. Shared with the `teams` route's `prefetch`.
 */
export function teamApiParams(filters: TeamFilters) {
  return {
    search: filters.search,
    page: filters.page,
    size: filters.size,
    minRole: membershipToMinRole[filters.membership],
    ...(isJoinableFilterOn(filters) ? { joinable: true } : {}),
    ...teamListOrder(filters.membership),
  }
}

/** « Ouvertes à l'adhésion » counts, and is sent, under « Toutes les équipes » only (RL3). */
export function isJoinableFilterOn(filters: TeamFilters): boolean {
  return filters.membership === 'all' && filters.joinable
}
