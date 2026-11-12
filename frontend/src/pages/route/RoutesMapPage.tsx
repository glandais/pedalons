import { Navigate, useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { Group, Stack } from '@mantine/core'
import { paths } from '../../config/paths'
import { LoadingPage } from '../../components/common/LoadingSpinner'
import { TeamLayout } from '../../components/team/TeamLayout'
import { RouteFilterPanel } from '../../components/route/RouteFilterPanel'
import { RoutesTileMap } from '../../components/route/RoutesTileMap'
import { RouteViewSwitch } from '@/components/route/RouteViewSwitch'
import { RoutesListHeader } from '@/components/route/RoutesListHeader'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useRoutesMapData } from './routesMapData'
import { TagFilter } from '../../components/tag'

export function RoutesMapPage() {
  const { teamSlug } = useParams<{ teamSlug: string }>()
  const { t } = useTranslation()

  const {
    filters,
    setFilters,
    filtersOpen,
    setFiltersOpen,
    handleFiltersChange,
    activeFilterCount,
    clearFilters,
    team: { data: team, isLoading },
    tilesUrl,
    bounds,
  } = useRoutesMapData(teamSlug)

  useCanonicalPath(team ? paths.routesMap(team.slug) : undefined)

  if (isLoading) {
    return <LoadingPage message={t('routes.list.title')} />
  }

  if (!team || !tilesUrl) {
    return <Navigate to={paths.teams()} replace />
  }

  return (
    <TeamLayout team={team} currentTab="routes">
      <Stack py="lg">
        {/* The list's head, creation included (RL13): the map is a view of the same list. */}
        <RoutesListHeader team={team} />

        <RouteFilterPanel
          filters={filters}
          onFiltersChange={handleFiltersChange}
          isOpen={filtersOpen}
          onOpenChange={setFiltersOpen}
          activeCount={activeFilterCount}
          onClear={clearFilters}
          showSort={false}
        />

        <TagFilter
          teamSlug={team.slug}
          type="ROUTE"
          value={filters.tags}
          onChange={(tags) => setFilters({ tags })}
        />

        <Group justify="flex-end">
          <RouteViewSwitch current="map" teamSlug={team.slug} />
        </Group>

        <RoutesTileMap
          tilesUrl={tilesUrl}
          bounds={bounds.data?.bounds}
          boundsPending={bounds.isLoading}
        />
      </Stack>
    </TeamLayout>
  )
}
