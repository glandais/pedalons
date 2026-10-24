import { Suspense, useMemo, useState, type ReactNode } from 'react'
import type { TrackDto, WeatherAttributionDto, WeatherLegDto } from '@/api/dto'
import type { ColorByOption } from '@/components/route/ColorByControl'
import type { PlannerColorBy } from '@/lib/plannerSurface'
import { hasSurfaces } from '@/lib/trackSurface'
import { attributionHtml } from '@/lib/weatherOnRoute'
import { LazyWeatherCheckpointMarkers as WeatherCheckpointMarkers } from '@/components/weather/LazyWeatherCheckpointMarkers'
import { useRouteWindColors } from './useRouteWindColors'

const NO_TRACKS: TrackDto[] = []

interface WindColorModeOptions {
  /** The tracks the map draws; undefined while the route loads. */
  tracks: TrackDto[] | undefined
  /**
   * The leg whose wind the Météo mode shows, only when the mode is on offer (a forecast, an event
   * neither finished nor cancelled, a stage not gone): the page decides. Without it, no Météo mode,
   * and a Météo choice reads as the grade.
   */
  leg: WeatherLegDto | undefined
  /** The forecast's credit, owed while the wind colours the line. */
  attribution?: WeatherAttributionDto
  /** The ride's or the stage's zone: the passages of the forecast's points read in it. */
  timezone?: string
  /** The checkpoint whose popup is open, when the page holds it (WEB-117); left out, the badges keep their own. */
  openIndex?: number | null
  onOpenChange?: (index: number | null) => void
}

/**
 * What colours one route's line on a detail page — the grade, the surface, or the wind of a leg
 * (ledger WEB-115/116, plan 2026-10-24-weather-on-map.md) —, held by the page and handed to its
 * `RouteMapView` (`mapProps`) and its `ColorModeControls`. One logic for a ride group's page, a solo
 * ride's and a trip stage's (WEB-118): the mode is exclusive, never the default, the profile stays
 * on the grade, and a leg losing its forecast (a refetch) falls back on the grade. The Météo mode
 * puts a badge at every forecast point and a drop where rain becomes likely, the km markers giving
 * way to them.
 */
export function useWindColorMode({
  tracks = NO_TRACKS,
  leg,
  attribution,
  timezone,
  openIndex,
  onOpenChange,
}: WindColorModeOptions) {
  const [chosen, setColorBy] = useState<ColorByOption>('grade')
  // The forecast gone, the choice reads as the grade.
  const colorBy: ColorByOption = chosen === 'wind' && !leg ? 'grade' : chosen
  const windLeg = colorBy === 'wind' ? leg : undefined
  const lineColorAt = useRouteWindColors(tracks, windLeg)
  const options = useMemo(() => {
    const modes: ColorByOption[] = ['grade']
    if (hasSurfaces(tracks)) modes.push('surface')
    if (leg) modes.push('wind')
    return modes
  }, [tracks, leg])
  const overlays: ReactNode = windLeg ? (
    <Suspense fallback={null}>
      <WeatherCheckpointMarkers
        tracks={tracks}
        leg={windLeg}
        timezone={timezone}
        openIndex={openIndex}
        onOpenChange={onOpenChange}
      />
    </Suspense>
  ) : undefined
  // The profile and the surface's own colouring know the grade and the surface only
  const plannerColorBy: PlannerColorBy = colorBy === 'surface' ? 'surface' : 'grade'

  return {
    colorBy,
    setColorBy,
    options,
    /** The leg the line is coloured by, in the Météo mode only. */
    windLeg,
    plannerColorBy,
    /** For `RouteMapView` / `RouteTrackMap`, beside `colorBy={plannerColorBy}`. */
    mapProps: {
      lineColorAt,
      lineAttribution: windLeg && attribution ? attributionHtml(attribution) : undefined,
      overlays,
      kmMarkers: !windLeg,
    },
  }
}

export type WindColorMode = ReturnType<typeof useWindColorMode>
