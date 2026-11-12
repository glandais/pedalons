import { UnitSystem } from '@/api/dto'

// Conversion constants
const KM_TO_MI = 0.621371
const M_TO_FT = 3.28084
const KMH_TO_MPH = 0.621371

export interface UnitConfig {
  distanceUnit: 'km' | 'mi'
  elevationUnit: 'm' | 'ft'
  speedUnit: 'km/h' | 'mph'
  distanceMultiplier: number // from meters
  elevationMultiplier: number // from meters
  speedMultiplier: number // from km/h
}

export function getUnitConfig(unitSystem: UnitSystem): UnitConfig {
  if (unitSystem === 'IMPERIAL') {
    return {
      distanceUnit: 'mi',
      elevationUnit: 'ft',
      speedUnit: 'mph',
      distanceMultiplier: KM_TO_MI / 1000, // meters to miles
      elevationMultiplier: M_TO_FT,
      speedMultiplier: KMH_TO_MPH,
    }
  }
  return {
    distanceUnit: 'km',
    elevationUnit: 'm',
    speedUnit: 'km/h',
    distanceMultiplier: 0.001, // meters to km
    elevationMultiplier: 1,
    speedMultiplier: 1,
  }
}

/** No-break space (U+00A0), between a value and its unit (docs/BRANDING.md §8.3). */
export const NBSP = '\u00a0'

const decimalFormats = new Map<string, Intl.NumberFormat>()

/**
 * A number in the language of the interface, to a fixed number of decimals: « 92,4 » and « 1 240 »
 * (narrow no-break space, U+202F, as Intl writes it) in French, « 92.4 » and « 1,240 » in English
 * (docs/LEDGER_*.md WEB-167, D13). Cached per language: a chart formats hundreds of labels.
 */
export function formatNumber(value: number, locale: string, fractionDigits: number = 0): string {
  const key = `${locale}/${fractionDigits}`
  let format = decimalFormats.get(key)
  if (!format) {
    format = new Intl.NumberFormat(locale, {
      minimumFractionDigits: fractionDigits,
      maximumFractionDigits: fractionDigits,
    })
    decimalFormats.set(key, format)
  }
  // `+ 0` folds -0 into 0: « -0 m » reads as a bug.
  return format.format((fractionDigits === 0 ? Math.round(value) : value) + 0)
}

/** A value and its unit, bound by a no-break space: « 92,4 km » never splits at a line end. */
export function withUnit(value: string, symbol: string): string {
  return `${value}${NBSP}${symbol}`
}

/** A route's length, to the tenth, without its unit: « 92,4 » (fr), « 28.8 » (mi, en). */
export function formatDistance(meters: number, unitSystem: UnitSystem, locale: string): string {
  const config = getUnitConfig(unitSystem)
  return formatNumber(meters * config.distanceMultiplier, locale, 1)
}

/** A climb or an altitude, to the unit, without its unit: « 1 240 » (fr), « 4,068 » (ft, en). */
export function formatElevation(meters: number, unitSystem: UnitSystem, locale: string): string {
  const config = getUnitConfig(unitSystem)
  return formatNumber(meters * config.elevationMultiplier, locale)
}

/** A speed, to the unit, without its unit: « 25 », « 16 » (mph). */
export function formatSpeed(kmh: number, unitSystem: UnitSystem, locale: string): string {
  const config = getUnitConfig(unitSystem)
  return formatNumber(kmh * config.speedMultiplier, locale)
}

/** « 92,4 km », « 28.8 mi » — the one rendering of a distance (`useUnits().distance`). */
export function distanceText(meters: number, unitSystem: UnitSystem, locale: string): string {
  return withUnit(
    formatDistance(meters, unitSystem, locale),
    getUnitConfig(unitSystem).distanceUnit
  )
}

/** « 1 240 m », « 4,068 ft » (`useUnits().elevation`). */
export function elevationText(meters: number, unitSystem: UnitSystem, locale: string): string {
  return withUnit(
    formatElevation(meters, unitSystem, locale),
    getUnitConfig(unitSystem).elevationUnit
  )
}

/** « 25 km/h », « 16 mph » (`useUnits().speed`). */
export function speedText(kmh: number, unitSystem: UnitSystem, locale: string): string {
  return withUnit(formatSpeed(kmh, unitSystem, locale), getUnitConfig(unitSystem).speedUnit)
}

/**
 * A whole percentage: « 60 % ». The no-break space before « % » holds in English too — the app's
 * rendering (`AppFormatters.formatPercent`), kept by `contracts/format-cases.json`.
 */
export function formatPercent(percent: number, locale: string): string {
  return withUnit(formatNumber(percent, locale), '%')
}

/** A gradient, to the tenth: « 6,5 % » (fr), « 6.5 % » (en) — the app's `formatGrade`. */
export function formatGrade(percent: number, locale: string): string {
  return withUnit(formatNumber(percent, locale, 1), '%')
}

/**
 * A temperature from the API (always °C) in the reader's unit system, rounded to the degree:
 * °F for IMPERIAL. Degrees are shown whole — a forecast is not precise to the tenth.
 */
