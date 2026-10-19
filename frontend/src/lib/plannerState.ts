// The editing state of the route planner, as it is saved with the track and read back when the
// route is opened again (docs/LEDGER_*.md WEB-100, C4a; format and bounds: docs/plans/
// 2026-10-17-editeur-parcours-web.md, backend `PlannerStates`).
//
// A route of n pieces has n + 1 junctions: junction k opens piece k and junction k + 1 closes it. A
// junction carries its coordinates; a piece carries only its interior, so the pieces are contiguous
// by construction. Serialising happens at save time only; restoring makes no request.
import {
  PlannerJunctionKind,
  PlannerPieceMode,
  RouterProfile,
  type PlannerJunction,
  type PlannerPiece,
  type PlannerSource as PlannerSourceDto,
  type PlannerState,
} from '@/api/dto'
import {
  computeRouteFromPieces,
  createPoint,
  cumulativeClimb,
  edgeMode,
  type EdgeMode,
  type PlannerSource,
  type Route,
  type RoutePoint,
} from '@/lib/planner'
import { decode1, decode2, encode1, encode2 } from '@/lib/polyline'

export type { PlannerSource } from '@/lib/planner'
export { sourceOf } from '@/lib/planner'

// Same bounds as the backend (GpxLimits): a state past them is not sent, the points are.
export const PLANNER_STATE_VERSION = 1
export const MAX_PLANNER_PIECES = 2_000
export const MAX_PLANNER_SOURCES = 8
export const MAX_PLANNER_POINTS = 100_000
export const MAX_PLANNER_STATE_CHARS = 2_000_000

const MAX_ASCEND_SCALE = 100
const MIN_ASCEND_SCALE = 1e-3

/** The saved state cannot be read back (unknown version, malformed or inconsistent content). */
export class PlannerStateFormatError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'PlannerStateFormatError'
  }
}

const round6 = (x: number) => Math.round(x * 1e6) / 1e6
const round1 = (x: number) => Math.round(x * 10) / 10
const round2 = (x: number) => Math.round(x * 100) / 100

function hasProvenance(p: RoutePoint, sources: PlannerSource[]): boolean {
  return (
    p.imported &&
    p.sourceId !== undefined &&
    p.sourceIdx !== undefined &&
    sources[p.sourceId] !== undefined
  )
}

/**
 * The state of a route, or null when there is none to save: under two points, or past the bounds
 * (then the caller sends the points of the route instead). O(n).
 */
