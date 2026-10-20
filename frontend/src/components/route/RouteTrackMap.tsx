import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import {
  Source,
  Layer,
  MapRef,
  MapLayerMouseEvent,
  ViewStateChangeEvent,
} from 'react-map-gl/maplibre'
import type { PaddingOptions } from 'maplibre-gl'
import { Box } from '@mantine/core'
import { useUncontrolled } from '@mantine/hooks'
import { StartMarker, EndMarker, HoverMarker, KmMarkersLayer } from '../map/MapMarkers'
import {
  calculateBounds,
  distance,
  findNearestPoint,
  createGradientLineFeatures,
} from '../map/mapUtils'
import { PedalonsMap } from '../map/PedalonsMap'
import { routeArrowLayout } from '../map/routeArrowLayout'
import { HideTrackControl } from '../map/HideTrackControl'
import { WAYPOINT_HIT_LAYER, WaypointLayer } from '../map/WaypointLayer'
import { useMapStyle } from '@/hooks/useMapStyle'
import type { WaypointSelection } from '@/lib/waypoints'
import { useHideTrackKey } from '@/hooks/useHideTrackKey'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'
import type { MappableRoute } from './RouteMapView'
// maplibre-gl CSS is provided by maplibre-theme in index.css

interface RouteTrackMapProps {
  route: MappableRoute
  mapRef: React.RefObject<MapRef | null>
  hoveredPointIndex: number
  onHoverPoint: (index: number) => void
  /** Padding used when fitting the track to the viewport. Defaults to 50px on every side. */
  fitPadding?: number | PaddingOptions
  onMoveStart?: () => void
  /**
   * The colour of the segment starting at a point (track index, point index in the track), instead
   * of the climb's grade (surface of a saved route, WEB-100 C1b). Keep its identity stable.
   */
  lineColorAt?: (trackIndex: number, pointIndex: number) => string
  /** Gets the MapLibre event, whose `eventData` tells a programmatic move from the user's. */
  onMoveEnd?: (event: ViewStateChangeEvent) => void
  /**
   * Map controls (`MapControlGroup`). Rendered *inside* the map, where `useControl` can reach the
   * map context — unlike `children`, which sits outside it.
   */
  controls?: React.ReactNode
  /** The waypoint picked on the map, the profile or the list (uncontrolled when omitted). */
  waypointSelection?: WaypointSelection | null
  onWaypointSelect?: (selection: WaypointSelection | null) => void
  /** Overlays (the elevation chart) absolutely positioned on top of the map. */
  children?: React.ReactNode
}

/**
 * The gradient-colored track map extracted from RouteMapView: MapLibre map + colored line,
 * start/end/waypoint markers, km markers, hover marker, and nearest-point hover handling.
 * Fills its parent (100% width/height); the parent decides the actual size.
 */
