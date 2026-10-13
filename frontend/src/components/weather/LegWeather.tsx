import { useTranslation } from 'react-i18next'
import { Stack, Text } from '@mantine/core'
import type { WeatherLegDto } from '@/api/dto'
import { WeatherStatus } from '@/api/dto'
import { useUnits } from '@/hooks/useUnits'
import { useRendezvousFormat } from '@/hooks/useRendezvousFormat'
import { useWeatherLabels } from './useWeatherLabels'
import { WeatherCheckpointStrip } from './WeatherCheckpointStrip'
import { WeatherRainBanner } from './WeatherRainBanner'
import { WindExposureBar } from './WindExposureBar'
import { hasForecast } from './weatherDisplay'

/** One group's route, or one trip stage's: when it leaves and arrives, at what speed, then rain, points and wind. */
export function LegWeather({
  leg,
  subject = 'group',
  timezone,
}: {
  leg: WeatherLegDto
  /** The ride's or stage's zone: passages are rendezvous read in it (docs/LEDGER_*.md API-60). */
  timezone?: string
  /** What rides the leg — only the wording of a missing route or speed changes. */
  subject?: 'group' | 'stage'
}) {
  const { t } = useTranslation()
  const { distance, speed } = useUnits()
  const { formatTime, isGuessedText } = useRendezvousFormat(timezone)
  const labels = useWeatherLabels()

  if (leg.status === WeatherStatus.NO_LOCATION) {
    return (
      <Text size="sm" c="dimmed">
        {subject === 'stage' ? t('trips.weather.noRoute') : t('rides.weather.leg.noRoute')}
      </Text>
    )
  }
  if (!hasForecast(leg.status) || leg.checkpoints.length === 0) {
    return (
      <Text size="sm" c="dimmed">
        {t('rides.weather.leg.unavailable')}
      </Text>
    )
  }

  return (
    <Stack gap="sm">
      <Stack gap={2}>
        <Text size="sm" fw={600} suppressHydrationWarning={isGuessedText}>
          {t('rides.weather.leg.schedule', {
            start: formatTime(leg.startTime),
            arrival: formatTime(leg.arrivalTime),
            distance: distance(leg.distance),
          })}
        </Text>
        <Text size="xs" c="dimmed">
          {leg.speedIsDefault
            ? t(
                subject === 'stage'
                  ? 'trips.weather.speedDefault'
                  : 'rides.weather.leg.speedDefault',
                {
                  speed: speed(leg.averageSpeed),
                }
              )
            : t('rides.weather.leg.speed', { speed: speed(leg.averageSpeed) })}
        </Text>
        {leg.prevailingWind && (
          <Text size="xs" c="dimmed">
            {t('rides.weather.leg.prevailingWind', {
              wind: labels.windWithGusts(leg.prevailingWind),
            })}
          </Text>
        )}
      </Stack>
      <WeatherRainBanner rainAlert={leg.rainAlert} timezone={timezone} />
      <WeatherCheckpointStrip checkpoints={leg.checkpoints} timezone={timezone} />
      <WindExposureBar
        segments={leg.segments}
        exposure={leg.windExposure}
        distance={leg.distance}
      />
    </Stack>
  )
}
