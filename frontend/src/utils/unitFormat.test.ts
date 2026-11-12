import { describe, expect, it } from 'vitest'
import { formatAmount } from './priceFormat'
import {
  formatFileSize,
  formatNumber,
  formatPrecipitation,
  formatTemperature,
  formatTemperatureRange,
  temperatureToDisplay,
} from './unitFormat'

// Intl separates value and unit with a no-break space; compare on plain spaces.
const plain = (s: string) => s.replace(/[  ]/g, ' ')

describe('formatFileSize', () => {
  it('uses the French symbols', () => {
    expect(plain(formatFileSize(512, 'fr'))).toBe('512 o')
    expect(plain(formatFileSize(240_000, 'fr'))).toBe('240 ko')
    expect(plain(formatFileSize(2_400_000, 'fr'))).toBe('2,4 Mo')
  })

  it('uses the English symbols', () => {
    expect(formatFileSize(240_000, 'en')).toBe('240 kB')
    expect(formatFileSize(2_400_000, 'en')).toBe('2.4 MB')
  })

  it('moves to the next unit rather than showing 1000', () => {
    expect(formatFileSize(999_700, 'en')).toBe('1 MB')
    expect(formatFileSize(15_300_000, 'en')).toBe('15 MB')
  })
})

describe('temperatureToDisplay', () => {
  it('keeps °C for a metric reader, rounded to the degree', () => {
    expect(temperatureToDisplay(14.4, 'METRIC')).toBe(14)
    expect(temperatureToDisplay(14.5, 'METRIC')).toBe(15)
  })

  it('converts to °F for an imperial reader', () => {
    expect(temperatureToDisplay(0, 'IMPERIAL')).toBe(32)
    expect(temperatureToDisplay(100, 'IMPERIAL')).toBe(212)
    expect(temperatureToDisplay(-40, 'IMPERIAL')).toBe(-40)
  })

  it('never writes minus zero', () => {
    expect(formatTemperature(-0.3, 'METRIC')).toBe('0')
  })
})

describe('formatPrecipitation', () => {
  it('keeps mm to the tenth for a metric reader, in the decimal of the language', () => {
    expect(formatPrecipitation(1.24, 'METRIC', 'fr')).toBe('1,2')
    expect(formatPrecipitation(1.24, 'METRIC', 'en')).toBe('1.2')
    expect(formatPrecipitation(3, 'METRIC', 'en')).toBe('3.0')
  })

  it('converts to inches, to the hundredth, for an imperial reader', () => {
    expect(formatPrecipitation(25.4, 'IMPERIAL', 'en')).toBe('1.00')
    expect(formatPrecipitation(1.2, 'IMPERIAL', 'fr')).toBe('0,05')
  })
})

// docs/LEDGER_*.md WEB-167, R2: the app's « 9–13 °C ».
describe('formatTemperatureRange', () => {
  it('joins the ends with an en dash, no spaces', () => {
    expect(formatTemperatureRange(9.2, 12.6, 'METRIC')).toBe('9\u201313')
    expect(formatTemperatureRange(12.6, 9.2, 'METRIC')).toBe('9\u201313')
  })

  it('gives one value when both ends round alike, in the reader’s units', () => {
    expect(formatTemperatureRange(12.2, 12.4, 'METRIC')).toBe('12')
    expect(formatTemperatureRange(8.2, 14.4, 'IMPERIAL')).toBe('47\u201358')
  })
})

// Decision of 2026-11-12 (KIT §9): an ordinary no-break space between thousands, never Intl's
// narrow one (U+202F), which the system fonts draw too thin to read in bold.
describe('thousands separator', () => {
  it('is U+00A0 in a French number and price, never U+202F', () => {
    expect(formatNumber(1240, 'fr')).toBe('1\u00a0240')
    expect(formatNumber(1234567.8, 'fr', 1)).toBe('1\u00a0234\u00a0567,8')
    expect(formatAmount(1200, 'fr')).toBe('1\u00a0200,00\u00a0€')
    expect(formatNumber(1240, 'fr')).not.toContain('\u202f')
  })

  it('stays a comma in English', () => {
    expect(formatNumber(1240, 'en')).toBe('1,240')
  })
})
