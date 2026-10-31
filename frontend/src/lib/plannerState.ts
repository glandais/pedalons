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
  type UnpavedSpan,
} from '@/api/dto'
import {
  computeRouteFromPieces,
  createPoint,
  cumulativeClimb,
  edgeMode,
  pieceShape,
  type EdgeMode,
  type PlannerSource,
  type Route,
  type RoutePoint,
  isUnpavedShare,
  legShape,
  shapeOf,
} from '@/lib/planner'
import { decode1, decode2, encode1, encode2 } from '@/lib/polyline'

export type { PlannerSource } from '@/lib/planner'
export { sourceOf } from '@/lib/planner'

// Same bounds as the backend (GpxLimits): a state past them is not sent, the points are.
export const PLANNER_STATE_VERSION = 1
export const MAX_PLANNER_PIECES = 2_000
export const MAX_PLANNER_SOURCES = 8
export const MAX_PLANNER_POINTS = 100_000
export const MAX_PLANNER_UNPAVED_SPANS = 50_000
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
 *
 * <p>The raw shapes (docs/LEDGER_*.md API-147, phase C) never cost the save: when the state with
 * all of them is past the bounds, the largest are dropped until it fits, and at worst all of them
 * (the state of a client before them). At most four passes.
 */
export function serializePlannerState(
  route: Route,
  sources: PlannerSource[],
  profile: RouterProfile
): PlannerState | null {
  let pass = build(route, sources, profile, () => true)
  if (pass.state || pass.shapes.length === 0 || !pass.past) return pass.state
  // A source sent whole for its shape pushed the sources past their points: none goes whole
  const noSource = (key: string) => !key.startsWith('source:')
  if (pass.past === 'points') {
    pass = build(route, sources, profile, noSource)
    if (pass.state || pass.past !== 'chars') return pass.state
  }
  // Past the characters: the largest shapes first, until they fit. Dropping a source's shape also
  // trims the source again, which only saves more: the estimate errs on the safe side.
  let excess = pass.chars - MAX_PLANNER_STATE_CHARS
  const dropped = new Set<string>()
  for (const { key, length } of [...pass.shapes].sort((x, y) => y.length - x.length)) {
    if (excess <= 0) break
    dropped.add(key)
    excess -= length
  }
  const kept = pass.shapes.filter(({ key }) => !dropped.has(key))
  if (kept.length > 0) {
    const keptKeys = new Set(kept.map(({ key }) => key))
    const some = build(route, sources, profile, (key) => keptKeys.has(key))
    if (some.state) return some.state
  }
  return build(route, sources, profile, () => false).state
}

/** A raw shape the state carries: `piece:<k>` or `source:<editor source id>`, and its length. */
interface ShapeEntry {
  key: string
  length: number
}

/**
 * One pass of {@link serializePlannerState}, carrying the raw shapes `keep` accepts. `past`: the
 * state was refused only for a bound the shapes count in (its characters, the points of its
 * sources), so a pass with fewer shapes may fit; `chars` and `shapes` are then what it held.
 */
