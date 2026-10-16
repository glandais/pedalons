import { useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import type { WeatherCheckpointDto } from '@/api/dto'
import { WeatherCheckpointKind } from '@/api/dto'
import { useUnits } from '@/hooks/useUnits'
import { durationParts } from './windPhases'

/**
 * The words of a route's places and lengths, in the reader's units: « km 150 » (a marker along the
 * route, whole), « km 105.1 » (a point, to the tenth), « 90 km » (a length, whole), « 1 h 05 ».
 */
export function useRouteLabels() {
  const { t } = useTranslation()
  const { config, formatDistance, unitSystem } = useUnits()
  const isImperial = unitSystem === 'IMPERIAL'

  const whole = useCallback(
    (meters: number) => Math.round(meters * config.distanceMultiplier).toString(),
    [config]
  )

  /** « km 150 » — where along the route; `precise` keeps the tenth. */
  const marker = useCallback(
    (meters: number, precise = false) =>
      t(
        (isImperial
          ? 'rides.weather.route.marker_imperial'
          : 'rides.weather.route.marker') satisfies
          'rides.weather.route.marker' | 'rides.weather.route.marker_imperial',
        { distance: precise ? formatDistance(meters) : whole(meters) }
      ),
    [t, isImperial, formatDistance, whole]
  )

  /** « 90 km » — a length, whole. */
  const length = useCallback(
    (meters: number) =>
      t(
        (isImperial ? 'distance_imperial' : 'distance') satisfies 'distance' | 'distance_imperial',
        {
          distance: whole(meters),
        }
      ),
    [t, isImperial, whole]
  )

  /** « km 15–45 » — a stretch. */
  const range = useCallback(
    (from: number, to: number) =>
      t('rides.weather.route.phases.range', { from: marker(from), to: whole(to) }),
    [t, marker, whole]
  )

  /** « Départ », « km 105.1 », « Arrivée · km 307.4 ». */
  const place = useCallback(
    (checkpoint: WeatherCheckpointDto) =>
      checkpoint.kind === WeatherCheckpointKind.START
        ? t('rides.weather.checkpoints.start')
        : checkpoint.kind === WeatherCheckpointKind.FINISH
          ? t('rides.weather.route.detail.finish', { distance: marker(checkpoint.distance, true) })
          : marker(checkpoint.distance, true),
    [t, marker]
  )

  /** « 29 min », « 1 h 05 ». */
  const duration = useCallback(
    (totalMinutes: number) => {
      const { hours, minutes } = durationParts(totalMinutes)
      return hours === 0
        ? t('rides.weather.route.duration.minutes', { minutes })
        : t('rides.weather.route.duration.hours', {
            hours,
            minutes: minutes.toString().padStart(2, '0'),
          })
    },
    [t]
  )

  return { marker, length, range, place, duration, whole }
}
