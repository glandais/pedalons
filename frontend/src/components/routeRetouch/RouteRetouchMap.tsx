import { useEffect, useMemo, useRef } from 'react'
import { useTranslation } from 'react-i18next'
import { Layer, Source } from 'react-map-gl/maplibre'
import type { MapLayerMouseEvent, MapRef } from 'react-map-gl/maplibre'
import { Box, Paper, Skeleton, Text } from '@mantine/core'
import type { GeoPoint, RetouchedRouteDto } from '@/api/dto'
import { useDefaultMapView } from '@/hooks/useDefaultMapView'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'
import { decode2 } from '@/lib/polyline'
import { routeColor } from '@/lib/routeColors'
import { changedCoords, circleCoords, isTruncation } from '@/lib/routeRetouch'
import { EndMarker, StartMarker } from '../map/MapMarkers'
import { PedalonsMap } from '../map/PedalonsMap'
import { routeArrowLayout } from '../map/routeArrowLayout'

/** The accent of the stretch that changed: it has to stand out from every route colour. */
export const CHANGED_COLOR = '#e8590c'

interface RouteRetouchMapProps {
  /** The original route, `[lng, lat]` pairs. */
  original: number[][]
  candidates: RetouchedRouteDto[]
  selected: number
  hovered: number | null
  /** The finish asked for (a tap, or a team place), with the range the engine searched. */
  end?: GeoPoint
  endSnapM?: number
  /** A tap on the map places the finish. */
  placing: boolean
  onPick: (point: GeoPoint) => void
  /** The map's height (any CSS length). */
  height: string
}

const ROUND = 1e5
const round5 = (n: number) => Math.round(n * ROUND) / ROUND

function lineFeature(coordinates: number[][]): GeoJSON.Feature<GeoJSON.LineString> {
  return { type: 'Feature', properties: {}, geometry: { type: 'LineString', coordinates } }
}

/**
 * The preview of a retouch: the original in grey behind, the proposals over it (the selected one
 * thicker, with direction chevrons), the stretch that changed in an accent colour on top, the asked
 * finish with the range searched round it. A tap places the finish while `placing`.
 */
