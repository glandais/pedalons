import { useCallback, useEffect, useRef, useState } from 'react'
import { useLocation, useSearchParams } from 'react-router-dom'
import type { ViewStateChangeEvent } from 'react-map-gl/maplibre'
import { MAP_VIEW_PARAM, formatMapView, parseMapView, type MapViewParam } from '@/lib/mapViewParam'

/** Rewrites `?map=` on the current history entry, leaving the path and every other parameter alone. */
function writeMapView(value: string) {
  const { pathname, search, hash } = window.location
  const params = new URLSearchParams(search)
  if (params.get(MAP_VIEW_PARAM) === value) return
  params.delete(MAP_VIEW_PARAM)
  // Written by hand rather than through `URLSearchParams`, which would escape the slashes
  // (`12%2F45.2%2F5.7`): the value is digits, `.`, `-` and `/`, all legal in a query as they are.
  const others = params.toString()
  const query = `?${others ? `${others}&` : ''}${MAP_VIEW_PARAM}=${value}`
  window.history.replaceState(window.history.state, '', `${pathname}${query}${hash}`)
}

/**
 * Keeps an exploration map's camera in the URL (`?map=z/lat/lon`, see {@link MAP_VIEW_PARAM}),
 * so a reload, a Back from a route opened from the map, or a shared link lands where the map was.
 *
 * `initialView` is read once, at mount: it is where the map opens, ahead of its usual framing.
 * `onMoveEnd` goes on the map.
 *
 * The write goes **around React Router**, straight to `history.replaceState`: one navigation per
 * pan would re-run the route's prefetch and re-render the page for a value nothing renders. Two
 * consequences, both handled here:
 * - `window.location.pathname` is the browser's path, which on a pinned host is not the router's
 *   (`pinnedHistory.ts`) — kept as it is, never rebuilt from `useLocation`;
 * - the router does not know the parameter, so a navigation that rebuilds the query string (a
 *   filter, through `useUrlFilters`) drops it: it is written back after each one.
 *
 * Never a new history entry: moving the map is not a step Back should undo.
 */
export function useMapViewParam(): {
  initialView: MapViewParam | null
  onMoveEnd: (event: ViewStateChangeEvent) => void
} {
  const [searchParams] = useSearchParams()
  const [initialView] = useState(() => parseMapView(searchParams.get(MAP_VIEW_PARAM)))
  const lastRef = useRef<string | null>(initialView ? formatMapView(initialView) : null)

  const { search } = useLocation()
  useEffect(() => {
    if (lastRef.current) writeMapView(lastRef.current)
  }, [search])

  const onMoveEnd = useCallback((event: ViewStateChangeEvent) => {
    const { zoom, latitude, longitude } = event.viewState
    const value = formatMapView({ zoom, latitude, longitude })
    lastRef.current = value
    writeMapView(value)
  }, [])

  return { initialView, onMoveEnd }
}
