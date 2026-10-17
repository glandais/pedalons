import { useCallback, useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import { Layer, Popup, Source } from 'react-map-gl/maplibre'
import type { MapLayerMouseEvent } from 'react-map-gl/maplibre'
import { Anchor, Box, Group, Skeleton, Stack, Text } from '@mantine/core'
import type { BoundsDto } from '@/api/dto'
import { paths } from '@/config/paths'
import { useMapHeight } from '@/hooks/useResponsive'
import { useUnits } from '@/hooks/useUnits'
import { useDefaultMapView } from '@/hooks/useDefaultMapView'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'
import { PedalonsMap } from '../map/PedalonsMap'
import { MapSearchControl } from '../map/MapSearchControl'
import { routeArrowLayout } from '../map/routeArrowLayout'
import {
  ROUTES_FIT_OPTIONS,
  ROUTES_SOURCE_LAYER,
  ROUTE_LINE_COLOR,
  ROUTE_LINE_HOVER_COLOR,
} from '../map/mapConstants'

const SOURCE_ID = 'routes-tiles'
const LINES_LAYER = 'routes-lines'
/** Wide transparent copy of the lines: thin tracks are near impossible to click otherwise. */
const HIT_LAYER = 'routes-hit'

/** Feature properties encoded in the tile by ST_AsMVT (see `route_mvt_row`). */
interface RouteFeature {
  slug: string
  name: string
  team_slug: string
  distance: number | null
  elevation_gain: number | null
}

interface SelectedRoute extends RouteFeature {
  longitude: number
  latitude: number
}

const featureOf = (event: MapLayerMouseEvent): RouteFeature | null => {
  const properties = event.features?.[0]?.properties
  return properties ? (properties as unknown as RouteFeature) : null
}

export interface RoutesTileMapProps {
  tilesUrl: string
  /**
   * Extent to open on, once {@link boundsPending} is false. Read at mount only: refraiming under
   * the fingers of someone who is narrowing the filters would be disorienting.
   */
  bounds?: BoundsDto
  /**
   * True while the extent query is in flight. The map is held back until then — an absent `bounds`
   * otherwise can't be told apart from one that hasn't arrived, and opening on a guess is exactly
   * the flash this avoids.
   */
  boundsPending: boolean
}

export function RoutesTileMap({ tilesUrl, bounds, boundsPending }: RoutesTileMapProps) {
  const { distance, elevation } = useUnits()
  const colorScheme = useResolvedColorScheme()
  // A dedicated map page can afford more room than the maps embedded in detail pages.
  const mapHeight = useMapHeight('fullscreen')
  const defaultView = useDefaultMapView()

  const [hoveredSlug, setHoveredSlug] = useState<string | null>(null)
  const [selected, setSelected] = useState<SelectedRoute | null>(null)

  const tiles = useMemo(() => [tilesUrl], [tilesUrl])

  const handleMouseMove = useCallback((event: MapLayerMouseEvent) => {
    setHoveredSlug(featureOf(event)?.slug ?? null)
  }, [])

  const handleMouseLeave = useCallback(() => setHoveredSlug(null), [])

  const handleClick = useCallback((event: MapLayerMouseEvent) => {
    const feature = featureOf(event)
    setSelected(
      feature ? { ...feature, longitude: event.lngLat.lng, latitude: event.lngLat.lat } : null
    )
  }, [])

  // Read once, at mount: the map isn't rendered at all before this resolves.
  const initialViewState = useMemo(() => {
    if (bounds) {
      return {
        bounds: [
          [bounds.minLon, bounds.minLat],
          [bounds.maxLon, bounds.maxLat],
        ] as [[number, number], [number, number]],
        fitBoundsOptions: ROUTES_FIT_OPTIONS,
      }
    }
    return defaultView ?? undefined
  }, [bounds, defaultView])

  const container = (children: ReactNode) => (
    <Box
      pos="relative"
      w="100%"
      h={mapHeight}
      className={colorScheme === 'dark' ? 'dark' : undefined}
      style={{
        zIndex: 0,
        border: '1px solid var(--mantine-color-default-border)',
        borderRadius: 'var(--mantine-radius-sm)',
        overflow: 'hidden',
      }}
    >
      {children}
    </Box>
  )

  // Nothing to frame on yet. The placeholder is the map's own size, so the page doesn't jump.
  if (boundsPending || !initialViewState) {
    return container(<Skeleton h="100%" w="100%" radius={0} />)
  }

  return container(
    <PedalonsMap
      initialViewState={initialViewState}
      cursor={hoveredSlug ? 'pointer' : 'grab'}
      interactiveLayerIds={[HIT_LAYER]}
      onMouseMove={handleMouseMove}
      onMouseLeave={handleMouseLeave}
      onClick={handleClick}
    >
      <MapSearchControl />
      <Source id={SOURCE_ID} type="vector" tiles={tiles} minzoom={0} maxzoom={14}>
        <Layer
          id={LINES_LAYER}
          type="line"
          source-layer={ROUTES_SOURCE_LAYER}
          layout={{ 'line-cap': 'round', 'line-join': 'round' }}
          paint={{
            'line-color': [
              'case',
              ['==', ['get', 'slug'], hoveredSlug ?? ''],
              ROUTE_LINE_HOVER_COLOR,
              ROUTE_LINE_COLOR,
            ],
            'line-opacity': 0.75,
            'line-width': ['interpolate', ['linear'], ['zoom'], 5, 1, 10, 2.5, 14, 4],
          }}
        />
        {/* Direction chevrons on the route under the pointer (or whose popup is open) only:
            on every trace at once they would bury the map. */}
        <Layer
          id={`${LINES_LAYER}-arrows`}
          type="symbol"
          source-layer={ROUTES_SOURCE_LAYER}
          filter={['==', ['get', 'slug'], hoveredSlug ?? selected?.slug ?? '']}
          layout={routeArrowLayout}
        />
        <Layer
          id={HIT_LAYER}
          type="line"
          source-layer={ROUTES_SOURCE_LAYER}
          paint={{ 'line-color': ROUTE_LINE_COLOR, 'line-opacity': 0, 'line-width': 12 }}
        />
      </Source>

      {selected && (
        <Popup
          longitude={selected.longitude}
          latitude={selected.latitude}
          offset={12}
          closeOnClick={false}
          onClose={() => setSelected(null)}
        >
          <Stack gap={2}>
            <Anchor href={paths.route(selected.team_slug, selected.slug)} fw={600} size="sm">
              {selected.name}
            </Anchor>
            <Group gap="xs">
              {selected.distance !== null && (
                <Text size="xs" c="dimmed">
                  {distance(selected.distance)}
                </Text>
              )}
              {selected.elevation_gain !== null && (
                <Text size="xs" c="dimmed">
                  {elevation(selected.elevation_gain)}
                </Text>
              )}
            </Group>
          </Stack>
        </Popup>
      )}
    </PedalonsMap>
  )
}
