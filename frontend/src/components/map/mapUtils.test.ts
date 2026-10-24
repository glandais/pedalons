import { describe, expect, it } from 'vitest'
import type { TrackDto } from '@/api/dto'
import { NEUTRAL_COLOR, createGradientLineFeatures } from './mapUtils'

function track(n: number, lon0: number): TrackDto {
  return {
    line: {
      type: 'LineString',
      coordinates: Array.from({ length: n }, (_, i) => [lon0 + i * 0.001, 45, 100, i * 100]),
    },
    climbs: [],
  }
}

describe('createGradientLineFeatures', () => {
  it('is empty without track', () => {
    expect(createGradientLineFeatures([]).features).toEqual([])
  })

  it('keeps one neutral line on the flat when no colour is given', () => {
    const { features } = createGradientLineFeatures([track(4, 2)])
    expect(features).toHaveLength(1)
    expect(features[0].properties?.color).toBe(NEUTRAL_COLOR)
    expect(features[0].geometry.coordinates).toHaveLength(4)
  })

  it('cuts at each change of colour, the cut point closing one piece and opening the next', () => {
    const colors = ['red', 'red', 'blue', 'blue', 'blue']
    const { features } = createGradientLineFeatures([track(5, 2)], (_, i) => colors[i])
    expect(features.map((f) => f.properties?.color)).toEqual(['red', 'blue'])
    // point 2 changes the colour: it ends the red piece and starts the blue one
    expect(features[0].geometry.coordinates.map((c) => c[0])).toEqual([2, 2.001, 2.002])
    expect(features[1].geometry.coordinates.map((c) => c[0])).toEqual([2.002, 2.003, 2.004])
  })

  it('hands the track and point index of the colour, one piece per track', () => {
    const seen: [number, number][] = []
    const { features } = createGradientLineFeatures([track(3, 2), track(2, 3)], (j, i) => {
      seen.push([j, i])
      return j === 0 ? 'green' : 'orange'
    })
    expect(seen).toEqual([
      [0, 0],
      [0, 0],
      [0, 1],
      [0, 2],
      [1, 0],
      [1, 1],
    ])
    expect(features.map((f) => f.properties?.color)).toEqual(['green', 'orange'])
  })

  it('keeps the grade where the colour gives none', () => {
    const colors = ['teal', undefined, undefined, 'teal', 'teal']
    const { features } = createGradientLineFeatures([track(5, 2)], (_, i) => colors[i])
    expect(features.map((f) => f.properties?.color)).toEqual(['teal', NEUTRAL_COLOR, 'teal'])
  })
})
