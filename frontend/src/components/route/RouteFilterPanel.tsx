import { useCallback, useId, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { IconChevronDown, IconChevronUp } from '@tabler/icons-react'
import { Collapse, Select, Button, Paper, Group, SimpleGrid, Stack } from '@mantine/core'
import { RangeInput } from '@/components/common/RangeInput'
import { FilterPanelToggle } from '@/components/common/FilterPanelToggle'
import { Hilliness, SurfaceType, WindDirection, RouteSortBy, SortDirection } from '@/api/dto'
import type { RouteFilters } from '@/hooks/filters/routeFilters'
import { useDebouncedSearch } from '@/hooks/useDebouncedSearch'
import { SearchInput } from '../common/SearchInput'
import { useUnits } from '@/hooks/useUnits'

const NONE_VALUE = '_none'

interface RouteFilterPanelProps {
  filters: RouteFilters
  /** Replaces the whole filter set: omitted keys fall back to their default. */
  onFiltersChange: (filters: Partial<RouteFilters>) => void
  isOpen: boolean
  onOpenChange: (open: boolean) => void
  /** What « Effacer les filtres » lifts (`useRouteFilters`' `activeFilterCount`). */
  activeCount: number
  /** « Effacer les filtres »: `useRouteFilters`' `clearFilters`, which keeps the sort (RL4). */
  onClear: () => void
  /** The cross-team list's scope selector, on the line of « Filtres » (RL2). */
  scope?: ReactNode
  /** The map view orders nothing, so it hides the sort rather than showing an inert control. */
  showSort?: boolean
}

/**
 * The routes' bar (RL6, docs/LEDGER_*.md WEB-175): the search and the sort always in sight, then
 * the scope (cross-team list) and « Filtres », whose panel holds the criteria alone — distance,
 * elevation gain, hilliness, surface, wind.
 */
export function RouteFilterPanel({
  filters,
  onFiltersChange,
  isOpen,
  onOpenChange,
  activeCount,
  onClear,
  scope,
  showSort = true,
}: RouteFilterPanelProps) {
  const { t } = useTranslation()
  const { config, distanceUnit, elevationUnit } = useUnits()
  const panelId = useId()

  const updateFilter = <K extends keyof RouteFilters>(key: K, value: RouteFilters[K]) => {
    onFiltersChange({ ...filters, [key]: value, page: 0 })
  }

  const commitSearch = useCallback(
    (value: string) => onFiltersChange({ ...filters, search: value || undefined, page: 0 }),
    [filters, onFiltersChange]
  )
  const [search, setSearch] = useDebouncedSearch(filters.search ?? '', commitSearch)

  const clear = () => {
    setSearch('')
    onClear()
  }

  const direction = filters.sortDir === SortDirection.ASC ? 'ASC' : 'DESC'

  return (
    <Stack gap="sm">
      <Group gap="sm" align="flex-end" wrap="wrap">
        <SearchInput
          id="routes-search"
          value={search}
          onChange={setSearch}
          placeholder={t('routes.list.search.placeholder')}
          label={t('routes.list.search.label')}
          style={{ flex: '1 1 260px' }}
          fullWidth
        />
        {showSort && (
          <Group gap="xs" wrap="nowrap">
            <Select
              aria-label={t('routes.list.filters.sort.label')}
              value={filters.sortBy ?? RouteSortBy.DATE_TIME}
              onChange={(value) => value && updateFilter('sortBy', value as RouteSortBy)}
              allowDeselect={false}
              w={180}
              data={Object.values(RouteSortBy).map((sort) => ({
                value: sort,
                label: t(
                  `routes.list.filters.sort.${sort satisfies 'DISTANCE' | 'ELEVATION_GAIN' | 'HILLINESS' | 'DATE_TIME'}`
                ),
              }))}
            />
            <Button
              variant="default"
              px="xs"
              onClick={() =>
                updateFilter(
                  'sortDir',
                  filters.sortDir === SortDirection.ASC ? SortDirection.DESC : SortDirection.ASC
                )
              }
              aria-label={t(`routes.list.filters.sort.${direction}`)}
            >
              {direction === 'ASC' ? <IconChevronUp size={16} /> : <IconChevronDown size={16} />}
            </Button>
          </Group>
        )}
      </Group>

      <Group gap="sm" wrap="wrap" align="center">
        {scope}
        <FilterPanelToggle
          activeCount={activeCount}
          open={isOpen}
          onToggle={() => onOpenChange(!isOpen)}
          controls={panelId}
          onClear={clear}
        />
      </Group>

      <Collapse expanded={isOpen} id={panelId}>
        <Paper withBorder p="md">
          <SimpleGrid cols={{ base: 1, sm: 2, lg: 3 }} spacing="md">
            <RangeInput
              label={t('routes.detail.stats.distance')}
              minValue={filters.minDistance}
              maxValue={filters.maxDistance}
              onMinChange={(v) => updateFilter('minDistance', v)}
              onMaxChange={(v) => updateFilter('maxDistance', v)}
              minPlaceholder={t('routes.list.filters.distance.min')}
              maxPlaceholder={t('routes.list.filters.distance.max')}
              unit={distanceUnit()}
              step={5}
              displayMultiplier={config.distanceMultiplier}
            />

            <RangeInput
              label={t('routes.list.filters.elevationGain.label')}
              minValue={filters.minElevationGain}
              maxValue={filters.maxElevationGain}
              onMinChange={(v) => updateFilter('minElevationGain', v)}
              onMaxChange={(v) => updateFilter('maxElevationGain', v)}
              minPlaceholder={t('routes.list.filters.elevationGain.min')}
              maxPlaceholder={t('routes.list.filters.elevationGain.max')}
              unit={elevationUnit()}
              step={50}
              displayMultiplier={config.elevationMultiplier}
            />

            <Select
              label={t('routes.list.filters.hilliness.label')}
              value={filters.hilliness ?? NONE_VALUE}
              onChange={(value) =>
                updateFilter('hilliness', value === NONE_VALUE ? undefined : (value as Hilliness))
              }
              placeholder={t('routes.list.filters.hilliness.placeholder')}
              data={[
                { value: NONE_VALUE, label: t('routes.list.filters.hilliness.placeholder') },
                ...Object.values(Hilliness).map((type) => ({
                  value: type,
                  label: t(
                    `routes.list.filters.hilliness.${type satisfies 'FLAT' | 'HILLY' | 'MOUNTAINOUS'}`
                  ),
                })),
              ]}
            />

            <Select
              label={t('routes.list.filters.surfaceType.label')}
              value={filters.surfaceType ?? NONE_VALUE}
              onChange={(value) =>
                updateFilter(
                  'surfaceType',
                  value === NONE_VALUE ? undefined : (value as SurfaceType)
                )
              }
              placeholder={t('routes.list.filters.surfaceType.placeholder')}
              data={[
                { value: NONE_VALUE, label: t('routes.list.filters.surfaceType.placeholder') },
                ...Object.values(SurfaceType).map((type) => ({
                  value: type,
                  label: t(
                    `routes.surfaceType.${type satisfies 'ROAD' | 'GRAVEL' | 'MTB' | 'MIXED'}`
                  ),
                })),
              ]}
            />

            <Select
              label={t('routes.list.filters.windDirection.label')}
              value={filters.windDirection ?? NONE_VALUE}
              onChange={(value) =>
                updateFilter(
                  'windDirection',
                  value === NONE_VALUE ? undefined : (value as WindDirection)
                )
              }
              placeholder={t('routes.list.filters.windDirection.placeholder')}
              data={[
                { value: NONE_VALUE, label: t('routes.list.filters.windDirection.placeholder') },
                ...Object.values(WindDirection).map((dir) => ({
                  value: dir,
                  label: t(
                    `routes.list.filters.windDirection.${dir satisfies 'NORTH' | 'NORTH_EAST' | 'EAST' | 'SOUTH_EAST' | 'SOUTH' | 'SOUTH_WEST' | 'WEST' | 'NORTH_WEST'}`
                  ),
                })),
              ]}
            />
          </SimpleGrid>
        </Paper>
      </Collapse>
    </Stack>
  )
}
