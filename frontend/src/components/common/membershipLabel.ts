import type { TFunction } from 'i18next'
import type { MembershipFilterValue } from '@/hooks/filters/membership'

/** A membership value as the selector names it — and the filtered empty state with it (RL10). */
export function membershipLabel(t: TFunction, value: MembershipFilterValue): string {
  switch (value) {
    case 'all':
      return t('filters.membership.all')
    case 'member':
      return t('roles.MEMBER')
    case 'organizer':
      return t('roles.ORGANIZER')
    case 'admin':
      return t('roles.ADMIN')
  }
}

/** What `TeamScopeSelect` holds when no team is picked: « Toutes mes équipes ». */
export const ALL_MY_TEAMS = 'all'
