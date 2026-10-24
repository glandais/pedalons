import { useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import type { WeatherCheckpointDto } from '@/api/dto'
import { useUnits } from '@/hooks/useUnits'
import { useRendezvousFormat } from '@/hooks/useRendezvousFormat'
import { useRouteLabels } from './useRouteLabels'
import { useWeatherLabels } from './useWeatherLabels'
import { isKnownRelativeWind } from './weatherDisplay'

/** « 15 °C, Partiellement nuageux, pluie 13 %, Vent dans le dos, 13 km/h » — a point, spoken. */
export function useCheckpointSummary(timezone: string | undefined) {
  const { t } = useTranslation()
  const { temperature, speed } = useUnits()
  const { formatTime } = useRendezvousFormat(timezone)
  const labels = useWeatherLabels()
  const route = useRouteLabels()

  return useCallback(
    (checkpoint: WeatherCheckpointDto) => {
      const weather = checkpoint.weather
      let summary: string
      if (!weather) summary = t('rides.weather.checkpoints.noForecast')
      else {
        const temperatureText = temperature(weather.temperature)
        const condition = labels.condition(weather.condition)
        const wind = isKnownRelativeWind(checkpoint.relativeWind)
          ? t('rides.weather.wind.relativeAria', {
              relativeWind: labels.relativeWind(checkpoint.relativeWind),
              speed: speed(weather.wind.speed),
            })
          : labels.wind(weather.wind)
        // No chance of rain in the model is not a measured 0 %: it is left unsaid.
        summary =
          weather.precipitationProbability === undefined
            ? t('rides.weather.route.timeline.summaryNoRain', {
                temperature: temperatureText,
                condition,
                wind,
              })
            : t('rides.weather.route.timeline.summary', {
                temperature: temperatureText,
                condition,
                rain: weather.precipitationProbability,
                wind,
              })
      }
      return t('rides.weather.route.timeline.column', {
        time: formatTime(checkpoint.time),
        place: route.place(checkpoint),
        summary,
      })
    },
    [t, temperature, speed, formatTime, labels, route]
  )
}
