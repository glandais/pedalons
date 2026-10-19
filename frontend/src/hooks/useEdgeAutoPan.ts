import { useCallback, useEffect, useMemo, useRef, type RefObject } from 'react'
import type { MapRef } from 'react-map-gl/maplibre'
import { EDGE_PAN_MAX_DT_MS, edgePanVelocity } from '@/lib/edgePan'
import type { Point } from '@/lib/planner'

/** The point must have left its press by this much (px) before the edge may scroll the map. */
const ARMING_DISTANCE_PX = 3
/** Duration assumed for the first frame of a scroll. */
const FIRST_FRAME_MS = 16

export interface EdgeAutoPan {
  /** A gesture starts with the point at `lngLat`: a mere grab near the edge never scrolls. */
  begin: (lngLat: Point) => void
  /** The dragged point is now at `lngLat`; starts the scrolling when it sits in the edge zone. */
  follow: (lngLat: Point) => void
  /** Stops scrolling but stays armed (the mouse left the map: coming back resumes). */
  stop: () => void
  /** The gesture is over (release, cancel, Escape): stops and disarms. */
  end: () => void
  /** Stops and refuses every `follow` until the next `begin` (a second finger). */
  block: () => void
}

/**
 * Scrolls the map while a dragged point sits near its edge, one `panBy` per animation frame. The
 * point stays under the pointer: its screen position is kept and `onPan` receives the coordinates
 * now under it. All the state lives in refs, the loop must always read the latest values.
 */
export function useEdgeAutoPan(
  mapRef: RefObject<MapRef | null>,
  onPan: (lngLat: Point) => void
): EdgeAutoPan {
  const onPanRef = useRef(onPan)
  useEffect(() => {
    onPanRef.current = onPan
  })

  const start = useRef<{ x: number; y: number } | null>(null)
  const current = useRef<Point | null>(null)
  const armed = useRef(false)
  const blocked = useRef(false)
  const frame = useRef<number | null>(null)
  const previousTime = useRef<number | null>(null)
  const listening = useRef(false)

  // The window listeners are one stable function, calling `end` through a ref
  const endRef = useRef<() => void>(() => {})
  const onWindowRelease = useCallback(() => endRef.current(), [])

  const stop = useCallback(() => {
    if (frame.current !== null) cancelAnimationFrame(frame.current)
    frame.current = null
    previousTime.current = null
  }, [])

  const end = useCallback(() => {
    stop()
    if (listening.current) {
      window.removeEventListener('pointerup', onWindowRelease)
      window.removeEventListener('pointercancel', onWindowRelease)
      listening.current = false
    }
    armed.current = false
    start.current = null
    current.current = null
  }, [stop, onWindowRelease])
  useEffect(() => {
    endRef.current = end
  }, [end])

  const tick = useCallback(
    (time: number) => {
      frame.current = null
      const map = mapRef.current
      const at = current.current
      if (!map || !at) return stop()
      const p = map.project([at.lng, at.lat])
      const container = map.getContainer()
      const { vx, vy } = edgePanVelocity(p, {
        width: container.clientWidth,
        height: container.clientHeight,
      })
      if (vx === 0 && vy === 0) return stop()
      const dt =
        Math.min(
          previousTime.current === null ? FIRST_FRAME_MS : time - previousTime.current,
          EDGE_PAN_MAX_DT_MS
        ) / 1000
      previousTime.current = time
      // Without animate:false panBy animates over 500 ms
      map.panBy([vx * dt, vy * dt], { animate: false })
      // The screen position is kept, so the point stays under the finger or the mouse
      const moved = map.unproject(p)
      current.current = { lng: moved.lng, lat: moved.lat }
      onPanRef.current(current.current)
      frame.current = requestAnimationFrame(tick)
    },
    [mapRef, stop]
  )

  const begin = useCallback(
    (lngLat: Point) => {
      stop()
      const map = mapRef.current
      const p = map?.project([lngLat.lng, lngLat.lat])
      start.current = p ? { x: p.x, y: p.y } : null
      current.current = lngLat
      armed.current = false
      blocked.current = false
      // Listening for the whole gesture: a release outside the map reaches no map event, and the
      // mouse leaving the map only `stop`s (stays armed), so the window must end the gesture
      if (!listening.current) {
        window.addEventListener('pointerup', onWindowRelease)
        window.addEventListener('pointercancel', onWindowRelease)
        listening.current = true
      }
    },
    [mapRef, stop, onWindowRelease]
  )

  const follow = useCallback(
    (lngLat: Point) => {
      const map = mapRef.current
      if (blocked.current || !map || !start.current) return
      current.current = lngLat
      const p = map.project([lngLat.lng, lngLat.lat])
      if (
        !armed.current &&
        Math.hypot(p.x - start.current.x, p.y - start.current.y) > ARMING_DISTANCE_PX
      ) {
        armed.current = true
      }
      if (!armed.current || frame.current !== null) return
      const container = map.getContainer()
      const { vx, vy } = edgePanVelocity(p, {
        width: container.clientWidth,
        height: container.clientHeight,
      })
      if (vx === 0 && vy === 0) return
      frame.current = requestAnimationFrame(tick)
    },
    [mapRef, tick]
  )

  const block = useCallback(() => {
    stop()
    blocked.current = true
  }, [stop])

  useEffect(() => end, [end])

  return useMemo(() => ({ begin, follow, stop, end, block }), [begin, follow, stop, end, block])
}
