import type { RideDto, RideWeatherDto } from '@/api/dto'
import type { MapRouteItem } from '@/components/route/RoutesMapView'
import { routeColorsById } from '@/lib/routeColors'
import type { MapItemWind } from '@/lib/tripWeatherOnMap'
import { soloGroup } from '@/utils/soloGroup'
import { groupWindLeg } from './rideGroupData'

/**
 * The ride page's map: **one layer per distinct route**, never one per group. A group with no route
 * of its own rides the ride's (`group.routeSlug || ride.routeSlug`), and several groups on the same
 * route share one trace, one checkbox, one colour — the bar on each of their cards.
 *
 * Built here rather than in `RoutesMapView`, which stays one layer per item for the trip page (one
 * per stage).
 */
export interface RideMapRoutes {
  /** One item per distinct route: the ride's first when it has one, then in the groups' order. */
  items: MapRouteItem[]
  /** The item (route) each group rides; a group without any route has none. */
  itemIdByGroupId: Map<string, string>
  /** The colour of each group's trace, by group id — the same as its route's on the map. */
  colorByGroupId: Map<string, string>
}

/** A route's item id: its slug, so two groups on the same route land on the same item. */
export const routeItemId = (routeSlug: string) => `route-${routeSlug}`

/**
 * @param mainRouteLabel the name of the ride's own route when no group rides it
 *   (`rides.detail.mainRoute`); otherwise a layer is named after its groups, joined by « · ».
 */
export function rideMapRoutes(ride: RideDto | undefined, mainRouteLabel: string): RideMapRoutes {
  const itemIdByGroupId = new Map<string, string>()
  const groupNamesBySlug = new Map<string, string[]>()
  // Insertion order is the order of appearance, which numbers the colours.
  const slugs = new Set<string>()
  if (ride?.routeSlug) slugs.add(ride.routeSlug)
  for (const group of ride?.groups ?? []) {
    const slug = group.routeSlug || ride?.routeSlug
    if (!slug) continue
    slugs.add(slug)
    itemIdByGroupId.set(group.id, routeItemId(slug))
    groupNamesBySlug.set(slug, [...(groupNamesBySlug.get(slug) ?? []), group.name])
  }

  const items: MapRouteItem[] = Array.from(slugs, (slug) => ({
    id: routeItemId(slug),
    name: groupNamesBySlug.get(slug)?.join(' · ') ?? mainRouteLabel,
    routeSlug: slug,
  }))

  const colorByItemId = routeColorsById(items)
  const colorByGroupId = new Map<string, string>()
  for (const [groupId, itemId] of itemIdByGroupId) {
    const color = colorByItemId.get(itemId)
    if (color) colorByGroupId.set(groupId, color)
  }

  return { items, itemIdByGroupId, colorByGroupId }
}

/**
 * The Météo mode of the ride page's map of several routes (ledger WEB-178): the wind of **the
 * reader's group** — the one they are registered in, or a solo ride's only group — on the route it
 * rides, by map item id. One entry at most; empty when the reader has no group, when the group has
 * no route, or when its leg offers no wind (`groupWindLeg`, the group page's own rule) — the map
 * then has no Météo mode, each group keeping it on its own page.
 */
export function rideMapWinds(
  ride: RideDto | undefined,
  weather: RideWeatherDto | undefined,
  itemIdByGroupId: ReadonlyMap<string, string>
): Map<string, MapItemWind> {
  const winds = new Map<string, MapItemWind>()
  if (!ride) return winds
  const groupId = soloGroup(ride)?.id ?? ride.registeredGroupId
  const itemId = groupId ? itemIdByGroupId.get(groupId) : undefined
  if (!groupId || !itemId) return winds
  const leg = groupWindLeg(
    ride,
    weather?.legs.find((l) => l.groupId === groupId)
  )
  if (leg) winds.set(itemId, { leg, timezone: ride.timezone })
  return winds
}