export function RouteTrackMap({
  route,
  mapRef,
  hoveredPointIndex,
  onHoverPoint,
  fitPadding = 50,
  lineColorAt,
  onMoveStart,
  onMoveEnd,
  controls,
  waypointSelection,
  onWaypointSelect,
  children,
}: RouteTrackMapProps) {
  const colorScheme = useResolvedColorScheme()
  const { darkBasemap } = useMapStyle()
  const [selection, setSelection] = useUncontrolled<WaypointSelection | null>({
    value: waypointSelection,
    defaultValue: null,
    finalValue: null,
    onChange: onWaypointSelect,
  })
  const [hoveredWaypoint, setHoveredWaypoint] = useState<number | null>(null)

  // Press "h" to hide the trace and its markers, revealing the basemap underneath
  const [trackHidden, toggleTrackHidden] = useHideTrackKey()

  // Flatten all track points from multiple tracks
  const trackPoints = useMemo(
    () => route.tracks.flatMap((track) => track.line.coordinates) || [],
    [route.tracks]
  )
  const waypoints = useMemo(() => route.waypoints ?? [], [route.waypoints])

  // Create gradient line GeoJSON
  const lineFeatures = useMemo(
    () => createGradientLineFeatures(route.tracks, lineColorAt),
    [route.tracks, lineColorAt]
  )

  // The direction chevrons follow whole tracks: placed on the gradient's short segments, they
  // would restart (or vanish) at every colour change.
  const directionLines = useMemo(
    () => ({
      type: 'FeatureCollection' as const,
      features: route.tracks.map((track) => ({
        type: 'Feature' as const,
        properties: {},
        geometry: track.line,
      })),
    }),
    [route.tracks]
  )

  // The track is already in hand on the first render — the parent doesn't mount this without one —
  // so the map opens on it via `initialViewState` instead of snapping to it after `onLoad`.
  const computedBounds = useMemo(
    () => (trackPoints.length > 0 ? calculateBounds(trackPoints) : null),
    [trackPoints]
  )
  // The background swap of a fast profile for the precise one (ledger `WEB-102`) hands over new
  // points with the same extent: keep the previous bounds object (extent rounded to ~100 m) so the
  // re-centre effect below does not throw away the viewer's zoom and pan.
  const boundsRef = useRef<{ key: string; bounds: typeof computedBounds }>({
    key: '',
    bounds: null,
  })
  const boundsKey = computedBounds
    ? JSON.stringify(computedBounds, (_, v) => (typeof v === 'number' ? Math.round(v * 1e3) : v))
    : ''
  if (boundsRef.current.key !== boundsKey) {
    boundsRef.current = { key: boundsKey, bounds: computedBounds }
  }
  const bounds = boundsRef.current.bounds

  // Re-center when the route changes (e.g. switching trip stages), which keeps the map mounted so
  // `initialViewState` no longer applies. Skipped on mount, where it would fight the initial frame.
  const framedRef = useRef(false)
  useEffect(() => {
    if (!bounds) return
    if (!framedRef.current) {
      framedRef.current = true
      return
    }
    mapRef.current?.fitBounds(bounds, { padding: fitPadding, duration: 300 })
  }, [bounds, fitPadding, mapRef])

  // Handle mouse move for nearest point detection
  const handleMouseMove = useCallback(
    (event: MapLayerMouseEvent) => {
      const featureId = event.features?.[0]?.id
      const hovered = typeof featureId === 'number' ? featureId : null
      setHoveredWaypoint((previous) => (previous === hovered ? previous : hovered))

      if (!mapRef.current || trackPoints.length === 0) return

      const bounds = mapRef.current.getBounds()
      const sw = bounds.getSouthWest()
      const ne = bounds.getNorthEast()
      const mapViewSize = distance(sw.lng, sw.lat, ne.lng, ne.lat)

      const nearestIndex = findNearestPoint(
        trackPoints,
        event.lngLat.lat,
        event.lngLat.lng,
        mapViewSize / 20.0
      )

      if (nearestIndex >= 0) {
        onHoverPoint(nearestIndex)
      }
    },
    [trackPoints, mapRef, onHoverPoint]
  )

  const handleMouseLeave = useCallback(() => {
    setHoveredWaypoint(null)
    onHoverPoint(-1)
  }, [onHoverPoint])

  const handleClick = useCallback(
    (event: MapLayerMouseEvent) => {
      const id = event.features?.[0]?.id
      const waypoint = typeof id === 'number' ? waypoints[id] : undefined
      setSelection(waypoint ? { waypoint, from: 'map' } : null)
    },
    [waypoints, setSelection]
  )

  const hoveredPoint = hoveredPointIndex >= 0 ? trackPoints[hoveredPointIndex] : null

  return (
    <Box
      pos="relative"
      w="100%"
      h="100%"
      className={colorScheme === 'dark' ? 'dark' : undefined}
      style={{ zIndex: 0 }}
    >
      <PedalonsMap
        ref={mapRef}
        initialViewState={{
          bounds: bounds ?? undefined,
          fitBoundsOptions: { padding: fitPadding },
        }}
        interactiveLayerIds={trackHidden ? [] : [WAYPOINT_HIT_LAYER]}
        cursor={hoveredWaypoint !== null ? 'pointer' : undefined}
        onClick={handleClick}
        onMouseMove={handleMouseMove}
        onMouseLeave={handleMouseLeave}
        onMoveStart={onMoveStart}
        onMoveEnd={onMoveEnd}
      >
        <HideTrackControl hidden={trackHidden} onToggle={toggleTrackHidden} />
        {controls}

        {!trackHidden && (
          <>
            {/* Gradient-colored route line */}
            <Source id="route-segments" type="geojson" data={lineFeatures}>
              <Layer
                id="route-line"
                type="line"
                paint={{
                  'line-color': ['get', 'color'],
                  'line-width': 8,
                  'line-opacity': 0.8,
                }}
              />
            </Source>
            <Source id="route-direction" type="geojson" data={directionLines}>
              <Layer id="route-direction-arrows" type="symbol" layout={routeArrowLayout} />
            </Source>

            {/* Author's waypoints: a symbol layer, under the DOM markers below */}
            <WaypointLayer
              waypoints={waypoints}
              selection={selection}
              onSelect={setSelection}
              hoveredIndex={hoveredWaypoint}
              darkBasemap={darkBasemap}
            />

            {/* Start marker */}
            <StartMarker longitude={trackPoints[0][0]} latitude={trackPoints[0][1]} />

            {/* End marker */}
            <EndMarker
              longitude={trackPoints[trackPoints.length - 1][0]}
              latitude={trackPoints[trackPoints.length - 1][1]}
            />

            {/* Km markers */}
            <KmMarkersLayer coords={trackPoints} totalDistanceM={route.distance} />

            {/* Hover marker */}
            {hoveredPoint && <HoverMarker longitude={hoveredPoint[0]} latitude={hoveredPoint[1]} />}
          </>
        )}
      </PedalonsMap>

      {children}
    </Box>
  )
}
