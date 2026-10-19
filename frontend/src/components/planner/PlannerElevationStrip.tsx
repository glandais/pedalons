import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { IconChevronDown, IconChevronUp } from '@tabler/icons-react'
import { ActionIcon, Box, Group, SegmentedControl, Text, useMantineTheme } from '@mantine/core'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'
import { useUnits } from '@/hooks/useUnits'
import type { PlannerMappable, Route, SurfaceClass, SurfaceStats } from '@/lib/planner'
import { SURFACE_CLASSES, surfaceColors, type PlannerColorBy } from '@/lib/plannerSurface'
import { ElevationChart } from '../route/ElevationChart'

interface PlannerElevationStripProps {
  route: Route
  /** The profile of `route` (lib/planner.ts plannerRouteToMappable); null when its elevations are unknown. */
  mappable: PlannerMappable | null
  /** Index in the profile of the entry hovered (on the map or on the profile); -1 for none. */
  hoveredIndex: number
  onHoverIndex: (index: number) => void
  /** Height of the chart body, in px. */
  height: number
  /** What the profile is coloured by; the control that changes it is shown when `onColorByChange` is. */
  colorBy?: PlannerColorBy
  onColorByChange?: (colorBy: PlannerColorBy) => void
  /** Length of the route by surface class: the legend and the summary of the surface mode. */
  surfaceStats?: SurfaceStats
  /** Finger layout: a 44 px header holding the 44 px fold button above the chart. */
  collapsible?: { collapsed: boolean; onToggle: () => void }
}

/**
 * The elevation profile of the route being drawn, under the map. It follows every edit (the
 * route's own points, elevations filled in along straight lines) and shares its hovered point with
 * the map: the chart reports an index of the profile, whose entries are the route's points and, under a
 * straight line whose relief was read, the samples between them; the map draws a marker at its
 * position.
 */
export function PlannerElevationStrip({
  route,
  mappable,
  hoveredIndex,
  onHoverIndex,
  height,
  collapsible,
  colorBy = 'grade',
  onColorByChange,
  surfaceStats,
}: PlannerElevationStripProps) {
  const { t } = useTranslation()
  const { elevation } = useUnits()
  const theme = useMantineTheme()
  const colorScheme = useResolvedColorScheme()
  const colors = useMemo(() => surfaceColors(theme, colorScheme), [theme, colorScheme])
  const bySurface = colorBy === 'surface'
  const surfaceAt = useMemo(
    () => (i: number) => colors[mappable?.surface[i] ?? 'unknown'],
    [mappable, colors]
  )
  // The segment starting at entry i is dashed when it is (part of) a straight line
  const dashedSegment = useMemo(() => (i: number) => !!mappable?.dashed[i], [mappable])

  const collapsed = !!collapsible?.collapsed
  const colorByControl = onColorByChange && (
    <SegmentedControl
      size="xs"
      value={colorBy}
      onChange={(value) => onColorByChange(value as PlannerColorBy)}
      aria-label={t('planner.colorBy.label')}
      data={[
        { value: 'grade', label: t('planner.colorBy.grade') },
        { value: 'surface', label: t('planner.colorBy.surface') },
      ]}
      data-testid="planner-color-by"
    />
  )
  const surfaceLegend = bySurface && surfaceStats && (
    <SurfaceLegend stats={surfaceStats} colors={colors} />
  )
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
          <Group gap={0} wrap="nowrap">
            {colorByControl}
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
        </Group>
      )}
      {!collapsible && colorByControl && (
        <Group justify="space-between" wrap="wrap" gap="xs" px="xs" pt={4}>
          {colorByControl}
          {surfaceLegend}
        </Group>
      )}
      {collapsible && !collapsed && surfaceLegend && (
        <Group px="xs" pb={2}>
          {surfaceLegend}
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
              colorBy={colorBy}
              surfaceAt={surfaceAt}
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

const CLASS_LABEL_KEYS = {
  paved: 'planner.surface.paved',
  unpaved: 'planner.surface.unpaved',
  unknown: 'planner.surface.unknown',
  offNetwork: 'planner.surface.offNetwork',
} as const satisfies Record<SurfaceClass, string>

const percent = (part: number, total: number) => (total > 0 ? Math.round((part / total) * 100) : 0)

/**
 * The legend of the surface colours and what the route is made of: « unpaved x % (routed), unknown
 * y % » (the router's own figure, a hint and not the saved surface), a third part for the straight
 * lines when there are some. The classes are never told by colour alone: each has its label.
 */
function SurfaceLegend({
  stats,
  colors,
}: {
  stats: SurfaceStats
  colors: Record<SurfaceClass, string>
}) {
  const { t } = useTranslation()
  return (
    <Group gap="xs" wrap="wrap" data-testid="planner-surface-legend" style={{ rowGap: 2 }}>
      {SURFACE_CLASSES.map((c) => (
        <Group key={c} gap={4} wrap="nowrap">
          <Box
            w={14}
            h={0}
            style={{
              borderTop: `4px ${c === 'offNetwork' ? 'dotted' : 'solid'} ${colors[c]}`,
              flexShrink: 0,
            }}
          />
          <Text size="xs">{t(CLASS_LABEL_KEYS[c])}</Text>
        </Group>
      ))}
      <Text size="xs" c="dimmed" data-testid="planner-surface-summary">
        {t('planner.surface.summary', {
          unpaved: percent(stats.unpaved, stats.total),
          unknown: percent(stats.unknown, stats.total),
        })}
        {stats.offNetwork > 0 &&
          t('planner.surface.summary.offNetwork', {
            offNetwork: percent(stats.offNetwork, stats.total),
          })}
      </Text>
    </Group>
  )
}
