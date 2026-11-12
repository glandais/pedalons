import { describe, expect, it } from 'vitest'
import { splitUpcomingFirst } from './upcomingFirst'

const rows = (n: number, from = 0) => Array.from({ length: n }, (_, i) => from + i)

/** RL15: a page of a `when=UPCOMING_FIRST` list, cut where « À venir » ends. */
describe('splitUpcomingFirst', () => {
  it('a page wholly ahead has no « Plus tôt »', () => {
    expect(splitUpcomingFirst(rows(12), { page: 0, size: 12, upcomingTotal: 18 })).toEqual({
      upcoming: rows(12),
      earlier: [],
    })
  })

  it('cuts the page where the first section ends, by global position', () => {
    // Positions 12…23: 12…17 ahead, 18…23 earlier.
    const { upcoming, earlier } = splitUpcomingFirst(rows(12, 12), {
      page: 1,
      size: 12,
      upcomingTotal: 18,
    })
    expect(upcoming).toEqual(rows(6, 12))
    expect(earlier).toEqual(rows(6, 18))
  })

  it('a page past the first section is all « Plus tôt », its heading repeated on top', () => {
    expect(splitUpcomingFirst(rows(12, 24), { page: 2, size: 12, upcomingTotal: 18 })).toEqual({
      upcoming: [],
      earlier: rows(12, 24),
    })
  })

  it('no first section at all: everything is « Plus tôt »', () => {
    expect(splitUpcomingFirst(rows(3), { page: 0, size: 12, upcomingTotal: 0 }).upcoming).toEqual(
      []
    )
  })
})
