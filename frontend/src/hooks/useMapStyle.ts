import { useGetConfig } from '@/api/endpoints/configuration/configuration'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'
import {
  isDarkBasemap,
  resolveMapStyle,
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
 * pick therefore survives a theme change, and the switcher shows one line per basemap rather than
 * one per basemap-and-scheme.
 */
export function useMapStyle() {
  const colorScheme = useResolvedColorScheme()
  const { data: config } = useGetConfig()
  const styles = config?.mapStyles ?? NO_STYLES
  // Served like the basemaps, and undefined when the deployment configures no provider — the relief
  // switches then disappear rather than offering a control that can only fail.
  const terrainSource = config?.terrain

  const {
    savedStyleId,
    terrain3d,
    hillshade,
    setStyleId,
    clearStylePreference,
    setTerrain3d,
    setHillshade,
  } = useMapStyleStore()

  const currentStyle = resolveMapStyle(styles, savedStyleId)
  const styleId: MapStyleId | undefined = currentStyle?.id
  const style = currentStyle ? styleUrlFor(currentStyle, colorScheme === 'dark') : undefined
  const darkBasemap = isDarkBasemap(currentStyle, colorScheme === 'dark')

  return {
    styleId,
    styles,
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
  }
}
