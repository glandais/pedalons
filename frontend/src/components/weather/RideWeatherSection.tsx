import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  Badge,
  Button,
  Divider,
  Group,
  Paper,
  Select,
  SegmentedControl,
  Stack,
  Text,
  Title,
} from '@mantine/core'
import {
  IconCalendarTime,
  IconCloudOff,
  IconHistory,
  IconMapPinOff,
  IconRefresh,
} from '@tabler/icons-react'
import type { RideDto, RideWeatherDto, WeatherLegDto } from '@/api/dto'
import { Status, WeatherStatus } from '@/api/dto'
import { useFormattedDate } from '@/utils/dateFormat'
import { DepartureWeather } from './DepartureWeather'
import { LegWeather } from './LegWeather'
import { WeatherAttribution } from './WeatherAttribution'
import { defaultLegIndex, hasForecast, showsDetailBlock } from './weatherDisplay'

/** Up to this many groups pick from a segmented control; beyond, a select keeps the row short. */
const SEGMENTED_MAX_LEGS = 4

interface RideWeatherSectionProps {
  ride: RideDto
  /** `GET …/rides/{rideSlug}/weather`, read by `useRideDetailData` and prefetched with it. */
  weather: RideWeatherDto | undefined
  isLoading: boolean
  isFetching: boolean
  onRetry: () => void
  /** Organisers alone hear about a ride without a place (NO_LOCATION): they can fix it. */
  canEdit: boolean
  /**
   * The group chosen on the page — here, on the map or among the group cards. Left undefined, the
   * block keeps its own choice; either way it opens on the reader's group.
   */
  selectedGroupId?: string | null
  onSelectGroup?: (groupId: string) => void
}

/**
 * The weather block of the ride page: the meeting point at departure, then one group's route —
 * the reader's own group by default — as forecast points at their estimated passages, a rain or
 * dry banner, and the wind stretch by stretch.
 *
 * Every number is the server's (docs/plans/archive/2026-10-05-weather.md §1: passages, relative wind,
 * exposure and rain alert are computed once, backend side); this only words them and converts
 * the units. A finished or cancelled ride, OUT_OF_RANGE and a status this build does not know draw
 * nothing.
 */
export function RideWeatherSection({
  ride,
  weather,
  isLoading,
  isFetching,
  onRetry,
  canEdit,
  selectedGroupId,
  onSelectGroup,
}: RideWeatherSectionProps) {
  const { t } = useTranslation()
  const { formatDate, isGuessedTimezone } = useFormattedDate()
  const [ownSelectedLeg, setOwnSelectedLeg] = useState<string | null>(null)
  const selectedLeg = selectedGroupId !== undefined ? selectedGroupId : ownSelectedLeg
  const setSelectedLeg = (key: string) => {
    setOwnSelectedLeg(key)
    onSelectGroup?.(key)
  }

  if (ride.finished || ride.status === Status.CANCELLED || isLoading) return null

  // No data — a failed read included — is the same promise as UNAVAILABLE: nothing to show yet,
  // try again. A failed *refetch* is not: React Query v5 keeps its data beside `isError`, and the
  // forecast already on screen stays, as the server itself serves a stale one rather than nothing.
  // That is why this takes no `isError`.
  const status = !weather ? WeatherStatus.UNAVAILABLE : weather.status
  if (!showsDetailBlock(status, canEdit)) return null

  const legs = weather && hasForecast(status) ? weather.legs : []
  const legKey = (leg: WeatherLegDto, index: number) => leg.groupId ?? `leg-${index}`
  const defaultIndex = defaultLegIndex(legs, ride.registeredGroupId)
  const selectedIndex = legs.findIndex((leg, index) => legKey(leg, index) === selectedLeg)
  const legIndex = selectedIndex >= 0 ? selectedIndex : defaultIndex
  const leg = legs[legIndex]

  const groupName = (leg: WeatherLegDto, index: number) =>
    ride.groups?.find((group) => group.id === leg.groupId)?.name ??
    t('rides.weather.leg.unnamed', { index: index + 1 })
  const legOptions = legs.map((leg, index) => ({
    value: legKey(leg, index),
    label: groupName(leg, index),
  }))

  return (
    <Paper withBorder p="lg" mb="lg" component="section" aria-labelledby="ride-weather-title">
      <Stack gap="md">
        <Group justify="space-between" wrap="wrap" gap="xs">
          <Title order={4} id="ride-weather-title">
            {t('rides.weather.title')}
          </Title>
          {status === WeatherStatus.STALE && (
            <Badge
              color="yellow"
              variant="light"
              leftSection={<IconHistory size={12} aria-hidden />}
            >
              {t('rides.weather.stale')}
            </Badge>
          )}
        </Group>

        {status === WeatherStatus.NOT_YET_AVAILABLE && (
          <Group gap="xs" wrap="nowrap">
            <IconCalendarTime size={18} color="var(--mantine-color-dimmed)" aria-hidden />
            <Text size="sm" c="dimmed" suppressHydrationWarning={isGuessedTimezone}>
              {weather?.availableFrom
                ? t('rides.weather.notYetAvailable', { date: formatDate(weather.availableFrom) })
                : t('rides.weather.notYetAvailableNoDate')}
            </Text>
          </Group>
        )}

        {status === WeatherStatus.UNAVAILABLE && (
          <Group gap="sm" wrap="wrap" justify="space-between">
            <Group gap="xs" wrap="nowrap">
              <IconCloudOff size={18} color="var(--mantine-color-dimmed)" aria-hidden />
              <Text size="sm" c="dimmed">
                {t('rides.weather.unavailable')}
              </Text>
            </Group>
            <Button
              variant="light"
              size="xs"
              leftSection={<IconRefresh size={14} aria-hidden />}
              loading={isFetching}
              onClick={onRetry}
            >
              {t('rides.weather.retry')}
            </Button>
          </Group>
        )}

        {status === WeatherStatus.NO_LOCATION && (
          <Group gap="xs" wrap="nowrap">
            <IconMapPinOff size={18} color="var(--mantine-color-dimmed)" aria-hidden />
            <Text size="sm" c="dimmed">
              {t('rides.weather.noLocation')}
            </Text>
          </Group>
        )}

        {weather && hasForecast(status) && (
          <>
            <DepartureWeather
              departure={weather.departure}
              time={ride.dateTime}
              timezone={ride.timezone}
            />

            {leg && (
              <>
                <Divider />
                {legs.length > 1 &&
                  (legs.length <= SEGMENTED_MAX_LEGS ? (
                    <SegmentedControl
                      data={legOptions}
                      value={legKey(leg, legIndex)}
                      onChange={setSelectedLeg}
                      aria-label={t('rides.weather.leg.select')}
                      fullWidth
                    />
                  ) : (
                    <Select
                      data={legOptions}
                      value={legKey(leg, legIndex)}
                      onChange={(value) => value && setSelectedLeg(value)}
                      label={t('rides.weather.leg.select')}
                      allowDeselect={false}
                      maxDropdownHeight={400}
                      maw={320}
                    />
                  ))}
                <LegWeather leg={leg} timezone={ride.timezone} />
              </>
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
