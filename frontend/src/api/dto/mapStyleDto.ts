/**
 * A basemap style the clients may offer
 */
export interface MapStyleDto {
  /** Stable style identifier, e.g. 'cycling' */
  id: string
  /** Human-readable label for the style switcher */
  label: string
  /** Section the switcher should list this style under — 'vector', 'satellite' or 'raster'. Clients group consecutive styles sharing a value and localise the heading themselves; an unknown value is rendered as its own section rather than dropped. */
  group: string
  /** URL of the MapLibre style document to load in light mode (or at all times when darkVariant is null). Either a third-party style document or, for a raster basemap the server wraps itself, a URL on /api/map/styles/{id}.json. */
  url: string
  /** URL of the style document to load instead of 'url' when the client renders in dark mode. Null when the style has no dark counterpart — the client then keeps using 'url'. */
  darkVariant?: string
  /** Credit the style document does not declare itself, to be displayed IN ADDITION to the attribution the map engine derives from that document — not instead of it. Null for a style that credits itself (most of them) and for a raster basemap, whose credit is already on the source of the wrapper served at /api/map/styles/{id}.json. Non-null only where the provider ships no attribution at all, which would otherwise render the basemap uncredited. */
  attribution?: string
}
