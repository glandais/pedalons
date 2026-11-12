import { Group, Stack } from '@mantine/core'
import { useAllRouteListData } from './allRouteListData'
import { isSingleTeam } from '../../config/appConfig'
import { MembershipSelect } from '../../components/common/MembershipSelect'
import { RouteFilterPanel } from '../../components/route/RouteFilterPanel'
import { RouteListContent } from '../../components/route/RouteListContent'
import { ResultCount } from '@/components/common/ResultCount'
import { RouteDeadEnd } from '@/components/route/RouteDeadEnd'
import { RouteViewSwitch } from '@/components/route/RouteViewSwitch'

export function AllRoutesPage() {
  const {
    filters,
    setFilters,
    setFiltersOpen,
    filtersOpen,
    handleFiltersChange,
    handlePageChange,
    hasFiltersOrSearch,
    clearFilters,
    routes,
    density,
    totalPages,
  } = useAllRouteListData()

  const { data: routesData, isLoading, isError, error, refetch } = routes

  return (
    <Stack my="lg">
      <MembershipSelect
        value={filters.membership}
        onChange={(membership) => setFilters({ membership })}
      />

      <RouteFilterPanel
        filters={filters}
        onFiltersChange={handleFiltersChange}
        isOpen={filtersOpen}
        onOpenChange={setFiltersOpen}
      />

      <Group justify="space-between" align="center" wrap="wrap">
        <ResultCount total={routesData?.total} resource="routes" />
        <RouteViewSwitch
          current={density}
          onDensityChange={(value) => setFilters({ density: value })}
        />
      </Group>

      <RouteListContent
        density={density}
        deadEnd={
          <RouteDeadEnd
            filters={filters}

            onSetFilters={setFilters}
            onClearFilters={clearFilters}
          />
        }
        routes={routesData?.routes}
        isLoading={isLoading}
        isError={isError}
        error={error}
        onRetry={() => void refetch()}
        showTeam={!isSingleTeam()}
        hasFiltersOrSearch={hasFiltersOrSearch}
        currentPage={filters.page}
        totalPages={totalPages}
        onPageChange={handlePageChange}
        onClearFilters={clearFilters}
      />
    </Stack>
  )
}
