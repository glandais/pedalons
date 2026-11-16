/**
 * Stands in for `@/components/map/MapSearchControl` in the embedded planner's bundle
 * (`vite.mobile-planner.config.ts` aliases it, docs/LEDGER_*.md WEB-183). The site's search box is
 * `@stadiamaps/maplibre-search-box`, which calls Stadia Maps from the browser: the page searches
 * through the app instead (`BridgeSearchControl`, given to the planner by `PlannerMapControls`),
 * so the package — 52 KB of script — has no business in the app's assets.
 */
/** The site's type, restated: importing it from the real module would go through this alias. */
export interface SearchedPlace {
  lng: number
  lat: number
  label: string
}

/** Never rendered: the embed always provides its own search. */
export function MapSearchControl(): null {
  return null
}
