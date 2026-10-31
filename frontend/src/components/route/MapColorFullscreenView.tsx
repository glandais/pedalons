import { useUrlFilters } from '@/hooks/useUrlFilters'
import { mapColorFiltersAlias, mapColorFiltersSchema } from '@/hooks/filters/mapColorFilters'
import { RouteFullscreenView, type RouteFullscreenViewProps } from './RouteFullscreenView'

/**
 * A fullscreen route map whose colour mode lives in its URL (`?color=grade|surface|wind`,
 * `mapColorFilters.ts`, ledger WEB-117/118): the page that opens it passes its own mode, so a shared
 * link shows the same map. Without the parameter, the grade; a mode the map cannot offer — no
 * surface, no `windLeg` (no forecast, an event over or cancelled, a stage gone) — reads as the grade
 * (`RouteFullscreenView`). A switch here rewrites the URL in place.
 *
 * One wrapper for every fullscreen route map: a ride group's, a solo ride's and a trip stage's (with
 * the Météo mode), a route's and a GPX preview's. The back button returns the mode to the page.
 */
export function MapColorFullscreenView(
  props: Omit<RouteFullscreenViewProps, 'colorBy' | 'onColorByChange'>
) {
  const {
    filters: { colorBy },
    setFilters,
  } = useUrlFilters({ schema: mapColorFiltersSchema, alias: mapColorFiltersAlias })
  return (
    <RouteFullscreenView
      {...props}
      colorBy={colorBy}
      onColorByChange={(next) => setFilters({ colorBy: next })}
    />
  )
}