export function serializePlannerState(
  route: Route,
  sources: PlannerSource[],
  profile: RouterProfile
): PlannerState | null {
  const pts = route.points
  const n = pts.length
  if (n < 2) return null

  // Edge into each point
  const mode: EdgeMode[] = new Array(n)
  for (let i = 1; i < n; i++) {
    const m = edgeMode(pts, i)
    // An edge that reads as imported but whose file is not known cannot be saved as a stretch of it:
    // it is saved as the line it is.
    mode[i] =
      m === 'IMPORTED' && !(hasProvenance(pts[i], sources) && hasProvenance(pts[i - 1], sources))
        ? 'ROUTED'
        : m
  }

  // Junctions: the ends, every control point, every change of the nature of the edge, and every
  // imported point that is not strictly inside a stretch of its file (a join whose import is gone
  // on both sides is still a handle, and its provenance lets a later deletion rely on it).
  const J: number[] = [0]
  for (let i = 1; i < n - 1; i++) {
    const flanked = mode[i] === 'IMPORTED' && mode[i + 1] === 'IMPORTED'
    if (pts[i].manual || mode[i] !== mode[i + 1] || (pts[i].imported && !flanked)) J.push(i)
  }
  J.push(n - 1)
  const pieceCount = J.length - 1
  if (pieceCount > MAX_PLANNER_PIECES) return null

  // Sources: only those referenced, trimmed to the range of indices that is, renumbered in the
  // order of first reference.
  const ranges = new Map<number, { lo: number; hi: number; next: number }>()
  for (const i of J) {
    const p = pts[i]
    if (!hasProvenance(p, sources)) continue
    const r = ranges.get(p.sourceId!)
    if (r) {
      r.lo = Math.min(r.lo, p.sourceIdx!)
      r.hi = Math.max(r.hi, p.sourceIdx!)
    } else {
      ranges.set(p.sourceId!, { lo: p.sourceIdx!, hi: p.sourceIdx!, next: ranges.size })
    }
  }
  if (ranges.size > MAX_PLANNER_SOURCES) return null
  let chars = 0
  let sourcePoints = 0
  const dtoSources: PlannerSourceDto[] = []
  for (const [id, r] of ranges) {
    const src = sources[id]
    if (src.coords.length < 2) return null
    // A source has at least two points
    if (r.hi === r.lo) {
      if (r.hi + 1 < src.coords.length) r.hi++
      else r.lo--
    }
    const slice = src.coords.slice(r.lo, r.hi + 1)
    sourcePoints += slice.length
    const line = encode2(slice)
    // A point without elevation takes the previous one's (the first ones, the next known): one gap
    // must not cost the whole file its climb and its profile.
    const firstEle = slice.find((c) => typeof c[2] === 'number' && Number.isFinite(c[2]))?.[2]
    let last = firstEle
    const filled = slice.map((c) => {
      if (typeof c[2] === 'number' && Number.isFinite(c[2])) last = c[2]
      return last as number
    })
    const ele = firstEle !== undefined ? encode1(filled) : undefined
    chars += line.length + (ele?.length ?? 0)
    let scale = Number.isFinite(src.ascendScale) ? src.ascendScale : 1
    // The server's climb of an imported file travels with it, rebased on the first point kept. The
    // scale stays the ratio to the raw sum, so a reader that ignores `climb` reaches the same total.
    let climb: string | undefined
    if (src.serverClimb && ele !== undefined && src.cumul.length === src.coords.length) {
      const base = src.cumul[r.lo]
      const rebased = src.cumul.slice(r.lo, r.hi + 1).map((c) => Math.max(0, c - base))
      climb = encode1(rebased)
      chars += climb.length
      const raw = cumulativeClimb(filled.map((e) => [0, 0, e]))
      const rawTotal = raw[raw.length - 1]
      scale = rawTotal > 0 ? rebased[rebased.length - 1] / rawTotal : 1
    }
    dtoSources[r.next] = {
      line,
      ...(ele !== undefined && { ele }),
      ...(climb !== undefined && { climb }),
      ascendScale: Math.min(MAX_ASCEND_SCALE, Math.max(MIN_ASCEND_SCALE, scale)),
    }
  }
  if (sourcePoints > MAX_PLANNER_POINTS) return null

  const provenance = (p: RoutePoint) => {
    if (!hasProvenance(p, sources)) return {}
    const r = ranges.get(p.sourceId!)!
    return { source: r.next, idx: p.sourceIdx! - r.lo }
  }

  const junctions: PlannerJunction[] = J.map((i) => {
    const p = pts[i]
    const ele = p.ele
    return {
      kind: p.manual ? PlannerJunctionKind.CONTROL : PlannerJunctionKind.JOIN,
      lng: round6(p.lng),
      lat: round6(p.lat),
      ...(typeof ele === 'number' && ele >= -1000 && ele <= 10000 && { ele: round1(ele) }),
      ...provenance(p),
    }
  })

  const pieces: PlannerPiece[] = []
  let derived = J.length
  for (let k = 0; k < pieceCount; k++) {
    const a = J[k]
    const b = J[k + 1]
    const m = mode[a + 1]
    if (m === 'IMPORTED') {
      const entry = junctions[k]
      const exit = junctions[k + 1]
      if (entry.source === undefined || entry.source !== exit.source) return null
      pieces.push({
        mode: PlannerPieceMode.IMPORTED,
        source: entry.source,
        from: entry.idx,
        to: exit.idx,
      })
      derived += exit.idx! - entry.idx! - 1
      continue
    }
    const interior = pts.slice(a + 1, b)
    const line = encode2(interior.map((p) => [p.lng, p.lat]))
    chars += line.length
    derived += interior.length
    const piece: PlannerPiece = {
      mode: m === 'DIRECT' ? PlannerPieceMode.DIRECT : PlannerPieceMode.ROUTED,
      line,
    }
    if (interior.length > 0 && interior.every((p) => typeof p.ele === 'number')) {
      piece.ele = encode1(interior.map((p) => p.ele as number))
      chars += piece.ele.length
    }
    if (m === 'ROUTED') {
      let sum = 0
      let any = false
      for (let i = a + 1; i <= b; i++) {
        const climb = pts[i].legAscend
        if (climb !== undefined) {
          sum += climb
          any = true
        }
      }
      if (any) piece.ascend = Math.max(0, round2(sum))
    }
    pieces.push(piece)
  }
  if (chars > MAX_PLANNER_STATE_CHARS) return null
  if (derived < 2 || derived > MAX_PLANNER_POINTS) return null

  return {
    version: PLANNER_STATE_VERSION,
    profile,
    sources: dtoSources,
    junctions,
    pieces,
  }
}