export function RouteRetouchMap({
  original,
  candidates,
  selected,
  hovered,
  end,
  endSnapM,
  placing,
  onPick,
  height,
}: RouteRetouchMapProps) {
  const { t } = useTranslation()
  const colorScheme = useResolvedColorScheme()
  const defaultView = useDefaultMapView()
  const mapRef = useRef<MapRef>(null)

  const decoded = useMemo(() => candidates.map((c) => decode2(c.polyline)), [candidates])
  const originalLine = useMemo(() => lineFeature(original), [original])
  const lines = useMemo(() => decoded.map(lineFeature), [decoded])
  const current = candidates[selected] as RetouchedRouteDto | undefined
  const changedLine = useMemo(() => {
    if (!current || isTruncation(current)) return undefined
    const coords = changedCoords(
      decoded[selected] ?? [],
      current.changed.startIndex,
      current.changed.endIndex
    )
    return coords.length >= 2 ? lineFeature(coords) : undefined
  }, [current, decoded, selected])
  const cutPoint =
    current && isTruncation(current) ? decoded[selected]?.[decoded[selected].length - 1] : undefined

  const rangeFeature = useMemo<GeoJSON.Feature<GeoJSON.Polygon> | undefined>(
    () =>
      end && endSnapM
        ? {
            type: 'Feature',
            properties: {},
            geometry: { type: 'Polygon', coordinates: [circleCoords(end, endSnapM)] },
          }
        : undefined,
    [end, endSnapM]
  )

  // Frame the original and every proposal (new proposals replace the previous seed's)
  useEffect(() => {
    const map = mapRef.current
    if (!map || original.length === 0) return
    let minLon = Infinity
    let minLat = Infinity
    let maxLon = -Infinity
    let maxLat = -Infinity
    for (const [lng, lat] of original) {
      minLon = Math.min(minLon, lng)
      maxLon = Math.max(maxLon, lng)
      minLat = Math.min(minLat, lat)
      maxLat = Math.max(maxLat, lat)
    }
    for (const { bounds } of candidates) {
      minLon = Math.min(minLon, bounds.minLon)
      minLat = Math.min(minLat, bounds.minLat)
      maxLon = Math.max(maxLon, bounds.maxLon)
      maxLat = Math.max(maxLat, bounds.maxLat)
    }
    map.fitBounds(
      [
        [minLon, minLat],
        [maxLon, maxLat],
      ],
      { padding: 40, duration: 0 }
    )
  }, [original, candidates])

  // A finish picked from the list may lie off screen: bring it into view
  useEffect(() => {
    const map = mapRef.current
    if (!map || !end) return
    if (!map.getBounds().contains([end.lng, end.lat])) map.easeTo({ center: [end.lng, end.lat] })
    // eslint-disable-next-line react-hooks/exhaustive-deps -- on a moved point, not a new object
  }, [end?.lat, end?.lng])

  const first = original[0]
  const initialViewState = first
    ? { longitude: first[0], latitude: first[1], zoom: 10 }
    : (defaultView ?? undefined)

  const handleClick = (event: MapLayerMouseEvent) => {
    if (placing) onPick({ lat: round5(event.lngLat.lat), lng: round5(event.lngLat.lng) })
  }

  return (
    <Box
      pos="relative"
      w="100%"
      h={height}
      className={colorScheme === 'dark' ? 'dark' : undefined}
      style={{
        zIndex: 0,
        border: '1px solid var(--mantine-color-default-border)',
        borderRadius: 'var(--mantine-radius-sm)',
        overflow: 'hidden',
      }}
      data-testid="route-retouch-map"
    >
      {!initialViewState ? (
        <Skeleton h="100%" w="100%" radius={0} />
      ) : (
        <PedalonsMap
          ref={mapRef}
          initialViewState={initialViewState}
          cursor={placing ? 'crosshair' : 'grab'}
          onClick={handleClick}
        >
          <Source id="retouch-original" type="geojson" data={originalLine}>
            <Layer
              id="retouch-original-line"
              type="line"
              layout={{ 'line-cap': 'round', 'line-join': 'round' }}
              paint={{ 'line-color': '#868e96', 'line-width': 4, 'line-opacity': 0.6 }}
            />
          </Source>
          {rangeFeature && (
            <Source id="retouch-range" type="geojson" data={rangeFeature}>
              <Layer
                id="retouch-range-fill"
                type="fill"
                paint={{ 'fill-color': CHANGED_COLOR, 'fill-opacity': 0.12 }}
              />
            </Source>
          )}
          {lines.map((line, i) => {
            const isSelected = i === selected
            const active = isSelected || i === hovered
            return (
              <Source key={i} id={`retouch-${i}`} type="geojson" data={line}>
                <Layer
                  id={`retouch-line-${i}`}
                  type="line"
                  layout={{ 'line-cap': 'round', 'line-join': 'round' }}
                  paint={{
                    'line-color': routeColor(i),
                    'line-width': active ? 5 : 3,
                    'line-opacity': active ? 1 : 0.55,
                  }}
                />
                <Layer
                  id={`retouch-arrows-${i}`}
                  type="symbol"
                  layout={{ ...routeArrowLayout, visibility: isSelected ? 'visible' : 'none' }}
                />
              </Source>
            )
          })}
          {changedLine && (
            <Source id="retouch-changed" type="geojson" data={changedLine}>
              <Layer
                id="retouch-changed-casing"
                type="line"
                layout={{ 'line-cap': 'round', 'line-join': 'round' }}
                paint={{ 'line-color': '#ffffff', 'line-width': 10 }}
              />
              <Layer
                id="retouch-changed-line"
                type="line"
                layout={{ 'line-cap': 'round', 'line-join': 'round' }}
                paint={{ 'line-color': CHANGED_COLOR, 'line-width': 7 }}
              />
            </Source>
          )}
          {first && <StartMarker longitude={first[0]} latitude={first[1]} />}
          {end && <EndMarker longitude={end.lng} latitude={end.lat} />}
          {cutPoint && <EndMarker longitude={cutPoint[0]} latitude={cutPoint[1]} />}
        </PedalonsMap>
      )}

      {placing && (
        <Paper
          shadow="md"
          withBorder
          px="sm"
          py={6}
          pos="absolute"
          top={8}
          left="50%"
          style={{ transform: 'translateX(-50%)', zIndex: 5 }}
          role="status"
        >
          <Text size="sm">{t('routeRetouch.moveEnd.clickHint')}</Text>
        </Paper>
      )}
    </Box>
  )
}
