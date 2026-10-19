import { lineElevation } from '@/api/endpoints/router/router'
import type { GpxImportTrack } from '@/api/dto'
import { apiErrorStatus } from '@/lib/apiError'
import { decode1, decode2 } from '@/lib/polyline'
import type { DirectProfile, StraightEdge } from '@/lib/planner'

// The relief of the straight edges of a route being drawn (POST /api/router/elevation, WEB-100 B1b):
// read in the background, grouped, and kept for the editing session, whatever the gestures do.

/** Per request, as the server takes (50 lines, 200 km together). */
export const MAX_LINES_PER_REQUEST = 50
export const MAX_METERS_PER_REQUEST = 200_000

/** What the session knows of an edge: its relief, or that reading it failed (not asked again). */
export type ElevationCache = Map<string, DirectProfile | 'failed'>

/** Edges cut into requests of at most 50 lines and 200 km. */
export function chunkEdges(edges: StraightEdge[]): StraightEdge[][] {
  const chunks: StraightEdge[][] = []
  let current: StraightEdge[] = []
  let meters = 0
  for (const edge of edges) {
    if (
      current.length > 0 &&
      (current.length >= MAX_LINES_PER_REQUEST || meters + edge.meters > MAX_METERS_PER_REQUEST)
    ) {
      chunks.push(current)
      current = []
      meters = 0
    }
    current.push(edge)
    meters += edge.meters
  }
  if (current.length > 0) chunks.push(current)
  return chunks
}

/** The profile of an edge from the track the server answered; null when the answer cannot be read. */
export function decodeProfile(key: string, track: GpxImportTrack): DirectProfile | null {
  try {
    if (track.ele === undefined || track.climb === undefined) return null
    const lngLat = decode2(track.line)
    const ele = decode1(track.ele)
    if (lngLat.length < 2 || ele.length !== lngLat.length) return null
    if (!Number.isFinite(track.ascend)) return null
    return { key, lngLat, ele, ascend: track.ascend }
  } catch {
    return null
  }
}

/**
 * Reads the relief of the edges (one request per chunk, one after the other) into `profiles`, by
 * key: the chunks answered before a failure are kept. An edge the server answered nothing usable
 * for is not added. Throws on a failed request.
 */
export async function readDirectProfiles(
  edges: StraightEdge[],
  teamSlug: string | undefined,
  profiles: Map<string, DirectProfile>,
  signal?: AbortSignal
): Promise<void> {
  for (const chunk of chunkEdges(edges)) {
    signal?.throwIfAborted()
    // Silent on failure: the climb stays the net one between the ends
    const response = await lineElevation(
      { teamSlug, lines: chunk.map((e) => ({ from: e.from, to: e.to })) },
      { skipErrorToast: true },
      signal
    )
    if (response.lines.length !== chunk.length) continue
    chunk.forEach((edge, i) => {
      const profile = decodeProfile(edge.key, response.lines[i])
      if (profile) profiles.set(edge.key, profile)
    })
  }
}

/** An old backend (rolling deployment) does not know the endpoint: the feature is off for the session. */
export function isElevationUnsupported(error: unknown): boolean {
  const status = apiErrorStatus(error)
  return status === 404 || status === 405
}
