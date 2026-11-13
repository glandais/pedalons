import { useGetConfig } from '@/api/endpoints/configuration/configuration'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'
import {
  isDarkBasemap,
  rendersDark,
  resolveMapChoice,
  styleUrlFor,
  type MapStyle,
  type MapStyleId,
} from '../components/map/mapStyles'
import { useMapStyleStore } from '@/store/mapStyleStore'

const NO_STYLES: MapStyle[] = []

/**
 * The basemap to render, and the switcher's contents.
 *
 * Both come from `GET /api/config` — already prefetched during SSR, so `styles` is populated on the
 * first render of a public page. There is deliberately no compiled-in fallback: a style URL hard-coded
 * here would be one more thing to keep in step with the server, and that drift is what this replaces.
 *
 * Dark mode no longer selects a *different entry* (it used to jump to `eclipse`, which the switcher
 * listed separately): the chosen basemap keeps its identity and loads its `darkVariant`. The user's
 * pick therefore survives a theme change, and the switcher shows one line per basemap. Under a dark
 * theme, a basemap with a dark counterpart can be kept light by one switch, shared by every basemap
 * (`lightInDark`, docs/LEDGER_*.md WEB-177); a light theme never renders a dark map.
 */
export function useMapStyle() {
  const colorScheme = useResolvedColorScheme()
  const { data: config } = useGetConfig()
  const served = config?.mapStyles ?? NO_STYLES
  const dark = colorScheme === 'dark'
  // Served like the basemaps, and undefined when the deployment configures no provider — the relief
  // switches then disappear rather than offering a control that can only fail.
  const terrainSource = config?.terrain

  const {
    savedStyleId,
    terrain3d,
    hillshade,
    lightInDark,
    setStyleId,
    clearStylePreference,
    setTerrain3d,
    setHillshade,
    setLightInDark,
  } = useMapStyleStore()

  const currentStyle = resolveMapChoice(served, savedStyleId)
  const styleId: MapStyleId | undefined = currentStyle?.id
  const renderDark = rendersDark(currentStyle, dark, lightInDark)
  // Only where the switch does something: a dark theme, and a basemap that has a dark counterpart.
  const canForceLight = dark && !!currentStyle?.darkVariant
  const style = currentStyle ? styleUrlFor(currentStyle, renderDark) : undefined
  const darkBasemap = isDarkBasemap(currentStyle, renderDark)

  return {
    styleId,
    styles: served,
    terrainSource,
    setStyleId,
    clearPreference: clearStylePreference,
    currentStyle,
    style,
    /** The basemap as rendered is dark (satellite, or a dark variant): what is drawn over it reads by this, not by the colour scheme. */
    darkBasemap,
    terrain3d,
    setTerrain3d,
    hillshade,
    setHillshade,
    lightInDark,
    setLightInDark,
    canForceLight,
  }
}
