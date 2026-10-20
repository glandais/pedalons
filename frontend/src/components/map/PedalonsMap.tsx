import { forwardRef, useContext, useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import Map, { NavigationControl } from 'react-map-gl/maplibre'
import type { MapProps, MapRef } from 'react-map-gl/maplibre'
import * as maplibregl from 'maplibre-gl'
import './setupMaplibreWorker'
import { Terrain3D } from './Terrain3D'
import { MapAttribution } from './MapAttribution'
import { RouteArrowImage } from './RouteArrows'
import { MapStyleSwitcher, type MapStyleSwitcherProps } from './MapStyleSwitcher'
import { MapPanelContext, useMapPanelState } from './mapPanelState'
import { useMapStyle } from '@/hooks/useMapStyle'

/**
 * Every map control in this app lives in ONE column, top-left, in one visual language: the zoom
 * buttons, then the basemap switcher, then whatever the page adds through `MapControlGroup`.
 * There is deliberately no per-map position prop — a control that moves between pages is a control
 * the visitor has to look for.
 */
type PedalonsMapProps = Omit<MapProps, 'mapLib' | 'mapStyle' | 'style'> &
  /** The traces the basemap panel lets the visitor show or hide, on a map that holds several. */
  Pick<MapStyleSwitcherProps, 'traces' | 'onTraceToggle'>

export const PedalonsMap = forwardRef<MapRef, PedalonsMapProps>(
  ({ children, traces, onTraceToggle, ...props }, ref) => {
    const { t } = useTranslation()
    // One open panel at a time across the control column (basemap, profile, help…). A page that
    // has panels outside the map as well provides the state higher up: the map then shares it.
    const ownPanelState = useMapPanelState()
    const panelState = useContext(MapPanelContext) ?? ownPanelState
    const {
      styleId,
      styles,
      terrainSource,
      setStyleId,
      style,
      terrain3d,
      setTerrain3d,
      hillshade,
      setHillshade,
    } = useMapStyle()

    // MapLibre's own controls (zoom, compass, fullscreen, geolocation) label themselves in English otherwise.
    // `locale` is a map *construction* option: switching language re-labels the next map to mount,
    // not one already on screen. Fine for tooltips, but don't read this as reactive.
    const locale = useMemo(
      () => ({
        'FullscreenControl.Enter': t('map.fullscreen.enter'),
        'FullscreenControl.Exit': t('map.fullscreen.exit'),
        'GeolocateControl.FindMyLocation': t('map.locate.find'),
        'GeolocateControl.LocationNotAvailable': t('map.locate.unavailable'),
        'NavigationControl.ZoomIn': t('map.zoomIn'),
        'NavigationControl.ZoomOut': t('map.zoomOut'),
        'NavigationControl.ResetBearing': t('map.resetBearing'),
      }),
      [t]
    )

    return (
      <MapPanelContext.Provider value={panelState}>
        <Map
          ref={ref}
          mapLib={maplibregl}
          mapStyle={style}
          locale={locale}
          // VersaTiles styles ask for the globe since their v6, the IGN and raster ones don't: without
          // this the projection would change with the basemap. Re-applied on every style load.
          projection="mercator"
          style={{ width: '100%', height: '100%' }}
          // Off as a map *option*, on as a child: `MapAttribution` has to rebuild the control when the
          // basemap changes, which the built-in one — constructed once with the map — cannot do.
          attributionControl={false}
          {...props}
        >
          <NavigationControl position="top-left" />
          <MapAttribution />
          <Terrain3D source={terrainSource} terrain={terrain3d} hillshade={hillshade} />
          {/* Every trace on the site shows its direction (`routeArrowLayout`): the image is ready on
          every map rather than registered by each page that draws one. */}
          <RouteArrowImage />
          <MapStyleSwitcher
            styles={styles}
            currentStyleId={styleId}
            onStyleChange={setStyleId}
            terrain3d={terrain3d}
            hillshade={hillshade}
            // No served elevation source, no relief controls: the switches would toggle nothing.
            onTerrain3DChange={terrainSource ? setTerrain3d : undefined}
            onHillshadeChange={terrainSource ? setHillshade : undefined}
            traces={traces}
            onTraceToggle={onTraceToggle}
          />
          {children}
        </Map>
      </MapPanelContext.Provider>
    )
  }
)
PedalonsMap.displayName = 'PedalonsMap'
