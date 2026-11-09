import { lazy, Suspense } from 'react'
import { useTranslation } from 'react-i18next'
import { Box, Paper, Skeleton, Stack, Text, Title } from '@mantine/core'
import {
  ElevationState,
  type RouteDetailDto,
  type WeatherAttributionDto,
  type WeatherLegDto,
} from '@/api/dto'
import { ErrorBoundary } from '@/components/common/ErrorBoundary'
import { RideGroupRouteActions } from '@/components/ride/RideGroupRouteActions'
import { ColorModeControls } from '@/components/route/ColorModeControls'
import { RouteWaypointList } from '@/components/route/RouteWaypointList'
import type { WindLegendSubject } from '@/components/weather/WindMapLegend'
import { useMapHeight, type MapHeightVariant } from '@/hooks/useResponsive'
import { useWaypointSelection } from '@/hooks/useWaypointSelection'
import { useWindColorMode } from '@/hooks/useWindColorMode'
import { paths } from '@/config/paths'
import type { PlannerColorBy } from '@/lib/plannerSurface'

/**
 * What colours the line: the planner's modes, plus the wind of the leg (WEB-115). The panel's own
 * type: `PlannerColorBy` serves the planner and every route view, which have no wind.
 */
export type RouteMapColorBy = PlannerColorBy | 'wind'

// Lazy: the map pulls in map-vendor (~1 MB) and the elevation chart chart-vendor.
const RouteMapView = lazy(() =>
  import('@/components/route/RouteMapView').then((m) => ({ default: m.RouteMapView }))
)

/**
 * The single route of a ride group or a trip stage (docs/LEDGER_*.md WEB-155): the map with its
 * profile and a way to full screen, then — unless `withActions` is off — what to do with it (view,
 * GPX, FIT, send to a device). While the route's elevation is still being refined, says so.
 *
 * With a `leg` that has a forecast, a « Météo » mode colours the line by the wind (ledger WEB-115,
 * plan 2026-10-24-weather-on-map.md): exclusive of the grade and the surface, never the default,
 * the profile staying on the grade. The leg losing its forecast falls back to the grade. The same
 * mode puts a badge at every forecast point, its detail a click away, and a drop where rain becomes
 * likely, the km markers giving way to them (ledger WEB-116). The group's page shares the badge
 * whose popup is open with the row selected in its « Heure par heure » (`selectedCheckpoint`,
 * ledger WEB-117), and opens its own fullscreen map in the current mode (`fullscreenPath`).
 */
export function RouteMapPanel({
  teamSlug,
  routeSlug,
  route,
  leg,
  attribution,
  timezone,
  selectedCheckpoint,
  onSelectCheckpoint,
  fullscreenPath,
  withActions = true,
  heightVariant,
  subject = 'group',
}: {
  teamSlug: string
  routeSlug: string
  /** From the ride's one `/routes/bulk` read; undefined while it loads. */
  route: RouteDetailDto | undefined
  /**
   * The group's leg of the forecast, only when the wind mode is on offer (`hasWindForecast`, a ride
   * neither finished nor cancelled): the page decides.
   */
  leg?: WeatherLegDto
  /** The forecast's credit, owed while the wind colours the line. */
  attribution?: WeatherAttributionDto
  /** The ride's zone: the passages of the forecast's points read in it. */
  timezone?: string
  /**
   * The checkpoint (its `index`) whose badge is lit and popup open in the Météo mode, when the
   * page holds it; left out, the badges keep their own.
   */
  selectedCheckpoint?: number | null
  /** A badge opened (its `index`) or its popup closed (`null`). */
  onSelectCheckpoint?: (index: number | null) => void
  /** The fullscreen map, opened in the mode the line is in; the route's own map without it. */
  fullscreenPath?: (colorBy: RouteMapColorBy) => string
  withActions?: boolean
  /** The map's height, `RouteMapView`'s (`full` when left out); `sticky` on a solo ride's page. */
  heightVariant?: MapHeightVariant
  /** Whose speed the wind legend says the passages assume by default: a group's or a stage's. */
  subject?: Extract<WindLegendSubject, 'group' | 'stage'>
}) {
  const { t } = useTranslation()
  const mode = useWindColorMode({
    tracks: route?.tracks,
    leg,
    attribution,
    timezone,
    openIndex: selectedCheckpoint,
    onOpenChange: onSelectCheckpoint,
  })
  const { selection, setSelection, mapBoxRef, selectFromList } = useWaypointSelection()
  // The placeholder takes the map's height when the page sets one, its former 500 px otherwise
  const variantHeight = useMapHeight(heightVariant ?? 'full')
  const skeletonHeight = heightVariant ? variantHeight : 500
  return (
    <Stack gap="md">
      <ErrorBoundary variant="inline">
        {route ? (
          <>
            <Suspense fallback={<Skeleton height={skeletonHeight} radius="md" />}>
              <Box ref={mapBoxRef}>
                <RouteMapView
                  route={route}
                  fullscreenPath={
                    fullscreenPath
                      ? fullscreenPath(mode.colorBy)
                      : paths.routeMap(teamSlug, routeSlug)
                  }
                  colorBy={mode.plannerColorBy}
                  {...mode.mapProps}
                  waypointSelection={selection}
                  onWaypointSelectionChange={setSelection}
                  // A ride's map keeps its profile laid over it, unlike a route's sheet
                  profilePlacement="overlay"
                  heightVariant={heightVariant}
                />
              </Box>
            </Suspense>
            {route.elevationState === ElevationState.PENDING && (
              <Text size="xs" c="dimmed">
                {t('routes.detail.elevationRefining')}
              </Text>
            )}
            <ColorModeControls
              mode={mode}
              tracks={route.tracks}
              attribution={attribution}
              subject={subject}
            />
            <RouteWaypointList
              waypoints={route.waypoints}
              selected={selection?.waypoint ?? null}
              onSelect={selectFromList}
            />
          </>
        ) : (
          <Skeleton height={skeletonHeight} radius="md" />
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
