// The surface along a saved track (WEB-100 C1b): the spans the API derives from OpenStreetMap
// after the save, turned into the colour of each profile and map segment and into the breakdown of
// the route sheet. The families come from the business colour code (docs/BRANDING.md §3.6,
// `TrackSurface`); only the shades live here. The route being drawn takes its colours from here too
// (`plannerSurface.ts`), so it looks like the saved one. `suggestSurfaceType` (C1c) reads the same
// spans to offer a value for the route form's surface type, never to apply it.
import type { MantineTheme } from '@mantine/core'
import {
  SurfaceType,
  TrackSurface,
  TrackSurfaceState,
  type SurfaceSpanDto,
  type TrackDto,
} from '@/api/dto'
import { TRACK_SURFACE_COLORS } from '@/lib/badgeColors.generated'

/** The classes, in the order of the legend. */
export const TRACK_SURFACES: TrackSurface[] = [
  TrackSurface.PAVED,
  TrackSurface.PAVED_ROUGH,
  TrackSurface.GRAVEL,
  TrackSurface.DIRT,
  TrackSurface.PATH,
  TrackSurface.UNKNOWN,
  TrackSurface.OFF_NETWORK,
]

/**
 * The shade of each class within its family, per colour scheme. Three classes share the grey: in
 * light, paved is the dark one, unknown the palest and off the network in between; the dark theme
 * loads the basemap's dark variant, where a dark grey vanishes, so there paved is the light one and
 * unknown the dimmer.
 */
export const TRACK_SURFACE_SHADES: Record<'light' | 'dark', Record<TrackSurface, number>> = {
  light: {
    PAVED: 7,
    PAVED_ROUGH: 6,
    GRAVEL: 6,
    DIRT: 7,
    PATH: 6,
    UNKNOWN: 4,
    OFF_NETWORK: 5,
  },
  dark: {
    PAVED: 2,
    PAVED_ROUGH: 6,
    GRAVEL: 6,
    DIRT: 7,
    PATH: 6,
    UNKNOWN: 6,
    OFF_NETWORK: 4,
  },
}

/** The colour of every class, resolved from the Mantine theme for the given colour scheme. */
export function trackSurfaceColors(
  theme: MantineTheme,
  colorScheme: 'light' | 'dark'
): Record<TrackSurface, string> {
  const shades = TRACK_SURFACE_SHADES[colorScheme]
  const colors = {} as Record<TrackSurface, string>
  for (const surface of TRACK_SURFACES) {
    colors[surface] = theme.colors[TRACK_SURFACE_COLORS[surface]][shades[surface]]
  }
  return colors
}

/**
 * The class at `m` metres (binary search: the spans are contiguous and sorted), UNKNOWN outside the
 * spans or without any. A boundary belongs to the span that starts there.
 */
export function surfaceAtDistance(
  spans: SurfaceSpanDto[] | null | undefined,
  m: number
): TrackSurface {
  if (!spans || spans.length === 0) return TrackSurface.UNKNOWN
  let lo = 0
  let hi = spans.length - 1
  while (lo <= hi) {
    const mid = (lo + hi) >> 1
    const span = spans[mid]
    if (m < span.from) hi = mid - 1
    else if (m > span.to || (m === span.to && mid < spans.length - 1)) lo = mid + 1
    else return span.surface
  }
  return TrackSurface.UNKNOWN
}

function readySpans(track: TrackDto): SurfaceSpanDto[] | null {
  return track.surfaceState === TrackSurfaceState.READY && track.surfaces?.length
    ? track.surfaces
    : null
}

/** At least one track has its surface. */
export function hasSurfaces(tracks: TrackDto[]): boolean {
  return tracks.some((track) => readySpans(track) !== null)
}

/** No track has its surface yet, and at least one is being computed. */
export function surfacesPending(tracks: TrackDto[]): boolean {
  return (
    !hasSurfaces(tracks) && tracks.some((track) => track.surfaceState === TrackSurfaceState.PENDING)
  )
}

