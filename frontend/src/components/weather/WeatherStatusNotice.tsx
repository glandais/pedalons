import { useTranslation } from 'react-i18next'
import { Button, Group, Text } from '@mantine/core'
import { IconCalendarTime, IconCloudOff, IconMapPinOff, IconRefresh } from '@tabler/icons-react'
import type { Instant } from '@/api/dto'
import { WeatherStatus } from '@/api/dto'
import { useFormattedDate } from '@/utils/dateFormat'

interface WeatherStatusNoticeProps {
  status: string
  /** For NOT_YET_AVAILABLE: when the ride's forecast opens. */
  availableFrom?: Instant
  isFetching: boolean
  onRetry: () => void
  /** Whose weather it is: a ride's (default) or a trip stage's, for the two notices that differ. */
  subject?: 'ride' | 'stage'
}

const NOTICE_KEYS = {
  ride: {
    notYetAvailableNoDate: 'rides.weather.notYetAvailableNoDate',
    noLocation: 'rides.weather.noLocation',
  },
  stage: {
    notYetAvailableNoDate: 'trips.weather.notYetAvailableNoDate',
    noLocation: 'trips.weather.noLocation',
  },
} as const

/**
 * What a ride's weather block says when it has no forecast to show: when it will (beyond the
 * seven-day horizon), that it could not be read — with a retry —, or that the ride has no place
 * (NO_LOCATION, shown to organisers only: `showsDetailBlock` decides). OK and STALE say nothing
 * here. Shared by the ride's « Météo au départ » and the « Météo du parcours » of a group or a stage.
 */
export function WeatherStatusNotice({
  status,
  availableFrom,
  isFetching,
  onRetry,
  subject = 'ride',
}: WeatherStatusNoticeProps) {
  const { t } = useTranslation()
  const { formatDate, isGuessedTimezone } = useFormattedDate()

  switch (status) {
    case WeatherStatus.NOT_YET_AVAILABLE:
      return (
        <Group gap="xs" wrap="nowrap">
          <IconCalendarTime size={18} color="var(--mantine-color-dimmed)" aria-hidden />
          <Text size="sm" c="dimmed" suppressHydrationWarning={isGuessedTimezone}>
            {availableFrom
              ? t('rides.weather.notYetAvailable', { date: formatDate(availableFrom) })
              : t(NOTICE_KEYS[subject].notYetAvailableNoDate)}
          </Text>
        </Group>
      )
    case WeatherStatus.UNAVAILABLE:
      return (
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
      )
    case WeatherStatus.NO_LOCATION:
      return (
        <Group gap="xs" wrap="nowrap">
          <IconMapPinOff size={18} color="var(--mantine-color-dimmed)" aria-hidden />
          <Text size="sm" c="dimmed">
            {t(NOTICE_KEYS[subject].noLocation)}
          </Text>
        </Group>
      )
    default:
      return null
  }
}
