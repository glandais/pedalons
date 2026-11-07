import { describe, expect, it } from 'vitest'
import { departureChange, departureFormFields, departureJsonFields } from './departure'

const DATE = '2026-11-08T09:30:00'

describe('departureChange', () => {
  it('says nothing about what did not move', () => {
    expect(
      departureChange({ departure: DATE, averageSpeed: 25 }, { departure: DATE, averageSpeed: 25 })
    ).toEqual({})
    expect(departureChange({}, {})).toEqual({})
  })

  it('sends a value that was set or changed, the date and the speed each on their own', () => {
    expect(departureChange({}, { departure: DATE })).toEqual({ departure: DATE })
    expect(departureChange({ averageSpeed: 20 }, { averageSpeed: 22.5 })).toEqual({
      averageSpeed: 22.5,
    })
    expect(
      departureChange(
        { departure: '2026-11-01T08:00:00', averageSpeed: 20 },
        { departure: DATE, averageSpeed: 20 }
      )
    ).toEqual({ departure: DATE })
  })

  it('normalises the picker format to an ISO wall time', () => {
    expect(departureChange({}, { departure: '2026-11-08 09:30' })).toEqual({
      departure: '2026-11-08T09:30:00',
    })
  })

  it('asks to clear what was emptied, each on its own', () => {
    expect(departureChange({ departure: DATE, averageSpeed: 20 }, { averageSpeed: 20 })).toEqual({
      clearDeparture: true,
    })
    expect(departureChange({ departure: DATE, averageSpeed: 20 }, { departure: DATE })).toEqual({
      clearAverageSpeed: true,
    })
  })
})

describe('departureFormFields', () => {
  it('turns what is set into text', () => {
    expect(departureFormFields({ departure: DATE, averageSpeed: 27.5 })).toEqual({
      departure: DATE,
      averageSpeed: '27.5',
    })
  })

  it('has no key at all for what is empty, nor for a clearing', () => {
    expect(departureFormFields({})).toEqual({})
    expect(departureFormFields({ clearDeparture: true, clearAverageSpeed: true })).toEqual({})
  })
})

describe('departureJsonFields', () => {
  it('keeps the speed a number and drops the empty', () => {
    expect(departureJsonFields({ departure: DATE, averageSpeed: 27.5 })).toEqual({
      departure: DATE,
      averageSpeed: 27.5,
    })
    expect(departureJsonFields({})).toEqual({})
  })
})
