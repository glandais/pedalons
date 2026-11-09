import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import type { TrackDto } from '@/api/dto'
import { routeLeg } from '@/test/weatherFixtures'

// Every checkpoint at one spot on screen: only the room shared between the legs decides.
const map = {
  project: () => ({ x: 10, y: 10 }),
  on: vi.fn(),
  off: vi.fn(),
}
vi.mock('react-map-gl/maplibre', () => ({
  useMap: () => ({ current: { getMap: () => map } }),
}))
vi.mock('./WeatherCheckpointMarkers', () => ({
  WeatherCheckpointMarkers: ({ layout }: { layout: ReadonlyMap<number, unknown> }) => (
    <span data-testid="leg">{[...layout.keys()].join(',')}</span>
  ),
}))

import { WeatherLegsMarkers } from './WeatherLegsMarkers'

const tracks = [
  {
    line: {
      type: 'LineString',
      coordinates: Array.from({ length: 7 }, (_, i) => [5, 45 + i / 10, 0, i * 15_000]),
    },
    climbs: [],
  },
] as unknown as TrackDto[]

const LEGS = [
  { id: 'a', tracks, leg: routeLeg() },
  { id: 'b', tracks, leg: routeLeg() },
]

describe('WeatherLegsMarkers (WEB-142)', () => {
  afterEach(cleanup)

  const lastIndex = routeLeg().checkpoints.length - 1

  it('keeps the start and finish of every trace, and nothing en route when they crowd it', () => {
    render(<WeatherLegsMarkers legs={LEGS} open={null} onOpenChange={() => {}} />)
    expect(screen.getAllByTestId('leg').map((l) => l.textContent)).toEqual([
      `0,${lastIndex}`,
      `0,${lastIndex}`,
    ])
  })

  it("keeps the open badge of one trace, the other's points still giving way", () => {
    render(<WeatherLegsMarkers legs={LEGS} open={{ id: 'b', index: 2 }} onOpenChange={() => {}} />)
    expect(screen.getAllByTestId('leg').map((l) => l.textContent)).toEqual([
      `0,${lastIndex}`,
      `0,2,${lastIndex}`,
    ])
  })
})
