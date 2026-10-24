import type { RelativeWind, TrackDto } from '@/api/dto'
import { createGradientLineFeatures, NEUTRAL_COLOR } from '@/components/map/mapUtils'
import { windLineColorAt } from '@/hooks/useRouteWindColors'
import type { MapItemWind } from '@/lib/tripWeatherOnMap'

/**
 * One trace of a several-route map (`RoutesMapView`) in the Météo mode (a trip's overview, ledger
 * WEB-118): coloured by the wind of its own leg, laid on its own tracks — each stage's distances are
 * chained from its own start, never from the trip's —, a feature per stretch of one colour. A trace
 * without a wind forecast (a stage gone, not yet forecast, without weather) takes the line's default
 * colour, never its stage colour (one of them could read as a wind) nor the grey of a cross wind.
 */
export function windTraceLines(
  tracks: TrackDto[],
  wind: MapItemWind | undefined,
  colors: Record<RelativeWind, string>
): GeoJSON.FeatureCollection<GeoJSON.LineString> {
  return createGradientLineFeatures(
    tracks,
    wind ? windLineColorAt(tracks, wind.leg, colors) : () => NEUTRAL_COLOR
  )
}
