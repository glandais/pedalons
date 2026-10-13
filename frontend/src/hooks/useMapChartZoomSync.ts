import { useCallback, useEffect, useMemo, useRef } from 'react'
import type { MapRef } from 'react-map-gl/maplibre'
import { calculateBounds } from '../components/map/mapUtils'
import type { ElevationChartHandle } from '../components/route/ElevationChart'
import type { MappableRoute } from '../components/route/RouteMapView'
import { pointsInDistanceRange, visibleDistanceRange } from '../components/route/trackDistanceRange'

/** Minimum chart x-range (meters) so very short routes/gestures never collapse to a sliver. */
const MIN_RANGE_METERS = 1000
/** Duration of the map move a chart gesture induces. */
const INDUCED_MOVE_MS = 300
/**
 * Releases the chart guard if the induced move never reports its end. Only a fallback: the guard
 * is normally released by that move's own `moveend`, however long a slow frame (3D terrain) makes it.
 */
const CHART_GUARD_FALLBACK_MS = 1500
/** Tags the map moves the chart induces: MapLibre copies `eventData` onto the move events. */
const CHART_SYNC_KEY = 'chartSync'

export interface MapChartZoomSync {
  mapRef: React.RefObject<MapRef | null>
  chartRef: React.RefObject<ElevationChartHandle | null>
  /** True while the map viewport is being dragged/zoomed (guards feedback loops + hover). */
  mapMoving: React.RefObject<boolean>
  /** True while the chart is panned/zoomed, and until the map move it induces has ended. */
  chartMoving: React.RefObject<boolean>
  onMapMoveStart: () => void
  /** Takes the map's `moveend` event, which tells a move the chart induced from the user's. */
  onMapMoveEnd: (event: object) => void
  onChartMoveStart: () => void
  onChartMoveComplete: (min: number, max: number) => void
}

/**
 * Bidirectional zoom/pan sync between the track map viewport and the elevation chart x-range,
 * after biketeam's `leaflet-custom.js`:
 *
 * - Map `moveend` → narrow the chart x-range to the cumulative-distance span of the track inside
 *   the map viewport (full extent when the viewport shows no track).
 * - Chart pan/zoom complete → fit the map to the part of the track inside the new chart x-range.
 *
 * The map move a chart gesture induces carries `{ chartSync: <id> }` as its event data, so its
 * `moveend` is never fed back into the chart — no timing guess involved, unlike the timer this
 * replaced, which bounced the chart outward whenever the map's animation ran past it. Only the
 * latest induced move releases `chartMoving` (a newer `fitBounds` interrupts the previous one,
 * whose `moveend` fires first); a user move during that animation still drives the chart.
 */
export function useMapChartZoomSync(route: MappableRoute): MapChartZoomSync {
  const mapRef = useRef<MapRef | null>(null)
  const chartRef = useRef<ElevationChartHandle | null>(null)
  const mapMoving = useRef(false)
  const chartMoving = useRef(false)
  /** Between a chart gesture's start and its completion. */
  const chartGesture = useRef(false)
  /** Id of the latest map move induced by the chart. */
  const inducedMoveId = useRef(0)
  const fallbackTimer = useRef<ReturnType<typeof setTimeout> | null>(null)

  const tracks = useMemo(() => route.tracks.map((track) => track.line.coordinates), [route.tracks])
  const totalDistance = route.distance

  const clearFallbackTimer = useCallback(() => {
    if (fallbackTimer.current !== null) {
      clearTimeout(fallbackTimer.current)
      fallbackTimer.current = null
    }
  }, [])

  const releaseChartGuard = useCallback(() => {
    clearFallbackTimer()
    chartMoving.current = false
  }, [clearFallbackTimer])

  // Map viewport changed → drive the chart x-range from the visible track span.
  const syncChartToMap = useCallback(() => {
    const map = mapRef.current
    const chart = chartRef.current
    if (!map || !chart) return

    const bounds = map.getBounds()
    const range = visibleDistanceRange(tracks, {
      west: bounds.getWest(),
      south: bounds.getSouth(),
      east: bounds.getEast(),
      north: bounds.getNorth(),
    })

    // No track in view → show the full profile.
    if (!range) {
      chart.setXRange(0, totalDistance)
      return
    }

    let { min, max } = range
    // Keep a readable minimum window on tiny spans, clamped to the route extent.
    if (max - min < MIN_RANGE_METERS) {
      const center = (min + max) / 2
      min = Math.max(0, center - MIN_RANGE_METERS / 2)
      max = Math.min(totalDistance, center + MIN_RANGE_METERS / 2)
    }

    chart.setXRange(min, max)
  }, [tracks, totalDistance])

  const onMapMoveStart = useCallback(() => {
    mapMoving.current = true
  }, [])

  const onMapMoveEnd = useCallback(
    (event: object) => {
      mapMoving.current = false
      const induced = (event as Record<string, unknown>)[CHART_SYNC_KEY]
      if (induced !== undefined) {
        if (induced === inducedMoveId.current && !chartGesture.current) releaseChartGuard()
        return
      }
      // A map move while the chart is mid-gesture would fight the zoom plugin.
      if (chartGesture.current) return
      syncChartToMap()
    },
    [syncChartToMap, releaseChartGuard]
  )

  const onChartMoveStart = useCallback(() => {
    chartMoving.current = true
    chartGesture.current = true
    clearFallbackTimer()
  }, [clearFallbackTimer])

  const onChartMoveComplete = useCallback(
    (min: number, max: number) => {
      chartGesture.current = false
      const map = mapRef.current
      const points = pointsInDistanceRange(tracks, min, max)
      if (!map || points.length === 0) {
        releaseChartGuard()
        return
      }
      // Bumped before the call: fitBounds stops the previous induced move, whose moveend fires
      // synchronously and must no longer count as the latest.
      const id = ++inducedMoveId.current
      chartMoving.current = true
      clearFallbackTimer()
      fallbackTimer.current = setTimeout(releaseChartGuard, CHART_GUARD_FALLBACK_MS)
      map.fitBounds(
        calculateBounds(points),
        { padding: 50, duration: INDUCED_MOVE_MS },
        { [CHART_SYNC_KEY]: id }
      )
    },
    [tracks, clearFallbackTimer, releaseChartGuard]
  )

  useEffect(() => clearFallbackTimer, [clearFallbackTimer])

  return {
    mapRef,
    chartRef,
    mapMoving,
    chartMoving,
    onMapMoveStart,
    onMapMoveEnd,
    onChartMoveStart,
    onChartMoveComplete,
  }
}
