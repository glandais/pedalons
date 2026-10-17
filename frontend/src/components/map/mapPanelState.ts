import { createContext, useCallback, useContext, useMemo, useState } from 'react'

/**
 * Which panel of the map's control column is open, if any. One state for the whole map, so opening
 * the profile selector closes the basemap switcher instead of stacking over it.
 */
export interface MapPanelState {
  openId: string | null
  setOpenId: (id: string | null) => void
}

let lastOutsideCloseAt = 0

/** Records that a panel was just dismissed by a press outside it (see {@link panelJustDismissed}). */
export function markPanelDismissed() {
  lastOutsideCloseAt = Date.now()
}

/**
 * True right after a panel was dismissed by a press outside it. The press that closes a panel on
 * the map is followed by a `click` the map would take for a new point (a billed routing request):
 * the map's click handler drops that click.
 */
export function panelJustDismissed(): boolean {
  return Date.now() - lastOutsideCloseAt < 500
}

export const MapPanelContext = createContext<MapPanelState | null>(null)

/** Open/close state of the panel `id`. Without a provider it falls back to a private state. */
export function useMapPanel(id: string) {
  const shared = useContext(MapPanelContext)
  const [localOpenId, setLocalOpenId] = useState<string | null>(null)
  const openId = shared ? shared.openId : localOpenId
  const setOpenId = shared ? shared.setOpenId : setLocalOpenId

  const opened = openId === id
  const toggle = useCallback(() => setOpenId(opened ? null : id), [setOpenId, opened, id])
  const close = useCallback(() => {
    if (opened) setOpenId(null)
  }, [setOpenId, opened])
  return { opened, toggle, close, setOpened: (v: boolean) => setOpenId(v ? id : null) }
}

/**
 * The open-panel state of one map's control column. {@link PedalonsMap} owns one; a page whose
 * panels live outside the map too (the planner's bottom bar) creates it higher and provides it
 * with {@link MapPanelContext}, which the map then reuses instead of making its own.
 */
export function useMapPanelState(): MapPanelState {
  const [openId, setOpenId] = useState<string | null>(null)
  return useMemo(() => ({ openId, setOpenId }), [openId])
}
