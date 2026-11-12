import type { TFunction } from 'i18next'

/** What a list holds, as its filtered empty state names it: « Aucune annonce pour ces filtres ». */
export type FilteredResource =
  | 'publications'
  | 'agenda'
  | 'agendaRides'
  | 'agendaTrips'
  | 'events'
  | 'routes'
  | 'ads'
  | 'teams'
  | 'members'
  | 'participants'
  | 'notifications'
  | 'templates'

/** A search, as a filtered empty state names it: « monts », in the language's quotation marks. */
export function searchFilter(t: TFunction, search: string): string {
  return t('list.emptyFiltered.search', { search })
}

/** The filters' names, joined as the filtered empty state writes them. */
export function filtersSentence(t: TFunction, filters: string[]): string {
  return t('list.emptyFiltered.message', { filters: filters.join(' · ') })
}
