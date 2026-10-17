import * as zod from 'zod'

/**
 * Returns the place whose id a search result carried, with lat and lon always set. Call it only for the result the user picked, never for every suggestion: each call is billed by the provider. The id is a query parameter because it contains ':'. An id that is not shaped like a provider id, or that the provider does not know, is a 404 (NOT_FOUND); a provider failure or spent quota is a 503 (GEOCODING_UNAVAILABLE) — the client should then let the user search and pick again, or leave the position empty.
 * @summary Resolve the position of a picked place
 */
export const ResolvePlaceQueryParams = zod.object({
  id: zod.string().describe('The id of a search result, e.g. whosonfirst:locality:101750851'),
})

export const ResolvePlaceResponse = zod
  .object({
    id: zod
      .string()
      .describe(
        'Opaque identifier of the result, stable enough to key a list on; what GET /api/geocode/place takes to resolve the position'
      ),
    displayName: zod.string().describe('Full human-readable name of the place'),
    lat: zod
      .number()
      .optional()
      .describe(
        "Latitude in degrees (WGS 84). Null on a search suggestion the provider gave no position for: resolve it with GET /api/geocode/place once the user picks it. Always set in that endpoint's answer."
      ),
    lon: zod
      .number()
      .optional()
      .describe(
        'Longitude in degrees (WGS 84). Null exactly when lat is null: resolve it with GET /api/geocode/place once the user picks the suggestion.'
      ),
  })
  .describe('A place matching a geocoding query')

/**
 * Returns at most 5 places matching the query, or an empty list when the query is shorter than 3 characters or the provider is unreachable. A result's lat and lon are null when the provider gave no position for it (the usual case): once the user picks it, resolve its position with GET /api/geocode/place?id=. Never resolve every suggestion: each resolution is billed. Results come from the Stadia Maps geocoder: a client displaying them must credit 'Stadia Maps, © OpenStreetMap contributors & others'.
 * @summary Search places by name
 */
export const SearchPlacesQueryParams = zod.object({
  q: zod.string().optional(),
})

export const SearchPlacesResponseItem = zod
  .object({
    id: zod
      .string()
      .describe(
        'Opaque identifier of the result, stable enough to key a list on; what GET /api/geocode/place takes to resolve the position'
      ),
    displayName: zod.string().describe('Full human-readable name of the place'),
    lat: zod
      .number()
      .optional()
      .describe(
        "Latitude in degrees (WGS 84). Null on a search suggestion the provider gave no position for: resolve it with GET /api/geocode/place once the user picks it. Always set in that endpoint's answer."
      ),
    lon: zod
      .number()
      .optional()
      .describe(
        'Longitude in degrees (WGS 84). Null exactly when lat is null: resolve it with GET /api/geocode/place once the user picks the suggestion.'
      ),
  })
  .describe('A place matching a geocoding query')
export const SearchPlacesResponse = zod.array(SearchPlacesResponseItem)
