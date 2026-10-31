import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { IconArrowsMaximize } from '@tabler/icons-react'
import { Box, Center, Paper, Text } from '@mantine/core'
import { useUncontrolled } from '@mantine/hooks'
import type { WaypointSelection } from '@/lib/waypoints'
import { MapControlButton, MapControlGroup } from '@/components/map/MapControl'
import type { RouteDetailDto } from '@/api/dto'
import type { PlannerColorBy } from '@/lib/plannerSurface'
import { useMapHeight } from '@/hooks/useResponsive'
import { getOverlayBg } from '@/lib/colors'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'
import { useRouteSurfaceColors } from '@/hooks/useRouteSurfaceColors'
import { useMapChartZoomSync } from '@/hooks/useMapChartZoomSync'
import { RouteTrackMap } from './RouteTrackMap'
import { ElevationChart } from './ElevationChart'

/**
 * The subset of a route these views actually render. Satisfied by both `RouteDetailDto` and
 * `GpxPreviewDto`, which is what lets the GPX tools reuse the map and elevation chart as-is.
 */
export type MappableRoute = Pick<RouteDetailDto, 'tracks' | 'waypoints' | 'distance'>

// Stable fit paddings, module-level so re-renders don't retrigger fit-to-bounds. Over the map, the
// profile needs room at the bottom so the whole track stays visible; below it, nothing to clear.
const OVERLAY_FIT_PADDING = { top: 50, bottom: 220, left: 50, right: 50 }
const BELOW_FIT_PADDING = 50
/** Height of the profile strip under the map, the fullscreen view's. */
const BELOW_PROFILE_HEIGHT = 160

/**
 * Where the profile sits: under the map (default, as in the fullscreen view and the planner), or
 * laid over its bottom — kept on a ride's pages, where the map sits among the groups' content.
 */
export type ProfilePlacement = 'below' | 'overlay'

interface RouteMapViewProps {
  route: MappableRoute
  /** When set, shows a fullscreen action linking to this path (built by the caller via paths.xxx). */
  fullscreenPath?: string
  /**
   * What colours the profile and the line: the grade (default) or, once the route has its surface
   * (WEB-100 C1b), the surface; without it, the grade whatever is asked.
   */
  colorBy?: PlannerColorBy
  /**
   * The line's colour from the caller (the wind of a group's leg, WEB-115), ahead of the surface;
   * the profile keeps `colorBy`. Same contract as `RouteTrackMap`'s — keep its identity stable.
   */
  lineColorAt?: (trackIndex: number, pointIndex: number) => string | undefined
  /** The credit that colouring owes, for the map's attribution control (HTML). */
  lineAttribution?: string
  /** Markers drawn on the track, inside the map (`RouteTrackMap`'s). */
  overlays?: React.ReactNode
  /** Whether the km markers show (default). */
  kmMarkers?: boolean
  /** The waypoint picked on the map, the profile or the page's list (internal state when omitted). */
  waypointSelection?: WaypointSelection | null
  onWaypointSelectionChange?: (selection: WaypointSelection | null) => void
  /** Where the profile sits (`below` by default). */
  profilePlacement?: ProfilePlacement
}

