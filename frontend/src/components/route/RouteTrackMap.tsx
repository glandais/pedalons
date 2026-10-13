import { useCallback, useEffect, useMemo, useRef } from 'react'
import { Source, Layer, MapRef, MapMouseEvent, ViewStateChangeEvent } from 'react-map-gl/maplibre'
import type { PaddingOptions } from 'maplibre-gl'
import { Box } from '@mantine/core'
import {
  StartMarker,
  EndMarker,
  HoverMarker,
  WaypointMarker,
  KmMarkersLayer,
} from '../map/MapMarkers'
import {
  calculateBounds,
  distance,
  findNearestPoint,
  createGradientLineFeatures,
} from '../map/mapUtils'
import { PedalonsMap } from '../map/PedalonsMap'
import { routeArrowLayout } from '../map/routeArrowLayout'
import { HideTrackControl } from '../map/HideTrackControl'
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
  /** Gets the MapLibre event, whose `eventData` tells a programmatic move from the user's. */
  onMoveEnd?: (event: ViewStateChangeEvent) => void
  /**
   * Map controls (`MapControlGroup`). Rendered *inside* the map, where `useControl` can reach the
   * map context — unlike `children`, which sits outside it.
   */
  controls?: React.ReactNode
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
  onMoveStart,
  onMoveEnd,
  controls,
  children,
}: RouteTrackMapProps) {
  const colorScheme = useResolvedColorScheme()

  // Press "h" to hide the trace and its markers, revealing the basemap underneath
  const [trackHidden, toggleTrackHidden] = useHideTrackKey()

  // Flatten all track points from multiple tracks
  const trackPoints = useMemo(
    () => route.tracks.flatMap((track) => track.line.coordinates) || [],
    [route.tracks]
  )
  const waypoints = route.waypoints || []

  // Create gradient line GeoJSON
  const lineFeatures = useMemo(() => createGradientLineFeatures(route.tracks), [route.tracks])

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
  const bounds = useMemo(
    () => (trackPoints.length > 0 ? calculateBounds(trackPoints) : null),
    [trackPoints]
  )

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
    (event: MapMouseEvent) => {
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
    onHoverPoint(-1)
  }, [onHoverPoint])

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

            {/* Start marker */}
            <StartMarker longitude={trackPoints[0][0]} latitude={trackPoints[0][1]} />

            {/* End marker */}
            <EndMarker
              longitude={trackPoints[trackPoints.length - 1][0]}
              latitude={trackPoints[trackPoints.length - 1][1]}
            />

            {/* Waypoints */}
            {waypoints.map(
              (waypoint, index) =>
                waypoint.geometry.coordinates[0] &&
                waypoint.geometry.coordinates[1] && (
                  <WaypointMarker
                    key={`waypoint-${index}`}
                    longitude={waypoint.geometry.coordinates[0]}
                    latitude={waypoint.geometry.coordinates[1]}
                    name={waypoint.name}
                  />
                )
            )}

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
