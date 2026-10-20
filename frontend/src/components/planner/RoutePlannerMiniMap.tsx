import { useTranslation } from 'react-i18next'
import { useRef, useEffect, useState, useCallback } from 'react'
import Map, { Source, Layer } from 'react-map-gl/maplibre'
import * as maplibregl from 'maplibre-gl'
import '@/components/map/setupMaplibreWorker'
import type { MapRef } from 'react-map-gl/maplibre'
import { ActionIcon, Box, Stack } from '@mantine/core'
import { IconPlus, IconMinus } from '@tabler/icons-react'
import { RouteArrowImage } from '@/components/map/RouteArrows'
import { routeArrowLayout } from '@/components/map/routeArrowLayout'
import { useMapStyle } from '@/hooks/useMapStyle'

const DEFAULT_ZOOM = 15
const MIN_ZOOM = 1
const MAX_ZOOM = 22

interface RoutePlannerMiniMapProps {
  center: { lng: number; lat: number }
  routeGeoJson: GeoJSON.LineString | null
}

export function RoutePlannerMiniMap({ center, routeGeoJson }: RoutePlannerMiniMapProps) {
  const { t } = useTranslation()
  const mapRef = useRef<MapRef>(null)
  const { style } = useMapStyle()
  const [zoom, setZoom] = useState(DEFAULT_ZOOM)

  useEffect(() => {
    mapRef.current?.jumpTo({ center: [center.lng, center.lat] })
  }, [center])

  const zoomIn = useCallback(() => {
    setZoom((z) => {
      const next = Math.min(z + 1, MAX_ZOOM)
      mapRef.current?.zoomTo(next, { duration: 150 })
      return next
    })
  }, [])

  const zoomOut = useCallback(() => {
    setZoom((z) => {
      const next = Math.max(z - 1, MIN_ZOOM)
      mapRef.current?.zoomTo(next, { duration: 150 })
      return next
    })
  }, [])

  return (
    <Box
      pos="absolute"
      bottom={48}
      right={16}
      w={200}
      h={200}
      style={{
        zIndex: 5,
        borderRadius: 'var(--mantine-radius-md)',
        overflow: 'hidden',
        border: '2px solid var(--mantine-color-default-border)',
        boxShadow: 'var(--mantine-shadow-lg)',
        pointerEvents: 'none',
      }}
    >
      <Map
        ref={mapRef}
        mapLib={maplibregl}
        mapStyle={style}
        // Same projection as the main map whatever the style asks for (see PedalonsMap).
        projection="mercator"
        style={{ width: '100%', height: '100%' }}
        initialViewState={{ longitude: center.lng, latitude: center.lat, zoom: DEFAULT_ZOOM }}
        interactive={false}
        attributionControl={false}
      >
        {/* No attribution here: the inset sits on top of the planner's main map, which shows the
            same tiles and already credits them. */}
        <RouteArrowImage />
        {routeGeoJson && (
          <Source id="mini-route" type="geojson" data={routeGeoJson}>
            <Layer
              id="mini-route-line"
              type="line"
              paint={{ 'line-color': '#4F46E5', 'line-width': 3, 'line-opacity': 0.8 }}
            />
            <Layer id="mini-route-arrows" type="symbol" layout={routeArrowLayout} />
          </Source>
        )}
      </Map>

      {/* Crosshair */}
      <Box
        pos="absolute"
        top="50%"
        left={0}
        right={0}
        h={1}
        bg="rgba(0,0,0,0.5)"
        style={{ transform: 'translateY(-50%)', pointerEvents: 'none' }}
      />
      <Box
        pos="absolute"
        left="50%"
        top={0}
        bottom={0}
        w={1}
        bg="rgba(0,0,0,0.5)"
        style={{ transform: 'translateX(-50%)', pointerEvents: 'none' }}
      />

      {/* Zoom controls */}
      <Stack pos="absolute" top={8} right={8} gap={2} style={{ pointerEvents: 'auto' }}>
        <ActionIcon
          size="xs"
          variant="white"
          onClick={zoomIn}
          aria-label={t('map.zoomIn')}
          disabled={zoom >= MAX_ZOOM}
          style={{ boxShadow: 'var(--mantine-shadow-xs)' }}
        >
          <IconPlus size={10} />
        </ActionIcon>
        <ActionIcon
          size="xs"
          variant="white"
          onClick={zoomOut}
          aria-label={t('map.zoomOut')}
          disabled={zoom <= MIN_ZOOM}
          style={{ boxShadow: 'var(--mantine-shadow-xs)' }}
        >
          <IconMinus size={10} />
        </ActionIcon>
      </Stack>
    </Box>
  )
}
