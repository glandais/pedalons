import { describe, expect, it } from 'vitest'
import { ROUTE_COLORS, routeColorsById } from './routeColors'

describe('routeColorsById', () => {
  it('numbers only the items that have a route, as the map does', () => {
    const colors = routeColorsById([
      { id: 'ride-main-route', routeSlug: 'main' },
      { id: 'a' },
      { id: 'b', routeSlug: 'b' },
    ])
    expect(colors.get('ride-main-route')).toBe(ROUTE_COLORS[0])
    expect(colors.has('a')).toBe(false)
    expect(colors.get('b')).toBe(ROUTE_COLORS[1])
  })

  it('wraps around the palette', () => {
    const items = Array.from({ length: ROUTE_COLORS.length + 1 }, (_, i) => ({
      id: String(i),
      routeSlug: 'r',
    }))
    expect(routeColorsById(items).get(String(ROUTE_COLORS.length))).toBe(ROUTE_COLORS[0])
  })
})
