import { describe, expect, it, vi } from 'vitest'
import type { Chart as ChartJS } from 'chart.js'
import type { WaypointDto } from '@/api/dto'
import { waypointAt, waypointMarkersPlugin } from './waypointMarkersPlugin'

function wp(name: string, distance?: number, type = 'WATER'): WaypointDto {
  return {
    name,
    type,
    distance,
    origin: 'AUTHOR',
    geometry: { type: 'Point', coordinates: [3, 45] },
  } as WaypointDto
}

// 1 m = 0.1 px
const scaleX = { getPixelForValue: (v: number) => v / 10 }

function fakeChart(markers: WaypointDto[], min = 0, max = 10000) {
  const calls: number[] = []
  const ctx = new Proxy(
    {},
    {
      get: (_t, key: string) => (key === 'moveTo' ? (x: number) => calls.push(x) : vi.fn()),
      set: () => true,
    }
  )
  const chart = {
    ctx,
    chartArea: { left: 0, right: 1000, top: 10, bottom: 100 },
    scales: { x: { min, max, getPixelForValue: scaleX.getPixelForValue } },
    options: { plugins: { waypointMarkers: { markers, selected: null } } },
  }
  return { chart: chart as unknown as ChartJS<'line'>, calls }
}

describe('waypointMarkersPlugin', () => {
  it('draws the markers inside the displayed range, not the others nor the off-track ones', () => {
    const { chart, calls } = fakeChart(
      [wp('in', 5000), wp('before', 500), wp('after', 9000), wp('off')],
      1000,
      8000
    )
    waypointMarkersPlugin.afterDatasetsDraw?.(
      chart,
      { cancelable: true } as never,
      {},
      undefined as never
    )
    expect(calls).toEqual([500])
  })

  it('draws nothing without markers', () => {
    const { chart, calls } = fakeChart([])
    waypointMarkersPlugin.afterDatasetsDraw?.(
      chart,
      { cancelable: true } as never,
      {},
      undefined as never
    )
    expect(calls).toEqual([])
  })
})

describe('waypointAt', () => {
  const near = wp('near', 5000)
  it('picks a marker within 8 px and no other', () => {
    expect(waypointAt([near], scaleX, 507)).toBe(near)
    expect(waypointAt([near], scaleX, 492)).toBe(near)
    expect(waypointAt([near], scaleX, 509)).toBeNull()
    expect(waypointAt([wp('off')], scaleX, 0)).toBeNull()
  })

  it('prefers the more important type on a tie', () => {
    const info = wp('i', 5000, 'INFO')
    const danger = wp('d', 5000, 'DANGER')
    expect(waypointAt([danger, info], scaleX, 500)).toBe(danger)
  })
})
