import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import Map, { Layer, Source } from 'react-map-gl/maplibre'
import * as maplibregl from 'maplibre-gl'
import '@/components/map/setupMaplibreWorker'
import { Box, Paper, Text } from '@mantine/core'
import { MapAttribution } from '@/components/map/MapAttribution'
import { useMapStyle } from '@/hooks/useMapStyle'
import type { AdDtoLocationGeometry } from '@/api/dto'

const MAP_HEIGHT = 200

/**
 * Radius of the sector, in metres.
 *
 * `AdDto.locationGeometry` is the centre of a cell about **1 km** across, so a 500 m radius is
 * the exact translation of that blur — neither caution nor approximation.
 */
const SECTOR_RADIUS_M = 500

/** Sector fill/stroke: the Mantine primary (indigo-5), which the map style never uses. */
const SECTOR_COLOR = '#4c6ef5'

/** Enough segments that the ring reads as a circle, not a polygon, at any zoom this map allows. */
const CIRCLE_SEGMENTS = 96

/** A GeoJSON polygon approximating the circle of `radius` metres around `[lon, lat]`. */
function circlePolygon(lon: number, lat: number, radius: number): GeoJSON.Feature<GeoJSON.Polygon> {
  // One degree of latitude is ~111.32 km everywhere; a degree of longitude shrinks with the
  // cosine of the latitude, which is why the ring is not a circle in degree space.
  const latRadius = radius / 111_320
  const lonRadius = radius / (111_320 * Math.cos((lat * Math.PI) / 180))
  const ring: [number, number][] = []
  for (let i = 0; i <= CIRCLE_SEGMENTS; i++) {
    const angle = (i / CIRCLE_SEGMENTS) * 2 * Math.PI
    ring.push([lon + lonRadius * Math.cos(angle), lat + latRadius * Math.sin(angle)])
  }
  return { type: 'Feature', properties: {}, geometry: { type: 'Polygon', coordinates: [ring] } }
}

export interface AdLocationMapProps {
  /** `AdDto.locationGeometry` — a GeoJSON point, `[longitude, latitude]`. */
  geometry: AdDtoLocationGeometry
}

/**
 * The approximate location of an ad.
 *
 * **A sector, never a pin.** A pin dropped on a cell centre would claim a precision the data does
 * not have: it would point at a crossroads when the ad is somewhere in the neighbourhood. The
 * rendering is therefore a translucent 500 m disc with no centre mark, framed on the disc's own
 * extent — never a high zoom that would suggest an address — and captioned in so many words.
 *
 * The block does not exist at all when `locationGeometry` is null: a map centred on a fallback
 * would be one more lie. That is the caller's check.
 */
export function AdLocationMap({ geometry }: AdLocationMapProps) {
  const { t } = useTranslation()
  const { style } = useMapStyle()

  const [lon, lat] = geometry.coordinates
  const circle = useMemo(() => circlePolygon(lon, lat, SECTOR_RADIUS_M), [lon, lat])

  // Framed on the circle's bounds with a small margin, so the sector fills the frame without the
  // viewport ever resolving finer than the blur.
  const bounds = useMemo(() => {
    const ring = circle.geometry.coordinates[0]
    const lons = ring.map((point) => point[0])
    const lats = ring.map((point) => point[1])
    return [
      [Math.min(...lons), Math.min(...lats)],
      [Math.max(...lons), Math.max(...lats)],
    ] as [[number, number], [number, number]]
  }, [circle])

  return (
    <Box>
      <Paper withBorder p={0} style={{ overflow: 'hidden' }}>
        <Box h={MAP_HEIGHT} role="img" aria-label={t('ads.detail.locationApproximate')}>
          <Map
            mapLib={maplibregl}
            mapStyle={style}
            // Same projection as the other maps whatever the style asks for (see PedalonsMap).
            projection="mercator"
            style={{ width: '100%', height: '100%' }}
            initialViewState={{ bounds, fitBoundsOptions: { padding: 24 } }}
            // The map illustrates, it is not explored: letting it be dragged would suggest the
            // address is in there somewhere.
            interactive={false}
            attributionControl={false}
          >
            {/* The map does not pan, but it still shows someone else's tiles: the credit is owed
                whatever the interaction model. Collapsed, at 200 px there is no room for the text. */}
            <MapAttribution compact />
            <Source id="ad-sector" type="geojson" data={circle}>
              <Layer
                id="ad-sector-fill"
                type="fill"
                paint={{ 'fill-color': SECTOR_COLOR, 'fill-opacity': 0.22 }}
              />
              <Layer
                id="ad-sector-outline"
                type="line"
                paint={{ 'line-color': SECTOR_COLOR, 'line-width': 1, 'line-opacity': 0.55 }}
              />
            </Source>
          </Map>
        </Box>
      </Paper>
      <Text size="xs" c="dimmed" mt={4}>
        {t('ads.detail.locationApproximate')}
      </Text>
    </Box>
  )
}
