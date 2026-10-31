/**
 * The names a GPX file carries, read in the browser when the file is chosen: its document name
 * (`<metadata><name>`, or `<gpx><name>` in GPX 1.0), the name of each of its tracks and routes, and its file
 * name. They are offered as the route's name; the default follows the server's rule for a planner
 * import (`GpxProcessingService.documentName`): the document, else the first track, else the file.
 */

/** Same cap as the server's `GpxImportService.MAX_NAME_LENGTH`. */
const MAX_NAME_LENGTH = 250

export interface GpxNames {
  /** File name without its `.gpx` extension. */
  fileName: string
  documentName: string | null
  /** Names of the tracks and routes (`<trk>`, `<rte>`) holding at least one point, in file order (blank names dropped). */
  trackNames: string[]
}

function clean(raw: string | null | undefined): string | null {
  if (!raw) return null
  // eslint-disable-next-line no-control-regex
  const cleaned = raw.replace(/[\u0000-\u001f\u007f]/g, ' ').trim()
  if (!cleaned) return null
  return cleaned.length > MAX_NAME_LENGTH ? cleaned.slice(0, MAX_NAME_LENGTH).trim() : cleaned
}

/** The point element of each kind of path a GPX holds. */
const POINT_OF: Record<string, string | undefined> = { trk: 'trkpt', rte: 'rtept' }

/** The text of the first direct child named `name` (namespace-agnostic). */
function childName(el: Element): string | null {
  for (const child of Array.from(el.children)) {
    if (child.localName === 'name') return clean(child.textContent)
  }
  return null
}

export function gpxBaseName(fileName: string): string {
  const trimmed = fileName.trim()
  return /\.gpx$/i.test(trimmed) && trimmed.length > 4 ? trimmed.slice(0, -4) : trimmed
}

/** Reads the names out of a GPX document's text; an unreadable file yields only its file name. */
export function parseGpxNames(fileName: string, xml: string): GpxNames {
  const names: GpxNames = { fileName: gpxBaseName(fileName), documentName: null, trackNames: [] }
  let doc: Document
  try {
    doc = new DOMParser().parseFromString(xml, 'application/xml')
  } catch {
    return names
  }
  const root = doc.documentElement
  if (!root || root.localName !== 'gpx') return names

  const metadata = Array.from(root.children).find((c) => c.localName === 'metadata')
  names.documentName = (metadata && childName(metadata)) || childName(root)

  // Tracks and routes alike, in file order: the server's parser reads a <rte> as a track too
  for (const child of Array.from(root.children)) {
    const point = POINT_OF[child.localName]
    if (!point || child.getElementsByTagNameNS('*', point).length === 0) continue
    const name = childName(child)
    if (name) names.trackNames.push(name)
  }
  return names
}

export async function readGpxNames(file: File): Promise<GpxNames> {
  try {
    return parseGpxNames(file.name, await file.text())
  } catch {
    return { fileName: gpxBaseName(file.name), documentName: null, trackNames: [] }
  }
}

/** Every distinct name, the default first: document, tracks, then file name. */
export function gpxNameCandidates(names: GpxNames): string[] {
  const all = [names.documentName, ...names.trackNames, names.fileName]
  const seen = new Set<string>()
  const out: string[] = []
  for (const n of all) {
    if (n && !seen.has(n)) {
      seen.add(n)
      out.push(n)
    }
  }
  return out
}

/** The name a route created from this file takes when nobody picks one. */
export function defaultGpxName(names: GpxNames): string {
  return gpxNameCandidates(names)[0] ?? names.fileName
}
