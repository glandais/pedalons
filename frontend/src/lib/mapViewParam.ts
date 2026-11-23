/**
 * The camera of an exploration map in its URL: `?map=<zoom>/<lat>/<lon>`, the shape OpenStreetMap
 * uses in its `#map=`. A query parameter rather than a fragment: the app's link resolver carries
 * the query of a map page over to the screen it opens (`appLocationFor`), and drops the fragment.
 *
 * The app reads the same parameter (`mobile/lib/core/pdl/map/map_view_param.dart`): change the
 * format in both, or links shared from the site stop opening where they were.
 */
export const MAP_VIEW_PARAM = 'map'

export interface MapViewParam {
  zoom: number
  latitude: number
  longitude: number
}

const MAX_ZOOM = 22
/** Web Mercator's limit: beyond it, no map can centre. */
const MAX_LATITUDE = 85.05

/** The parameter's camera, or `null` when it is missing or malformed — the map then frames as before. */
export function parseMapView(value: string | null | undefined): MapViewParam | null {
  if (!value) return null
  const parts = value.split('/')
  if (parts.length !== 3) return null
  const [zoom, latitude, longitude] = parts.map(Number)
  if (![zoom, latitude, longitude].every(Number.isFinite)) return null
  if (zoom < 0 || zoom > MAX_ZOOM) return null
  if (Math.abs(latitude) > MAX_LATITUDE || Math.abs(longitude) > 180) return null
  return { zoom, latitude, longitude }
}

/**
 * Coordinates rounded to what the zoom can show — about one pixel, as OpenStreetMap does — so the
 * URL does not carry fifteen decimals nobody can see.
 */
export function formatMapView({ zoom, latitude, longitude }: MapViewParam): string {
  const decimals = Math.min(6, Math.max(0, Math.ceil(Math.log10((2 ** zoom * 256) / 360))))
  const lon = ((((longitude + 180) % 360) + 360) % 360) - 180
  return `${zoom.toFixed(2).replace(/\.?0+$/, '')}/${latitude.toFixed(decimals)}/${lon.toFixed(decimals)}`
}
