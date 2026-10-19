// Google-style polyline codec, as the planner state stores its coordinates and elevations
// (docs/LEDGER_*.md WEB-100, C4a). Same arithmetic as the backend's PolylineCodec: zigzag varints
// of the delta to the previous value, 5 bits per character.
//  - two dimensions: [lng, lat] pairs, written latitude first, at precision 6 (0.11 m);
//  - one dimension: a value times `factor` (10: tenths of a metre, for elevations).

const PRECISION = 1e6

function writeValue(out: string[], delta: number) {
  let v = delta < 0 ? -2 * delta - 1 : 2 * delta
  while (v >= 0x20) {
    out.push(String.fromCharCode(((v % 0x20) | 0x20) + 63))
    v = Math.floor(v / 0x20)
  }
  out.push(String.fromCharCode(v + 63))
}

function readValue(s: string, cursor: { i: number }): number {
  let result = 0
  let blocks = 0
  let b: number
  do {
    if (cursor.i >= s.length || blocks >= 7) throw new Error('polyline: malformed')
    const c = s.charCodeAt(cursor.i++)
    if (c < 63 || c > 126) throw new Error('polyline: malformed')
    b = c - 63
    result += (b % 0x20) * 2 ** (5 * blocks)
    blocks++
  } while (b >= 0x20)
  return result % 2 === 1 ? -(result + 1) / 2 : result / 2
}

/** Encodes `[lng, lat]` pairs (any further entry of a coordinate is ignored). */
export function encode2(coords: number[][]): string {
  const out: string[] = []
  let prevLat = 0
  let prevLng = 0
  for (const c of coords) {
    const lat = Math.round(c[1] * PRECISION)
    const lng = Math.round(c[0] * PRECISION)
    writeValue(out, lat - prevLat)
    writeValue(out, lng - prevLng)
    prevLat = lat
    prevLng = lng
  }
  return out.join('')
}

/** Decodes into `[lng, lat]` pairs; throws on a malformed string. */
export function decode2(encoded: string): number[][] {
  const out: number[][] = []
  const cursor = { i: 0 }
  let lat = 0
  let lng = 0
  while (cursor.i < encoded.length) {
    lat += readValue(encoded, cursor)
    if (cursor.i >= encoded.length) throw new Error('polyline: latitude without longitude')
    lng += readValue(encoded, cursor)
    out.push([lng / PRECISION, lat / PRECISION])
  }
  return out
}

export function encode1(values: number[], factor = 10): string {
  const out: string[] = []
  let prev = 0
  for (const v of values) {
    const x = Math.round(v * factor)
    writeValue(out, x - prev)
    prev = x
  }
  return out.join('')
}

export function decode1(encoded: string, factor = 10): number[] {
  const out: number[] = []
  const cursor = { i: 0 }
  let value = 0
  while (cursor.i < encoded.length) {
    value += readValue(encoded, cursor)
    out.push(value / factor)
  }
  return out
}
