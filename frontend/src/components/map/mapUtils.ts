import type { LngLatBoundsLike } from 'maplibre-gl'
import KDBush from 'kdbush'
import { around } from 'geokdbush'
import type { ClimbDto, RouteDetailDto, TrackDto } from '@/api/dto'

// Color calculation (matching biketeam single-map.js `getColor`)
const NEUTRAL_HUE = 210
// Hue ramp: 0% grade → 85 (green), 18% grade → -105 (which wraps to 255 = red/magenta), passing
// through yellow/orange/red for the usual 3–10% range. MAX_HUE stays negative on purpose; the
// `+ 360` below wraps it back into a valid CSS hue only after the linear interpolation.
const MIN_HUE = 85
const MAX_HUE = -105
const SATURATION = '86%'
const LIGHTNESS = '62%'
export const NEUTRAL_COLOR = `hsl(${NEUTRAL_HUE},${SATURATION},${LIGHTNESS})`

// Calculate color based on gradient
export function getColorFromGradient(gradient: number): string {
  if (gradient === 0) return NEUTRAL_COLOR

  // Map gradient (0% to 18%) to hue (MIN_HUE to MAX_HUE)
  const normalizedGradient = Math.min(18, Math.max(0, gradient))
  let hue = Math.round(MIN_HUE + (normalizedGradient / 18.0) * (MAX_HUE - MIN_HUE))

  // Clamp into [MAX_HUE, MIN_HUE] before wrapping negatives back into [0, 360).
  hue = Math.min(MIN_HUE, Math.max(MAX_HUE, hue))

  if (hue < 0) {
    hue = hue + 360
  }

  return `hsl(${hue},${SATURATION},${LIGHTNESS})`
}

// Determine if a point is in a climb and get its gradient.
// When the containing climb exposes parts, return the grade of the specific part the point falls
// in (matching prendslaroue's per-part coloring); otherwise fall back to the climb's average.
export function getPointClimbGradient(point: number[], climbs: ClimbDto[]): number {
  const cumulativeDistance = point[3]
  for (const climb of climbs) {
    if (cumulativeDistance >= climb.startDistance && cumulativeDistance <= climb.endDistance) {
      if (climb.parts && climb.parts.length > 0) {
        for (const part of climb.parts) {
          if (cumulativeDistance >= part.startDistance && cumulativeDistance <= part.endDistance) {
            return part.grade
          }
        }
      }
      return climb.averageGradient
    }
  }
  return 0
}

// Convert track points to GeoJSON LineString
export function routeToGeoJSON(
  route: RouteDetailDto,
  properties: Record<string, unknown> = {}
): GeoJSON.FeatureCollection<GeoJSON.LineString> {
  const features: GeoJSON.Feature<GeoJSON.LineString>[] = []
  for (let i = 0; i < route.tracks.length; i++) {
    const line: GeoJSON.Feature<GeoJSON.LineString> = {
      type: 'Feature',
      geometry: route.tracks[i].line,
      properties: { trackIndex: i, ...properties, climbs: route.tracks[i].climbs },
    }
    features.push(line)
  }
  return {
    type: 'FeatureCollection',
    features,
  }
}

// Calculate bounds from track points
// Note: MapLibre uses [lng, lat] order (GeoJSON standard)
export function calculateBounds(trackPoints: number[][]): LngLatBoundsLike {
  if (trackPoints.length === 0) {
    return [
      [-180, -90],
      [180, 90],
    ]
  }

  let minLng = Infinity,
    maxLng = -Infinity
  let minLat = Infinity,
    maxLat = -Infinity

  for (const point of trackPoints) {
    minLng = Math.min(minLng, point[0])
    maxLng = Math.max(maxLng, point[0])
    minLat = Math.min(minLat, point[1])
    maxLat = Math.max(maxLat, point[1])
  }

  return [
    [minLng, minLat],
    [maxLng, maxLat],
  ]
}

