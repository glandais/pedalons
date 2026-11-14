import { useEffect, useMemo, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Layer, Source } from 'react-map-gl/maplibre'
import type { MapLayerMouseEvent, MapRef } from 'react-map-gl/maplibre'
import { Box, Button, Group, Loader, Paper, Skeleton, Text } from '@mantine/core'
import type { GeneratedRouteDto, GeoPoint } from '@/api/dto'
import { useDefaultMapView } from '@/hooks/useDefaultMapView'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'
import { decode2 } from '@/lib/polyline'
import { routeColor } from '@/lib/routeColors'
import { EndMarker, StartMarker } from '../map/MapMarkers'
import { MapSearchControl, type SearchedPlace } from '../map/MapSearchControl'
import { FoundPlaceOverlay } from './FoundPlaceOverlay'
import { PedalonsMap } from '../map/PedalonsMap'
import { routeArrowLayout } from '../map/routeArrowLayout'

/** What a click on the map places: the start, the end, or nothing (it then selects a line). */
export type GeneratorClickMode = 'start' | 'end' | null

interface RouteGeneratorMapProps {
  start?: GeoPoint
  end?: GeoPoint
  candidates: GeneratedRouteDto[]
  selected: number
  hovered: number | null
  clickMode: GeneratorClickMode
  /** The end is « Ailleurs »: a found place can be the arrival too (the keyboard's way to place it). */
  endElsewhere?: boolean
  onPick: (mode: 'start' | 'end', point: GeoPoint) => void
  onCancelClickMode: () => void
  onSelect: (index: number) => void
  loading?: boolean
  /** The map's height (any CSS length). */
  height: string
}

const HIT_PREFIX = 'gen-hit-'
const ROUND = 1e5
const round5 = (n: number) => Math.round(n * ROUND) / ROUND

/**
 * The map of the generator: the start and the end (placed by a click), and up to three candidate
 * lines in the multi-route palette. The selected one is thicker and carries direction chevrons,
 * because which way a loop runs matters. Ledger `WEB-179`.
 */
export function RouteGeneratorMap({
  start,
  end,
  candidates,
  selected,
  hovered,
  clickMode,
  endElsewhere = false,
  onPick,
  onCancelClickMode,
  onSelect,
  loading = false,
  height,
}: RouteGeneratorMapProps) {
  const { t } = useTranslation()
  const colorScheme = useResolvedColorScheme()
  const defaultView = useDefaultMapView()
  const mapRef = useRef<MapRef>(null)
  const [foundPlace, setFoundPlace] = useState<SearchedPlace | null>(null)

  const lines = useMemo(
    () =>
      candidates.map<GeoJSON.Feature<GeoJSON.LineString>>((candidate) => ({
        type: 'Feature',
        properties: {},
        geometry: { type: 'LineString', coordinates: decode2(candidate.polyline) },
      })),
    [candidates]
  )

  // New candidates: frame all of them (the previous seed's stay where they were until then)
  useEffect(() => {
    if (candidates.length === 0) return
    const map = mapRef.current
    if (!map) return
    let minLon = Infinity
    let minLat = Infinity
    let maxLon = -Infinity
    let maxLat = -Infinity
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
  }, [candidates])

  const initialViewState = start
    ? { longitude: start.lng, latitude: start.lat, zoom: 11 }
    : (defaultView ?? undefined)

  const handleClick = (event: MapLayerMouseEvent) => {
    if (clickMode) {
      onPick(clickMode, { lat: round5(event.lngLat.lat), lng: round5(event.lngLat.lng) })
      return
    }
    const id = event.features?.[0]?.layer.id
    if (id?.startsWith(HIT_PREFIX)) onSelect(Number(id.slice(HIT_PREFIX.length)))
  }

  // The selected line is drawn last, over the others. MapLibre stacks layers in the order they
  // were added and react-maplibre does not reorder them, so the layers of every candidate stay
  // mounted (casing and chevrons hidden when not selected) and the selected candidate's are moved
  // to the top of the stack.
  useEffect(() => {
    const map = mapRef.current?.getMap()
    if (!map) return
    for (const id of [
      `gen-casing-${selected}`,
      `gen-line-${selected}`,
      `gen-arrows-${selected}`,
      `${HIT_PREFIX}${selected}`,
    ]) {
      if (map.getLayer(id)) map.moveLayer(id)
    }
  }, [selected, candidates])

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
      data-testid="route-generator-map"
    >
      {!initialViewState ? (
        <Skeleton h="100%" w="100%" radius={0} />
      ) : (
        <PedalonsMap
          ref={mapRef}
          initialViewState={initialViewState}
          cursor={clickMode ? 'crosshair' : 'grab'}
          interactiveLayerIds={lines.map((_, i) => `${HIT_PREFIX}${i}`)}
          onClick={handleClick}
        >
          <MapSearchControl onResultSelected={setFoundPlace} />
          {lines.map((_, i) => {
            const isSelected = i === selected
            const active = isSelected || i === hovered
            return (
              <Source key={i} id={`gen-${i}`} type="geojson" data={lines[i]}>
                <Layer
                  id={`gen-casing-${i}`}
                  type="line"
                  layout={{ 'line-cap': 'round', 'line-join': 'round' }}
                  paint={{
                    'line-color': '#ffffff',
                    'line-width': 7,
                    'line-opacity': isSelected ? 1 : 0,
                  }}
                />
                <Layer
                  id={`gen-line-${i}`}
                  type="line"
                  layout={{ 'line-cap': 'round', 'line-join': 'round' }}
                  paint={{
                    'line-color': routeColor(i),
                    'line-width': isSelected ? 5 : active ? 5 : 3,
                    'line-opacity': isSelected || active ? 1 : 0.75,
                  }}
                />
                <Layer
                  id={`gen-arrows-${i}`}
                  type="symbol"
                  layout={{ ...routeArrowLayout, visibility: isSelected ? 'visible' : 'none' }}
                />
                <Layer
                  id={`${HIT_PREFIX}${i}`}
                  type="line"
                  paint={{ 'line-color': routeColor(i), 'line-opacity': 0, 'line-width': 14 }}
                />
              </Source>
            )
          })}
          {start && <StartMarker longitude={start.lng} latitude={start.lat} />}
          {end && <EndMarker longitude={end.lng} latitude={end.lat} />}
        </PedalonsMap>
      )}

      {clickMode && (
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
          <Group gap="sm" wrap="nowrap">
            <Text size="sm">
              {clickMode === 'start'
                ? t('routeGenerator.start.clickHint')
                : t('routeGenerator.end.clickHint')}
            </Text>
            <Button size="compact-sm" variant="default" onClick={onCancelClickMode}>
              {t('actions.cancelAction')}
            </Button>
          </Group>
        </Paper>
      )}

      {foundPlace && !clickMode && (
        <FoundPlaceOverlay
          place={foundPlace}
          endElsewhere={endElsewhere}
          onPick={(mode, point) => {
            onPick(mode, { lat: round5(point.lat), lng: round5(point.lng) })
            setFoundPlace(null)
          }}
        />
      )}

      {loading && (
        <Box
          pos="absolute"
          top="50%"
          left="50%"
          style={{ transform: 'translate(-50%, -50%)', zIndex: 5 }}
        >
          <Loader />
        </Box>
      )}
    </Box>
  )
}
