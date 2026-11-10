import { ScaleControl } from 'react-map-gl/maplibre'
import { usePreferencesStore } from '@/store/preferencesStore'

/**
 * MapLibre's scale bar, in the visitor's unit system (km/m or mi/ft) — the same preference as every
 * distance on the site. Switching it re-labels the bar on the maps already on screen
 * (`ScaleControl` calls `setUnit` when the prop changes).
 *
 * Bottom-left, the bottom line's other end from the attribution (bottom-right): on a finger the
 * bottom-right corner holds the control column. docs/LEDGER_*.md WEB-157.
 */
export function MapScale() {
  const unitSystem = usePreferencesStore((state) => state.unitSystem)
  return (
    <ScaleControl position="bottom-left" unit={unitSystem === 'IMPERIAL' ? 'imperial' : 'metric'} />
  )
}
