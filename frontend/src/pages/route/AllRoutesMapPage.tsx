import { Group, Stack } from '@mantine/core'
import { useAllRoutesMapData } from './allRouteListData'
import { MembershipSelect } from '../../components/common/MembershipSelect'
import { RouteFilterPanel } from '../../components/route/RouteFilterPanel'
import { RoutesTileMap } from '../../components/route/RoutesTileMap'
import { RouteViewSwitch } from '@/components/route/RouteViewSwitch'

export function AllRoutesMapPage() {
  const {
    filters,
    setFilters,
    filtersOpen,
    setFiltersOpen,
    handleFiltersChange,
    activeFilterCount,
    clearFilters,
    tilesUrl,
    bounds,
  } = useAllRoutesMapData()

  return (
    <Stack my="lg">
      <RouteFilterPanel
        filters={filters}
        onFiltersChange={handleFiltersChange}
        isOpen={filtersOpen}
        onOpenChange={setFiltersOpen}
        activeCount={activeFilterCount}
        onClear={clearFilters}
        showSort={false}
        scope={
          <MembershipSelect
            value={filters.membership}
            onChange={(membership) => setFilters({ membership })}
          />
        }
      />

      <Group justify="flex-end">
        <RouteViewSwitch current="map" />
      </Group>

      <RoutesTileMap
        tilesUrl={tilesUrl}
        bounds={bounds.data?.bounds}
        boundsPending={bounds.isLoading}
      />
    </Stack>
  )
}
