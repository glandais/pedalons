/**
 * A page of a `when=UPCOMING_FIRST` list (API-185, RL15), cut into its two sections. The list is
 * one, paginated: « À venir » is its first `upcomingTotal` rows, « Plus tôt » the rest. A row at
 * index `i` of page `page` sits at `page * size + i`, so the cut on this page falls at
 * `upcomingTotal - page * size`, clamped to the page — a page wholly in one section has the other
 * empty, and a page that opens in the middle of a section starts with it.
 *
 * `size` is the size the page *asked for*: the server echoes it, not the one it applied after
 * capping.
 */
export interface UpcomingFirstPage<T> {
  upcoming: T[]
  earlier: T[]
}

export function splitUpcomingFirst<T>(
  items: readonly T[],
  { page, size, upcomingTotal }: { page: number; size: number; upcomingTotal: number }
): UpcomingFirstPage<T> {
  const cut = Math.max(0, Math.min(items.length, upcomingTotal - page * size))
  return { upcoming: items.slice(0, cut), earlier: items.slice(cut) }
}
