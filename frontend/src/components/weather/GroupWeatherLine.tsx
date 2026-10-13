import { useTranslation } from 'react-i18next'
import { Badge, Group, Text } from '@mantine/core'
import { IconUmbrella } from '@tabler/icons-react'
import type { WeatherLegDto } from '@/api/dto'
import { RelativeWind } from '@/api/dto'
import { useUnits } from '@/hooks/useUnits'
import { useRendezvousFormat } from '@/hooks/useRendezvousFormat'
import { WeatherIcon } from './WeatherIcon'
import { useWeatherLabels } from './useWeatherLabels'
import { hasForecast, rainAlertCondition, relativeWindColor } from './weatherDisplay'

interface GroupWeatherLineProps {
  /** The group's leg of the ride's forecast; nothing is drawn without one. */
  leg: WeatherLegDto | undefined
  /** The ride's zone: the rain's time is a passage, read in it (docs/LEDGER_*.md API-60). */
  timezone?: string
}

/** The kinds of wind the line names: the two a rider feels, never the crosswind. */
const LINE_WINDS = [RelativeWind.HEAD, RelativeWind.TAIL] as const

/**
 * A group's weather in one line, on its card of the ride page — not a link, the group's page holds
 * the detail: the sky and temperature at the group's own start, a rain alert when one is raised
 * (« Pluie 40 % vers 10:30 »), and how far it rides against and with the wind. The wind badges
 * take their colour from the generated `RELATIVE_WIND_COLORS` and always say their kind: never
 * colour alone. No forecast for the leg, nothing at all.
 */
export function GroupWeatherLine({ leg, timezone }: GroupWeatherLineProps) {
  const { t } = useTranslation()
  const { temperature, distance } = useUnits()
  const passage = useRendezvousFormat(timezone)
  const labels = useWeatherLabels()

  const start = leg?.checkpoints[0]?.weather
  if (!leg || !hasForecast(leg.status) || !start) return null

  const exposure: Record<(typeof LINE_WINDS)[number], number> = {
    [RelativeWind.HEAD]: leg.windExposure.head,
    [RelativeWind.TAIL]: leg.windExposure.tail,
  }

  return (
    <Group
      gap="xs"
      wrap="wrap"
      role="group"
      aria-label={t('rides.weather.groupLine.label')}
      data-testid="group-weather-line"
    >
      <Group gap={4} wrap="nowrap">
        <WeatherIcon condition={start.condition} daylight={start.daylight} size={16} />
        <Text size="sm" c="dimmed">
          {t('rides.weather.groupLine.conditions', {
            temperature: temperature(start.temperature),
            condition: labels.condition(start.condition),
          })}
        </Text>
      </Group>
      {leg.rainAlert && (
        <Badge
          size="sm"
          color="blue"
          variant="light"
          leftSection={<IconUmbrella size={12} aria-hidden />}
        >
          <span suppressHydrationWarning={passage.isGuessedText}>
            {t('rides.weather.groupLine.rain', {
              condition: labels.condition(rainAlertCondition(leg.rainAlert.condition)),
              probability: leg.rainAlert.probability,
              time: passage.formatTime(leg.rainAlert.time),
            })}
          </span>
        </Badge>
      )}
      {LINE_WINDS.filter((kind) => exposure[kind] > 0).map((kind) => (
        <Badge
          key={kind}
          size="sm"
          color={relativeWindColor(kind)}
          variant="light"
          aria-label={t('rides.weather.exposure.total', {
            relativeWind: labels.relativeWind(kind),
            distance: distance(exposure[kind]),
          })}
        >
          {t('rides.weather.exposure.total', {
            relativeWind: labels.relativeWindShort(kind),
            distance: distance(exposure[kind]),
          })}
        </Badge>
      ))}
    </Group>
  )
}
