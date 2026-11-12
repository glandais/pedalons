import { describe, it, expect } from 'vitest'
import { readUrlFilters } from '@/hooks/useUrlFilters'
import {
  publicationApiParams,
  publicationFiltersAlias,
  publicationFiltersSchema,
} from './publicationFilters'

const read = (query: string) =>
  readUrlFilters(new URLSearchParams(query), {
    schema: publicationFiltersSchema,
    alias: publicationFiltersAlias,
  })

describe('home feed filters — « Tout / Je participe » in two sections (RL15)', () => {
  it('« Tout » asks for when=UPCOMING_FIRST: upcoming soonest first, then the rest', () => {
    const params = publicationApiParams(read(''))
    expect(params).toMatchObject({ when: 'UPCOMING_FIRST', view: 'COMPACT' })
    expect(params).not.toHaveProperty('participating')
    expect(params).not.toHaveProperty('from')
    expect(params).not.toHaveProperty('sortDir')
  })

  it('« Sorties » and « Voyages » keep the two sections, the posts alone have none', () => {
    expect(publicationApiParams(read('type=ride'))).toMatchObject({
      type: 'RIDE',
      when: 'UPCOMING_FIRST',
    })
    expect(publicationApiParams(read('type=trip'))).toMatchObject({ when: 'UPCOMING_FIRST' })
    expect(publicationApiParams(read('type=post'))).not.toHaveProperty('when')
  })

  it('« Je participe » is participating, over the same two sections', () => {
    expect(publicationApiParams(read('w=me'))).toMatchObject({
      participating: true,
      when: 'UPCOMING_FIRST',
    })
  })

  it('reads a former « À venir » link as « Tout »', () => {
    expect(read('w=upcoming').scope).toBe('all')
  })
})
