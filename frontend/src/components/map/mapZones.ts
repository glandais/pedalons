import { useState } from 'react'
import type { ControlPosition } from 'react-map-gl/maplibre'

/**
 * The two families of map controls (docs/LEDGER_*.md WEB-157). Each family has one corner, the
 * same on every map of the site — a control that moves between pages is a control the visitor has
 * to look for:
 *
 * - `camera` moves the view: place search, zoom and compass, « Me localiser », fullscreen;
 * - `display` changes what the map shows: the basemap panel, « Masquer le tracé ».
 *
 * On a fine pointer the camera column is top-left and the display column top-right. On a finger
 * both share one column bottom-right, under the thumb; the place search alone stays at the top,
 * across the map's width. Within a corner the order is fixed by index.css (`pdl-ctrl-<slot>`),
 * never by the mounting order.
 */
export type MapZone = 'camera' | 'display'

/**
 * Where a control stands within its corner. index.css gives each slot an `order`; the native
 * controls without a class of ours (zoom, geolocate, fullscreen) are matched by their buttons.
 */
export type MapControlSlot = 'fullscreen' | 'style' | 'hide-track'

/** The side a tooltip or a panel opens towards: away from the edge its column stands on. */
export type MapControlSide = 'left' | 'right'

export interface MapZones {
  camera: ControlPosition
  display: ControlPosition
  /** Per zone, the side its tooltips and panels open towards. */
  side: Record<MapZone, MapControlSide>
}

const COARSE_POINTER = '(pointer: coarse)'

/** The side opposite to the column's edge: a left column opens to the right, and vice versa. */
export function openingSide(position: ControlPosition): MapControlSide {
  return position.endsWith('left') ? 'right' : 'left'
}

/**
 * The zones for the current primary pointer. Without a window (never the case for a control: the
 * map's children only render in the browser) it answers the fine-pointer layout.
 */
export function readMapZones(): MapZones {
  const coarse =
    typeof window !== 'undefined' &&
    typeof window.matchMedia === 'function' &&
    window.matchMedia(COARSE_POINTER).matches
  const camera: ControlPosition = coarse ? 'bottom-right' : 'top-left'
  const display: ControlPosition = coarse ? 'bottom-right' : 'top-right'
  return { camera, display, side: { camera: openingSide(camera), display: openingSide(display) } }
}

/**
 * {@link readMapZones}, read once when the component mounts and frozen there: MapLibre fixes a
 * control's corner when it is added (`useControl`), so a zone that followed a pointer change would
 * only move the tooltips away from their buttons.
 */
export function useMapZones(): MapZones {
  const [zones] = useState(readMapZones)
  return zones
}
