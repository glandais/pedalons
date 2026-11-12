import { describe, expect, it } from 'vitest'
import { makeTeamFiltersSchema, teamApiParams } from './teamFilters'

/** The team list's order follows its scope (docs/LEDGER_*.md WEB-175, RL5). */
describe('teamApiParams — the order', () => {
  const filters = (membership: 'all' | 'member' | 'organizer') =>
    makeTeamFiltersSchema('member').parse({ membership })

  it('one’s own teams by name, A to Z', () => {
    expect(teamApiParams(filters('member'))).toMatchObject({ sortBy: 'NAME', sortDir: 'ASC' })
    expect(teamApiParams(filters('organizer'))).toMatchObject({ sortBy: 'NAME', sortDir: 'ASC' })
  })

  it('all the teams by member count, the largest first', () => {
    expect(teamApiParams(filters('all'))).toMatchObject({
      sortBy: 'MEMBER_COUNT',
      sortDir: 'DESC',
    })
  })
})

/** « Ouvertes à l'adhésion » (RL3): `joinable=true`, under « Toutes les équipes » only. */
describe('teamApiParams — « Ouvertes à l’adhésion »', () => {
  const schema = makeTeamFiltersSchema('member')

  it('sends joinable=true under « Toutes les équipes »', () => {
    expect(teamApiParams(schema.parse({ membership: 'all', joinable: 'true' }))).toMatchObject({
      joinable: true,
    })
  })

  it('sends nothing under « Membre », nor when it is off', () => {
    expect(
      teamApiParams(schema.parse({ membership: 'member', joinable: 'true' }))
    ).not.toHaveProperty('joinable')
    expect(teamApiParams(schema.parse({ membership: 'all' }))).not.toHaveProperty('joinable')
  })
})
