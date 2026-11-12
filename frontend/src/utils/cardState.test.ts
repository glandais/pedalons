import { describe, expect, it } from 'vitest'
import { cardState, eventState } from './cardState'

// docs/LEDGER_*.md WEB-167, R1: the one state a card says, never « Publié ».
describe('cardState', () => {
  const now = Date.parse('2026-04-10T10:00:00Z')
  const span = (start: string, end: string) => ({ start, end })

  it('says nothing of a published content still to come, or not dated', () => {
    expect(
      cardState({ status: 'PUBLISHED', ...span('2026-04-11T07:00Z', '2026-04-11T12:00Z') }, now)
    ).toBeUndefined()
    expect(cardState({ status: 'PUBLISHED' }, now)).toBeUndefined()
  })

  it('puts cancelled and draft before the dates', () => {
    const past = span('2026-04-01T07:00Z', '2026-04-01T12:00Z')
    expect(cardState({ status: 'CANCELLED', ...past }, now)).toBe('CANCELLED')
    expect(cardState({ status: 'DRAFT', ...past }, now)).toBe('DRAFT')
    expect(cardState({ status: 'DRAFT' }, now)).toBe('DRAFT')
  })

  it('is under way between its start and its end, over from its end', () => {
    expect(
      cardState({ status: 'PUBLISHED', ...span('2026-04-10T08:00Z', '2026-04-10T13:00Z') }, now)
    ).toBe('UNDER_WAY')
    expect(
      cardState({ status: 'PUBLISHED', ...span('2026-04-10T05:00Z', '2026-04-10T10:00Z') }, now)
    ).toBe('FINISHED')
  })

  it('reads a calendar event’s `finished` when it has no end', () => {
    const event = { status: 'PUBLISHED' as const, start: '2026-04-09T07:00Z', finished: true }
    expect(eventState(event, now)).toBe('FINISHED')
    expect(eventState({ ...event, finished: false }, now)).toBeUndefined()
    expect(eventState({ ...event, end: '2026-04-10T12:00Z', finished: true }, now)).toBe(
      'UNDER_WAY'
    )
  })
})
