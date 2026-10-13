/**
 * Multi-route palette (matching biketeam, and the mobile `kMultiTrackPalette`).
 *
 * A trace's colour is its index among the map items that **have** a route: the ride page's map and
 * its group cards both go through `routeColorsById`, so the bar in front of a group's name is the
 * colour of its trace — computing it from `sortOrder` would drift as soon as the ride has a main
 * route or a group has none.
 */
export const ROUTE_COLORS = [
  '#566B13',
  '#1d32a8',
  '#732C7B',
  '#bdbd22',
  '#c90808',
  '#b81491',
  '#628de3',
  '#6dcc5c',
  '#c694d4',
  '#e3a209',
] as const

export function routeColor(index: number): string {
  return ROUTE_COLORS[index % ROUTE_COLORS.length]
}

/** The colour of each item's trace on the map, by item id; an item with no route has none. */
export function routeColorsById(items: { id: string; routeSlug?: string }[]): Map<string, string> {
  const colors = new Map<string, string>()
  items.filter((item) => item.routeSlug).forEach((item, i) => colors.set(item.id, routeColor(i)))
  return colors
}
