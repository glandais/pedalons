import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { Anchor, Box, Group, Stack, Text, useMantineTheme } from '@mantine/core'
import type { WeatherAttributionDto } from '@/api/dto'
import { WeatherStatus } from '@/api/dto'
import { useUnits } from '@/hooks/useUnits'
import { relativeWindStrokeColors, windShares } from '@/lib/weatherOnRoute'
import type { WindLegendSource } from '@/lib/tripWeatherOnMap'
import { useWeatherLabels } from './useWeatherLabels'
import { WeatherStaleBadge } from './WeatherStaleBadge'

/** Who rides at the default speed, which only changes how that is said. */
export type WindLegendSubject = 'group' | 'stage' | 'trip'

const SPEED_DEFAULT_KEYS = {
  group: 'rides.weather.leg.speedDefault',
  stage: 'trips.weather.speedDefault',
  trip: 'trips.weather.map.speedDefault',
} as const satisfies Record<WindLegendSubject, string>

interface WindMapLegendProps {
  /** A leg — a group's, a stage's —, or a trip's stages taken together (`combinedWindLegend`). */
  leg: WindLegendSource
  /** Whose speed the passages assume when it is the default: a group (default), a stage, a trip. */
  subject?: WindLegendSubject
  /** The forecast's credit, repeated under the map: the profile overlay can cover the map's own. */
  attribution?: WeatherAttributionDto
}

/**
 * What the wind colouring of a group's route says, in words (ledger WEB-115): « Dos 32 km ·
 * Travers 18 km · Face 40 km », each behind a stroke of the line's colour — never the colour alone
 * (docs/BRANDING.md §3.6). Says when the forecast is old and when the passages assume the default
 * speed, which the wind of each stretch depends on.
 */
export function WindMapLegend({ leg, subject = 'group', attribution }: WindMapLegendProps) {
  const { t } = useTranslation()
  const theme = useMantineTheme()
  const { distance, speed } = useUnits()
  const labels = useWeatherLabels()
  const colors = useMemo(() => relativeWindStrokeColors(theme), [theme])
  const shares = windShares(leg)

  return (
    <Stack gap={4} data-testid="wind-map-legend">
      <Group gap="md" wrap="wrap" style={{ rowGap: 2 }}>
        <Text size="xs" c="dimmed">
          {t('rides.weather.map.legend')}
        </Text>
        {shares.map(({ relativeWind, length }) => (
          <Group key={relativeWind} gap={4} wrap="nowrap">
            {/* A stroke of the line's colour, as in the surface legend */}
            <Box
              w={14}
              h={0}
              aria-hidden
              style={{ borderTop: `4px solid ${colors[relativeWind]}`, flexShrink: 0 }}
            />
            <Text size="xs">
              {t('rides.weather.exposure.total', {
                relativeWind: labels.relativeWindShort(relativeWind),
                distance: distance(length),
              })}
            </Text>
          </Group>
        ))}
        {leg.status === WeatherStatus.STALE && <WeatherStaleBadge />}
      </Group>
      {leg.speedIsDefault && (
        <Text size="xs" c="dimmed">
          {t(SPEED_DEFAULT_KEYS[subject], { speed: speed(leg.averageSpeed) })}
        </Text>
      )}
      {attribution && (
        <Text size="xs" c="dimmed">
          {t('rides.weather.attribution')}{' '}
          <Anchor href={attribution.url} target="_blank" rel="noopener noreferrer" inherit>
            {attribution.name}
          </Anchor>
        </Text>
      )}
    </Stack>
  )
}
