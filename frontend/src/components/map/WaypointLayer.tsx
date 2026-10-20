import { useEffect, useMemo } from 'react'
import { DEFAULT_THEME } from '@mantine/core'
import type { SymbolLayerSpecification } from 'maplibre-gl'
import { Layer, Popup, Source, useMap } from 'react-map-gl/maplibre'
import type { WaypointDto } from '@/api/dto'
import { waypointFeatures, type WaypointSelection } from '@/lib/waypoints'
import { WaypointDetails } from '../route/WaypointDetails'

export const WAYPOINT_HIT_LAYER = 'route-waypoints-hit'

/**
 * From this zoom on, a waypoint shows its name; below, only its pictogram, the name on hover. A
 * route can carry dozens of waypoints whose names overlap into an unreadable mass once zoomed out.
 */
export const WAYPOINT_LABEL_MIN_ZOOM = 12

/** A selection of at least this zoom when the list sends the map to a point. */
const LIST_SELECT_ZOOM = 13

const LABEL_LAYOUT: SymbolLayerSpecification['layout'] = {
  'icon-image': ['get', 'label'],
  'icon-anchor': 'left',
  'icon-offset': [15, 0],
  'symbol-sort-key': ['-', 0, ['get', 'priority']],
}

interface WaypointLayerProps {
  waypoints: readonly WaypointDto[]
  selection: WaypointSelection | null
  onSelect: (selection: WaypointSelection | null) => void
  /** Index (in `waypoints`) of the pictogram under the pointer. */
  hoveredIndex: number | null
  darkBasemap: boolean
}

/**
 * The author's waypoints as a `symbol` layer: one pictogram per type, the name beside it from zoom
 * 12 (an image, not a `text-field`: raster basemaps have no glyphs), a popup for the selected one.
 * The hit layer is the click target and the halo of the hovered or selected point; picking is up to
 * the map (`interactiveLayerIds`). No clustering — a danger must never be hidden — and no filter on
 * the coordinates (ledger WEB-108).
 */
export function WaypointLayer({
  waypoints,
  selection,
  onSelect,
  hoveredIndex,
  darkBasemap,
}: WaypointLayerProps) {
  const { current: mapRef } = useMap()
  const data = useMemo(() => waypointFeatures(waypoints, darkBasemap), [waypoints, darkBasemap])
  const selectedIndex = selection ? waypoints.indexOf(selection.waypoint) : -1
  const selected = selectedIndex >= 0 ? waypoints[selectedIndex] : null
  const hov = hoveredIndex ?? -1

  // Escape closes the popup (it does not take the focus, so the key goes to the page).
  useEffect(() => {
    if (!selected) return
    const onKey = (event: KeyboardEvent) => {
      // An Escape that closed a menu or a dialog over the map is not for the popup
      if (event.key !== 'Escape' || event.defaultPrevented) return
      const target = event.target instanceof Element ? event.target : null
      if (target?.closest('[role=dialog], [role=menu]')) return
      onSelect(null)
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [selected, onSelect])

  // Bring the map to a point picked elsewhere; a pick on the map itself moves nothing. Keyed on the
  // selection object, so picking the same point again from the list brings the map back to it.
  useEffect(() => {
    if (!mapRef || !selection || selection.from === 'map') return
    if (!waypoints.includes(selection.waypoint)) return
    const [lng, lat] = selection.waypoint.geometry.coordinates
    const map = mapRef.getMap()
    const reduced = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
    const duration = reduced ? 0 : undefined
    if (selection.from === 'list') {
      map.easeTo({ center: [lng, lat], zoom: Math.max(map.getZoom(), LIST_SELECT_ZOOM), duration })
    } else if (!map.getBounds().contains([lng, lat])) {
      map.easeTo({ center: [lng, lat], duration })
    }
  }, [mapRef, selection, waypoints])

  return (
    <>
      <Source id="route-waypoints" type="geojson" data={data}>
        <Layer
          id={WAYPOINT_HIT_LAYER}
          type="circle"
          paint={{
            'circle-radius': ['interpolate', ['linear'], ['zoom'], 8, 13, 12, 17],
            'circle-color': DEFAULT_THEME.colors.blue[6],
            'circle-opacity': [
              'case',
              ['==', ['id'], selectedIndex],
              0.35,
              ['==', ['id'], hov],
              0.2,
              0,
            ],
            'circle-stroke-color': '#fff',
            'circle-stroke-width': ['case', ['==', ['id'], selectedIndex], 2, 0],
          }}
        />
        <Layer
          id="route-waypoints"
          type="symbol"
          layout={{
            'icon-image': ['get', 'icon'],
            'icon-size': ['interpolate', ['linear'], ['zoom'], 8, 0.7, 12, 1],
            'icon-allow-overlap': true,
            'icon-ignore-placement': false,
            'symbol-sort-key': ['get', 'priority'],
          }}
        />
        <Layer
          id="route-waypoints-label"
          type="symbol"
          minzoom={WAYPOINT_LABEL_MIN_ZOOM}
          filter={[
            'all',
            ['!=', ['get', 'label'], ''],
            ['!=', ['id'], selectedIndex],
            ['!=', ['id'], hov],
          ]}
          layout={{ ...LABEL_LAYOUT, 'icon-allow-overlap': false }}
        />
        <Layer
          id="route-waypoints-label-hover"
          type="symbol"
          filter={[
            'all',
            ['!=', ['get', 'label'], ''],
            ['==', ['id'], hov],
            ['!=', ['id'], selectedIndex],
          ]}
          layout={{
            ...LABEL_LAYOUT,
            'icon-allow-overlap': true,
            'icon-ignore-placement': true,
          }}
        />
      </Source>

      {selected && (
        <Popup
          longitude={selected.geometry.coordinates[0]}
          latitude={selected.geometry.coordinates[1]}
          offset={16}
          closeOnClick={false}
          focusAfterOpen={false}
          maxWidth="280px"
          onClose={() => onSelect(null)}
        >
          <WaypointDetails waypoint={selected} />
        </Popup>
      )}
    </>
  )
}
