import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { IconChevronDown, IconChevronUp } from '@tabler/icons-react'
import { ActionIcon, Box, Group, Text } from '@mantine/core'
import { useUnits } from '@/hooks/useUnits'
import { plannerRouteToMappable, type Route } from '@/lib/planner'
import { ElevationChart } from '../route/ElevationChart'

interface PlannerElevationStripProps {
  route: Route
  /** Index in `route.points` of the point hovered (on the map or on the profile); -1 for none. */
  hoveredIndex: number
  onHoverIndex: (index: number) => void
  /** Height of the chart body, in px. */
  height: number
  /** Finger layout: a 44 px header holding the 44 px fold button above the chart. */
  collapsible?: { collapsed: boolean; onToggle: () => void }
}

/**
 * The elevation profile of the route being drawn, under the map. It follows every edit (the
 * route's own points, elevations filled in along straight lines) and shares its hovered point with
 * the map: the chart reports an index of `route.points`, the map draws a marker there.
 */
export function PlannerElevationStrip({
  route,
  hoveredIndex,
  onHoverIndex,
  height,
  collapsible,
}: PlannerElevationStripProps) {
  const { t } = useTranslation()
  const { elevation } = useUnits()
  const mappable = useMemo(() => plannerRouteToMappable(route), [route])
  // The edge arriving at point i+1 is straight when that point says so
  const dashedSegment = useMemo(() => (i: number) => !!route.points[i + 1]?.direct, [route.points])

  const collapsed = !!collapsible?.collapsed
  return (
    <Box
      data-testid="planner-elevation-strip"
      bg="var(--mantine-color-body)"
      style={{
        flexShrink: 0,
        borderTop: '1px solid var(--mantine-color-default-border)',
      }}
      onMouseLeave={() => onHoverIndex(-1)}
      // Chart.js listens to touchstart/touchmove only: lifting the finger must clear the hover
      onTouchEnd={() => onHoverIndex(-1)}
      onTouchCancel={() => onHoverIndex(-1)}
    >
      {collapsible && (
        <Group justify="space-between" wrap="nowrap" h={44} pl="sm" pr={0}>
          <Group gap="xs" wrap="nowrap">
            <Text size="sm" fw={500}>
              {t('planner.elevation.title')}
            </Text>
            {mappable && (
              <Text size="sm" c="green">
                +{elevation(route.ascend)}
              </Text>
            )}
          </Group>
          <ActionIcon
            variant="subtle"
            color="gray"
            size={44}
            onClick={collapsible.onToggle}
            aria-expanded={!collapsed}
            aria-label={t(collapsed ? 'planner.elevation.expand' : 'planner.elevation.collapse')}
          >
            {collapsed ? <IconChevronUp size={20} /> : <IconChevronDown size={20} />}
          </ActionIcon>
        </Group>
      )}
      {!collapsed && (
        <Box h={height} px="xs" pb={4}>
          {mappable ? (
            <ElevationChart
              route={mappable}
              hoveredPointIndex={hoveredIndex}
              onHoverPoint={onHoverIndex}
              dashedSegment={dashedSegment}
            />
          ) : (
            <Text size="sm" c="dimmed" ta="center" pt="md">
              {t('planner.elevation.unknown')}
            </Text>
          )}
        </Box>
      )}
    </Box>
  )
}
