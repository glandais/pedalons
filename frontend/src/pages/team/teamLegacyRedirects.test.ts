import { describe, it, expect } from 'vitest'

import { paths } from '@/config/paths'
import {
  homeFeedRedirect,
  teamAgendaRedirect,
  teamHomeRedirect,
  teamRidesRedirect,
  teamTripsRedirect,
} from './teamLegacyRedirects'

const q = (query: string) => new URLSearchParams(query)
const agenda = paths.teamAgenda('vc')

describe('former team feed addresses (WEB-68, plan §5)', () => {
  it('leaves the bare team URL alone: it is the dashboard', () => {
    expect(teamHomeRedirect('vc', q(''))).toBeUndefined()
    expect(teamHomeRedirect('vc', q('q=col'))).toBeUndefined()
  })

  it('sends the feed of posts to « Publications », search and tags kept', () => {
    expect(teamHomeRedirect('vc', q('tab=publications&type=post'))).toBe(paths.teamPosts('vc'))
    expect(teamHomeRedirect('vc', q('type=post&q=col&tags=0ab'))).toBe(
      `${paths.teamPosts('vc')}?q=col&tags=0ab`
    )
  })

  it('sends a feed of rides or trips to the agenda of that kind', () => {
    expect(teamHomeRedirect('vc', q('tab=publications&type=ride'))).toBe(`${agenda}?type=ride`)
    expect(teamHomeRedirect('vc', q('type=trip&w=me&tags=0ab'))).toBe(
      `${agenda}?type=trip&w=me&tags=0ab`
    )
  })

  it('maps the scopes: w=me to « Je participe », the others to « Toutes les dates »', () => {
    expect(teamHomeRedirect('vc', q('tab=publications&w=me'))).toBe(`${agenda}?w=me`)
    expect(teamHomeRedirect('vc', q('tab=publications&w=upcoming'))).toBe(agenda)
    expect(teamHomeRedirect('vc', q('w=all'))).toBe(agenda)
    expect(teamHomeRedirect('vc', q('w=past'))).toBe(agenda)
  })

  it('sends ?tab=publications alone to the dashboard', () => {
    expect(teamHomeRedirect('vc', q('tab=publications'))).toBe(paths.team('vc'))
  })

  it('sends the former « Sorties » and « Voyages » tabs to the agenda', () => {
    expect(teamRidesRedirect('vc', q(''))).toBe(agenda)
    expect(teamRidesRedirect('vc', q('w=upcoming'))).toBe(agenda)
    expect(teamTripsRedirect('vc', q('w=me'))).toBe(`${agenda}?type=trip&w=me`)
  })
})

describe('former periods of the agenda and the home feed (RL15)', () => {
  it('drops « À venir » and « Passées » from the agenda, keeping the rest', () => {
    expect(teamAgendaRedirect('vc', q('w=past&type=trip'))).toBe(`${agenda}?type=trip`)
    expect(teamAgendaRedirect('vc', q('w=upcoming'))).toBe(agenda)
    expect(teamAgendaRedirect('vc', q('type=ride&w=past&view=row'))).toBe(
      `${agenda}?type=ride&view=row`
    )
  })

  it('leaves « Je participe » and a bare agenda alone', () => {
    expect(teamAgendaRedirect('vc', q('w=me'))).toBeUndefined()
    expect(teamAgendaRedirect('vc', q('type=ride'))).toBeUndefined()
  })

  it('drops « À venir » from the home feed', () => {
    expect(homeFeedRedirect(q('w=upcoming&role=member'))).toBe(`${paths.home()}?role=member`)
    expect(homeFeedRedirect(q('w=upcoming'))).toBe(paths.home())
    expect(homeFeedRedirect(q('w=me'))).toBeUndefined()
    expect(homeFeedRedirect(q(''))).toBeUndefined()
  })
})
