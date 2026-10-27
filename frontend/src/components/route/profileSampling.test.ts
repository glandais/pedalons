import { describe, it, expect } from 'vitest'
import {
  BUCKETS_PER_WINDOW,
  breaksGradient,
  colorBreaks,
  SAMPLING_THRESHOLD,
  sampleProfile,
  sampledIndexOf,
} from './profileSampling'

/** A profile of `n` points, one meter apart, with a sawtooth elevation and a spike at `spike`. */
function profile(n: number, spike = -1) {
  const xs = Array.from({ length: n }, (_, i) => i)
  const ys = xs.map((i) => (i === spike ? 5000 : i % 7))
  return { xs, ys }
}

describe('sampleProfile', () => {
  it('keeps a short profile whole', () => {
    const { xs, ys } = profile(10)
    expect(
      sampleProfile(
        xs,
        ys,
        xs.map(() => 'a')
      )
    ).toEqual(xs)
  })

  it('thins a long profile to about two points per bucket, keeping its ends and peaks', () => {
    const n = 22_000
    const { xs, ys } = profile(n, 12_345)
    const sources = sampleProfile(
      xs,
      ys,
      xs.map(() => 'a')
    )
    expect(sources.length).toBeLessThanOrEqual(2 * BUCKETS_PER_WINDOW + 4)
    expect(sources[0]).toBe(0)
    expect(sources.at(-1)).toBe(n - 1)
    expect(sources).toContain(12_345)
    expect([...sources].sort((a, b) => a - b)).toEqual(sources)
  })

  it('keeps every point where the style changes', () => {
    const n = SAMPLING_THRESHOLD * 3
    const { xs, ys } = profile(n)
    const styles = xs.map((i) => (i >= 5001 && i < 5003 ? 'b' : 'a'))
    const sources = sampleProfile(xs, ys, styles)
    expect(sources).toContain(5001)
    expect(sources).toContain(5003)
  })

  it('samples a zoom window at its own resolution, with a window of margin on each side', () => {
    const n = 100_000
    const { xs, ys } = profile(n)
    const sources = sampleProfile(
      xs,
      ys,
      xs.map(() => 'a'),
      { min: 50_000, max: 51_000 }
    )
    expect(sources[0]).toBeLessThanOrEqual(49_000)
    expect(sources[0]).toBeGreaterThan(48_000)
    expect(sources.at(-1)).toBeGreaterThanOrEqual(52_000)
    expect(sources.at(-1)).toBeLessThan(53_000)
    const inWindow = sources.filter((i) => i >= 50_000 && i <= 51_000)
    expect(inWindow.length).toBeGreaterThan(BUCKETS_PER_WINDOW / 2)
  })
})

describe('sampledIndexOf', () => {
  const xs = [0, 10, 20, 30, 40]
  const sources = [0, 2, 4]

  it('finds the drawn point closest in distance', () => {
    expect(sampledIndexOf(sources, xs, 2)).toBe(1)
    expect(sampledIndexOf(sources, xs, 1)).toBe(0)
    expect(sampledIndexOf(sources, xs, 3)).toBe(1)
  })

  it('answers -1 for no point or one outside the sampled range', () => {
    expect(sampledIndexOf(sources, xs, -1)).toBe(-1)
    expect(sampledIndexOf([1, 2], xs, 4)).toBe(-1)
  })
})

describe('colorBreaks / breaksGradient', () => {
  const xs = [0, 10, 20, 30, 40]
  const breaks = colorBreaks(xs, ['a', 'a', 'b', 'b', 'c'])

  it('marks where each colour starts', () => {
    expect(breaks).toEqual([
      { x: 0, color: 'a' },
      { x: 20, color: 'b' },
      { x: 40, color: 'c' },
    ])
  })

  it('puts a hard stop at each break inside the axis', () => {
    const stops: [number, string][] = []
    const ctx = {
      createLinearGradient: () => ({
        addColorStop: (offset: number, color: string) => stops.push([offset, color]),
      }),
    } as unknown as CanvasRenderingContext2D
    // The axis shows 10 → 50 m over 400 px.
    breaksGradient(ctx, breaks, 0, 400, (x) => (x - 10) * 10)
    expect(stops).toEqual([
      [0, 'a'],
      [0.25, 'a'],
      [0.25, 'b'],
      [0.75, 'b'],
      [0.75, 'c'],
      [1, 'c'],
    ])
  })
})
