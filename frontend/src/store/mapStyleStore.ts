import { create } from 'zustand'
import { type MapStyleId } from '@/components/map/mapStyles'

const STYLE_KEY = 'pedalons-map-style'
const TERRAIN_KEY = 'pedalons-map-terrain3d'
const HILLSHADE_KEY = 'pedalons-map-hillshade'
const LIGHT_IN_DARK_KEY = 'pedalons-map-light-in-dark'

/**
 * The remembered pick, unvalidated.
 *
 * It used to be checked against the compiled-in table; the table is now served, and the store is
 * read before the config arrives. `useMapStyle` does the falling back — an id that has left the
 * contract resolves to the first served basemap there, and is kept in localStorage in case the
 * server serves it again.
 */
function getSavedStyleId(): MapStyleId | null {
  if (typeof window === 'undefined') return null
  return localStorage.getItem(STYLE_KEY)
}

/**
 * Whether the map stays light under a dark theme (docs/LEDGER_*.md WEB-177).
 *
 * Until the switch has been touched, a pick remembered as `<id>:light` — the line « (clair) » the
 * switcher used to have — stands for it. `<id>:dark` has no successor: a light theme no longer
 * renders a dark map.
 */
function getSavedLightInDark(): boolean {
  if (typeof window === 'undefined') return false
  const saved = localStorage.getItem(LIGHT_IN_DARK_KEY)
  if (saved !== null) return saved === 'true'
  return localStorage.getItem(STYLE_KEY)?.endsWith(':light') ?? false
}

interface MapStyleState {
  savedStyleId: MapStyleId | null
  terrain3d: boolean
  hillshade: boolean
  lightInDark: boolean
  setStyleId: (id: MapStyleId) => void
  clearStylePreference: () => void
  setTerrain3d: (enabled: boolean) => void
  setHillshade: (enabled: boolean) => void
  setLightInDark: (enabled: boolean) => void
}

export const useMapStyleStore = create<MapStyleState>()((set) => ({
  savedStyleId: getSavedStyleId(),
  terrain3d: typeof window !== 'undefined' && localStorage.getItem(TERRAIN_KEY) === 'true',
  hillshade: typeof window !== 'undefined' && localStorage.getItem(HILLSHADE_KEY) === 'true',
  lightInDark: getSavedLightInDark(),

  setStyleId: (id) => {
    localStorage.setItem(STYLE_KEY, id)
    set({ savedStyleId: id })
  },

  clearStylePreference: () => {
    localStorage.removeItem(STYLE_KEY)
    set({ savedStyleId: null })
  },

  setTerrain3d: (enabled) => {
    localStorage.setItem(TERRAIN_KEY, String(enabled))
    set({ terrain3d: enabled })
  },

  setHillshade: (enabled) => {
    localStorage.setItem(HILLSHADE_KEY, String(enabled))
    set({ hillshade: enabled })
  },

  setLightInDark: (enabled) => {
    localStorage.setItem(LIGHT_IN_DARK_KEY, String(enabled))
    set({ lightInDark: enabled })
  },
}))
