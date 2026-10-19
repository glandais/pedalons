// How the surface of the route being drawn is coloured (WEB-100 C1a), on the map and on the
// profile. Its four classes take the colours of the saved route's (`trackSurface.ts`, C1b), whose
// families are the business colour code's (docs/BRANDING.md §3.6, `TrackSurface`): a paved edge is
// asphalt's grey (ROAD's on a route's badge), an unpaved one the compacted orange (GRAVEL's), so the
// colour means the same thing while drawing, once saved and on the badge. What is not known is a
// paler grey than paved, and what is not on the network (a straight line, drawn dashed) a medium
// one. The greys depend on the colour scheme: the dark theme loads the basemap's dark variant, where
// a dark grey vanishes, so there paved is the light one and unknown the dimmer.
import type { MantineTheme } from '@mantine/core'
import { TrackSurface } from '@/api/dto'
import type { SurfaceClass } from '@/lib/planner'
import { trackSurfaceColors } from '@/lib/trackSurface'

/** What the profile and the map colour by. */
export type PlannerColorBy = 'grade' | 'surface'

/** The classes of the legend, in its order. */
export const SURFACE_CLASSES: SurfaceClass[] = ['paved', 'unpaved', 'unknown', 'offNetwork']

/** The class of the saved route whose colour each class of the route being drawn takes. */
const CLASS: Record<SurfaceClass, TrackSurface> = {
  paved: TrackSurface.PAVED,
  unpaved: TrackSurface.GRAVEL,
  unknown: TrackSurface.UNKNOWN,
  offNetwork: TrackSurface.OFF_NETWORK,
}

/** The colour of every class, resolved from the Mantine theme for the given colour scheme. */
export function surfaceColors(
  theme: MantineTheme,
  colorScheme: 'light' | 'dark'
): Record<SurfaceClass, string> {
  const saved = trackSurfaceColors(theme, colorScheme)
  return {
    paved: saved[CLASS.paved],
    unpaved: saved[CLASS.unpaved],
    unknown: saved[CLASS.unknown],
    offNetwork: saved[CLASS.offNetwork],
  }
}
