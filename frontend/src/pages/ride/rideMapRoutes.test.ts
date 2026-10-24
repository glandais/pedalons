import { describe, expect, it } from 'vitest'
import type { RideDto, RideGroupDto } from '@/api/dto'
import { ROUTE_COLORS } from '@/lib/routeColors'
import { rideMapRoutes, routeItemId } from './rideMapRoutes'

const g = (id: string, name: string, routeSlug?: string) =>
  ({ id, name, routeSlug }) as RideGroupDto
const ride = (routeSlug: string | undefined, groups: RideGroupDto[]) =>
  ({ routeSlug, groups }) as unknown as RideDto

describe('rideMapRoutes', () => {
  it('puts the groups that share a route on one item, named after them in order', () => {
    const { items, itemIdByGroupId } = rideMapRoutes(
      ride('boucle', [g('g1', 'Chill'), g('g2', 'Rapide', 'col'), g('g3', 'G1', 'boucle')]),
      'Parcours principal'
    )
    expect(items).toEqual([
      { id: routeItemId('boucle'), name: 'Chill · G1', routeSlug: 'boucle' },
      { id: routeItemId('col'), name: 'Rapide', routeSlug: 'col' },
    ])
    expect(itemIdByGroupId.get('g1')).toBe(routeItemId('boucle'))
    expect(itemIdByGroupId.get('g3')).toBe(routeItemId('boucle'))
    expect(itemIdByGroupId.get('g2')).toBe(routeItemId('col'))
  })

  it("keeps the main-route label on the ride's route when no group rides it", () => {
    const { items } = rideMapRoutes(
      ride('boucle', [g('g1', 'Rapide', 'col'), g('g2', 'Cool', 'plat')]),
      'Parcours principal'
    )
    expect(items.map((i) => i.name)).toEqual(['Parcours principal', 'Rapide', 'Cool'])
  })

  it('gives a colour per route, the same to every group on it', () => {
    const { colorByGroupId } = rideMapRoutes(
      ride('boucle', [g('g1', 'A'), g('g2', 'B', 'col'), g('g3', 'C')]),
      'main'
    )
    expect(colorByGroupId.get('g1')).toBe(ROUTE_COLORS[0])
    expect(colorByGroupId.get('g3')).toBe(ROUTE_COLORS[0])
    expect(colorByGroupId.get('g2')).toBe(ROUTE_COLORS[1])
  })

  it('leaves out a group without any route', () => {
    const { items, itemIdByGroupId, colorByGroupId } = rideMapRoutes(
      ride(undefined, [g('g1', 'A'), g('g2', 'B', 'col')]),
      'main'
    )
    expect(items).toEqual([{ id: routeItemId('col'), name: 'B', routeSlug: 'col' }])
    expect(itemIdByGroupId.has('g1')).toBe(false)
    expect(colorByGroupId.has('g1')).toBe(false)
  })

  it('has no item for a ride without routes, nor for no ride', () => {
    expect(rideMapRoutes(ride(undefined, [g('g1', 'A')]), 'main').items).toEqual([])
    expect(rideMapRoutes(undefined, 'main').items).toEqual([])
  })
})