// Simple distance calculation (Haversine formula)
export function distance(lng1: number, lat1: number, lng2: number, lat2: number): number {
  const R = 6371000 // Earth radius in meters
  const dLat = ((lat2 - lat1) * Math.PI) / 180
  const dLon = ((lng2 - lng1) * Math.PI) / 180
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return R * c
}

/**
 * Bounds for an elevation chart's y axis, anchored on the route's real min/max.
 *
 * Chart.js's auto-scaling rounds the axis outward to whole tick steps: a Loire-valley route
 * spanning -0.5 m to 106 m gets an axis of -20 m to 120 m, so a fifth of the strip renders empty
 * below sea level. Pinning the bounds to the data gives that height back to the profile —
 * Chart.js still picks round tick *labels* inside the range, only the ends stop being padded.
 *
 * Returns null when there is no elevation data, in which case leave the axis to Chart.js.
 */
export function getElevationAxisBounds(elevations: number[]): { min: number; max: number } | null {
  let min = Infinity
  let max = -Infinity
  for (const ele of elevations) {
    if (!Number.isFinite(ele)) continue
    if (ele < min) min = ele
    if (ele > max) max = ele
  }
  if (min === Infinity) return null

  // A dead-flat route would collapse the axis to a single value; give it something to draw in.
  const span = max - min
  if (span < 1) return { min: min - 5, max: max + 5 }

  // Only the top gets a sliver of padding, so the summit's 2px stroke isn't clipped by the frame.
  return { min, max: max + span * 0.03 }
}

/**
 * The elevations drawn inside a distance window, for {@link getElevationAxisBounds}: every point
 * in it plus the nearest one on each side, so the line running out of the frame still fits the
 * axis. Without a window, the whole profile. `xs` are cumulative distances, in ascending order.
 */
export function elevationsInWindow(
  xs: ArrayLike<number>,
  ys: ArrayLike<number>,
  window: { min: number; max: number } | null
): number[] {
  if (!window) return Array.from(ys)
  const elevations: number[] = []
  for (let i = 0; i < xs.length; i++) {
    const next = i + 1 < xs.length ? xs[i + 1] : Infinity
    const previous = i > 0 ? xs[i - 1] : -Infinity
    if (next >= window.min && previous <= window.max) elevations.push(ys[i])
  }
  return elevations
}

// Returns km marker interval based on total distance
export function getKmMarkerInterval(distanceKm: number): number {
  if (distanceKm < 10) return 1
  if (distanceKm < 20) return 2
  if (distanceKm < 50) return 5
  return 10
}

// Compute km marker positions along coords.
// coords is [lng, lat, ele?, cumDistM?][]. If cumDistM (4th element) is present it is used
// directly; otherwise cumulative distance is computed using haversine.
export function computeKmMarkers(
  coords: number[][],
  totalDistanceM: number
): { lng: number; lat: number; label: string }[] {
  if (totalDistanceM <= 0 || coords.length < 2) return []

  const intervalM = getKmMarkerInterval(totalDistanceM / 1000) * 1000

  // Build cumulative-distance array: use 4th element when available, else compute
  const hasCumDist = coords[0].length >= 4 && coords[coords.length - 1][3] > 0
  const cumDists: number[] = hasCumDist
    ? coords.map((p) => p[3])
    : new Array<number>(coords.length).fill(0)

  if (!hasCumDist) {
    let acc = 0
    for (let i = 1; i < coords.length; i++) {
      acc += distance(coords[i - 1][0], coords[i - 1][1], coords[i][0], coords[i][1])
      cumDists[i] = acc
    }
  }

  const markers: { lng: number; lat: number; label: string }[] = []
  let targetDist = intervalM

  while (targetDist < totalDistanceM) {
    const idx = cumDists.findIndex((d) => d >= targetDist)
    if (idx > 0) {
      const p0 = coords[idx - 1]
      const p1 = coords[idx]
      const span = cumDists[idx] - cumDists[idx - 1]
      const t = span === 0 ? 0 : (targetDist - cumDists[idx - 1]) / span
      markers.push({
        lng: p0[0] + t * (p1[0] - p0[0]),
        lat: p0[1] + t * (p1[1] - p0[1]),
        label: String(Math.round(targetDist / 1000)),
      })
    }
    targetDist += intervalM
  }

  return markers
}

