import { useTranslation } from 'react-i18next'
import { Group, Paper, Stack, Text, Title } from '@mantine/core'
import type { DepartureWeatherDto, WeatherAttributionDto, WeatherLegDto } from '@/api/dto'
import { WeatherStatus } from '@/api/dto'
import { DepartureWeather } from './DepartureWeather'
import { RouteWeather, type RouteWeatherSelection } from './RouteWeather'
import { WeatherAttribution } from './WeatherAttribution'
import { WeatherStaleBadge } from './WeatherStaleBadge'
import { WeatherStatusNotice } from './WeatherStatusNotice'
import { hasForecast, showsDetailBlock } from './weatherDisplay'

export interface RouteWeatherSectionProps {
  /** Whose weather: a ride group's or a trip stage's — the wording of a few lines follows. */
  subject: 'group' | 'stage'
  /** False once the ride or the trip is over or cancelled: nothing is drawn. */
  offered: boolean
  /** The forecast's state, undefined when it could not be read (UNAVAILABLE). */
  status: WeatherStatus | undefined
  availableFrom?: string
  attribution?: WeatherAttributionDto
  fetchedAt?: string
  /** The weather when it leaves: its temperature, sunrise and sunset feed the verdicts. */
  departure: DepartureWeatherDto | undefined
  /** When the departure forecast is for: the hour `DepartureWeather` names without a leg. */
  departureTime: string
  leg: WeatherLegDto | undefined
  /** The ride's or the stage's zone: passages are rendezvous read in it (API-60). */
  timezone: string
  isLoading: boolean
  isFetching: boolean
  onRetry: () => void
  /** Organisers alone hear about a missing place or route (NO_LOCATION): they can fix it. */
  canEdit: boolean
  /** The point selected in « Heure par heure », when the page shares it with its map (WEB-117). */
  selection?: RouteWeatherSelection
  onSelectionChange?: (selection: RouteWeatherSelection) => void
  /** The heading's id, which names the section. */
  titleId?: string
}

/**
 * The whole weather along a route, full width under the map of a ride group's page or a trip
 * stage's (docs/LEDGER_*.md WEB-155): four verdicts (temperatures, rain, wind, daylight), the wind
 * phase by phase, then every forecast point at its estimated passage (`RouteWeather`). A leg without
 * a forecast — no route, or not yet — keeps the departure and a word why.
 *
 * Same states as the ride's block: over or cancelled, OUT_OF_RANGE and a status this build does
 * not know draw nothing; no data — a failed read included — reads as UNAVAILABLE.
 */
export function RouteWeatherSection({
  subject,
  offered,
  status: readStatus,
  availableFrom,
  attribution,
  fetchedAt,
  departure,
  departureTime,
  leg,
  timezone,
  isLoading,
  isFetching,
  onRetry,
  canEdit,
  selection,
  onSelectionChange,
  titleId = 'route-weather-title',
}: RouteWeatherSectionProps) {
  const { t } = useTranslation()

  if (!offered || isLoading) return null

  const status = readStatus ?? WeatherStatus.UNAVAILABLE
  if (!showsDetailBlock(status, canEdit)) return null

  const legHasForecast = !!leg && hasForecast(leg.status) && leg.checkpoints.length > 0
  const departureWeather = departure ?? { status }

  return (
    <Paper withBorder p={{ base: 'md', sm: 'lg' }} component="section" aria-labelledby={titleId}>
      <Stack gap="lg">
        <Group justify="space-between" wrap="wrap" gap="xs" align="baseline">
          <Group gap="xs" wrap="wrap">
            <Title order={3} size="h4" id={titleId}>
              {t('rides.group.weatherTitle')}
            </Title>
            {status === WeatherStatus.STALE && <WeatherStaleBadge />}
          </Group>
          {attribution && status !== WeatherStatus.NO_LOCATION && (
            <WeatherAttribution attribution={attribution} fetchedAt={fetchedAt} />
          )}
        </Group>

        <WeatherStatusNotice
          status={status}
          availableFrom={availableFrom}
          isFetching={isFetching}
          onRetry={onRetry}
          subject={subject === 'stage' ? 'stage' : 'ride'}
        />

        {hasForecast(status) &&
          (legHasForecast ? (
            <RouteWeather
              leg={leg}
              departure={departureWeather}
              timezone={timezone}
              selection={selection}
              onSelectionChange={onSelectionChange}
              subject={subject}
            />
          ) : (
            <Stack gap="md">
              <DepartureWeather
                departure={departureWeather}
                time={departureTime}
                timezone={timezone}
              />
              <Text size="sm" c="dimmed">
                {leg?.status === WeatherStatus.NO_LOCATION
                  ? t(subject === 'stage' ? 'trips.weather.noRoute' : 'rides.weather.leg.noRoute')
                  : t('rides.weather.leg.unavailable')}
              </Text>
            </Stack>
          ))}
      </Stack>
    </Paper>
  )
}
