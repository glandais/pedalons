import { describe, expect, it } from 'vitest'
import { makeAllRouteFiltersSchema, teamRouteFiltersSchema } from './filters/routeFilters'
import { countRouteFilters } from './useRouteFilters'

/** What the routes' « Filtres » button counts: what « Effacer les filtres » lifts (RL4). */
describe('countRouteFilters', () => {
  it('a range and a tag are two — never the sort', () => {
    const filters = teamRouteFiltersSchema.parse({
      minDistance: '50000',
      maxDistance: '100000',
      tags: '0ab',
      sortBy: 'DISTANCE',
      sortDir: 'ASC',
    })
    expect(countRouteFilters(filters, undefined)).toBe(2)
  })

  it('the search counts, and the scope off its default', () => {
    const schema = makeAllRouteFiltersSchema('member')
    expect(countRouteFilters(schema.parse({ search: 'monts' }), 'member')).toBe(1)
    expect(countRouteFilters(schema.parse({ membership: 'all' }), 'member')).toBe(1)
    expect(countRouteFilters(schema.parse({}), 'member')).toBe(0)
  })
})

describe('useRouteFilters — « Effacer les filtres » (RL4)', () => {
  it('lifts the search, the criteria and the tags, the scope back to its default, keeps the sort', async () => {
    const { renderHook, act } = await import('@testing-library/react')
    const { createElement } = await import('react')
    const { MemoryRouter, useLocation } = await import('react-router-dom')
    const { allRouteFiltersAlias } = await import('./filters/routeFilters')
    const { useRouteFilters } = await import('./useRouteFilters')
    const schema = makeAllRouteFiltersSchema('member')
    const { result } = renderHook(
      () => ({
        state: useRouteFilters({ schema, alias: allRouteFiltersAlias }),
        location: useLocation(),
      }),
      {
        wrapper: ({ children }) =>
          createElement(
            MemoryRouter,
            { initialEntries: ['/?q=monts&dmin=50000&surf=GRAVEL&role=all&sort=DISTANCE&dir=ASC'] },
            children
          ),
      }
    )
    expect(result.current.state.activeFilterCount).toBe(4)
    act(() => result.current.state.clearFilters())
    expect(result.current.location.search).toBe('?sort=DISTANCE&dir=ASC')
    expect(result.current.state.activeFilterCount).toBe(0)
  })
})
