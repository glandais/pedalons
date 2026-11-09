import { useEffect, useState } from 'react'
import { useMap } from 'react-map-gl/maplibre'
import { layoutBadges } from '@/lib/weatherOnRoute'

/** The capsule's room beside another — its width (icon, « 23° », arrow) and a gap — and above. */
const BADGE_STEP = 72
const BADGE_ROW = 26
/** How far apart the badges that may give way stay: below this, the map reads as saturated. */
const BADGE_CLEAR_WIDTH = 88
const BADGE_CLEAR_HEIGHT = 42

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
 * again at the end of every zoom, rotation or resize — never during a gesture (ledgers WEB-128,
 * WEB-142). Undefined outside a map: nothing to measure, every badge stands.
 */
export function useBadgeLayout<K>(items: readonly BadgeItem<K>[]): BadgeLayout<K> | undefined {
  const { current: mapRef } = useMap()
  const [layout, setLayout] = useState<BadgeLayout<K>>(() => new Map())

  useEffect(() => {
    if (!mapRef) return
    const map = mapRef.getMap()
    const update = () => {
      const placed = layoutBadges(
        items.map((item) => ({
          ...map.project([item.longitude, item.latitude]),
          rank: item.rank,
        })),
        BADGE_STEP,
        BADGE_ROW,
        BADGE_CLEAR_WIDTH,
        BADGE_CLEAR_HEIGHT
      )
      const next = new Map<K, readonly [number, number]>()
      items.forEach((item, i) => {
        const shift = placed[i]
        if (shift) next.set(item.key, [Math.round(shift.dx), Math.round(shift.dy)])
      })
      setLayout((previous) => (sameLayout(previous, next) ? previous : next))
    }
    update()
    map.on('zoomend', update)
    map.on('rotateend', update)
    map.on('pitchend', update)
    map.on('resize', update)
    return () => {
      map.off('zoomend', update)
      map.off('rotateend', update)
      map.off('pitchend', update)
      map.off('resize', update)
    }
  }, [mapRef, items])

  return mapRef ? layout : undefined
}
