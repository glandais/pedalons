import { addProtocol } from 'maplibre-gl'
import type { ConfigDto, MapStyleDto } from '@/api/dto'
import type { BridgeMapStyle, PlannerLoad } from './bridge'

/**
 * The basemaps of the embedded planner. The site reads them from `GET /api/config` and lets
 * MapLibre fetch each style document; the page cannot (`/api/map/styles/*` sends no CORS header
 * and the page's origin is `null`), so the app hands the documents over as objects.
 *
 * Nothing changes for the map components: an object is registered under a URL of a protocol of
 * ours, which MapLibre resolves here instead of on the network, and the list goes into the query
 * cache where `useMapStyle` and `useDefaultMapView` read the config.
 */
const PROTOCOL = 'pedalons-style'

const documents = new Map<string, unknown>()
let registered = false

function register(): void {
  if (registered) return
  registered = true
  addProtocol(PROTOCOL, async (request) => {
    const key = decodeURIComponent(request.url.slice(`${PROTOCOL}://style/`.length))
    const document = documents.get(key)
    if (!document) throw new Error(`unknown basemap: ${key}`)
    return { data: document }
  })
}

function urlOf(key: string, document: unknown): string {
  documents.set(key, typeof document === 'string' ? JSON.parse(document) : document)
  return `${PROTOCOL}://style/${encodeURIComponent(key)}`
}

/** The served basemap list, each document handed over replaced by a URL MapLibre resolves here. */
export function toMapStyles(styles: readonly BridgeMapStyle[]): MapStyleDto[] {
  register()
  documents.clear()
  const served: MapStyleDto[] = []
  for (const { style, darkStyle, url, darkVariant, ...entry } of styles) {
    const light = style != null ? urlOf(entry.id, style) : url
    // Neither a document nor a URL: nothing to render
    if (!light) continue
    const dark = darkStyle != null ? urlOf(`${entry.id}:dark`, darkStyle) : darkVariant
    served.push({ ...entry, url: light, ...(dark && { darkVariant: dark }) })
  }
  return served
}

/**
 * What the map components read of `GET /api/config`: the basemaps, the relief source, and where a
 * map opens with nothing to frame. The rest of the config is not read by the planner.
 */
export function toMapConfig(load: PlannerLoad): ConfigDto {
  const [lng, lat] = load.teamLocation ?? []
  const defaultCenter =
    load.defaultCenter ??
    (lng !== undefined && lat !== undefined
      ? { lon: lng, lat, zoom: 11 }
      : // Metropolitan France: the app should send `defaultCenter`; a map somewhere beats none.
        { lon: 2.5, lat: 46.6, zoom: 5 })
  return {
    mapStyles: toMapStyles(load.styles),
    defaultCenter,
    ...(load.terrain && { terrain: load.terrain }),
  } as ConfigDto
}
