import { useMemo } from 'react'
import { useMantineTheme } from '@mantine/core'
import type { RelativeWind, TrackDto, WeatherLegDto } from '@/api/dto'
import { NEUTRAL_COLOR } from '@/components/map/mapUtils'
import { windPhases } from '@/components/weather/windPhases'
import { pointWinds, relativeWindStrokeColors } from '@/lib/weatherOnRoute'

/**
 * The colour of the segment starting at a point (track index, point index in the track), from the
 * leg's wind stretches laid on `tracks` (their own chained measure, plan §3). A point no known
 * stretch covers gets the line's default colour (`NEUTRAL_COLOR`, the grade's off a climb): never
 * the grey of a cross wind, and never the grade's own colour either — in a climb that runs from
 * yellow to red through an orange a reader would take for a head wind.
 *
 * Pure, for a map drawing several legs at once (a trip's stages, ledger WEB-118), each on its own
 * route; a single route reads it through {@link useRouteWindColors}.
 */
export function windLineColorAt(
  tracks: Pick<TrackDto, 'line'>[],
  leg: WeatherLegDto,
  colors: Record<RelativeWind, string>
): (trackIndex: number, pointIndex: number) => string {
  const winds = pointWinds(tracks, windPhases(leg.segments, leg.checkpoints))
  return (trackIndex, pointIndex) => {
    const wind = winds[trackIndex]?.[pointIndex]
    return wind ? colors[wind] : NEUTRAL_COLOR
  }
}

/**
 * The wind colouring of a group's route line (ledger WEB-115): {@link windLineColorAt} for the
 * route's tracks. Undefined without a leg — the line then keeps its grade or surface.
 */
export function useRouteWindColors(tracks: TrackDto[], leg: WeatherLegDto | undefined) {
  const theme = useMantineTheme()
  const colors = useMemo(() => relativeWindStrokeColors(theme), [theme])
  return useMemo(
    () => (leg ? windLineColorAt(tracks, leg, colors) : undefined),
    [tracks, leg, colors]
  )
}
