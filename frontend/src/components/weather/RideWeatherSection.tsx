import { useTranslation } from 'react-i18next'
import { Divider, Group, Paper, Stack, Title } from '@mantine/core'
import type { RideDto, RideWeatherDto } from '@/api/dto'
import { Status, WeatherStatus } from '@/api/dto'
import { DepartureWeather } from './DepartureWeather'
import { LegWeather } from './LegWeather'
import { WeatherAttribution } from './WeatherAttribution'
import { WeatherStaleBadge } from './WeatherStaleBadge'
import { WeatherStatusNotice } from './WeatherStatusNotice'
import { hasForecast, showsDetailBlock } from './weatherDisplay'
import { ownLeg } from '@/utils/soloGroup'

interface RideWeatherSectionProps {
  ride: RideDto
  /** `GET …/rides/{rideSlug}/weather`, read by `useRideDetailData` and prefetched with it. */
  weather: RideWeatherDto | undefined
  isLoading: boolean
  isFetching: boolean
  onRetry: () => void
  /** Organisers alone hear about a ride without a place (NO_LOCATION): they can fix it. */
  canEdit: boolean
}

/**
 * The weather block of the ride page: « Météo au départ », the meeting point at the ride's
 * departure — sky, temperature and felt temperature, rain, wind and gusts, daylight —, then the
 * provider and the time of the forecast. Each group's route lives on the group's own page
 * (`GroupWeatherSection`, ledger WEB-77), its card carrying a one-line summary.
 *
 * One exception, for a ride with no group page — 0 **or** 1 group (ledger WEB-79, `ownLeg`): a
 * ride without groups unrolls its single leg (no `groupId`, the ride's own route), a solo ride its
 * one group's leg, under the departure — otherwise that weather would show nowhere.
 *
 * Every number is the server's (docs/plans/archive/2026-10-05-weather.md §1); this only words
 * them and converts the units. A finished or cancelled ride, OUT_OF_RANGE and a status this build
 * does not know draw nothing.
 */
export function RideWeatherSection({
  ride,
  weather,
  isLoading,
  isFetching,
  onRetry,
  canEdit,
}: RideWeatherSectionProps) {
  const { t } = useTranslation()

  if (ride.finished || ride.status === Status.CANCELLED || isLoading) return null

  // No data — a failed read included — is the same promise as UNAVAILABLE: nothing to show yet,
  // try again. A failed *refetch* is not: React Query v5 keeps its data beside `isError`, and the
  // forecast already on screen stays, as the server itself serves a stale one rather than nothing.
  // That is why this takes no `isError`.
  const status = !weather ? WeatherStatus.UNAVAILABLE : weather.status
  if (!showsDetailBlock(status, canEdit)) return null

  const leg = weather && hasForecast(status) ? ownLeg(ride, weather) : undefined

  return (
    <Paper withBorder p="lg" mb="lg" component="section" aria-labelledby="ride-weather-title">
      <Stack gap="md">
        <Group justify="space-between" wrap="wrap" gap="xs">
          <Title order={4} id="ride-weather-title">
            {t('rides.weather.departureTitle')}
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
          <DepartureWeather
            departure={weather.departure}
            time={ride.dateTime}
            timezone={ride.timezone}
          />
        )}

        {leg && (
          <>
            <Divider />
            <LegWeather leg={leg} timezone={ride.timezone} />
          </>
        )}

        {weather && status !== WeatherStatus.NO_LOCATION && (
          <WeatherAttribution attribution={weather.attribution} fetchedAt={weather.fetchedAt} />
        )}
      </Stack>
    </Paper>
  )
}
