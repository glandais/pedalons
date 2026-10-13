import { useTranslation } from 'react-i18next'
import { Group, Stack, Text } from '@mantine/core'
import { IconDroplet, IconSunrise, IconSunset, IconWind } from '@tabler/icons-react'
import type { DepartureWeatherDto, Instant } from '@/api/dto'
import { useUnits } from '@/hooks/useUnits'
import { useRendezvousFormat } from '@/hooks/useRendezvousFormat'
import { Stat } from '../card/common'
import { FormattedTime } from '../common/FormattedDate'
import { WeatherIcon } from './WeatherIcon'
import { useWeatherLabels } from './useWeatherLabels'
import { hasForecast } from './weatherDisplay'

interface DepartureWeatherProps {
  departure: DepartureWeatherDto
  /**
   * The ride's own departure (`ride.dateTime`), the moment the server forecasts the meeting point
   * for. Not `conditions.time`: that is the model's nearest round hour, and a 9:40 meeting must
   * not read « Au départ · 10:00 ».
   */
  time: Instant
  /** The ride's or stage's zone: passages are rendezvous read in it (docs/LEDGER_*.md API-60). */
  timezone?: string
}

/** The meeting point at departure: sky, temperature and felt temperature, rain, wind, daylight. */
export function DepartureWeather({ departure, time, timezone }: DepartureWeatherProps) {
  const { t } = useTranslation()
  const { temperature } = useUnits()
  const { formatTime, isGuessedText } = useRendezvousFormat(timezone)
  const labels = useWeatherLabels()
  const conditions = departure.conditions

  if (!hasForecast(departure.status) || !conditions) {
    return (
      <Text size="sm" c="dimmed">
        {t('rides.weather.departure.unavailable')}
      </Text>
    )
  }

  const wind = conditions.wind

  return (
    <Group gap="md" align="flex-start" wrap="nowrap">
      <WeatherIcon condition={conditions.condition} daylight={conditions.daylight} size={44} />
      <Stack gap={4} style={{ minWidth: 0 }}>
        <Text size="xs" c="dimmed" tt="uppercase" fw={600}>
          <span suppressHydrationWarning={isGuessedText}>
            {t('rides.weather.departure.title', { time: formatTime(time) })}
          </span>
        </Text>
        <Group gap="xs" align="baseline" wrap="wrap">
          <Text size="xl" fw={700}>
            {temperature(conditions.temperature)}
          </Text>
          <Text size="sm">{labels.condition(conditions.condition)}</Text>
          <Text size="sm" c="dimmed">
            {t('rides.weather.feelsLike', {
              temperature: temperature(conditions.apparentTemperature),
            })}
          </Text>
        </Group>
        <Group gap="md" wrap="wrap">
          {conditions.precipitationProbability !== undefined && (
            <Stat icon={<IconDroplet size={16} aria-hidden />}>
              {conditions.precipitation > 0
                ? t('rides.weather.precipitationWithAmount', {
                    probability: conditions.precipitationProbability,
                    amount: conditions.precipitation.toFixed(1),
                  })
                : t('rides.weather.precipitation', {
                    probability: conditions.precipitationProbability,
                  })}
            </Stat>
          )}
          <Stat icon={<IconWind size={16} aria-hidden />}>{labels.windWithGusts(wind)}</Stat>
          {departure.sunrise && (
            <Stat
              icon={<IconSunrise size={16} role="img" aria-label={t('rides.weather.sunrise')} />}
            >
              <FormattedTime date={departure.sunrise} />
            </Stat>
          )}
          {departure.sunset && (
            <Stat icon={<IconSunset size={16} role="img" aria-label={t('rides.weather.sunset')} />}>
              <FormattedTime date={departure.sunset} />
            </Stat>
          )}
        </Group>
      </Stack>
    </Group>
  )
}
