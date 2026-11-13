import { lazy, Suspense, useState } from 'react'
import { Skeleton, Stack } from '@mantine/core'
import type { WeatherAttributionDto } from '@/api/dto'
import { ErrorBoundary } from '@/components/common/ErrorBoundary'
import { ColorByControl } from '@/components/route/ColorByControl'
import type { MapRouteItem } from '@/components/route/RoutesMapView'
import { WindMapLegend } from '@/components/weather/WindMapLegend'
import type { MapItemWind } from '@/lib/tripWeatherOnMap'

// Lazy load the map component (pulls in map-vendor ~1MB and chart-vendor ~150KB)
const RoutesMapView = lazy(() =>
  import('@/components/route/RoutesMapView').then((m) => ({ default: m.RoutesMapView }))
)

/**
 * What colours the traces of a ride's map of several routes: one colour per route (the default), or
 * the wind on the reader's group's route. The map's own, as `TripMapMode` is the trip overview's.
 */
export type RideMapMode = 'routes' | 'wind'

/**
 * A ride's map of several routes — one trace per distinct route (`rideMapRoutes`) — and, for a
 * reader registered in a group whose leg has a forecast, its Météo mode (ledger WEB-178): **that
 * group's** route coloured by its wind, with its badges, under a « Parcours | Météo » switch and the
 * wind's legend; the other routes keep their colour. Never the default; a reader registered
 * nowhere has no switch — each group has the mode on its own page —, and a refetch losing the
 * forecast falls back on the routes' colours. Choosing Météo selects the group's route, so the
 * profile beside the map is the one the wind is laid on.
 */
export function RideOverviewMap({
  items,
  teamSlug,
  winds,
  attribution,
  highlightedItemId,
  onItemHover,
  selectedItemId,
  onItemSelect,
}: {
  /** One per distinct route, stable across hovers (the map would refetch and refit on a new array). */
  items: MapRouteItem[]
  teamSlug: string
  /**
   * The wind of the reader's group's route, by map item id (`rideMapWinds`, stable while the
   * forecast is); empty: no Météo mode.
   */
  winds: ReadonlyMap<string, MapItemWind>
  /** The forecast's credit, owed while the wind colours a trace. */
  attribution?: WeatherAttributionDto
  highlightedItemId: string | null
  onItemHover: (itemId: string | null) => void
  selectedItemId: string | null
  onItemSelect: (itemId: string) => void
}) {
  const [chosenMode, setChosenMode] = useState<RideMapMode>('routes')
  // The one route the wind is laid on: the reader's group's.
  const [windItemId, wind] = [...winds][0] ?? []
  const mode: RideMapMode = chosenMode === 'wind' && wind ? 'wind' : 'routes'
  const windOn = mode === 'wind'
  const setMode = (next: RideMapMode) => {
    setChosenMode(next)
    if (next === 'wind' && windItemId) onItemSelect(windItemId)
  }

  return (
    <Stack gap="xs">
      <ErrorBoundary variant="inline">
        <Suspense fallback={<Skeleton height="var(--detail-map-height, 500px)" radius="md" />}>
          <RoutesMapView
            variant="sticky"
            items={items}
            teamSlug={teamSlug}
            highlightedItemId={highlightedItemId}
            onItemHover={onItemHover}
            selectedItemId={selectedItemId}
            onItemSelect={onItemSelect}
            winds={windOn ? winds : undefined}
            windAttribution={windOn ? attribution : undefined}
            // A single trace's only; the Météo mode's badges take their place (WEB-146)
            kmMarkers={items.length === 1 && !windOn}
          />
        </Suspense>
      </ErrorBoundary>
      <ColorByControl
        value={mode}
        onChange={setMode}
        options={wind ? ['routes', 'wind'] : ['routes']}
        testId="ride-map-mode"
      />
      {windOn && wind && <WindMapLegend leg={wind.leg} subject="group" attribution={attribution} />}
    </Stack>
  )
}
