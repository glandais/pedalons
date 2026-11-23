import { describe, expect, it } from 'vitest'
import { formatMapView, parseMapView } from './mapViewParam'

describe('parseMapView', () => {
  it('reads zoom/lat/lon', () => {
    expect(parseMapView('12.5/45.1885/5.7245')).toEqual({
      zoom: 12.5,
      latitude: 45.1885,
      longitude: 5.7245,
    })
  })

  it.each([null, '', '12/45', '12/45/5/1', 'a/45/5', '23/45/5', '-1/45/5', '12/86/5', '12/45/181'])(
    'rejects %s',
    (value) => {
      expect(parseMapView(value)).toBeNull()
    }
  )
})

describe('formatMapView', () => {
  it('rounds the coordinates to about a pixel of the zoom', () => {
    expect(formatMapView({ zoom: 12, latitude: 45.188529123, longitude: 5.724524789 })).toBe(
      '12/45.1885/5.7245'
    )
    expect(formatMapView({ zoom: 5.25, latitude: 46.6, longitude: 2.4 })).toBe('5.25/46.60/2.40')
  })

  it('wraps a longitude panned past the antimeridian', () => {
    expect(formatMapView({ zoom: 3, latitude: 0, longitude: 190 })).toBe('3/0.0/-170.0')
  })

  it('round-trips', () => {
    const value = formatMapView({ zoom: 14.37, latitude: -33.86882, longitude: 151.20929 })
    expect(formatMapView(parseMapView(value)!)).toBe(value)
  })
})