// Find nearest point to lat/lng
export function findNearestPoint(
  trackPoints: number[][],
  lat: number,
  lng: number,
  maxDistance: number
): number {
  let nearestIndex = -1
  let minDist = maxDistance

  for (let i = 0; i < trackPoints.length; i++) {
    const dist = distance(lng, lat, trackPoints[i][0], trackPoints[i][1])
    if (dist < minDist) {
      minDist = dist
      nearestIndex = i
    }
  }

  return nearestIndex
}

/**
 * {@link findNearestPoint} over a spatial index built once for the track: a mouse move then costs a
 * few comparisons instead of a haversine per point (22 000 on a long route). Same arguments and
 * result, `maxDistance` in meters.
 */
export function nearestPointFinder(
  trackPoints: number[][]
): (lat: number, lng: number, maxDistance: number) => number {
  if (trackPoints.length === 0) return () => -1
  const index = new KDBush(trackPoints.length)
  for (const p of trackPoints) index.add(p[0], p[1])
  index.finish()
  return (lat, lng, maxDistance) => {
    const [nearest] = around(index, lng, lat, 1, maxDistance / 1000)
    return nearest ?? -1
  }
}

// Create GeoJSON FeatureCollection with multiple line segments for gradient coloring. With
// `colorAt` the colour of a point (track index, point index) replaces the grade's: it colours the
// segment that starts there, like the grade does. A point it has no colour for (undefined) keeps
// the grade's — so a caller that must not read as the grade (the wind colouring) gives every point
// a colour, `NEUTRAL_COLOR` where it knows none.
export function createGradientLineFeatures(
  tracks: TrackDto[],
  colorAt?: (trackIndex: number, pointIndex: number) => string | undefined
): GeoJSON.FeatureCollection<GeoJSON.LineString> {
  const features: GeoJSON.Feature<GeoJSON.LineString>[] = []

  if (tracks.length === 0) {
    return { type: 'FeatureCollection', features }
  }

  const colorOf = (trackIndex: number, pointIndex: number) =>
    colorAt?.(trackIndex, pointIndex) ??
    getColorFromGradient(
      getPointClimbGradient(
        tracks[trackIndex].line.coordinates[pointIndex],
        tracks[trackIndex].climbs
      )
    )

  let currentColor = colorOf(0, 0)
  let currentSegment: [number, number][] = []

  for (let j = 0; j < tracks.length; j++) {
    const trackPoints = tracks[j].line.coordinates

    for (let i = 0; i < trackPoints.length; i++) {
      const point = trackPoints[i]
      const color = colorOf(j, i)
      // A new track opens its own piece, whatever the previous one ended with
      if (i === 0) currentColor = color

      if (color !== currentColor && currentSegment.length > 0) {
        // Add last point of previous segment for continuity
        currentSegment.push([point[0], point[1]])

        features.push({
          type: 'Feature',
          properties: { color: currentColor },
          geometry: {
            type: 'LineString',
            coordinates: currentSegment,
          },
        })

        currentSegment = [[point[0], point[1]]]
        currentColor = color
      } else {
        currentSegment.push([point[0], point[1]])
      }
    }

    // Add final segment
    if (currentSegment.length > 1) {
      features.push({
        type: 'Feature',
        properties: { color: currentColor },
        geometry: {
          type: 'LineString',
          coordinates: currentSegment,
        },
      })
    }
    currentSegment = []
  }

  return {
    type: 'FeatureCollection',
    features,
  }
}
