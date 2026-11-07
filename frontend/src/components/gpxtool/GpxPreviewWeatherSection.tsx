import { useTranslation } from 'react-i18next'
import { Group, Loader, Paper, Stack, Text, Title } from '@mantine/core'
import type { GpxPreviewDto, RideWeatherDto } from '@/api/dto'
import { WeatherStatus } from '@/api/dto'
import { DepartureWeather } from '@/components/weather/DepartureWeather'
import { RouteWeather } from '@/components/weather/RouteWeather'
import { WeatherAttribution } from '@/components/weather/WeatherAttribution'
import { WeatherStaleBadge } from '@/components/weather/WeatherStaleBadge'
import { WeatherStatusNotice } from '@/components/weather/WeatherStatusNotice'
import { hasForecast, showsDetailBlock } from '@/components/weather/weatherDisplay'

interface GpxPreviewWeatherSectionProps {
  preview: GpxPreviewDto
  /** `GET /api/gpx-previews/{id}/weather`; undefined while loading or when the read failed. */
  weather: RideWeatherDto | undefined
  isLoading: boolean
  isFetching: boolean
  /** The cache is empty and the page is asking again: say that the forecast is on its way. */
  polling: boolean
  onRetry: () => void
}

/**
 * The weather of a GPX preview that has a departure date: the same bricks as a ride group's block
 * (`GroupWeatherSection`, typed on a ride), over the track's single leg. Nothing without a date.
 * A date already past says so, so that it is not mistaken for a failure; a read that failed reads
 * as UNAVAILABLE, like a ride's.
 */
export function GpxPreviewWeatherSection({
  preview,
  weather,
  isLoading,
  isFetching,
  polling,
  onRetry,
}: GpxPreviewWeatherSectionProps) {
  const { t } = useTranslation()

  if (!preview.departureTime || isLoading) return null

  const status = weather?.status ?? WeatherStatus.UNAVAILABLE
  if (status === WeatherStatus.OUT_OF_RANGE) {
    return (
      <Text size="sm" c="dimmed">
        {t('gpxTools.weather.departed')}
      </Text>
    )
  }
  if (!showsDetailBlock(status, false)) return null

  const leg = weather?.legs[0]
  const legHasForecast = !!leg && hasForecast(leg.status) && leg.checkpoints.length > 0

  return (
    <Paper
      withBorder
      p={{ base: 'md', sm: 'lg' }}
      component="section"
      aria-labelledby="gpx-preview-weather-title"
    >
      <Stack gap="lg">
        <Group justify="space-between" wrap="wrap" gap="xs" align="baseline">
          <Group gap="xs" wrap="wrap">
            <Title order={3} size="h4" id="gpx-preview-weather-title">
              {t('rides.group.weatherTitle')}
            </Title>
            {status === WeatherStatus.STALE && <WeatherStaleBadge />}
          </Group>
          {weather && (
            <WeatherAttribution attribution={weather.attribution} fetchedAt={weather.fetchedAt} />
          )}
        </Group>

        {polling ? (
          <Group gap="xs" wrap="nowrap">
            <Loader size="xs" />
            <Text size="sm" c="dimmed">
              {t('gpxTools.weather.pending')}
            </Text>
          </Group>
        ) : (
          <WeatherStatusNotice
            status={status}
            availableFrom={weather?.availableFrom}
            isFetching={isFetching}
            onRetry={onRetry}
          />
        )}

        {weather &&
          hasForecast(status) &&
          (legHasForecast ? (
            <RouteWeather
              leg={leg}
              departure={weather.departure}
              timezone={preview.departureTimezone}
              subject="track"
            />
          ) : (
            <Stack gap="md">
              <DepartureWeather
                departure={weather.departure}
                time={preview.departureTime}
                timezone={preview.departureTimezone}
              />
              <Text size="sm" c="dimmed">
                {t('rides.weather.leg.unavailable')}
              </Text>
            </Stack>
          ))}
      </Stack>
    </Paper>
  )
}
