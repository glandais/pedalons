/** A dragged point within this distance of the map's edge makes the map scroll. */
export const EDGE_PAN_ZONE_PX = 40
/** Scrolling speed with the point on the edge (or beyond it). */
export const EDGE_PAN_MAX_SPEED_PX_S = 600
/** One frame never counts for more than this: a background tab must not jump. */
export const EDGE_PAN_MAX_DT_MS = 50

/** Velocity along one axis of `length` px for a point at `position`: negative towards the origin side. */
function axisVelocity(position: number, length: number): number {
  // A small map keeps a free middle: the zone is at most a quarter of the axis
  const zone = Math.min(EDGE_PAN_ZONE_PX, length / 4)
  const towardsStart = position < length - position
  const distance = towardsStart ? position : length - position
  if (distance >= zone) return 0
  const speed = EDGE_PAN_MAX_SPEED_PX_S * (1 - Math.max(distance, 0) / zone)
  return towardsStart ? -speed : speed
}

/**
 * Pan velocity (px/s) for a dragged point at `p` (px in the map) in a `width` x `height` map: the
 * speed grows linearly from 0 at the edge of the zone to the maximum on the edge, and a point
 * outside the map scrolls at the maximum. Positive `vx` means the view moves east (`panBy([+,0])`),
 * positive `vy` south, so the map content moves the other way.
 */
export function edgePanVelocity(
  p: { x: number; y: number },
  size: { width: number; height: number }
): { vx: number; vy: number } {
  return { vx: axisVelocity(p.x, size.width), vy: axisVelocity(p.y, size.height) }
}
