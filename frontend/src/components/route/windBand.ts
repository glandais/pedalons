import type { Chart as ChartJS, ChartType, Plugin } from 'chart.js'
import type { RelativeWind } from '@/api/dto'
import { NEUTRAL_COLOR } from '../map/mapUtils'
import type { ChartWithCrosshair } from './chartCrosshair'

/**
 * The wind under a route's profile, in the Météo mode (ledger WEB-129): the relative wind of the
 * segment each point starts, indexed as the profile indexes its points — the tracks' points laid one
 * after the other —, undefined where no known stretch covers it; and the colours the map's line
 * draws them in.
 */
export interface ProfileWind {
  winds: readonly (RelativeWind | undefined)[]
  colors: Record<RelativeWind, string>
}

/** A stretch of the band in one colour, from one distance of the profile's axis to another. */
export interface BandRun {
  from: number
  to: number
  color: string
}

export interface WindBandOptions {
  runs: BandRun[]
}

declare module 'chart.js' {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars -- must repeat chart.js's parameter
  interface PluginOptionsByType<TType extends ChartType> {
    windBand?: WindBandOptions
  }
}

/** Height of the band, pixels, and its distance from the bottom of the plot. */
export const WIND_BAND_HEIGHT = 6
export const WIND_BAND_GAP = 2
/** The room the x axis' labels leave above them for the band (`ticks.padding`, tick marks off). */
export const WIND_BAND_LABEL_PADDING = WIND_BAND_GAP + WIND_BAND_HEIGHT + 4

/** The band's colour of every point: its wind's, the neutral blue where no wind is known. */
export function windBandColors(wind: ProfileWind, count: number): string[] {
  return Array.from({ length: count }, (_, i) => {
    const kind = wind.winds[i]
    // A wind this build does not know yet reads as unknown, never as its neighbour's colour
    return (kind && wind.colors[kind]) || NEUTRAL_COLOR
  })
}

/**
 * The band's stretches: each segment of a track (point `i` to `i + 1`) in the colour of point `i`,
 * placed at the distances `xs` the profile draws its points at, consecutive segments of one colour
 * merged. Never across two tracks: the segment from the last point of one to the first of the next
 * is not ridden, and the profile's axis may jump there (ledger WEB-81). `trackSizes` is the number
 * of points of each track, in the order `xs` and `colors` lay them.
 */
export function windBandRuns(
  xs: ArrayLike<number>,
  colors: readonly string[],
  trackSizes: readonly number[]
): BandRun[] {
  const runs: BandRun[] = []
  let start = 0
  for (const size of trackSizes) {
    let run: BandRun | null = null
    for (let i = start; i < start + size - 1; i++) {
      if (run && run.color === colors[i]) {
        run.to = xs[i + 1]
      } else {
        run = { from: xs[i], to: xs[i + 1], color: colors[i] }
        runs.push(run)
      }
    }
    start += size
  }
  return runs
}

/** The plugin's options on a chart, if it carries any. */
export function windBandOf(chart: ChartJS): WindBandOptions | undefined {
  return chart.options.plugins?.windBand as WindBandOptions | undefined
}

/**
 * Draws the wind band just under the profile's plot, on its x axis — so it follows the zoom —, and
 * the cursor's line across it. Always in the chart's plugin list (react-chartjs-2 reads that list
 * once); the stretches travel in the options, none outside the Météo mode.
 */
export const windBandPlugin: Plugin<'line'> = {
  id: 'windBand',
  afterDatasetsDraw: (chart) => {
    const options = windBandOf(chart as ChartJS)
    const x = chart.scales.x
    if (!options || options.runs.length === 0 || !x) return
    const { ctx, chartArea } = chart
    const top = chartArea.bottom + WIND_BAND_GAP
    ctx.save()
    ctx.beginPath()
    ctx.rect(chartArea.left, top, chartArea.right - chartArea.left, WIND_BAND_HEIGHT)
    ctx.clip()
    for (const run of options.runs) {
      const from = x.getPixelForValue(run.from)
      const to = x.getPixelForValue(run.to)
      if (Math.max(from, to) < chartArea.left || Math.min(from, to) > chartArea.right) continue
      ctx.fillStyle = run.color
      // Half a pixel either side, so two stretches never leave a hairline between them
      ctx.fillRect(Math.min(from, to) - 0.5, top, Math.abs(to - from) + 1, WIND_BAND_HEIGHT)
    }
    const crosshair = (chart as ChartWithCrosshair).crosshair
    if (crosshair?.x) {
      ctx.beginPath()
      ctx.moveTo(crosshair.x, top)
      ctx.lineTo(crosshair.x, top + WIND_BAND_HEIGHT)
      ctx.lineWidth = 2
      ctx.strokeStyle = crosshair.color || 'rgba(0, 0, 0, 0.3)'
      ctx.stroke()
    }
    ctx.restore()
  },
}
