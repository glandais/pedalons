import type { Chart as ChartJS, ChartType, Plugin, Scale } from 'chart.js'
import type { WaypointDto } from '@/api/dto'
import { WAYPOINT_PRIORITY, waypointTypeOf } from '@/lib/waypoints'
import { drawWaypointIcon, waypointDiscColor } from '../map/waypointIcons'

export interface WaypointMarkersOptions {
  /** The waypoints on the track (`distance` set): the off-track ones never reach the profile. */
  markers: WaypointDto[]
  selected: WaypointDto | null
}

declare module 'chart.js' {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars -- must repeat chart.js's parameter
  interface PluginOptionsByType<TType extends ChartType> {
    waypointMarkers?: WaypointMarkersOptions
  }
}

const ICON = 16
const ICON_SELECTED = 20
/** Distance, in pixels, within which a click picks a marker. */
export const WAYPOINT_PICK_PX = 8

/** `#rrggbb` with an alpha. */
function withAlpha(hex: string, alpha: number): string {
  const n = parseInt(hex.slice(1), 16)
  return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${alpha})`
}

function byPriority(a: WaypointDto, b: WaypointDto): number {
  return WAYPOINT_PRIORITY[waypointTypeOf(a.type)] - WAYPOINT_PRIORITY[waypointTypeOf(b.type)]
}

/**
 * The marker closest to the pixel `px` of the x axis, within {@link WAYPOINT_PICK_PX}; a more
 * important type wins a tie.
 */
export function waypointAt(
  markers: readonly WaypointDto[],
  scaleX: Pick<Scale, 'getPixelForValue'>,
  px: number
): WaypointDto | null {
  let best: WaypointDto | null = null
  let bestGap = WAYPOINT_PICK_PX + 1
  for (const marker of [...markers].sort(byPriority)) {
    if (marker.distance == null) continue
    const gap = Math.abs(scaleX.getPixelForValue(marker.distance) - px)
    if (gap <= WAYPOINT_PICK_PX && gap <= bestGap) {
      best = marker
      bestGap = gap
    }
  }
  return best
}

/** The options of the plugin on a chart, if it carries any. */
export function waypointMarkersOf(chart: ChartJS): WaypointMarkersOptions | undefined {
  return chart.options.plugins?.waypointMarkers as WaypointMarkersOptions | undefined
}

/**
 * Draws the route's waypoints on the elevation profile: a dashed rule at the distance and the type's
 * pictogram at the top. Only what falls inside the displayed range, so a zoom is respected. Always
 * in the chart's plugin list (react-chartjs-2 reads that list once); the data travel in the options.
 */
export const waypointMarkersPlugin: Plugin<'line'> = {
  id: 'waypointMarkers',
  afterDatasetsDraw: (chart) => {
    const options = waypointMarkersOf(chart as ChartJS)
    if (!options || options.markers.length === 0) return
    const { ctx, chartArea } = chart
    const x = chart.scales.x
    if (!x) return
    ctx.save()
    ctx.beginPath()
    ctx.rect(
      chartArea.left - ICON,
      0,
      chartArea.right - chartArea.left + 2 * ICON,
      chartArea.bottom
    )
    ctx.clip()
    for (const marker of [...options.markers].sort(byPriority)) {
      if (marker.distance == null || marker.distance < x.min || marker.distance > x.max) continue
      const px = x.getPixelForValue(marker.distance)
      const selected = marker === options.selected
      ctx.save()
      ctx.beginPath()
      if (!selected) ctx.setLineDash([3, 3])
      ctx.moveTo(px, chartArea.top)
      ctx.lineTo(px, chartArea.bottom)
      ctx.lineWidth = selected ? 2 : 1
      ctx.strokeStyle = withAlpha(waypointDiscColor(marker.type), selected ? 1 : 0.5)
      ctx.stroke()
      ctx.restore()
      drawWaypointIcon(ctx, marker.type, px, chartArea.top + 9, selected ? ICON_SELECTED : ICON, {
        selected,
      })
    }
    ctx.restore()
  },
}
