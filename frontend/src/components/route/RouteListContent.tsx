import { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { IconMap, IconSearchOff } from '@tabler/icons-react'
import { Box, Button, SimpleGrid, Stack } from '@mantine/core'
import type { RouteDto } from '@/api/dto'
import { RouteCard, RouteCardSkeleton } from '../card'
import { RouteRow } from './RouteRow'
import type { RouteDensity } from '@/hooks/filters/routeFilters'
import { EmptyState } from '../common/EmptyState'
import { Pagination } from '../common/Pagination'
import { OutOfRangeState } from '../common/OutOfRangeState'
import { QueryStateBoundary } from '../common/QueryStateBoundary'
import { useScrollToListTop } from '@/hooks/useScrollToListTop'

interface RouteListContentProps {
  routes: RouteDto[] | undefined
  isLoading: boolean
  isError?: boolean
  error?: unknown
  /** Reloads the list — the error state's « Réessayer ». */
  onRetry?: () => void
  showTeam: boolean
  hasFiltersOrSearch: boolean
  currentPage: number
  totalPages: number
  onPageChange: (page: number) => void
  /** Lets the user out of a filtered empty state — mandatory wherever filters can be active. */
  onClearFilters?: () => void
  /** When set, a filtered empty state renders the richer dead-end instead. */
  deadEnd?: ReactNode
  emptyAction?: ReactNode
  density?: RouteDensity
  /** The `⋯` menu of each card — given by a team's own list, which knows the reader's role. */
  cardActions?: (route: RouteDto) => ReactNode
}

export function RouteListContent({
  routes,
  isLoading,
  isError,
  error,
  onRetry,
  showTeam,
  hasFiltersOrSearch,
  currentPage,
  totalPages,
  onPageChange,
  onClearFilters,
  deadEnd,
  emptyAction,
  density = 'card',
  cardActions,
}: RouteListContentProps) {
  const { t } = useTranslation()
  const { listTopRef, scrollToListTop } = useScrollToListTop()

  const handlePageChange = (page: number) => {
    onPageChange(page)
    scrollToListTop()
  }

  if (isLoading) {
    return (
      <SimpleGrid cols={{ base: 1, sm: 2, lg: 3 }}>
        <RouteCardSkeleton count={6} />
      </SimpleGrid>
    )
  }

  if (isError) {
    return (
      <QueryStateBoundary isLoading={false} isError error={error} onRetry={onRetry}>
        {null}
      </QueryStateBoundary>
    )
  }

  if (routes && routes.length > 0) {
    return (
      <>
        {density === 'row' ? (
          <Stack ref={listTopRef} gap="xs">
            {routes.map((route) => (
              <RouteRow key={route.id} route={route} />
            ))}
          </Stack>
        ) : (
          <SimpleGrid ref={listTopRef} cols={{ base: 1, sm: 2, lg: 3 }} spacing="lg">
            {routes.map((route) => (
              <RouteCard
                key={route.id}
                route={route}
                showTeam={showTeam}
                actions={cardActions?.(route)}
              />
            ))}
          </SimpleGrid>
        )}

        <Box mt="xl">
          <Pagination
            currentPage={currentPage}
            totalPages={totalPages}
            onPageChange={handlePageChange}
          />
        </Box>
      </>
    )
  }

  // Past the last page (an old link, a list that shrank): not empty, so neither empty state.
  if (currentPage > 0) {
    return <OutOfRangeState onFirstPage={() => onPageChange(0)} />
  }

  // The filtered case is precisely the one needing the richest copy: it always carries a
  // description and a way out, never a bare title.
  if (hasFiltersOrSearch && deadEnd) {
    return <>{deadEnd}</>
  }

  return (
    <EmptyState
      variant={hasFiltersOrSearch ? 'filtered' : 'absolute'}
      icon={hasFiltersOrSearch ? <IconSearchOff size={48} /> : <IconMap size={48} />}
      title={hasFiltersOrSearch ? t('routes.list.noResultsTitle') : t('routes.list.empty.title')}
      description={
        hasFiltersOrSearch ? t('routes.list.noResults') : t('routes.list.empty.description')
      }
      actions={
        <>
          {hasFiltersOrSearch && onClearFilters && (
            <Button variant="light" onClick={onClearFilters}>
              {t('common.clearFilters')}
            </Button>
          )}
          {emptyAction}
        </>
      }
    />
  )
}
