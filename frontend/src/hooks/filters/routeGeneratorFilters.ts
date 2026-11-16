import { z } from 'zod'
import { CompassPoint, RouteGeneratorType } from '@/api/dto'
import { normalizePointParam } from '@/lib/routeGenerator'

/** Bounds of the wished distance, in km (the backend's own, `RouteGeneratorRequest`). */
export const GENERATOR_MIN_KM = 10
export const GENERATOR_MAX_KM = 200
export const GENERATOR_DEFAULT_KM = 50
export const GENERATOR_DEFAULT_DISCOVERY = 0.25

/** A point is a `"lat,lng"` string with 5 decimals; anything else is dropped. */
const pointField = z.string().transform(normalizePointParam).optional().catch(undefined)

/**
 * The generator page's state, in the query string (ledger `WEB-179`, D4: the start and the end are
 * written there, the team's location, the common case, never is). A malformed value falls back on
 * its default, never throws.
 */
export const routeGeneratorFiltersSchema = z.object({
  /** `"lat,lng"`; absent: the team's location. */
  start: pointField,
  /** `"lat,lng"`; absent: a loop. */
  end: pointField,
  bearing: z.enum(CompassPoint).optional().catch(undefined),
  distanceKm: z.coerce
    .number()
    .min(GENERATOR_MIN_KM)
    .max(GENERATOR_MAX_KM)
    .default(GENERATOR_DEFAULT_KM)
    .catch(GENERATOR_DEFAULT_KM),
  /** From the team's roads (0) to discovery (1), in quarters. */
  discovery: z.coerce
    .number()
    .min(0)
    .max(1)
    .transform((value) => Math.round(value * 4) / 4)
    .default(GENERATOR_DEFAULT_DISCOVERY)
    .catch(GENERATOR_DEFAULT_DISCOVERY),
  /** Absent: the dominant type of the team's routes. */
  type: z.enum(RouteGeneratorType).optional().catch(undefined),
  seed: z.coerce.number().int().min(0).default(0).catch(0),
  /** The candidate shown selected. */
  selected: z.coerce.number().int().min(0).max(2).default(0).catch(0),
  /** Set by « Générer »: nothing is requested until then. */
  go: z.stringbool().default(false).catch(false),
})

export type RouteGeneratorFilters = z.infer<typeof routeGeneratorFiltersSchema>

export const routeGeneratorFiltersAlias = {
  start: 's',
  end: 'e',
  bearing: 'cap',
  distanceKm: 'd',
  discovery: 'dec',
  type: 't',
  selected: 'sel',
} as const

/**
 * A change of a parameter drops the results instead of silently showing the ones of other
 * parameters: `go`, `seed` and `selected` go back to their defaults, as a list page resets `page`.
 */
export function generatorParamPatch(
  patch: Partial<RouteGeneratorFilters>
): Partial<RouteGeneratorFilters> {
  return { ...patch, go: false, seed: 0, selected: 0 }
}
