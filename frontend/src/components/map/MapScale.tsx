import { ScaleControl } from 'react-map-gl/maplibre'
import { usePreferencesStore } from '@/store/preferencesStore'

/**
 * MapLibre's scale bar, in the visitor's unit system (km/m or mi/ft) — the same preference as every
 * distance on the site. Switching it re-labels the bar on the maps already on screen
 * (`ScaleControl` calls `setUnit` when the prop changes).
 *
 * Bottom-right, above the attribution (index.css keeps it there): bottom-left is where the
 * elevation profile overlays the route maps, and the control column is top-left.
 */
export function MapScale() {
  const unitSystem = usePreferencesStore((state) => state.unitSystem)
  return (
    <ScaleControl
      position="bottom-right"
      unit={unitSystem === 'IMPERIAL' ? 'imperial' : 'metric'}
    />
  )
}