export function temperatureToDisplay(celsius: number, unitSystem: UnitSystem): number {
  const value = unitSystem === 'IMPERIAL' ? (celsius * 9) / 5 + 32 : celsius
  // `+ 0` folds -0 into 0: « -0 °C » reads as a bug.
  return Math.round(value) + 0
}

export function formatTemperature(celsius: number, unitSystem: UnitSystem): string {
  return temperatureToDisplay(celsius, unitSystem).toString()
}

/**
 * A range of temperatures, without its unit: « 9–13 » (an en dash, no spaces — the app's
 * `AppFormatters.formatTemperatureRange`), or the one value when both ends round to the same
 * degree in the reader's units (docs/LEDGER_*.md WEB-167, R2).
 */
export function formatTemperatureRange(
  minCelsius: number,
  maxCelsius: number,
  unitSystem: UnitSystem
): string {
  const low = temperatureToDisplay(Math.min(minCelsius, maxCelsius), unitSystem)
  const high = temperatureToDisplay(Math.max(minCelsius, maxCelsius), unitSystem)
  return low === high ? String(high) : `${low}\u2013${high}`
}

const MM_PER_INCH = 25.4

/**
 * An amount of precipitation from the API (always mm) in the reader's unit system and language:
 * « 1,2 » mm in French, « 1.2 » in English, inches to the hundredth for IMPERIAL (« 0.05 ») — a
 * tenth of an inch is 2.5 mm, too coarse for a shower.
 */
export function formatPrecipitation(mm: number, unitSystem: UnitSystem, locale?: string): string {
  const imperial = unitSystem === 'IMPERIAL'
  const digits = imperial ? 2 : 1
  return new Intl.NumberFormat(locale, {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  }).format(imperial ? mm / MM_PER_INCH : mm)
}

// Round to avoid floating-point precision issues (e.g., 25.000000000000004)
function round(value: number, decimals: number = 2): number {
  const factor = Math.pow(10, decimals)
  return Math.round(value * factor) / factor
}

// Parse display value to number, returning undefined for empty/invalid input
function parseDisplayValue(displayVal: string | number | undefined): number | undefined {
  if (displayVal === '' || displayVal === undefined) return undefined
  const num = typeof displayVal === 'number' ? displayVal : parseFloat(displayVal)
  return isNaN(num) ? undefined : num
}

// Generic conversion: internal value to display value
function toDisplay(value: number | undefined, multiplier: number): number | undefined {
  if (value === undefined) return undefined
  return round(value * multiplier)
}

// Generic conversion: display value to internal value
function fromDisplay(
  displayVal: string | number | undefined,
  multiplier: number
): number | undefined {
  const num = parseDisplayValue(displayVal)
  if (num === undefined) return undefined
  return round(num / multiplier)
}

// Speed conversion helpers (internal: km/h)
export function speedToDisplay(
  kmh: number | undefined,
  unitSystem: UnitSystem
): number | undefined {
  return toDisplay(kmh, getUnitConfig(unitSystem).speedMultiplier)
}

export function speedFromDisplay(
  displayVal: string | number | undefined,
  unitSystem: UnitSystem
): number | undefined {
  return fromDisplay(displayVal, getUnitConfig(unitSystem).speedMultiplier)
}

// Distance conversion helpers (internal: meters)
export function distanceToDisplay(
  meters: number | undefined,
  unitSystem: UnitSystem
): number | undefined {
  return toDisplay(meters, getUnitConfig(unitSystem).distanceMultiplier)
}

export function distanceFromDisplay(
  displayVal: string | number | undefined,
  unitSystem: UnitSystem
): number | undefined {
  return fromDisplay(displayVal, getUnitConfig(unitSystem).distanceMultiplier)
}

// Elevation conversion helpers (internal: meters)
export function elevationToDisplay(
  meters: number | undefined,
  unitSystem: UnitSystem
): number | undefined {
  return toDisplay(meters, getUnitConfig(unitSystem).elevationMultiplier)
}

export function elevationFromDisplay(
  displayVal: string | number | undefined,
  unitSystem: UnitSystem
): number | undefined {
  return fromDisplay(displayVal, getUnitConfig(unitSystem).elevationMultiplier)
}

const FILE_SIZE_UNITS = ['byte', 'kilobyte', 'megabyte', 'gigabyte'] as const

/**
 * The size of a file, in decimal (SI) units as the platforms' file managers show it: « 240 ko »,
 * « 2,4 Mo » in French, « 240 kB » in English. One decimal below 10, none above — enough to tell
 * two files apart without reading like a measurement. docs/LEDGER_*.md API-7.
 */
export function formatFileSize(bytes: number, locale: string): string {
  let value = bytes
  let unit = 0
  while (unit < FILE_SIZE_UNITS.length - 1 && Math.round(value) >= 1000) {
    value /= 1000
    unit++
  }
  const fractionDigits = unit === 0 || value >= 9.95 ? 0 : 1
  return new Intl.NumberFormat(locale, {
    style: 'unit',
    unit: FILE_SIZE_UNITS[unit],
    unitDisplay: 'short',
    maximumFractionDigits: fractionDigits,
    minimumFractionDigits: 0,
  }).format(value)
}
