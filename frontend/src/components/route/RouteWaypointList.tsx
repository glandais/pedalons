import { useId, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Box, Button, Group, Stack, Text, ThemeIcon, Title, UnstyledButton } from '@mantine/core'
import type { WaypointDto } from '@/api/dto'
import { useUnits } from '@/hooks/useUnits'
import { WAYPOINT_TYPE_COLORS } from '@/lib/badgeColors.generated'
import { sortWaypoints, waypointTypeOf } from '@/lib/waypoints'
import { WAYPOINT_ICONS } from '../map/waypointIcons'

/** Rows shown before the « Voir les N autres points » fold. */
const FOLD_AFTER = 10

interface RouteWaypointListProps {
  waypoints: readonly WaypointDto[]
  selected: WaypointDto | null
  onSelect: (waypoint: WaypointDto) => void
}

/**
 * The route's author waypoints along the route, off-track ones last. Each row gives what the map
 * popup gives, so the list is the keyboard and screen-reader way to them; a press selects the
 * point on the map.
 */
export function RouteWaypointList({ waypoints, selected, onSelect }: RouteWaypointListProps) {
  const { t } = useTranslation()
  const { distance } = useUnits()
  const titleId = useId()
  const [expanded, setExpanded] = useState(false)

  if (waypoints.length === 0) return null

  const sorted = sortWaypoints(waypoints)
  const folded = sorted.length > FOLD_AFTER && !expanded
  const shown = folded ? sorted.slice(0, FOLD_AFTER) : sorted

  return (
    <Box component="section" aria-labelledby={titleId}>
      <Title order={4} mb="sm" id={titleId}>
        {t('routes.waypoints.title')} ({waypoints.length})
      </Title>
      <Stack component="ul" gap={0} m={0} p={0} style={{ listStyle: 'none' }}>
        {shown.map((waypoint, index) => {
          const type = waypointTypeOf(waypoint.type)
          const { Icon } = WAYPOINT_ICONS[type]
          const typeLabel = t(`routes.waypoints.type.${type}`)
          const isSelected = waypoint === selected
          return (
            <li
              key={waypoint.id ?? `${index}-${waypoint.name}`}
              style={{ borderBottom: '1px solid var(--mantine-color-default-border)' }}
            >
              <UnstyledButton
                w="100%"
                py="xs"
                px="xs"
                aria-pressed={isSelected}
                onClick={() => onSelect(waypoint)}
                style={{
                  borderRadius: 'var(--mantine-radius-sm)',
                  backgroundColor: isSelected ? 'var(--mantine-color-default-hover)' : undefined,
                }}
              >
                <Group gap="sm" wrap="nowrap" align="flex-start">
                  <Text
                    size="sm"
                    c="dimmed"
                    w={78}
                    style={{ flexShrink: 0, fontVariantNumeric: 'tabular-nums' }}
                  >
                    {waypoint.distance != null
                      ? distance(waypoint.distance)
                      : t('routes.waypoints.offTrack')}
                  </Text>
                  <ThemeIcon
                    variant="filled"
                    color={WAYPOINT_TYPE_COLORS[type]}
                    radius="xl"
                    size={28}
                    aria-hidden
                    style={{ flexShrink: 0 }}
                  >
                    <Icon size={16} />
                  </ThemeIcon>
                  <Box style={{ minWidth: 0 }}>
                    <Group gap="xs" align="baseline">
                      <Text size="sm" fw={500}>
                        {waypoint.name || typeLabel}
                      </Text>
                      {waypoint.name && (
                        <Text size="xs" c="dimmed">
                          {typeLabel}
                        </Text>
                      )}
                    </Group>
                    {waypoint.description && (
                      <Text
                        size="sm"
                        c="dimmed"
                        lineClamp={2}
                        style={{ whiteSpace: 'pre-line', overflowWrap: 'anywhere' }}
                      >
                        {waypoint.description}
                      </Text>
                    )}
                  </Box>
                </Group>
              </UnstyledButton>
            </li>
          )
        })}
      </Stack>
      {sorted.length > FOLD_AFTER && (
        <Button variant="subtle" size="xs" mt="xs" onClick={() => setExpanded((v) => !v)}>
          {folded
            ? t('routes.waypoints.showMore', { count: sorted.length - FOLD_AFTER })
            : t('routes.waypoints.showLess')}
        </Button>
      )}
    </Box>
  )
}
