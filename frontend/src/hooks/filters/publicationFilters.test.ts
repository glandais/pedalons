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

describe('home feed filters — « À venir » (DL16)', () => {
  it('asks for when=UPCOMING, like the agenda: soonest first, a ride under way kept', () => {
    const params = publicationApiParams(read('w=upcoming'))
    expect(params).toMatchObject({ when: 'UPCOMING', view: 'COMPACT' })
    expect(params).not.toHaveProperty('from')
    expect(params).not.toHaveProperty('sortDir')
  })

  it('« Tout » sends no time filter, « Je participe » only participating', () => {
    expect(publicationApiParams(read(''))).not.toHaveProperty('when')
    const mine = publicationApiParams(read('w=me'))
    expect(mine).toMatchObject({ participating: true })
    expect(mine).not.toHaveProperty('when')
  })
})
