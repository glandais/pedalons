import { useRef, useState } from 'react'
import type { WaypointDto } from '@/api/dto'
import type { WaypointSelection } from '@/lib/waypoints'

/**
 * The waypoint picked on a route's map, profile or list, shared between them by the page. A pick
 * in the list also brings the map into view (`mapBoxRef` goes on the box that holds it), since the
 * list sits below the map and the popup opens there.
 */
export function useWaypointSelection() {
  const [selection, setSelection] = useState<WaypointSelection | null>(null)
  const mapBoxRef = useRef<HTMLDivElement>(null)

  const selectFromList = (waypoint: WaypointDto) => {
    setSelection({ waypoint, from: 'list' })
    const reduced = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
    mapBoxRef.current?.scrollIntoView?.({
      block: 'nearest',
      behavior: reduced ? 'auto' : 'smooth',
    })
  }

  return { selection, setSelection, mapBoxRef, selectFromList }
}
