/**
 * What a route's create or edit page is handed through the location state, besides a generated
 * route (`readGeneratedHandoff`): the GPX file already chosen elsewhere (« Importer des GPX » with
 * one file, « Remplacer le fichier GPX »), and « Tracer sur la carte », which opens the creation on
 * the planner rather than on the file field.
 */
export interface RouteEditorHandoff {
  gpxFile?: File
  draw?: boolean
}

export function readGpxFileHandoff(state: unknown): File | undefined {
  const file = (state as { gpxFile?: unknown } | null | undefined)?.gpxFile
  return typeof File !== 'undefined' && file instanceof File ? file : undefined
}

export function readDrawHandoff(state: unknown): boolean {
  return (state as { draw?: unknown } | null | undefined)?.draw === true
}
