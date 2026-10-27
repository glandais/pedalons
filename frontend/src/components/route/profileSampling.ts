/**
 * Thinning of an elevation profile for drawing. A long route carries tens of thousands of points
 * (22 000 for a 1 900 km one) for a strip a couple of thousand pixels wide: Chart.js then lays out,
 * styles and fills every segment on each update, which takes most of a second. The profile keeps,
 * per bucket of distance, its lowest and highest point — the peaks and dips survive — plus every
 * point where the segment style changes, so the colours (and dashes) start exactly where they did.
 */

/** Buckets per visible window: two points each at most, about one per pixel of a wide strip. */
export const BUCKETS_PER_WINDOW = 1000

/** Below this many points, the profile is drawn as is. */
export const SAMPLING_THRESHOLD = 4000

/** First index whose distance is >= `x` (`xs.length` when none). */
function lowerBound(xs: ArrayLike<number>, x: number): number {
  let lo = 0
  let hi = xs.length
  while (lo < hi) {
    const mid = (lo + hi) >>> 1
    if (xs[mid] < x) lo = mid + 1
    else hi = mid
  }
  return lo
}

/**
 * The source indices to draw, ascending. `xs` and `ys` are the distance and elevation of each
 * point, `styles` the style of the segment starting at each point (compared by identity). With a
 * window, only its points — and one window's worth on each side, so a pan gesture has something to
 * show before the next sampling — are kept, at the window's resolution.
 */
export function sampleProfile(
  xs: ArrayLike<number>,
  ys: ArrayLike<number>,
  styles: ArrayLike<unknown>,
  window?: { min: number; max: number } | null
): number[] {
  const n = xs.length
  if (n === 0) return []
  if (n <= SAMPLING_THRESHOLD) return Array.from({ length: n }, (_, i) => i)

  let from = xs[0]
  let to = xs[n - 1]
  let buckets = BUCKETS_PER_WINDOW
  if (window) {
    const width = Math.max(window.max - window.min, 1)
    from = Math.max(from, window.min - width)
    to = Math.min(to, window.max + width)
    buckets = Math.ceil((BUCKETS_PER_WINDOW * (to - from)) / width)
  }
  // One point beyond each end, so the line runs to the edge of the range.
  const lo = Math.max(0, lowerBound(xs, from) - 1)
  const hi = Math.min(n - 1, lowerBound(xs, to))
  const bucketWidth = Math.max((to - from) / buckets, Number.MIN_VALUE)

  const keep = new Uint8Array(n)
  keep[lo] = 1
  keep[hi] = 1
  let bucket = -1
  let minIndex = lo
  let maxIndex = lo
  for (let i = lo; i <= hi; i++) {
    const b = Math.floor((xs[i] - from) / bucketWidth)
    if (b !== bucket) {
      keep[minIndex] = 1
      keep[maxIndex] = 1
      bucket = b
      minIndex = i
      maxIndex = i
    } else if (ys[i] < ys[minIndex]) {
      minIndex = i
    } else if (ys[i] > ys[maxIndex]) {
      maxIndex = i
    }
    if (i > 0 && styles[i] !== styles[i - 1]) keep[i] = 1
  }
  keep[minIndex] = 1
  keep[maxIndex] = 1

  const sources: number[] = []
  for (let i = lo; i <= hi; i++) if (keep[i]) sources.push(i)
  return sources
}

/**
 * The drawn index closest in distance to source point `source`, -1 when it falls outside the
 * sampled range.
 */
export function sampledIndexOf(
  sources: readonly number[],
  xs: ArrayLike<number>,
  source: number
): number {
  if (source < 0 || sources.length === 0) return -1
  if (source < sources[0] || source > sources[sources.length - 1]) return -1
  const k = lowerBound(sources, source)
  if (sources[k] === source || k === 0) return k
  const x = xs[source]
  return x - xs[sources[k - 1]] <= xs[sources[k]] - x ? k - 1 : k
}

/** Where the colour changes along the profile: each break's colour runs from its distance on. */
export interface ColorBreak {
  x: number
  color: string
}

/** The colour breaks of a profile whose segment starting at point `i` has colour `colors[i]`. */
export function colorBreaks(xs: ArrayLike<number>, colors: readonly string[]): ColorBreak[] {
  const breaks: ColorBreak[] = []
  for (let i = 0; i < colors.length; i++) {
    if (i === 0 || colors[i] !== colors[i - 1]) breaks.push({ x: xs[i], color: colors[i] })
  }
  return breaks
}

/**
 * A horizontal gradient over `[left, right]` pixels, with hard stops at each break: the whole
 * profile then draws (and fills) as a single path — per-segment styles make Chart.js resolve
 * and stroke every segment on its own, on every frame. `toPixel` maps a distance to a pixel.
 */
export function breaksGradient(
  ctx: CanvasRenderingContext2D,
  breaks: readonly ColorBreak[],
  left: number,
  right: number,
  toPixel: (x: number) => number
): CanvasGradient {
  const gradient = ctx.createLinearGradient(left, 0, right, 0)
  const width = Math.max(right - left, 1)
  let color = breaks[0]?.color ?? 'transparent'
  let opened = false
  for (const b of breaks) {
    const offset = (toPixel(b.x) - left) / width
    if (offset <= 0) {
      color = b.color
      continue
    }
    if (!opened) {
      gradient.addColorStop(0, color)
      opened = true
    }
    if (offset >= 1) break
    gradient.addColorStop(offset, color)
    gradient.addColorStop(offset, b.color)
    color = b.color
  }
  if (!opened) gradient.addColorStop(0, color)
  gradient.addColorStop(1, color)
  return gradient
}
