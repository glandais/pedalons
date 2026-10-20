import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render } from '@testing-library/react'
import type { WaypointDto } from '@/api/dto'

const seen = vi.hoisted(() => ({
  sources: [] as Record<string, unknown>[],
  layers: [] as Record<string, unknown>[],
  popups: [] as Record<string, unknown>[],
}))

vi.mock('react-map-gl/maplibre', () => ({
  Source: (props: { children?: React.ReactNode } & Record<string, unknown>) => {
    seen.sources.push(props)
    return <>{props.children}</>
  },
  Layer: (props: Record<string, unknown>) => {
    seen.layers.push(props)
    return null
  },
  Popup: (props: { children?: React.ReactNode } & Record<string, unknown>) => {
    seen.popups.push(props)
    return <div data-testid="popup">{props.children}</div>
  },
  useMap: () => ({ current: undefined }),
}))
vi.mock('../route/WaypointDetails', () => ({
  WaypointDetails: ({ waypoint }: { waypoint: WaypointDto }) => <span>{waypoint.name}</span>,
}))

import { WaypointLayer } from './WaypointLayer'

function wp(name: string, coordinates: number[]): WaypointDto {
  return {
    name,
    type: 'WATER',
    origin: 'AUTHOR',
    geometry: { type: 'Point', coordinates },
  } as WaypointDto
}

describe('WaypointLayer', () => {
  afterEach(() => {
    cleanup()
    seen.sources.length = seen.layers.length = seen.popups.length = 0
  })

  it('hands the source the point on the equator, as the others (WEB-108)', () => {
    const waypoints = [wp('Equateur', [3, 0]), wp('Greenwich', [0, 45]), wp('Ailleurs', [3, 45])]
    render(
      <WaypointLayer
        waypoints={waypoints}
        selection={null}
        onSelect={() => {}}
        hoveredIndex={null}
        darkBasemap={false}
      />
    )
    const data = seen.sources[0].data as GeoJSON.FeatureCollection<GeoJSON.Point>
    expect(data.features.map((f) => f.geometry.coordinates)).toEqual([
      [3, 0],
      [0, 45],
      [3, 45],
    ])
    expect(seen.popups).toHaveLength(0)
    expect(seen.layers.map((l) => l.id)).toEqual([
      'route-waypoints-hit',
      'route-waypoints',
      'route-waypoints-label',
      'route-waypoints-label-hover',
    ])
  })

  it('opens the popup only for a selected point of the list, and closes through onSelect', () => {
    const a = wp('A', [3, 45])
    const onSelect = vi.fn()
    const { rerender, queryByTestId, getByText } = render(
      <WaypointLayer
        waypoints={[a]}
        selection={{ waypoint: a, from: 'map' }}
        onSelect={onSelect}
        hoveredIndex={null}
        darkBasemap={false}
      />
    )
    expect(getByText('A')).toBeTruthy()
    ;(seen.popups[0].onClose as () => void)()
    expect(onSelect).toHaveBeenCalledWith(null)

    rerender(
      <WaypointLayer
        waypoints={[a]}
        selection={{ waypoint: wp('Autre étape', [1, 1]), from: 'map' }}
        onSelect={onSelect}
        hoveredIndex={null}
        darkBasemap={false}
      />
    )
    expect(queryByTestId('popup')).toBeNull()
  })
})