function sourceFromDto(dto: PlannerSourceDto): PlannerSource {
  const lngLat = decode2(dto.line)
  if (lngLat.length < 2) throw new PlannerStateFormatError('source under two points')
  let coords: number[][] = lngLat
  if (dto.ele !== undefined) {
    const ele = decode1(dto.ele)
    if (ele.length !== lngLat.length) throw new PlannerStateFormatError('source elevations')
    coords = lngLat.map((c, i) => [c[0], c[1], ele[i]])
  }
  if (dto.climb !== undefined) {
    const cumul = decode1(dto.climb)
    if (dto.ele === undefined || cumul.length !== coords.length) {
      throw new PlannerStateFormatError('source climb')
    }
    return { coords, cumul, ascendScale: 1, serverClimb: true }
  }
  const scale = dto.ascendScale
  return {
    coords,
    cumul: cumulativeClimb(coords),
    ascendScale: Number.isFinite(scale) && scale > 0 ? scale : 1,
  }
}

/**
 * The route a saved state describes, and the sources it refers to. No request: the points are the
 * junctions and the pieces' interiors, simplified piece by piece.
 */
export function restorePlannerState(state: PlannerState): {
  route: Route
  sources: PlannerSource[]
} {
  if (state.version !== PLANNER_STATE_VERSION) {
    throw new PlannerStateFormatError(`unknown planner state version ${state.version}`)
  }
  try {
    return restore(state)
  } catch (e) {
    if (e instanceof PlannerStateFormatError) throw e
    throw new PlannerStateFormatError(e instanceof Error ? e.message : 'malformed planner state')
  }
}

function restore(state: PlannerState): { route: Route; sources: PlannerSource[] } {
  const { junctions, pieces } = state
  if (pieces.length < 1 || junctions.length !== pieces.length + 1) {
    throw new PlannerStateFormatError('junctions and pieces do not match')
  }
  const sources = state.sources.map(sourceFromDto)

  const importedPoint = (sourceId: number, idx: number, lng?: number, lat?: number) => {
    const src = sources[sourceId]
    const c = src?.coords[idx]
    if (!c) throw new PlannerStateFormatError('reference outside the source')
    const p = createPoint(lng ?? c[0], lat ?? c[1], c[2], true)
    p.sourceId = sourceId
    p.sourceIdx = idx
    p.importAscend = src.cumul[idx] * src.ascendScale
    return p
  }
  const junctionPoint = (j: PlannerJunction) => {
    let p: RoutePoint
    if (j.source !== undefined && j.idx !== undefined) {
      p = importedPoint(j.source, j.idx, j.lng, j.lat)
      p.ele = j.ele ?? p.ele
    } else {
      p = createPoint(j.lng, j.lat, j.ele)
    }
    p.manual = j.kind === PlannerJunctionKind.CONTROL
    return p
  }

  const points: RoutePoint[] = [junctionPoint(junctions[0])]
  const junctionIndices = [0]
  pieces.forEach((piece, k) => {
    const exit = junctionPoint(junctions[k + 1])
    if (piece.mode === PlannerPieceMode.IMPORTED) {
      const entry = junctions[k]
      if (
        piece.source === undefined ||
        piece.from === undefined ||
        piece.to === undefined ||
        piece.from >= piece.to ||
        entry.source !== piece.source ||
        entry.idx !== piece.from ||
        junctions[k + 1].source !== piece.source ||
        junctions[k + 1].idx !== piece.to
      ) {
        throw new PlannerStateFormatError('imported piece')
      }
      for (let i = piece.from + 1; i < piece.to; i++) points.push(importedPoint(piece.source, i))
    } else {
      const direct = piece.mode === PlannerPieceMode.DIRECT
      const line = decode2(piece.line ?? '')
      const ele = piece.ele !== undefined ? decode1(piece.ele) : undefined
      if (ele && ele.length !== line.length) throw new PlannerStateFormatError('piece elevations')
      line.forEach((c, i) => {
        const p = createPoint(c[0], c[1], ele?.[i])
        p.direct = direct
        points.push(p)
      })
      exit.direct = direct
      // `?? 0`: edgeMode must read ROUTED even between two imported junctions
      exit.legAscend = direct ? undefined : (piece.ascend ?? 0)
    }
    points.push(exit)
    junctionIndices.push(points.length - 1)
  })
  return { route: computeRouteFromPieces(points, junctionIndices), sources }
}
