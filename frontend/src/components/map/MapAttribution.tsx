import { AttributionControl } from 'react-map-gl/maplibre'
import { useMapStyle } from '@/hooks/useMapStyle'

interface MapAttributionProps {
  /**
   * Force the collapsed ⓘ button. Leave unset on a full-size map, where MapLibre already collapses
   * on narrow viewports and shows the text where there is room for it.
   */
  compact?: boolean
}

/**
 * The credit line every map owes its tile providers.
 *
 * Wraps MapLibre's own control for one reason: `MapStyleDto.attribution` — the credit a provider
 * ships *no* attribution for, IGN's `PLAN.IGN` being the case that exists — has to be passed as
 * `customAttribution`, and MapLibre only reads that when the control is constructed. Hence the
 * `key`: changing basemap rebuilds the control instead of leaving the previous provider credited.
 * Everything else (OpenStreetMap, CyclOSM, Esri, Géoportail, VersaTiles, the Mapterhorn DEM) comes
 * from the style document itself and needs nothing from us.
 *
 * A map that renders third-party tiles renders this. It is not a detail of taste: ODbL, Esri's terms
 * and IGN's all require the credit to be visible next to the tiles they apply to. The one exception
 * is an inset drawn over a map that already credits the same tiles (the planner's precision mini-map).
 */
export function MapAttribution({ compact }: MapAttributionProps) {
  const { currentStyle } = useMapStyle()
  const custom = currentStyle?.attribution ?? undefined

  return (
    <AttributionControl
      key={custom ?? 'style-credits-itself'}
      customAttribution={custom}
      compact={compact}
    />
  )
}
