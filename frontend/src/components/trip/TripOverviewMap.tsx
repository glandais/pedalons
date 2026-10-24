import { lazy, Suspense, useMemo, useState } from 'react'
import { Skeleton, Stack } from '@mantine/core'
import type { TripDto, TripWeatherDto } from '@/api/dto'
import { ErrorBoundary } from '@/components/common/ErrorBoundary'
import { ColorByControl } from '@/components/route/ColorByControl'
import type { MapRouteItem } from '@/components/route/RoutesMapView'
import { WindMapLegend } from '@/components/weather/WindMapLegend'
import { combinedWindLegend, tripMapWinds } from '@/lib/tripWeatherOnMap'

// Lazy load the map component (pulls in map-vendor ~1MB and chart-vendor ~150KB)
const RoutesMapView = lazy(() =>
  import('@/components/route/RoutesMapView').then((m) => ({ default: m.RoutesMapView }))
)

/**
 * What colours the overview map's traces: one colour per stage (the default), or the wind of each
 * stage (ledger WEB-118). The overview's own, as `GroupColorBy` is the group's.
 */
export type TripMapMode = 'stages' | 'wind'

/**
 * A trip's overview map — its own route, or every stage's — and, with a forecast, its Météo mode
 * (ledger WEB-118, plan 2026-10-24-weather-on-map.md §5 palier 3 lot B): every stage with a wind
 * forecast coloured by its own wind, at its own day, its badges read in its own zone
 * (`tripMapWinds`), under a « Étapes | Météo » switch and one legend for the stages taken together
 * (`combinedWindLegend`: their shares add up). Never the default; on offer only when a stage has a
 * forecast — not on a trip over or cancelled, not for a stage gone —, and a refetch losing them
 * falls back on the stages.
 */
export function TripOverviewMap({
  trip,
  items,
  teamSlug,
  weather,
  highlightedItemId,
  onItemHover,
}: {
  trip: TripDto
  /** One per trace, stable across hovers (the map would refetch and refit on a new array). */
  items: MapRouteItem[]
  teamSlug: string
  /** `GET …/trips/{tripSlug}/weather`, the page's own read. */
  weather: TripWeatherDto | undefined
  highlightedItemId: string | null
  onItemHover: (itemId: string | null) => void
}) {
  const [chosenMode, setMode] = useState<TripMapMode>('stages')
  const winds = useMemo(() => tripMapWinds(trip, weather), [trip, weather])
  const legend = useMemo(() => combinedWindLegend([...winds.values()].map((w) => w.leg)), [winds])
  const mode: TripMapMode = chosenMode === 'wind' && legend ? 'wind' : 'stages'

  return (
    <Stack gap="xs">
      <ErrorBoundary variant="inline">
        <Suspense fallback={<Skeleton height={500} radius="md" />}>
          <RoutesMapView
            items={items}
            teamSlug={teamSlug}
            highlightedItemId={highlightedItemId}
            onItemHover={onItemHover}
            winds={mode === 'wind' ? winds : undefined}
            windAttribution={mode === 'wind' ? weather?.attribution : undefined}
          />
        </Suspense>
      </ErrorBoundary>
      <ColorByControl
        value={mode}
        onChange={setMode}
        options={legend ? ['stages', 'wind'] : ['stages']}
        testId="trip-map-mode"
      />
      {mode === 'wind' && legend && (
        <WindMapLegend
          leg={legend}
          // A trip on its own route has no stage: its single leg
          subject={trip.routeSlug ? 'stage' : 'trip'}
          attribution={weather?.attribution}
        />
      )}
    </Stack>
  )
}
