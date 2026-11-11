import { useCallback, useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { usePreferencesStore } from '../store/preferencesStore'
import {
  distanceText,
  elevationText,
  formatDistance,
  formatElevation,
  formatGrade,
  formatPercent,
  formatPrecipitation,
  formatSpeed,
  formatTemperature,
  speedText,
  getUnitConfig,
  speedToDisplay as speedToDisplayFn,
  speedFromDisplay as speedFromDisplayFn,
  distanceToDisplay as distanceToDisplayFn,
  distanceFromDisplay as distanceFromDisplayFn,
  elevationToDisplay as elevationToDisplayFn,
  elevationFromDisplay as elevationFromDisplayFn,
} from '../utils/unitFormat'

export function useUnits() {
  const { t, i18n } = useTranslation()
  const unitSystem = usePreferencesStore((state) => state.unitSystem)
  const config = useMemo(() => getUnitConfig(unitSystem), [unitSystem])
  const isImperial = unitSystem === 'IMPERIAL'

  // The numbers follow the language of the interface, the unit is bound by a no-break space
  // (docs/LEDGER_*.md WEB-167, D13; cases in contracts/format-cases.json).
  const language = i18n?.language ?? 'fr'

  /** « 92,4 km » / « 28.8 mi ». */
  const distance = useCallback(
    (meters: number) => distanceText(meters, unitSystem, language),
    [unitSystem, language]
  )

  /** « 1 240 m » / « 4,068 ft ». */
  const elevation = useCallback(
    (meters: number) => elevationText(meters, unitSystem, language),
    [unitSystem, language]
  )

  /** « 25 km/h » / « 16 mph ». */
  const speed = useCallback(
    (kmh: number) => speedText(kmh, unitSystem, language),
    [unitSystem, language]
  )

  /** « 12 °C » / « 54 °F » — the API always speaks °C. */
  const temperature = useCallback(
    (celsius: number) => {
      const key = isImperial ? 'temperature_imperial' : 'temperature'
      return t(key satisfies 'temperature' | 'temperature_imperial', {
        temperature: formatTemperature(celsius, unitSystem),
      })
    },
    [t, unitSystem, isImperial]
  )

  /** « 6,5 % » — a gradient, to the tenth. */
  const grade = useCallback((percent: number) => formatGrade(percent, language), [language])

  /** « 60 % » — a whole percentage. */
  const percent = useCallback((value: number) => formatPercent(value, language), [language])

  /** « 1,2 mm » / « 0.05 in » — the API always speaks mm, the decimal follows the language. */
  const precipitation = useCallback(
    (mm: number) => {
      const key = isImperial ? 'precipitation_imperial' : 'precipitation'
      return t(key satisfies 'precipitation' | 'precipitation_imperial', {
        precipitation: formatPrecipitation(mm, unitSystem, language),
      })
    },
    [t, language, unitSystem, isImperial]
  )

  const distanceUnit = useCallback(() => {
    const key = isImperial
      ? 'routes.list.filters.distance.unit_imperial'
      : 'routes.list.filters.distance.unit'
    return t(
      key satisfies
        'routes.list.filters.distance.unit' | 'routes.list.filters.distance.unit_imperial'
    )
  }, [t, isImperial])

  const elevationUnit = useCallback(() => {
    const key = isImperial
      ? 'routes.list.filters.elevationGain.unit_imperial'
      : 'routes.list.filters.elevationGain.unit'
    return t(
      key satisfies
        'routes.list.filters.elevationGain.unit' | 'routes.list.filters.elevationGain.unit_imperial'
    )
  }, [t, isImperial])

  // Raw formatters for special cases (charts, inputs)
  const formatDistanceFn = useCallback(
    (m: number) => formatDistance(m, unitSystem, language),
    [unitSystem, language]
  )

  const formatElevationFn = useCallback(
    (m: number) => formatElevation(m, unitSystem, language),
    [unitSystem, language]
  )

  const formatSpeedFn = useCallback(
    (kmh: number) => formatSpeed(kmh, unitSystem, language),
    [unitSystem, language]
  )

  // Converters for form inputs
  const speedToDisplay = useCallback(
    (kmh: number | undefined) => speedToDisplayFn(kmh, unitSystem),
    [unitSystem]
  )

  const speedFromDisplay = useCallback(
    (displayVal: string | number | undefined) => speedFromDisplayFn(displayVal, unitSystem),
    [unitSystem]
  )

  const distanceToDisplay = useCallback(
    (meters: number | undefined) => distanceToDisplayFn(meters, unitSystem),
    [unitSystem]
  )

  const distanceFromDisplay = useCallback(
    (displayVal: string | number | undefined) => distanceFromDisplayFn(displayVal, unitSystem),
    [unitSystem]
  )

  const elevationToDisplay = useCallback(
    (meters: number | undefined) => elevationToDisplayFn(meters, unitSystem),
    [unitSystem]
  )

  const elevationFromDisplay = useCallback(
    (displayVal: string | number | undefined) => elevationFromDisplayFn(displayVal, unitSystem),
    [unitSystem]
  )

  return {
    unitSystem,
    config,
    distance,
    elevation,
    speed,
    temperature,
    precipitation,
    grade,
    percent,
    distanceUnit,
    elevationUnit,
    // Raw formatters for special cases (charts, inputs)
    formatDistance: formatDistanceFn,
    formatElevation: formatElevationFn,
    formatSpeed: formatSpeedFn,
    // Converters for form inputs (to/from display units)
    speedToDisplay,
    speedFromDisplay,
    distanceToDisplay,
    distanceFromDisplay,
    elevationToDisplay,
    elevationFromDisplay,
  }
}
