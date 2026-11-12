import { useTranslation } from 'react-i18next'
import { Group, Text } from '@mantine/core'
import { IconAlertTriangle, IconCalendarTime, IconHistory } from '@tabler/icons-react'
import type { RideWeatherSummaryDto } from '@/api/dto'
import { WeatherStatus } from '@/api/dto'
import { useUnits } from '@/hooks/useUnits'
import { useFormattedDate } from '@/utils/dateFormat'
import { useRendezvousFormat } from '@/hooks/useRendezvousFormat'
import { WeatherIcon } from './WeatherIcon'
import { WindFromArrow } from './WindFromArrow'
import { showsSummary, temperatureRange } from './weatherDisplay'
import classes from './RideWeatherSummaryLine.module.css'

interface RideWeatherSummaryLineProps {
  summary: RideWeatherSummaryDto | undefined
  /**
   * The ride's or stage's zone: passages are rendezvous read in it (docs/LEDGER_*.md API-60). The
   * summary's own `timezone` wins when set — a trip's card, whose line is its next stage's.
   */
  timezone?: string
}

/**
 * The weather line of a card — the app's (`RideWeatherSummaryLine`, KIT §8 and §9, docs/LEDGER_*.md
 * WEB-167 R2), on every card that carries a `RideWeatherSummaryDto`: a ride's (`PublicationCard`,
 * `NextRideCard`), a trip's (its next stage), a stage's (`TripStageCard`) and a group's
 * (`WeatherLegDto.summary`, through `GroupWeatherLine`).
 *
 * « ☁ 9–13 °C · ↗ 18 km/h · Pluie 20 % »: the sky's icon at departure, the range min–max over the
 * window, the wind at departure — its arrow carries the direction, the text the speed alone —, then
 * the rain, always written: the alert « Pluie 60 % vers 11:00 » in the warning tint when one is
 * raised, the highest probability otherwise. No sky in words, no Face / Dos badge: the detail
 * screens hold them. An old forecast keeps its mark; before the forecast opens, « Météo dès le
 * 15 novembre ». Anything else — no summary, a status this build does not know — draws nothing.
 *
 * Everything here is the server's (`RideDto.weather`, `TripDto.weather`,
 * docs/plans/archive/2026-10-05-weather.md §4): the card only words it and converts the units.
 */
export function RideWeatherSummaryLine({ summary, timezone }: RideWeatherSummaryLineProps) {
  const { t } = useTranslation()
  const { temperatureRange: rangeText, speed, percent } = useUnits()
  const { formatDayMonth, isGuessedTimezone } = useFormattedDate()
  const passage = useRendezvousFormat(summary?.timezone ?? timezone)

  if (!summary || !showsSummary(summary)) return null

  if (summary.status === WeatherStatus.NOT_YET_AVAILABLE) {
    return (
      <Group gap={4} wrap="nowrap" data-testid="ride-weather-summary">
        <IconCalendarTime size={16} color="var(--mantine-color-dimmed)" aria-hidden />
        <Text size="sm" c="dimmed" suppressHydrationWarning={isGuessedTimezone}>
          {t('rides.weather.summary.availableFrom', {
            date: formatDayMonth(summary.availableFrom),
          })}
        </Text>
      </Group>
    )
  }

  const range = temperatureRange(summary)
  const alert = summary.rainAlert
  const probability = summary.maxPrecipitationProbability

  return (
    <Group
      gap="sm"
      wrap="wrap"
      role="group"
      aria-label={t('rides.weather.title')}
      data-testid="ride-weather-summary"
    >
      {(summary.condition || range) && (
        <Group gap={4} wrap="nowrap">
          <WeatherIcon
            condition={summary.condition}
            daylight={summary.daylight ?? true}
            size={16}
          />
          {range && (
            <Text size="sm" c="dimmed">
              {rangeText(range.min, range.max)}
            </Text>
          )}
        </Group>
      )}
      {summary.wind && (
        <Text size="sm" c="dimmed" style={{ whiteSpace: 'nowrap' }}>
          <WindFromArrow wind={summary.wind} size={16} /> {speed(summary.wind.speed)}
        </Text>
      )}
      {alert ? (
        <Group gap={4} wrap="nowrap" data-testid="ride-weather-rain-alert">
          <IconAlertTriangle size={16} className={classes.alertIcon} aria-hidden />
          <Text
            size="sm"
            className={classes.alertText}
            suppressHydrationWarning={passage.isGuessedText}
          >
            {t('rides.weather.summary.rainAlert', {
              probability: percent(alert.probability),
              time: passage.formatTime(alert.time),
            })}
          </Text>
        </Group>
      ) : (
        probability !== undefined && (
          <Text size="sm" c="dimmed" style={{ whiteSpace: 'nowrap' }}>
            {t('rides.weather.summary.rain', { probability: percent(probability) })}
          </Text>
        )
      )}
      {summary.status === WeatherStatus.STALE && (
        <IconHistory
          size={14}
          color="var(--mantine-color-dimmed)"
          role="img"
          aria-label={t('rides.weather.stale')}
        />
      )}
    </Group>
  )
}
