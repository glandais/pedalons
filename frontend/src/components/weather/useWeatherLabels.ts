import { useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import { isKnownCompassPoint, isKnownCondition, isKnownRelativeWind } from './weatherDisplay'
import type { WindDto } from '@/api/dto'
import { useUnits } from '@/hooks/useUnits'

/**
 * The words of the weather enums, with their fallback for a value this build does not know yet:
 * the contract only grows, and a new condition must read « Météo » rather than a raw key.
 */
export function useWeatherLabels() {
  const { t } = useTranslation()
  const { speed } = useUnits()

  const condition = useCallback(
    (value: string | undefined) =>
      isKnownCondition(value)
        ? t(
            `rides.weather.condition.${
              value satisfies
                | 'CLEAR'
                | 'MOSTLY_CLEAR'
                | 'PARTLY_CLOUDY'
                | 'OVERCAST'
                | 'FOG'
                | 'DRIZZLE'
                | 'RAIN'
                | 'HEAVY_RAIN'
                | 'FREEZING_RAIN'
                | 'SHOWERS'
                | 'SNOW'
                | 'THUNDERSTORM'
            }`
          )
        : t('rides.weather.condition.unknown'),
    [t]
  )

  /** « Vent de face » — the long form, for labels and screen readers. */
  const relativeWind = useCallback(
    (value: string | undefined) =>
      isKnownRelativeWind(value)
        ? t(`rides.weather.relativeWind.${value satisfies 'HEAD' | 'CROSS' | 'TAIL'}`)
        : '',
    [t]
  )

  /** « Face » — the short form, under a badge or in the exposure legend. */
  const relativeWindShort = useCallback(
    (value: string | undefined) =>
      isKnownRelativeWind(value)
        ? t(`rides.weather.relativeWindShort.${value satisfies 'HEAD' | 'CROSS' | 'TAIL'}`)
        : '',
    [t]
  )

  /** Where the wind comes from, on the eight-point rose: « SO » in French, « SW » in English. */
  const compass = useCallback(
    (value: string | undefined) =>
      isKnownCompassPoint(value)
        ? t(
            `rides.weather.compass.${
              value satisfies 'N' | 'NE' | 'E' | 'SE' | 'S' | 'SW' | 'W' | 'NW'
            }`
          )
        : '',
    [t]
  )

  /** « SO 18 km/h » — the wind as a card states it. */
  const wind = useCallback(
    (value: WindDto) => {
      const from = compass(value.compass)
      return from
        ? t('rides.weather.wind.fromCompass', { compass: from, speed: speed(value.speed) })
        : speed(value.speed)
    },
    [t, compass, speed]
  )

  /** « SO 18 km/h, rafales 35 km/h » — the wind with its gusts, when the model gives them. */
  const windWithGusts = useCallback(
    (value: WindDto) =>
      value.gusts !== undefined
        ? t('rides.weather.wind.withGusts', { wind: wind(value), gusts: speed(value.gusts) })
        : wind(value),
    [t, wind, speed]
  )

  return { condition, relativeWind, relativeWindShort, compass, wind, windWithGusts }
}
