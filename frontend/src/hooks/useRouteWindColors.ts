import { useMemo } from 'react'
import { useMantineTheme } from '@mantine/core'
import type { RelativeWind, TrackDto, WeatherLegDto } from '@/api/dto'
import { NEUTRAL_COLOR } from '@/components/map/mapUtils'
import type { ProfileWind } from '@/components/route/windBand'
import { windPhases } from '@/components/weather/windPhases'
import { pointWinds, relativeWindStrokeColors } from '@/lib/weatherOnRoute'

type Winds = (RelativeWind | undefined)[][]

function colorOf(winds: Winds, colors: Record<RelativeWind, string>) {
  return (trackIndex: number, pointIndex: number) => {
    const wind = winds[trackIndex]?.[pointIndex]
    return wind ? colors[wind] : NEUTRAL_COLOR
  }
}

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
  return colorOf(pointWinds(tracks, windPhases(leg.segments, leg.checkpoints)), colors)
}

/**
 * The wind of one route, measured once for its line and its profile (ledger WEB-129): the line's
 * colour per (track, point), and the profile's band — the wind of every point of the tracks laid
 * one after the other, the profile's own indexing, so the band sits on the profile's points
 * whatever its axis does between two tracks.
 */
export function routeWind(
  tracks: Pick<TrackDto, 'line'>[],
  leg: WeatherLegDto,
  colors: Record<RelativeWind, string>
): { lineColorAt: (trackIndex: number, pointIndex: number) => string; profileWind: ProfileWind } {
  const winds = pointWinds(tracks, windPhases(leg.segments, leg.checkpoints))
  return { lineColorAt: colorOf(winds, colors), profileWind: { winds: winds.flat(), colors } }
}

/**
 * The wind colouring of a route's line (ledger WEB-115) and the band under its profile (WEB-129),
 * from {@link routeWind}. Both undefined without a leg — the line then keeps its grade or surface,
 * the profile its grade without a band.
 */
export function useRouteWindColors(tracks: TrackDto[], leg: WeatherLegDto | undefined) {
  const theme = useMantineTheme()
  const colors = useMemo(() => relativeWindStrokeColors(theme), [theme])
  const wind = useMemo(
    () => (leg ? routeWind(tracks, leg, colors) : undefined),
    [tracks, leg, colors]
  )
  return { lineColorAt: wind?.lineColorAt, profileWind: wind?.profileWind }
}
