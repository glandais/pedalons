import { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { IconMap } from '@tabler/icons-react'
import { Box, SimpleGrid, Stack } from '@mantine/core'
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
  /** The previous answer stands in while the next loads (`isPlaceholderData`): dimmed (RL11). */
  isRefreshing?: boolean
  isError?: boolean
  error?: unknown
  /** Reloads the list — the error state's « Réessayer ». */
  onRetry?: () => void
  showTeam: boolean
  hasFiltersOrSearch: boolean
  currentPage: number
  totalPages: number
  onPageChange: (page: number) => void
  /**
   * The filtered empty state (`RouteDeadEnd`): « Aucun parcours pour ces filtres », the filters
   * named, « Effacer les filtres », and the one filter whose lifting brings routes back (RL10).
   */
  deadEnd: ReactNode
  emptyAction?: ReactNode
  density?: RouteDensity
  /** The `⋯` menu of each card — given by a team's own list, which knows the reader's role. */
  cardActions?: (route: RouteDto) => ReactNode
}

export function RouteListContent({
  routes,
  isLoading,
  isRefreshing = false,
  isError,
  error,
  onRetry,
  showTeam,
  hasFiltersOrSearch,
  currentPage,
  totalPages,
  onPageChange,
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

  return (
    <QueryStateBoundary
      isLoading={isLoading}
      isError={isError}
      error={error}
      onRetry={onRetry}
      isRefreshing={isRefreshing}
      skeleton={
        <SimpleGrid cols={{ base: 1, sm: 2, lg: 3 }}>
          <RouteCardSkeleton count={6} />
        </SimpleGrid>
      }
    >
      {body()}
    </QueryStateBoundary>
  )

  function body() {
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
    if (hasFiltersOrSearch) {
      return <>{deadEnd}</>
    }

    return (
      <EmptyState
        icon={<IconMap size={48} />}
        title={t('routes.list.empty.title')}
        description={t('routes.list.empty.description')}
        actions={emptyAction}
      />
    )
  }
}
