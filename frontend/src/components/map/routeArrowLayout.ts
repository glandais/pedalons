import type { SymbolLayerSpecification } from 'maplibre-gl'

/** The chevron drawn along a trace to tell which way it runs, registered by `MapImages`. */
export const ROUTE_ARROW_IMAGE = 'pedalons-route-arrow'

/** Layout of a `symbol` layer that repeats the chevron along a line source. */
export const routeArrowLayout: SymbolLayerSpecification['layout'] = {
  'symbol-placement': 'line',
  'symbol-spacing': 90,
  'icon-image': ROUTE_ARROW_IMAGE,
  'icon-allow-overlap': true,
  'icon-ignore-placement': true,
  'icon-rotation-alignment': 'map',
}