/**
 * The class of every point of the flattened tracks (the index of the profile and of the map): that
 * of the segment the point starts, read at its midpoint; the last point of a track repeats the
 * previous one. The measure restarts at 0 on every track. A track without its surface is UNKNOWN.
 * Null when no track has one.
 */
export function pointSurfaces(tracks: TrackDto[]): TrackSurface[] | null {
  if (!hasSurfaces(tracks)) return null
  const result: TrackSurface[] = []
  for (const track of tracks) {
    const spans = readySpans(track)
    const points = track.line.coordinates
    for (let i = 0; i < points.length; i++) {
      if (!spans) {
        result.push(TrackSurface.UNKNOWN)
      } else if (i === points.length - 1) {
        result.push(i > 0 ? result[result.length - 1] : surfaceAtDistance(spans, points[i][3]))
      } else {
        result.push(surfaceAtDistance(spans, (points[i][3] + points[i + 1][3]) / 2))
      }
    }
  }
  return result
}

/** Length of each class over every track that has its surface, in legend order, empty classes dropped. */
export function surfaceShares(
  tracks: TrackDto[]
): { surface: TrackSurface; length: number; share: number }[] {
  const lengths = new Map<TrackSurface, number>()
  let total = 0
  for (const track of tracks) {
    for (const span of readySpans(track) ?? []) {
      const length = span.to - span.from
      if (length <= 0) continue
      lengths.set(span.surface, (lengths.get(span.surface) ?? 0) + length)
      total += length
    }
  }
  if (total === 0) return []
  return TRACK_SURFACES.filter((surface) => lengths.has(surface)).map((surface) => ({
    surface,
    length: lengths.get(surface)!,
    share: lengths.get(surface)! / total,
  }))
}

/** Above this share of the whole length unknown or off the network, no suggestion (WEB-100 C1c). */
export const SUGGEST_MAX_MISSING = 0.3
/** Above this share of paths (of the known length), MTB. */
export const SUGGEST_MTB_PATH = 0.3
/** Below this share of unpaved (of the known length), ROAD; up to SUGGEST_MIXED_MAX, MIXED; above, GRAVEL. */
export const SUGGEST_ROAD_BELOW = 0.05
export const SUGGEST_MIXED_MAX = 0.2

/**
 * The surface type a route's surface suggests (WEB-100 C1c), never applied by itself: the form
 * offers it. Read over every track: one whose surface is not READY counts as unknown for its whole
 * length (last M of its line). Null without any READY track, or when more than 30 % of the length
 * is unknown or off the network. On the known length: more than 30 % path -> MTB; else unpaved
 * (GRAVEL, DIRT, PATH; PAVED_ROUGH is paved) below 5 % -> ROAD, 5 to 20 % -> MIXED, above -> GRAVEL.
 */
export function suggestSurfaceType(tracks: TrackDto[]): SurfaceType | null {
  if (!hasSurfaces(tracks)) return null
  let total = 0
  let missing = 0
  let path = 0
  let unpaved = 0
  for (const track of tracks) {
    const spans = readySpans(track)
    if (!spans) {
      const length = track.line.coordinates.at(-1)?.[3] ?? 0
      total += length
      missing += length
      continue
    }
    for (const span of spans) {
      const length = span.to - span.from
      if (length <= 0) continue
      total += length
      switch (span.surface) {
        case TrackSurface.UNKNOWN:
        case TrackSurface.OFF_NETWORK:
          missing += length
          break
        case TrackSurface.PATH:
          path += length
          unpaved += length
          break
        case TrackSurface.GRAVEL:
        case TrackSurface.DIRT:
          unpaved += length
          break
        // PAVED, PAVED_ROUGH (and a later value): paved
      }
    }
  }
  if (total <= 0 || missing / total > SUGGEST_MAX_MISSING) return null
  const known = total - missing
  if (known <= 0) return null
  if (path / known > SUGGEST_MTB_PATH) return SurfaceType.MTB
  const share = unpaved / known
  if (share < SUGGEST_ROAD_BELOW) return SurfaceType.ROAD
  if (share <= SUGGEST_MIXED_MAX) return SurfaceType.MIXED
  return SurfaceType.GRAVEL
}
