import { describe, it, expect } from 'vitest'
import { readUrlFilters } from '@/hooks/useUrlFilters'
import { agendaApiParams, agendaFiltersAlias, agendaFiltersSchema } from './agendaFilters'

const read = (query: string) =>
  readUrlFilters(new URLSearchParams(query), {
    schema: agendaFiltersSchema,
    alias: agendaFiltersAlias,
  })

describe('agenda filters (WEB-68, RL15)', () => {
  it('opens on « Toutes les dates »: when=UPCOMING_FIRST&dated=true, no clock in the key', () => {
    const params = agendaApiParams(read(''))
    expect(params).toMatchObject({
      when: 'UPCOMING_FIRST',
      dated: true,
      view: 'COMPACT',
      page: 0,
    })
    expect(params).not.toHaveProperty('from')
    expect(params).not.toHaveProperty('participating')
    expect(params.type).toBeUndefined()
  })

  it('« Je participe » is participating, over the same two sections', () => {
    expect(agendaApiParams(read('w=me'))).toMatchObject({
      when: 'UPCOMING_FIRST',
      participating: true,
    })
  })

  it('reads the former periods as « Toutes les dates », and the former kinds without failing', () => {
    expect(read('w=past').scope).toBe('all')
    expect(read('w=upcoming').scope).toBe('all')
    expect(read('w=all').scope).toBe('all')
    expect(read('type=post').filter).toBe('all')
    expect(agendaApiParams(read('type=trip')).type).toBe('TRIP')
  })

  it('always keeps the posts out with dated=true: with or without a kind, « Je participe » or not', () => {
    for (const query of ['', 'type=ride', 'type=trip', 'w=me', 'type=ride&w=me']) {
      expect(agendaApiParams(read(query))).toMatchObject({ when: 'UPCOMING_FIRST', dated: true })
    }
  })

  it('keeps the view out of the API params', () => {
    const filters = read('view=row')
    expect(filters.density).toBe('row')
    expect(agendaApiParams(filters)).not.toHaveProperty('density')
  })
})
