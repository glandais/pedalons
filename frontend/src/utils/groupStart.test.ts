import { describe, it, expect } from 'vitest'
import { groupLeavesAtOwnTime, someGroupLeavesAtOwnTime, startFor } from './groupStart'

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

describe('someGroupLeavesAtOwnTime', () => {
  const ride = '2026-10-11T06:00:00Z'

  it('is false when every group leaves with the ride', () => {
    expect(someGroupLeavesAtOwnTime([{ startAt: ride }, { startAt: ride }], ride)).toBe(false)
  })

  it('is true as soon as one group leaves at another time', () => {
    expect(
      someGroupLeavesAtOwnTime([{ startAt: ride }, { startAt: '2026-10-11T06:30:00Z' }], ride)
    ).toBe(true)
  })
})

describe('startFor', () => {
  const ride = { dateTime: '2026-10-11T06:00:00Z' }

  it('is the ride’s departure when the group leaves with it', () => {
    const group = { id: 'g', startAt: '2026-10-11T08:00:00+02:00' }
    expect(Date.parse(startFor({ ...ride, registeredGroup: group }))).toBe(
      Date.parse(ride.dateTime)
    )
  })

  it('is the group’s departure when it leaves at its own time', () => {
    const group = { id: 'g', startAt: '2026-10-11T06:30:00Z' }
    expect(startFor({ ...ride, registeredGroup: group })).toBe('2026-10-11T06:30:00Z')
    expect(startFor(ride, group)).toBe('2026-10-11T06:30:00Z')
  })

  it('finds the registered group among the groups when the row does not carry it', () => {
    const groups = [
      { id: 'a', startAt: '2026-10-11T06:00:00Z' },
      { id: 'b', startAt: '2026-10-11T07:00:00Z' },
    ]
    expect(startFor({ ...ride, groups, registeredGroupId: 'b' })).toBe('2026-10-11T07:00:00Z')
  })

  it('is the ride’s departure without a group, or with an unreadable one', () => {
    expect(startFor(ride)).toBe(ride.dateTime)
    expect(startFor({ ...ride, registeredGroup: { startAt: '2026-10-11T07:00:00Z' } }, null)).toBe(
      ride.dateTime
    )
    expect(startFor(ride, { startAt: 'not a date' })).toBe(ride.dateTime)
  })
})