export function RouteMapView({
  route,
  fullscreenPath,
  colorBy = 'grade',
  lineColorAt: externalLineColorAt,
  lineAttribution,
  overlays,
  kmMarkers,
  waypointSelection,
  onWaypointSelectionChange,
  profilePlacement = 'below',
}: RouteMapViewProps) {
  const { t } = useTranslation()
  const colorScheme = useResolvedColorScheme()
  const mapHeight = useMapHeight('full')
  const [hoveredPointIndex, setHoveredPointIndex] = useState<number>(-1)
  const overlay = profilePlacement === 'overlay'
  const fitPadding = overlay ? OVERLAY_FIT_PADDING : BELOW_FIT_PADDING
  // Zoom/pan sync map ↔ profile, as in the fullscreen view; the fit a profile gesture induces
  // keeps the track clear of the profile when it lies over the map
  const {
    mapRef,
    chartRef,
    mapMoving,
    chartMoving,
    onMapMoveStart,
    onMapMoveEnd,
    onChartMoveStart,
    onChartMoveComplete,
  } = useMapChartZoomSync(route, fitPadding)
  // Ignore hover while a zoom/pan gesture is driving the counterpart view (RouteFullscreenView's)
  const handleHoverPoint = (index: number) => {
    if (mapMoving.current || chartMoving.current) return
    setHoveredPointIndex(index)
  }
  const [selection, setSelection] = useUncontrolled<WaypointSelection | null>({
    value: waypointSelection,
    defaultValue: null,
    finalValue: null,
    onChange: onWaypointSelectionChange,
  })

  const trackPoints = route.tracks.flatMap((track) => track.line.coordinates)

  const { surfaceAt, lineColorAt } = useRouteSurfaceColors(route.tracks, colorBy)

  if (trackPoints.length === 0) {
    return (
      <Center
        h={mapHeight}
        bg="var(--mantine-color-default-hover)"
        style={{ borderRadius: 'var(--mantine-radius-default)' }}
      >
        <Text c="dimmed">{t('map.noTrackData')}</Text>
      </Center>
    )
  }

  const overlayBg = getOverlayBg(colorScheme, true)

  const chart = (
    <ElevationChart
      ref={chartRef}
      route={route}
      hoveredPointIndex={hoveredPointIndex}
      onHoverPoint={handleHoverPoint}
      zoom={{
        onMoveStart: onChartMoveStart,
        onMoveComplete: onChartMoveComplete,
      }}
      colorBy={surfaceAt ? 'surface' : 'grade'}
      surfaceAt={surfaceAt}
      selectedWaypoint={selection?.waypoint ?? null}
      onSelectWaypoint={(waypoint) => setSelection({ waypoint, from: 'profile' })}
    />
  )

  return (
    <Paper withBorder style={{ overflow: 'hidden' }}>
      <Box w="100%" h={mapHeight}>
        <RouteTrackMap
          route={route}
          mapRef={mapRef}
          hoveredPointIndex={hoveredPointIndex}
          onHoverPoint={handleHoverPoint}
          onMoveStart={onMapMoveStart}
          onMoveEnd={onMapMoveEnd}
          fitPadding={fitPadding}
          lineColorAt={externalLineColorAt ?? lineColorAt}
          lineAttribution={lineAttribution}
          overlays={overlays}
          kmMarkers={kmMarkers}
          waypointSelection={selection}
          onWaypointSelect={setSelection}
          // Fullscreen action, in the control column with the zoom and basemap buttons
          controls={
            fullscreenPath && (
              <MapControlGroup>
                <MapControlButton
                  label={t('map.fullscreen.open')}
                  icon={<IconArrowsMaximize size={20} />}
                  to={fullscreenPath}
                />
              </MapControlGroup>
            )
          }
        >
          {/* Elevation chart overlay */}
          {overlay && (
            <Box
              pos="absolute"
              bottom={0}
              left={0}
              right={0}
              // Proportional to the (viewport-bounded) map so it never dominates a short map,
              // while staying readable on tall ones.
              h="clamp(110px, 38%, 200px)"
              style={{
                zIndex: 1000,
                pointerEvents: 'auto',
                boxShadow: 'var(--mantine-shadow-lg)',
                backgroundColor: overlayBg,
              }}
            >
              {chart}
            </Box>
          )}
        </RouteTrackMap>
      </Box>
      {/* Fixed elevation strip below the map (no overlap), as in the fullscreen view */}
      {!overlay && (
        <Box
          h={BELOW_PROFILE_HEIGHT}
          style={{
            borderTop: '1px solid var(--mantine-color-default-border)',
            backgroundColor: overlayBg,
          }}
        >
          {chart}
        </Box>
      )}
    </Paper>
  )
}
