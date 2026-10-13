import { useTranslation } from 'react-i18next'
import { Divider, Group, Paper, Stack, Text, Title } from '@mantine/core'
import type { RideDto, RideWeatherDto, WeatherLegDto } from '@/api/dto'
import { Status, WeatherStatus } from '@/api/dto'
import { DepartureWeather } from './DepartureWeather'
import { LegWeather } from './LegWeather'
import { WeatherAttribution } from './WeatherAttribution'
import { WeatherStaleBadge } from './WeatherStaleBadge'
import { WeatherStatusNotice } from './WeatherStatusNotice'
import { hasForecast, showsDetailBlock } from './weatherDisplay'

interface GroupWeatherSectionProps {
  ride: RideDto
  /** `GET …/rides/{rideSlug}/weather`, the ride page's own read (shared cache). */
  weather: RideWeatherDto | undefined
  /** This group's leg (`leg.groupId === group.id`), undefined when the forecast has none. */
  leg: WeatherLegDto | undefined
  isLoading: boolean
  isFetching: boolean
  onRetry: () => void
  /** Organisers alone hear about a ride without a place (NO_LOCATION): they can fix it. */
  canEdit: boolean
}

/**
 * The whole weather of one group, on the group's page: the meeting point at departure, then the
 * group's route — its schedule and speed, the prevailing wind, rain or dry, the forecast points at
 * their estimated passages and the wind stretch by stretch —, then the provider and the time of
 * the forecast. The ride page keeps only the departure (`RideWeatherSection`).
 *
 * Same states as the ride's block: a finished or cancelled ride, OUT_OF_RANGE and a status this
 * build does not know draw nothing; no data — a failed read included — reads as UNAVAILABLE.
 */
export function GroupWeatherSection({
  ride,
  weather,
  leg,
  isLoading,
  isFetching,
  onRetry,
  canEdit,
}: GroupWeatherSectionProps) {
  const { t } = useTranslation()

  if (ride.finished || ride.status === Status.CANCELLED || isLoading) return null

  const status = !weather ? WeatherStatus.UNAVAILABLE : weather.status
  if (!showsDetailBlock(status, canEdit)) return null

  return (
    <Paper withBorder p="lg" component="section" aria-labelledby="group-weather-title">
      <Stack gap="md">
        <Group justify="space-between" wrap="wrap" gap="xs">
          <Title order={3} size="h4" id="group-weather-title">
            {t('rides.group.weatherTitle')}
          </Title>
          {status === WeatherStatus.STALE && <WeatherStaleBadge />}
        </Group>

        <WeatherStatusNotice
          status={status}
          availableFrom={weather?.availableFrom}
          isFetching={isFetching}
          onRetry={onRetry}
        />

        {weather && hasForecast(status) && (
          <>
            <DepartureWeather
              departure={weather.departure}
              time={ride.dateTime}
              timezone={ride.timezone}
            />
            <Divider />
            {leg ? (
              <LegWeather leg={leg} timezone={ride.timezone} />
            ) : (
              <Text size="sm" c="dimmed">
                {t('rides.weather.leg.unavailable')}
              </Text>
            )}
          </>
        )}

        {weather && status !== WeatherStatus.NO_LOCATION && (
          <WeatherAttribution attribution={weather.attribution} fetchedAt={weather.fetchedAt} />
        )}
      </Stack>
    </Paper>
  )
}
