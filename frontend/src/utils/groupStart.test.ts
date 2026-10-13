import { describe, it, expect } from 'vitest'
import { groupLeavesAtOwnTime, groupStartRelation } from './groupStart'

// docs/LEDGER_*.md API-60: instants, not strings nor the deprecated `time`.
describe('groupLeavesAtOwnTime', () => {
  it('is false for the ride’s own instant, however it is written', () => {
    expect(groupLeavesAtOwnTime('2026-10-11T08:00:00+02:00', '2026-10-11T06:00:00Z')).toBe(false)
  })

  it('is true for another instant', () => {
    expect(groupLeavesAtOwnTime('2026-10-11T06:30:00Z', '2026-10-11T06:00:00Z')).toBe(true)
  })

  it('is false when either side is missing or unreadable', () => {
    expect(groupLeavesAtOwnTime(undefined, '2026-10-11T06:00:00Z')).toBe(false)
    expect(groupLeavesAtOwnTime('not a date', '2026-10-11T06:00:00Z')).toBe(false)
  })
})

describe('groupStartRelation', () => {
  it('compares instants: before, with or after the ride', () => {
    expect(groupStartRelation('2026-10-11T05:45:00Z', '2026-10-11T06:00:00Z')).toBe('before')
    expect(groupStartRelation('2026-10-11T08:00:00+02:00', '2026-10-11T06:00:00Z')).toBe('with')
    expect(groupStartRelation('2026-10-11T06:30:00Z', '2026-10-11T06:00:00Z')).toBe('after')
  })

  it('reads an unreadable value as leaving with the ride', () => {
    expect(groupStartRelation(undefined, '2026-10-11T06:00:00Z')).toBe('with')
    expect(groupStartRelation('not a date', '2026-10-11T06:00:00Z')).toBe('with')
  })
})
