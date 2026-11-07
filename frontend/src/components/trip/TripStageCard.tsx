import { useNavigate } from 'react-router-dom'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useTranslation } from 'react-i18next'
import { IconArrowsMaximize, IconArrowUp, IconMapPin } from '@tabler/icons-react'
import { Paper, Group, Text, UnstyledButton, Badge, Box } from '@mantine/core'
import type { RideWeatherSummaryDto, TripStageDto } from '@/api/dto'
import { RideWeatherSummaryLine } from '@/components/weather'
import { DepartureLine } from '../common/DepartureLine'
import { useUnits } from '@/hooks/useUnits'
import { MediaDisplay } from '../common/MediaDisplay'
import { EntityLogo } from '../common/EntityLogo'
import { paths } from '@/config/paths'
import classes from './TripStageCard.module.css'

interface TripStageCardProps {
  stage: TripStageDto
  index: number
  teamSlug: string
  tripSlug: string
  onHover?: (stageId: string | null) => void
  isHighlighted?: boolean
  /** The stage's weather line, from `GET …/trips/{tripSlug}/weather` (docs/LEDGER_*.md API-76). */
  weather?: RideWeatherSummaryDto
}

export function TripStageCard({
  stage,
  index,
  teamSlug,
  tripSlug,
  onHover,
  isHighlighted = false,
  weather,
}: TripStageCardProps) {
  const { t } = useTranslation()
  const { distance, elevation } = useUnits()
  const navigate = useNavigate()

  return (
    <Paper
      component={PrefetchLink}
      to={paths.stage(teamSlug, tripSlug, stage.slug)}
      withBorder
      p="md"
      radius="md"
      style={{
        borderColor: isHighlighted ? 'var(--mantine-primary-color-filled)' : undefined,
        backgroundColor: isHighlighted ? 'var(--mantine-primary-color-light)' : undefined,
        boxShadow: isHighlighted ? 'var(--mantine-shadow-md)' : undefined,
        transition: 'all 0.2s',
        textDecoration: 'none',
        color: 'inherit',
        cursor: 'pointer',
      }}
      onMouseEnter={() => onHover?.(stage.id)}
      onMouseLeave={() => onHover?.(null)}
    >
      <Group justify="space-between" mb="sm" wrap="nowrap">
        <Group gap="sm" wrap="nowrap" style={{ minWidth: 0 }}>
          {stage.media.assets.logo ? (
            <EntityLogo logo={stage.media.assets.logo} alt={stage.name} size="md" />
          ) : (
            <Badge size="lg" variant="light" color="primary" circle style={{ flexShrink: 0 }}>
              {index + 1}
            </Badge>
          )}
          <Text fw={600} truncate>
            {stage.name}
          </Text>
        </Group>
        {/* « sam. 12 avr. · 09:00 » in 700, short enough not to squeeze the name (WEB-138). */}
        <Box style={{ flexShrink: 0 }}>
          <DepartureLine date={stage.dateTime} zone={stage.timezone} size="sm" withDay />
        </Box>
      </Group>

      {weather && (
        <Box mb="sm">
          <RideWeatherSummaryLine summary={weather} timezone={stage.timezone} />
        </Box>
      )}

      {stage.media.markdown && (
        <Box mb="sm">
          <MediaDisplay media={stage.media} />
        </Box>
      )}

      {(stage.startPlace || stage.endPlace) && (
        <Group wrap="wrap">
          {stage.startPlace && (
            <Group gap={4} wrap="nowrap">
              <IconMapPin size={16} color="var(--mantine-color-green-text)" />
              <Text size="sm" c="var(--mantine-color-green-text)" fw={500}>
                {t('startPlace')}:
              </Text>
              <Text size="sm">{stage.startPlace.name}</Text>
            </Group>
          )}
          {stage.endPlace && (
            <Group gap={4} wrap="nowrap">
              <IconMapPin size={16} color="var(--mantine-color-red-text)" />
              <Text size="sm" c="var(--mantine-color-red-text)" fw={500}>
                {t('endPlace')}:
              </Text>
              <Text size="sm">{stage.endPlace.name}</Text>
            </Group>
          )}
        </Group>
      )}

      {stage.route && (
        <Group mt="sm" gap="md" wrap="wrap">
          <UnstyledButton
            onClick={(e) => {
              e.preventDefault()
              e.stopPropagation()
              navigate(paths.route(teamSlug, stage.route!.slug))
            }}
            className={classes.routeLink}
          >
            {t('trips.stage.viewRoute')}
          </UnstyledButton>
          <Group gap="md" wrap="nowrap">
            <Group gap={4}>
              <IconArrowsMaximize size={16} color="var(--mantine-color-dimmed)" />
              <Text size="sm" c="dimmed">
                {distance(stage.route.distance)}
              </Text>
            </Group>
            <Group gap={4}>
              <IconArrowUp size={16} color="var(--mantine-color-dimmed)" />
              <Text size="sm" c="dimmed">
                {elevation(stage.route.elevationGain)}
              </Text>
            </Group>
          </Group>
        </Group>
      )}
    </Paper>
  )
}
