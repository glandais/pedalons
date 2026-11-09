import { useState } from 'react'
import type { WeatherLegDto } from '@/api/dto'
import type { RouteWeatherSelection } from '@/components/weather'

/** The anchor of a child page's weather section: the parent's cards and the mobile app link to it. */
export const CHILD_WEATHER_ANCHOR = 'meteo'

/**
 * The forecast point the map and the « Heure par heure » table share (ledger WEB-117): the row
 * selected in the table, and the checkpoint (its `index`) whose badge is lit and popup open on the
 * map in the Météo mode — closing the popup leaves the row selected. Held for one child: another
 * group's or stage's page (the same component, its id changed) starts afresh.
 */
interface WeatherFocus {
  childId?: string
  selection: RouteWeatherSelection
  open: number | null
}

/** The table starts on its first point, no popup open. */
const NO_WEATHER_FOCUS: WeatherFocus = { selection: { position: 0 }, open: null }

/**
 * The shared point of a ride group's page and a trip stage's (docs/LEDGER_*.md WEB-155): what the
 * table selects lights its badge on the map — the camera stays, the mode does not switch by
 * itself —, and a badge opened on the map selects its row without scrolling the page.
 */
export function useWeatherFocus(childId: string | undefined, leg: WeatherLegDto | undefined) {
  const [held, setFocus] = useState<WeatherFocus>(NO_WEATHER_FOCUS)
  const focus = held.childId === childId ? held : NO_WEATHER_FOCUS

  const selectFromTable = (selection: RouteWeatherSelection) =>
    setFocus({
      childId,
      selection,
      open: leg?.checkpoints[selection.position]?.index ?? null,
    })

  const selectFromMap = (index: number | null) => {
    const position =
      index === null ? -1 : (leg?.checkpoints.findIndex((c) => c.index === index) ?? -1)
    setFocus({
      childId,
      selection: position >= 0 ? { position, fromMap: true } : focus.selection,
      open: index,
    })
  }

  return { selection: focus.selection, open: focus.open, selectFromTable, selectFromMap }
}
