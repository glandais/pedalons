import type { Scale } from 'chart.js'

/** Room each label of the elevation axis takes, about as Chart.js spaces its own (a 12 px font). */
const PX_PER_TICK = 20

/** The round step (1, 2 or 5 × 10ⁿ) closest above `raw`. */
export function niceStep(raw: number): number {
  const power = Math.pow(10, Math.floor(Math.log10(raw)))
  const fraction = raw / power
  const nice = fraction <= 1 ? 1 : fraction <= 2 ? 2 : fraction <= 5 ? 5 : 10
  return nice * power
}

/**
 * The elevation axis's ticks, round in the displayed unit but placed in metres — the profile's
 * data stays in metres. Chart.js would pick round numbers of metres, which read as 65.6, 131.2…
 * once labelled in feet (docs/LEDGER_*.md WEB-187). Strictly inside the bounds, as Chart.js's own
 * with `includeBounds: false`: the bounds are the route's raw min and max, never round.
 */
export function elevationTicks(
  minMeters: number,
  maxMeters: number,
  multiplier: number,
  maxTicks: number
): number[] {
  const low = minMeters * multiplier
  const high = maxMeters * multiplier
  if (!(high > low) || maxTicks < 2) return []
  const step = niceStep((high - low) / maxTicks)
  const ticks: number[] = []
  for (let i = Math.ceil(low / step); i * step <= high; i++) {
    const value = i * step
    if (value > low && value < high) ticks.push(value / multiplier)
  }
  return ticks
}

/**
 * The y scale's `afterBuildTicks` shared by the two elevation profiles: outside metres, round
 * ticks in the displayed unit; in metres, Chart.js's own (undefined).
 */
export function elevationAfterBuildTicks(multiplier: number) {
  if (multiplier === 1) return undefined
  return (axis: Scale) => {
    const count = Math.max(2, Math.ceil(axis.height / PX_PER_TICK))
    axis.ticks = elevationTicks(axis.min, axis.max, multiplier, count).map((value) => ({ value }))
  }
}
