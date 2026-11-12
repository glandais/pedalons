import type { ReactNode } from 'react'
import { Button } from '@mantine/core'
import { IconSearchOff } from '@tabler/icons-react'
import { useTranslation } from 'react-i18next'
import { EmptyState } from './EmptyState'
import { filtersSentence, type FilteredResource } from './filteredEmpty'

interface FilteredEmptyStateProps {
  resource: FilteredResource
  /**
   * The filters in force, as the bar names them — the search first, through `searchFilter`.
   * Never empty: a list without an active filter shows its absolute empty state instead.
   */
  filters: string[]
  /** « Effacer les filtres »: lifts everything the filters list names, keeps the sort (RL4). */
  onClear: () => void
  /** A further way out, before « Effacer les filtres » (the routes' « Retirer le filtre … »). */
  extraActions?: ReactNode
}

/**
 * The filtered empty state of every list (docs/LEDGER_*.md WEB-175, RL10): « Aucun {objet} pour ces
 * filtres », « Rien ne correspond à : {filtres} », and « Effacer les filtres ». Things exist; the
 * filters hide them — so it names those filters and always offers the way out.
 */
export function FilteredEmptyState({
  resource,
  filters,
  onClear,
  extraActions,
}: FilteredEmptyStateProps) {
  const { t } = useTranslation()
  return (
    <EmptyState
      variant="filtered"
      icon={<IconSearchOff size={48} />}
      title={t(`list.emptyFiltered.title.${resource satisfies FilteredResource}`)}
      description={filters.length > 0 ? filtersSentence(t, filters) : undefined}
      actions={
        <>
          {extraActions}
          <Button variant="light" onClick={onClear}>
            {t('common.clearFilters')}
          </Button>
        </>
      }
    />
  )
}
