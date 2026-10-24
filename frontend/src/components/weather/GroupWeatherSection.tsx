import { useTranslation } from 'react-i18next'
import { Group, Paper, Stack, Text, Title } from '@mantine/core'
import type { RideDto, RideWeatherDto, WeatherLegDto } from '@/api/dto'
import { Status, WeatherStatus } from '@/api/dto'
import { DepartureWeather } from './DepartureWeather'
import { RouteWeather, type RouteWeatherSelection } from './RouteWeather'
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
  /** The point selected in « Heure par heure », when the page shares it with its map (WEB-117). */
  selection?: RouteWeatherSelection
  onSelectionChange?: (selection: RouteWeatherSelection) => void
}

/**
 * The whole weather of one group, full width on the group's page: four verdicts (temperatures,
 * rain, wind, daylight), the wind phase by phase, then every forecast point at its estimated
 * passage (`RouteWeather`). A group whose leg has no forecast — no route, or not yet — keeps the
 * meeting point at departure and a word why. The ride page keeps only the departure
 * (`RideWeatherSection`); a trip stage keeps the strip (`LegWeather`).
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
  selection,
  onSelectionChange,
}: GroupWeatherSectionProps) {
  const { t } = useTranslation()

  if (ride.finished || ride.status === Status.CANCELLED || isLoading) return null

  const status = !weather ? WeatherStatus.UNAVAILABLE : weather.status
  if (!showsDetailBlock(status, canEdit)) return null

  const legHasForecast = !!leg && hasForecast(leg.status) && leg.checkpoints.length > 0 && !!weather

  return (
    <Paper
      withBorder
      p={{ base: 'md', sm: 'lg' }}
      component="section"
      aria-labelledby="group-weather-title"
    >
      <Stack gap="lg">
        <Group justify="space-between" wrap="wrap" gap="xs" align="baseline">
          <Group gap="xs" wrap="wrap">
            <Title order={3} size="h4" id="group-weather-title">
              {t('rides.group.weatherTitle')}
            </Title>
            {status === WeatherStatus.STALE && <WeatherStaleBadge />}
          </Group>
          {weather && status !== WeatherStatus.NO_LOCATION && (
            <WeatherAttribution attribution={weather.attribution} fetchedAt={weather.fetchedAt} />
          )}
        </Group>

        <WeatherStatusNotice
          status={status}
          availableFrom={weather?.availableFrom}
          isFetching={isFetching}
          onRetry={onRetry}
        />

        {weather &&
          hasForecast(status) &&
          (legHasForecast ? (
            <RouteWeather
              leg={leg}
              departure={weather.departure}
              timezone={ride.timezone}
              selection={selection}
              onSelectionChange={onSelectionChange}
            />
          ) : (
            <Stack gap="md">
              <DepartureWeather
                departure={weather.departure}
                time={ride.dateTime}
                timezone={ride.timezone}
              />
              <Text size="sm" c="dimmed">
                {leg?.status === WeatherStatus.NO_LOCATION
                  ? t('rides.weather.leg.noRoute')
                  : t('rides.weather.leg.unavailable')}
              </Text>
            </Stack>
          ))}
      </Stack>
    </Paper>
  )
}
