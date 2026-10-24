import { useMemo } from 'react'
import { useMantineTheme } from '@mantine/core'
import type { TrackDto, WeatherLegDto } from '@/api/dto'
import { NEUTRAL_COLOR } from '@/components/map/mapUtils'
import { windPhases } from '@/components/weather/windPhases'
import { pointWinds, relativeWindStrokeColors } from '@/lib/weatherOnRoute'

/**
 * The wind colouring of a group's route line (ledger WEB-115): the colour of the segment starting
 * at a point (track index, point index in the track), from the leg's wind stretches. Undefined
 * without a leg — the line then keeps its grade or surface. A point no known stretch covers gets
 * the line's default colour (`NEUTRAL_COLOR`, the grade's off a climb): never the grey of a cross
 * wind, and never the grade's own colour either — in a climb that runs from yellow to red through
 * an orange a reader would take for a head wind.
 */
export function useRouteWindColors(tracks: TrackDto[], leg: WeatherLegDto | undefined) {
  const theme = useMantineTheme()
  const winds = useMemo(
    () => (leg ? pointWinds(tracks, windPhases(leg.segments, leg.checkpoints)) : null),
    [tracks, leg]
  )
  const colors = useMemo(() => relativeWindStrokeColors(theme), [theme])
  return useMemo(() => {
    if (!winds) return undefined
    return (trackIndex: number, pointIndex: number): string => {
      const wind = winds[trackIndex]?.[pointIndex]
      return wind ? colors[wind] : NEUTRAL_COLOR
    }
  }, [winds, colors])
}
