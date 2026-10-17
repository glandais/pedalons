import * as zod from 'zod'

/**
 * Returns at most 5 places matching the query, or an empty list when the query is shorter than 3 characters or the provider is unreachable. Results come from the Stadia Maps geocoder: a client displaying them must credit 'Stadia Maps, © OpenStreetMap contributors & others'.
 * @summary Search places by name
 */
export const SearchPlacesQueryParams = zod.object({
  q: zod.string().optional(),
})

export const SearchPlacesResponseItem = zod
  .object({
    id: zod.string().describe('Opaque identifier of the result, stable enough to key a list on'),
    displayName: zod.string().describe('Full human-readable name of the place'),
    lat: zod.number().describe('Latitude in degrees (WGS 84)'),
    lon: zod.number().describe('Longitude in degrees (WGS 84)'),
  })
  .describe('A place matching a geocoding query')
export const SearchPlacesResponse = zod.array(SearchPlacesResponseItem)
