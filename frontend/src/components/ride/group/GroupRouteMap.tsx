import { lazy, Suspense, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Box, Paper, Skeleton, Stack, Title } from '@mantine/core'
import type { RouteDetailDto, WeatherAttributionDto, WeatherLegDto } from '@/api/dto'
import { ErrorBoundary } from '@/components/common/ErrorBoundary'
import { RideGroupRouteActions } from '@/components/ride/RideGroupRouteActions'
import { ColorByControl } from '@/components/route/ColorByControl'
import { RouteSurfaceSummary } from '@/components/route/RouteSurfaceSummary'
import { WindMapLegend } from '@/components/weather/WindMapLegend'
import { RouteWaypointList } from '@/components/route/RouteWaypointList'
import { useRouteWindColors } from '@/hooks/useRouteWindColors'
import { useWaypointSelection } from '@/hooks/useWaypointSelection'
import { paths } from '@/config/paths'
import type { PlannerColorBy } from '@/lib/plannerSurface'
import { hasSurfaces } from '@/lib/trackSurface'
import { attributionHtml } from '@/lib/weatherOnRoute'

/**
 * What colours the group's line: the planner's modes, plus the wind of the group's leg (WEB-115).
 * The page's own type: `PlannerColorBy` serves the planner and every route view, which have no wind.
 */
export type GroupColorBy = PlannerColorBy | 'wind'

const NO_TRACKS: RouteDetailDto['tracks'] = []

// Lazy: the map pulls in map-vendor (~1 MB) and the elevation chart chart-vendor.
const RouteMapView = lazy(() =>
  import('@/components/route/RouteMapView').then((m) => ({ default: m.RouteMapView }))
)

// Lazy as the map itself, whose chunk it shares: the forecast's points, in the Météo mode only.
const WeatherCheckpointMarkers = lazy(() =>
  import('@/components/weather/WeatherCheckpointMarkers').then((m) => ({
    default: m.WeatherCheckpointMarkers,
  }))
)

/**
 * A group's single route: the map with its profile and a way to full screen, then — unless
 * `withActions` is off — what to do with it (view, GPX, FIT, send to a device).
 *
 * With a `leg` that has a forecast, a « Météo » mode colours the line by the wind (ledger WEB-115,
 * plan 2026-10-24-weather-on-map.md): exclusive of the grade and the surface, never the default,
 * the profile staying on the grade. The leg losing its forecast falls back to the grade. The same
 * mode puts a badge at every forecast point, its detail a click away, and a drop where rain becomes
 * likely, the km markers giving way to them (ledger WEB-116). The group's page shares the badge
 * whose popup is open with the row selected in its « Heure par heure » (`selectedCheckpoint`,
 * ledger WEB-117), and opens its own fullscreen map in the current mode (`fullscreenPath`).
 */
export function GroupRouteMap({
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
  fullscreenPath?: (colorBy: GroupColorBy) => string
  withActions?: boolean
}) {
  const { t } = useTranslation()
  const [chosenColorBy, setColorBy] = useState<GroupColorBy>('grade')
  // The forecast gone (a refetch), the choice reads as the grade.
  const colorBy: GroupColorBy = chosenColorBy === 'wind' && !leg ? 'grade' : chosenColorBy
  const wind = colorBy === 'wind'
  const tracks = route?.tracks ?? NO_TRACKS
  const windColorAt = useRouteWindColors(tracks, wind ? leg : undefined)
  const options = useMemo(() => {
    const modes: GroupColorBy[] = ['grade']
    if (hasSurfaces(tracks)) modes.push('surface')
    if (leg) modes.push('wind')
    return modes
  }, [tracks, leg])
  const lineAttribution = wind && attribution ? attributionHtml(attribution) : undefined
  const overlays =
    wind && leg ? (
      <Suspense fallback={null}>
        <WeatherCheckpointMarkers
          tracks={tracks}
          leg={leg}
          timezone={timezone}
          openIndex={selectedCheckpoint}
          onOpenChange={onSelectCheckpoint}
        />
      </Suspense>
    ) : undefined
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
                  fullscreenPath={
                    fullscreenPath ? fullscreenPath(colorBy) : paths.routeMap(teamSlug, routeSlug)
                  }
                  colorBy={wind ? 'grade' : colorBy}
                  lineColorAt={windColorAt}
                  lineAttribution={lineAttribution}
                  overlays={overlays}
                  kmMarkers={!wind}
                  waypointSelection={selection}
                  onWaypointSelectionChange={setSelection}
                />
              </Box>
            </Suspense>
            <Stack gap="xs">
              <ColorByControl value={colorBy} onChange={setColorBy} options={options} />
              {wind && leg && <WindMapLegend leg={leg} attribution={attribution} />}
              <RouteSurfaceSummary
                tracks={route.tracks}
                colorBy={wind ? 'grade' : colorBy}
                onColorByChange={setColorBy}
                withControl={false}
              />
            </Stack>
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
