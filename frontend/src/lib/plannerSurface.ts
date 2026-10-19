// How the surface of the route being drawn is coloured (WEB-100 C1a), on the map and on the
// profile. The families are the business colour code's (docs/BRANDING.md §3.6, `SurfaceType`): a
// paved edge is ROAD's grey, an unpaved one GRAVEL's orange, so the colour means the same thing
// here as on a route's badge. What is not known is a lighter grey (still readable on a white strip
// and a light basemap), and what is not on the network (a straight line, drawn dashed) a medium one.
// The classes the detailed surface will add (C1b) take their families from the same code.
import type { MantineTheme } from '@mantine/core'
import { SURFACE_TYPE_COLORS, type BadgeFamily } from '@/lib/badgeColors.generated'
import type { SurfaceClass } from '@/lib/planner'

/** What the profile and the map colour by. */
export type PlannerColorBy = 'grade' | 'surface'

/** The classes of the legend, in its order. */
export const SURFACE_CLASSES: SurfaceClass[] = ['paved', 'unpaved', 'unknown', 'offNetwork']

const FAMILY: Record<SurfaceClass, { family: BadgeFamily; shade: number }> = {
  paved: { family: SURFACE_TYPE_COLORS.ROAD, shade: 7 },
  unpaved: { family: SURFACE_TYPE_COLORS.GRAVEL, shade: 6 },
  unknown: { family: SURFACE_TYPE_COLORS.ROAD, shade: 4 },
  offNetwork: { family: SURFACE_TYPE_COLORS.ROAD, shade: 5 },
}

/** The colour of every class, resolved from the Mantine theme. */
export function surfaceColors(theme: MantineTheme): Record<SurfaceClass, string> {
  const colorOf = (c: SurfaceClass) => theme.colors[FAMILY[c].family][FAMILY[c].shade]
  return {
    paved: colorOf('paved'),
    unpaved: colorOf('unpaved'),
    unknown: colorOf('unknown'),
    offNetwork: colorOf('offNetwork'),
  }
}
