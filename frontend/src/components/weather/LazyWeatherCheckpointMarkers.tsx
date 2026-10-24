import { lazy } from 'react'

/**
 * The forecast's points on a route map (`WeatherCheckpointMarkers`), lazy as the map itself, whose
 * chunk it shares: they only show in the Météo mode. Render it under a `Suspense`.
 */
export const LazyWeatherCheckpointMarkers = lazy(() =>
  import('./WeatherCheckpointMarkers').then((m) => ({ default: m.WeatherCheckpointMarkers }))
)
