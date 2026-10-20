import { useMemo } from 'react'
import { useMantineTheme } from '@mantine/core'
import type { TrackDto } from '@/api/dto'
import { pointSurfaces, trackSurfaceColors } from '@/lib/trackSurface'
import type { PlannerColorBy } from '@/lib/plannerSurface'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'
import { useMapStyle } from '@/hooks/useMapStyle'

/**
 * The surface colouring of a saved route's profile and line (WEB-100 C1b), shared by the embedded
 * map and the fullscreen viewer. Both are undefined unless `colorBy` is `surface` and the route has
 * its surface: the profile and the line then keep the grade.
 */
export function useRouteSurfaceColors(tracks: TrackDto[], colorBy: PlannerColorBy) {
  const theme = useMantineTheme()
  const colorScheme = useResolvedColorScheme()
  const { darkBasemap } = useMapStyle()

  // Class of every point of the flattened tracks, null while the route has no surface.
  const surfaces = useMemo(
    () => (colorBy === 'surface' ? pointSurfaces(tracks) : null),
    [colorBy, tracks]
  )
  // The profile is drawn on the page, so by the theme; the line over the basemap, by its tone (a
  // light basemap kept in dark mode, a satellite), as in the editor.
  const chartColors = useMemo(() => trackSurfaceColors(theme, colorScheme), [theme, colorScheme])
  const lineColors = useMemo(
    () => trackSurfaceColors(theme, darkBasemap ? 'dark' : 'light'),
    [theme, darkBasemap]
  )
  const surfaceAt = useMemo(
    () => (surfaces ? (i: number) => chartColors[surfaces[i]] : undefined),
    [surfaces, chartColors]
  )
  // The map asks per track: the flat index is the size of the tracks before it plus the point's.
  const lineColorAt = useMemo(() => {
    if (!surfaces) return undefined
    const offsets: number[] = []
    let offset = 0
    for (const track of tracks) {
      offsets.push(offset)
      offset += track.line.coordinates.length
    }
    return (trackIndex: number, pointIndex: number) =>
      lineColors[surfaces[offsets[trackIndex] + pointIndex]]
  }, [surfaces, lineColors, tracks])

  return { surfaceAt, lineColorAt }
}
