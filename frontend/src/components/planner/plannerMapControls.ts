import { createContext, type ComponentType } from 'react'
import type { SearchedPlace } from '@/components/map/MapSearchControl'

/**
 * The two map controls of the planner that reach outside the page, as a host may replace them
 * (docs/LEDGER_*.md WEB-183). Each is rendered as a child of the map, where `useControl` works.
 */
export interface PlannerMapControls {
  /** The place search: calls back with the place picked, once the map shows it. */
  Search: ComponentType<{ onResultSelected?: (place: SearchedPlace) => void }>
  /** « Me localiser »: calls back with each position found, once the map shows it. */
  Locate: ComponentType<{ onLocated: (place: { lng: number; lat: number }) => void }>
}

/**
 * Null on the site, which keeps its own controls: `MapSearchControl` (Stadia Maps' search box,
 * called from the browser) and `LocateControl` (the browser's geolocation). The page the mobile
 * app embeds provides controls that go through the app instead: it is loaded from a file, with
 * no origin the search provider knows and no geolocation permission of its own.
 */
export const PlannerMapControlsContext = createContext<PlannerMapControls | null>(null)
