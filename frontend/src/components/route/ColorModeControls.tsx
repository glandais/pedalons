import { Stack } from '@mantine/core'
import type { TrackDto, WeatherAttributionDto } from '@/api/dto'
import type { WindColorMode } from '@/hooks/useWindColorMode'
import { WindMapLegend, type WindLegendSubject } from '@/components/weather/WindMapLegend'
import { ColorByControl } from './ColorByControl'
import { RouteSurfaceSummary } from './RouteSurfaceSummary'

/**
 * Under a route's map, what its line is coloured by (`useWindColorMode`): the switch « Pente |
 * Revêtement | Météo » (drawn only with two modes or more), the wind's legend and the forecast's
 * credit in the Météo mode, then the surface's breakdown — a group's page, a solo ride's, a trip
 * stage's (ledger WEB-115, WEB-118).
 */
export function ColorModeControls({
  mode,
  tracks,
  attribution,
  subject,
}: {
  mode: WindColorMode
  tracks: TrackDto[]
  /** The forecast's credit, repeated under the map: the profile overlay can cover the map's own. */
  attribution?: WeatherAttributionDto
  /** Whose speed the legend speaks of when the passages assume the default one. */
  subject?: WindLegendSubject
}) {
  return (
    <Stack gap="xs">
      <ColorByControl value={mode.colorBy} onChange={mode.setColorBy} options={mode.options} />
      {mode.windLeg && (
        <WindMapLegend leg={mode.windLeg} subject={subject} attribution={attribution} />
      )}
      <RouteSurfaceSummary
        tracks={tracks}
        colorBy={mode.plannerColorBy}
        onColorByChange={mode.setColorBy}
        withControl={false}
      />
    </Stack>
  )
}
