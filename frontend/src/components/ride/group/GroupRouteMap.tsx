import { lazy, Suspense, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Box, Paper, Skeleton, Stack, Title } from '@mantine/core'
import type { RouteDetailDto } from '@/api/dto'
import { ErrorBoundary } from '@/components/common/ErrorBoundary'
import { RideGroupRouteActions } from '@/components/ride/RideGroupRouteActions'
import { RouteSurfaceSummary } from '@/components/route/RouteSurfaceSummary'
import { RouteWaypointList } from '@/components/route/RouteWaypointList'
import { useWaypointSelection } from '@/hooks/useWaypointSelection'
import { paths } from '@/config/paths'
import type { PlannerColorBy } from '@/lib/plannerSurface'

// Lazy: the map pulls in map-vendor (~1 MB) and the elevation chart chart-vendor.
const RouteMapView = lazy(() =>
  import('@/components/route/RouteMapView').then((m) => ({ default: m.RouteMapView }))
)

/**
 * A group's single route: the map with its profile and a way to full screen, then — unless
 * `withActions` is off — what to do with it (view, GPX, FIT, send to a device).
 */
export function GroupRouteMap({
  teamSlug,
  routeSlug,
  route,
  withActions = true,
}: {
  teamSlug: string
  routeSlug: string
  /** From the ride's one `/routes/bulk` read; undefined while it loads. */
  route: RouteDetailDto | undefined
  withActions?: boolean
}) {
  const { t } = useTranslation()
  const [colorBy, setColorBy] = useState<PlannerColorBy>('grade')
  const { selection, setSelection, mapBoxRef, selectFromList } = useWaypointSelection()
  return (
    <Stack gap="md">
      <ErrorBoundary variant="inline">
        {route ? (
          <>
            <Suspense fallback={<Skeleton height={500} radius="md" />}>
              <Box ref={mapBoxRef}>
                <RouteMapView
                  route={route}
                  fullscreenPath={paths.routeMap(teamSlug, routeSlug)}
                  colorBy={colorBy}
                  waypointSelection={selection}
                  onWaypointSelectionChange={setSelection}
                />
              </Box>
            </Suspense>
            <RouteSurfaceSummary
              tracks={route.tracks}
              colorBy={colorBy}
              onColorByChange={setColorBy}
            />
            <RouteWaypointList
              waypoints={route.waypoints}
              selected={selection?.waypoint ?? null}
              onSelect={selectFromList}
            />
          </>
        ) : (
          <Skeleton height={500} radius="md" />
        )}
      </ErrorBoundary>
      {withActions && (
        <Paper withBorder p="md">
          <Stack gap="xs">
            <Title order={3} size="h5">
              {t('rides.group.routeTitle')}
            </Title>
            <RideGroupRouteActions
              teamSlug={teamSlug}
              routeSlug={routeSlug}
              route={route}
              size="sm"
            />
          </Stack>
        </Paper>
      )}
    </Stack>
  )
}
