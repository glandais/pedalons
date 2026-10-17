/**
 * A place matching a geocoding query
 */
export interface GeocodeResultDto {
  /** Opaque identifier of the result, stable enough to key a list on; what GET /api/geocode/place takes to resolve the position */
  id: string
  /** Full human-readable name of the place */
  displayName: string
  /** Latitude in degrees (WGS 84). Null on a search suggestion the provider gave no position for: resolve it with GET /api/geocode/place once the user picks it. Always set in that endpoint's answer. */
  lat?: number
  /** Longitude in degrees (WGS 84). Null exactly when lat is null: resolve it with GET /api/geocode/place once the user picks the suggestion. */
  lon?: number
}
