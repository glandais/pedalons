import { describe, expect, it } from 'vitest'
import { readUrlFilters } from '@/hooks/useUrlFilters'
import {
  generatorParamPatch,
  routeGeneratorFiltersAlias,
  routeGeneratorFiltersSchema,
} from './routeGeneratorFilters'

const read = (query: string) =>
  readUrlFilters(new URLSearchParams(query), {
    schema: routeGeneratorFiltersSchema,
    alias: routeGeneratorFiltersAlias,
  })

describe('routeGeneratorFilters', () => {
  it('has no parameter by default', () => {
    expect(read('')).toEqual({
      start: undefined,
      end: undefined,
      bearing: undefined,
      distanceKm: 50,
      discovery: 0.25,
      type: undefined,
      seed: 0,
      selected: 0,
      go: false,
    })
  })

  it('falls back on the defaults for a garbage URL', () => {
    const filters = read('d=abc&cap=XX&s=foo&e=1,2,3&dec=zz&t=MIXED&seed=-4&sel=9&go=maybe')
    expect(filters.distanceKm).toBe(50)
    expect(filters.bearing).toBeUndefined()
    expect(filters.start).toBeUndefined()
    expect(filters.end).toBeUndefined()
    expect(filters.discovery).toBe(0.25)
    expect(filters.type).toBeUndefined()
    expect(filters.seed).toBe(0)
    expect(filters.selected).toBe(0)
    expect(filters.go).toBe(false)
  })

  it('catches a distance out of the 10 to 200 km range', () => {
    expect(read('d=250').distanceKm).toBe(50)
    expect(read('d=5').distanceKm).toBe(50)
    expect(read('d=120').distanceKm).toBe(120)
  })

  it('reads a point with 5 decimals and snaps the discovery to quarters', () => {
    expect(read('s=45.123456,5.1').start).toBe('45.12346,5.10000')
    expect(read('dec=0.6').discovery).toBe(0.5)
    expect(read('dec=0.9').discovery).toBe(1)
  })

  it('reads the flags', () => {
    const filters = read('go=true&cap=NE&t=GRAVEL&seed=2&sel=1')
    expect(filters).toMatchObject({ go: true, bearing: 'NE', type: 'GRAVEL', seed: 2, selected: 1 })
  })

  it('drops the results of a changed parameter', () => {
    expect(generatorParamPatch({ distanceKm: 80 })).toEqual({
      distanceKm: 80,
      go: false,
      seed: 0,
      selected: 0,
    })
  })
})
