/**
 * Distance ↔ geography conversions behind the map/elevation-chart zoom sync
 * (`useMapChartZoomSync`). A track point is `[lng, lat, elevation, cumulative distance (m)]`, and
 * each track is taken on its own: its distances are monotonic, the flattened route's are not.
 *
 * The track is Douglas-Peucker simplified server-side, so two vertices can sit hundreds of metres
 * apart on a straight road. Both directions therefore work on segments, not on vertices: reading
 * only the vertices would cut the chart short of the track the map shows, and leave the map short
 * of the window the chart shows — or not move it at all when the window falls between two vertices.
 */

/** The visible map area, in degrees. */
export interface LngLatBox {
  west: number
  south: number
  east: number
  north: number
}

export interface DistanceRange {
  min: number
  max: number
}

/**
 * Cumulative-distance span of the track inside `box`, segments crossing its edges clipped where
 * they cross it. Null when no part of the track is inside.
 */
export function visibleDistanceRange(tracks: number[][][], box: LngLatBox): DistanceRange | null {
  let min = Infinity
  let max = -Infinity
  for (const points of tracks) {
    if (points.length === 1) {
      const p = points[0]
      if (p[0] >= box.west && p[0] <= box.east && p[1] >= box.south && p[1] <= box.north) {
        min = Math.min(min, p[3])
        max = Math.max(max, p[3])
      }
      continue
    }
    for (let i = 0; i < points.length - 1; i++) {
      const a = points[i]
      const b = points[i + 1]
      const clip = clipSegment(a, b, box)
      if (!clip) continue
      const d0 = a[3] + clip[0] * (b[3] - a[3])
      const d1 = a[3] + clip[1] * (b[3] - a[3])
      min = Math.min(min, d0, d1)
      max = Math.max(max, d0, d1)
    }
  }
  return min === Infinity ? null : { min, max }
}

/**
 * The track points spanning the distance window `[min, max]`: the vertices inside it, plus a point
 * interpolated where the window starts and where it ends.
 */
export function pointsInDistanceRange(tracks: number[][][], min: number, max: number): number[][] {
  const result: number[][] = []
  for (const points of tracks) {
    for (let i = 0; i < points.length; i++) {
      const p = points[i]
      if (i > 0) {
        const a = points[i - 1]
        for (const d of [min, max]) {
          if (a[3] < d && d < p[3]) result.push(interpolate(a, p, (d - a[3]) / (p[3] - a[3])))
        }
      }
      if (p[3] >= min && p[3] <= max) result.push(p)
    }
  }
  return result
}

function interpolate(a: number[], b: number[], t: number): number[] {
  return [
    a[0] + t * (b[0] - a[0]),
    a[1] + t * (b[1] - a[1]),
    a[2] + t * (b[2] - a[2]),
    a[3] + t * (b[3] - a[3]),
  ]
}

/**
 * Liang–Barsky clipping of segment `a → b` against `box`: the `[t0, t1]` fractions of the segment
 * inside the box, or null when it misses it.
 */
function clipSegment(a: number[], b: number[], box: LngLatBox): [number, number] | null {
  const dx = b[0] - a[0]
  const dy = b[1] - a[1]
  let t0 = 0
  let t1 = 1
  const edges: [number, number][] = [
    [-dx, a[0] - box.west],
    [dx, box.east - a[0]],
    [-dy, a[1] - box.south],
    [dy, box.north - a[1]],
  ]
  for (const [p, q] of edges) {
    if (p === 0) {
      // Parallel to this edge: inside it or out for good.
      if (q < 0) return null
      continue
    }
    const r = q / p
    if (p < 0) {
      if (r > t1) return null
      if (r > t0) t0 = r
    } else {
      if (r < t0) return null
      if (r < t1) t1 = r
    }
  }
  return [t0, t1]
}
