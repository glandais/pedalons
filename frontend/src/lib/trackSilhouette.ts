/** Side of the square the track is fitted into, in SVG user units. */
const BOX = 100
/** Empty margin kept around the track so the stroke is never clipped. */
const MARGIN = 6
/** A silhouette needs no more vertices than that to look the same at this size. */
const MAX_VERTICES = 250

export interface Silhouette {
  /** `points` attribute of the polyline. */
  points: string
  width: number
  height: number
}

/**
 * Projects a track (`[lng, lat, …][]`) to a polyline fitted into a {@link BOX} square, north up.
 * Equirectangular, longitudes shrunk by the cosine of the mean latitude: exact enough for a
 * thumbnail, and no map, no tile, no WebGL. Null below two vertices.
 */
export function trackSilhouette(coordinates: readonly (readonly number[])[]): Silhouette | null {
  if (coordinates.length < 2) return null

  const step = Math.max(1, Math.ceil(coordinates.length / MAX_VERTICES))
  const vertices = coordinates.filter((_, i) => i % step === 0 || i === coordinates.length - 1)

  let minLng = Infinity
  let maxLng = -Infinity
  let minLat = Infinity
  let maxLat = -Infinity
  for (const [lng, lat] of vertices) {
    minLng = Math.min(minLng, lng)
    maxLng = Math.max(maxLng, lng)
    minLat = Math.min(minLat, lat)
    maxLat = Math.max(maxLat, lat)
  }

  const k = Math.cos((((minLat + maxLat) / 2) * Math.PI) / 180)
  const spanX = (maxLng - minLng) * k
  const spanY = maxLat - minLat
  const span = Math.max(spanX, spanY)
  if (span === 0) return null

  const scale = (BOX - 2 * MARGIN) / span
  const width = spanX * scale + 2 * MARGIN
  const height = spanY * scale + 2 * MARGIN
  const points = vertices
    .map(([lng, lat]) => {
      const x = (lng - minLng) * k * scale + MARGIN
      const y = (maxLat - lat) * scale + MARGIN
      return `${x.toFixed(2)},${y.toFixed(2)}`
    })
    .join(' ')

  return { points, width, height }
}
