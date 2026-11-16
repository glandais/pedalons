import { useEffect, useState } from 'react'
import { useMap } from 'react-map-gl/maplibre'
import { layoutBadges, type ScreenBox } from '@/lib/weatherOnRoute'

export interface BadgeSpacing {
  /** The room a badge takes beside another and above: those always shown are moved apart by it. */
  width: number
  height: number
  /** How far apart the badges that may give way stay. */
  clearWidth: number
  clearHeight: number
  /**
   * Where the badge's box is centred, in pixels below its point (negative: above). Set, the badges
   * keep out from under the map's controls (WEB-190); unset, the controls are not looked at.
   */
  centreY?: number
}

/**
 * A weather capsule: its width (icon, « 23° », arrow) and a gap, its height and a gap. Below the
 * clearance, the map reads as saturated. Its 22 px stand 6 px above the point
 * (`WeatherCheckpointMarkers`), so its centre is 17 px above it.
 */
const WEATHER_BADGE: BadgeSpacing = {
  width: 72,
  height: 26,
  clearWidth: 88,
  clearHeight: 42,
  centreY: -17,
}

/** The room left around a control: a badge set right against a button read as part of it. */
const CONTROL_GAP = 8

/**
 * The boxes of the controls standing over the map (zoom, basemaps, fullscreen, scale, credit…), in
 * the map's pixels, each with {@link CONTROL_GAP} around it. Read on screen: their corner depends
 * on the pointer (`mapZones.ts`) and their size on the page.
 */
function controlBoxes(container: HTMLElement): ScreenBox[] {
  const origin = container.getBoundingClientRect()
  return Array.from(
    container.querySelectorAll<HTMLElement>('.maplibregl-control-container .maplibregl-ctrl')
  )
    .map((control) => control.getBoundingClientRect())
    .filter((rect) => rect.width > 0 && rect.height > 0)
    .map((rect) => ({
      left: rect.left - origin.left - CONTROL_GAP,
      top: rect.top - origin.top - CONTROL_GAP,
      right: rect.right - origin.left + CONTROL_GAP,
      bottom: rect.bottom - origin.top + CONTROL_GAP,
    }))
}

export interface BadgeItem<K> {
  key: K
  longitude: number
  latitude: number
  /** See `checkpointRanks`; null is always shown. */
  rank: number | null
}

/** The badges the map shows, each with its shift in pixels. */
export type BadgeLayout<K> = ReadonlyMap<K, readonly [number, number]>

/** Equal layouts, so a zoom that changes nothing does not render the badges again. */
function sameLayout<K>(a: BadgeLayout<K>, b: BadgeLayout<K>) {
  if (a.size !== b.size) return false
  for (const [key, [dx, dy]] of b) {
    const other = a.get(key)
    if (!other || other[0] !== dx || other[1] !== dy) return false
  }
  return true
}

/**
 * Which badges fit at this zoom and how far to move them (`layoutBadges`), measured on screen and
 * again at the end of every move (zoom, rotation, pan — the controls stay put while the badges
 * move) or resize — never during a gesture (ledgers WEB-128, WEB-142, WEB-190). Undefined outside
 * a map: nothing to measure, every badge stands.
 */
export function useBadgeLayout<K>(
  items: readonly BadgeItem<K>[],
  spacing: BadgeSpacing = WEATHER_BADGE
): BadgeLayout<K> | undefined {
  const { current: mapRef } = useMap()
  const [layout, setLayout] = useState<BadgeLayout<K>>(() => new Map())

  useEffect(() => {
    if (!mapRef) return
    const map = mapRef.getMap()
    const update = () => {
      const centreY = spacing.centreY
      const placed = layoutBadges(
        items.map((item) => {
          const { x, y } = map.project([item.longitude, item.latitude])
          return { x, y: y + (centreY ?? 0), rank: item.rank }
        }),
        spacing.width,
        spacing.height,
        spacing.clearWidth,
        spacing.clearHeight,
        centreY === undefined
          ? undefined
          : {
              obstacles: controlBoxes(map.getContainer()),
              width: map.getContainer().clientWidth,
            }
      )
      const next = new Map<K, readonly [number, number]>()
      items.forEach((item, i) => {
        const shift = placed[i]
        if (shift) next.set(item.key, [Math.round(shift.dx), Math.round(shift.dy)])
      })
      setLayout((previous) => (sameLayout(previous, next) ? previous : next))
    }
    update()
    // `moveend` closes every zoom, rotation, pitch and pan; `load` comes once the controls stand
    map.on('moveend', update)
    map.on('resize', update)
    map.on('load', update)
    return () => {
      map.off('moveend', update)
      map.off('resize', update)
      map.off('load', update)
    }
  }, [mapRef, items, spacing])

  return mapRef ? layout : undefined
}
