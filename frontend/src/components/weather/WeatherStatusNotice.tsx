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
}

/**
 * What a ride's weather block says when it has no forecast to show: when it will (beyond the
 * seven-day horizon), that it could not be read — with a retry —, or that the ride has no place
 * (NO_LOCATION, shown to organisers only: `showsDetailBlock` decides). OK and STALE say nothing
 * here. Shared by the ride's « Météo au départ » and a group's « Météo du parcours ».
 */
export function WeatherStatusNotice({
  status,
  availableFrom,
  isFetching,
  onRetry,
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
              : t('rides.weather.notYetAvailableNoDate')}
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
            {t('rides.weather.noLocation')}
          </Text>
        </Group>
      )
    default:
      return null
  }
}