function build(
  route: Route,
  sources: PlannerSource[],
  profile: RouterProfile,
  keep: (key: string) => boolean
): {
  state: PlannerState | null
  chars: number
  shapes: ShapeEntry[]
  past?: 'chars' | 'points'
} {
  const shapes: ShapeEntry[] = []
  const refused = { state: null, chars: 0, shapes }
  const pts = route.points
  const n = pts.length
  if (n < 2) return refused

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
  if (pieceCount > MAX_PLANNER_PIECES) return refused

  // The sources an imported piece is cut from: only their raw shape is worth sending
  const cut = new Set<number>()
  for (let k = 0; k < pieceCount; k++) {
    if (mode[J[k] + 1] === 'IMPORTED') cut.add(pts[J[k]].sourceId!)
  }

  // Sources: only those referenced, trimmed to the range of indices that is, renumbered in the
  // order of first reference. A source sent with its raw shape is sent whole: the shape is the
  // whole file, and the server checks it against the whole line.
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
  if (ranges.size > MAX_PLANNER_SOURCES) return refused
  let chars = 0
  let sourcePoints = 0
  const dtoSources: PlannerSourceDto[] = []
  for (const [id, r] of ranges) {
    const src = sources[id]
    if (src.coords.length < 2) return refused
    const shapeKey = `source:${id}`
    const shape = src.shape !== undefined && cut.has(id) && keep(shapeKey) ? src.shape : undefined
    if (shape !== undefined) {
      r.lo = 0
      r.hi = src.coords.length - 1
      chars += shape.length
      shapes.push({ key: shapeKey, length: shape.length })
    }
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
      ...(shape !== undefined && { shape }),
    }
  }
  // Past the bound only because a source went whole for its shape: a pass without it may fit
  if (sourcePoints > MAX_PLANNER_POINTS) return { ...refused, past: 'points' }

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
      if (entry.source === undefined || entry.source !== exit.source) return refused
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
      // Only when the router said something about every edge of the piece: a gap is not « paved »
      const spans = unpavedSpans(pts, a, b)
      if (spans) piece.unpaved = spans
      // The router's raw geometry, when the piece is still exactly the leg it drew
      const shape = pieceShape(pts, a, b)
      const shapeKey = `piece:${k}`
      if (shape !== undefined && keep(shapeKey)) {
        piece.shape = shape
        chars += shape.length
        shapes.push({ key: shapeKey, length: shape.length })
      }
    }
    pieces.push(piece)
  }
  if (derived < 2 || derived > MAX_PLANNER_POINTS) return refused
  if (chars > MAX_PLANNER_STATE_CHARS) return { ...refused, chars, past: 'chars' }

  return {
    state: {
      version: PLANNER_STATE_VERSION,
      profile,
      sources: dtoSources,
      junctions,
      pieces,
    },
    chars,
    shapes,
  }
}

/**
 * The unpaved runs of the edges of `pts[a..b]` (half-open, ascending, never adjacent: the shape
 * the server checks), edge 0 being the one into `pts[a + 1]`. Undefined when the surface of one of
 * the edges is unknown, or past the server's bound.
 */
function unpavedSpans(pts: RoutePoint[], a: number, b: number): UnpavedSpan[] | undefined {
  const spans: UnpavedSpan[] = []
  let from = -1
  for (let i = a + 1; i <= b; i++) {
    const share = pts[i].unpaved
    if (share === undefined) return undefined
    const edge = i - a - 1
    if (isUnpavedShare(share)) {
      if (from < 0) from = edge
    } else if (from >= 0) {
      spans.push({ from, to: edge })
      from = -1
    }
  }
  if (from >= 0) spans.push({ from, to: b - a })
  return spans.length <= MAX_PLANNER_UNPAVED_SPANS ? spans : undefined
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
    return { coords, cumul, ascendScale: 1, serverClimb: true, ...shapeOf(dto) }
  }
  const scale = dto.ascendScale
  return {
    coords,
    cumul: cumulativeClimb(coords),
    ascendScale: Number.isFinite(scale) && scale > 0 ? scale : 1,
    ...shapeOf(dto),
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

/** 1 for the edges of a piece inside one of its unpaved runs, 0 for the others. */
function unpavedFlags(piece: PlannerPiece, edges: number): number[] {
  const flags = new Array<number>(edges).fill(0)
  for (const { from, to } of piece.unpaved ?? []) {
    for (let e = Math.max(0, from); e < Math.min(edges, to); e++) flags[e] = 1
  }
  return flags
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
      // Edge e of the piece ends at its interior point e, the last one at the exit; a straight piece
      // is off the network and a piece without runs has an unknown surface
      const unpaved =
        direct || piece.unpaved === undefined ? undefined : unpavedFlags(piece, line.length + 1)
      line.forEach((c, i) => {
        const p = createPoint(c[0], c[1], ele?.[i])
        p.direct = direct
        p.unpaved = unpaved?.[i]
        points.push(p)
      })
      exit.unpaved = unpaved?.[line.length]
      exit.direct = direct
      // `?? 0`: edgeMode must read ROUTED even between two imported junctions
      exit.legAscend = direct ? undefined : (piece.ascend ?? 0)
      // The router's raw geometry goes back on the leg it was saved for, between these junctions
      const entry = junctions[k]
      exit.legShape =
        !direct && piece.shape !== undefined ? legShape(entry, exit, piece.shape) : undefined
    }
    points.push(exit)
    junctionIndices.push(points.length - 1)
  })
  return { route: computeRouteFromPieces(points, junctionIndices), sources }
}
