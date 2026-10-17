import { useTranslation } from 'react-i18next'
import { Box, Group, Loader, Text, Tooltip } from '@mantine/core'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'
import { getOverlayBg } from '@/lib/colors'
import { useUnits } from '@/hooks/useUnits'

interface PlannerStatusProps {
  /** Number of control points the user placed. */
  pointCount: number
  isLoading: boolean
  /** Already translated message of the last routing failure. */
  error: string | null
  /** Distance and ascent (metres) of the computed route; shown once it has two points. */
  stats?: { distance: number; ascend: number }
  /**
   * `bar` (default): one line that never wraps, the bar holding it keeps one height. `chip`: the
   * floating pill, which takes no layout space, so a long error wraps on its own line (3 lines at
   * most) and is read in full: the pill is not interactive, a tooltip would never open.
   */
  variant?: 'bar' | 'chip'
}

/**
 * What the planner has to say about the trace: point count, a calculation in progress, a routing
 * error, then distance and ascent. One line that never wraps (a long error is truncated, its full
 * text in a tooltip), so the bar holding it keeps one height whatever it shows.
 */
export function PlannerStatus({
  pointCount,
  isLoading,
  error,
  stats,
  variant = 'bar',
}: PlannerStatusProps) {
  const { t } = useTranslation()
  const { distance, elevation } = useUnits()
  const wraps = variant === 'chip'

  return (
    // overflow hidden: whatever does not fit is clipped inside the group, it never pushes the
    // button next to it (the clear button) out of the bar.
    <Group
      gap="md"
      wrap={wraps ? 'wrap' : 'nowrap'}
      style={{ flex: 1, minWidth: 0, overflow: 'hidden', rowGap: wraps ? 4 : undefined }}
    >
      {pointCount > 0 && (
        <Text size="sm" c="dimmed" style={{ flexShrink: 0 }}>
          {t('planner.pointCount', { count: pointCount })}
        </Text>
      )}
      {isLoading && (
        <Group
          gap="xs"
          wrap="nowrap"
          c="primary"
          style={{ flexShrink: 0 }}
          role="status"
          aria-label={t('planner.calculating')}
        >
          <Loader size="xs" />
          {/* The spinner alone below xs (a 360 px bar): the text would push the rest out. */}
          <Text size="sm" visibleFrom="xs">
            {t('planner.calculating')}
          </Text>
        </Group>
      )}
      {error &&
        (wraps ? (
          <Text size="sm" c="red" lineClamp={3} style={{ flex: '1 1 100%', minWidth: 0 }}>
            {error}
          </Text>
        ) : (
          <Tooltip
            label={error}
            multiline
            maw={320}
            events={{ hover: true, focus: true, touch: true }}
          >
            <Text size="sm" c="red" truncate title={error} style={{ minWidth: 0 }}>
              {error}
            </Text>
          </Tooltip>
        ))}
      {stats && (
        <Group gap="xs" wrap="nowrap" style={{ flexShrink: 0 }}>
          <Text size="sm" fw={500}>
            {distance(stats.distance)}
          </Text>
          <Text size="sm" c="green">
            +{elevation(stats.ascend)}
          </Text>
        </Group>
      )}
    </Group>
  )
}

/**
 * {@link PlannerStatus} as a floating pill over the map, for the fullscreen editor where the inline
 * bar is not shown. It never takes layout space, so the map is not resized when it appears.
 */
export function PlannerStatusChip(props: PlannerStatusProps) {
  const colorScheme = useResolvedColorScheme()
  return (
    <Box
      px="md"
      py={6}
      bg={getOverlayBg(colorScheme)}
      maw="100%"
      style={{
        borderRadius: 'var(--mantine-radius-xl)',
        boxShadow: 'var(--mantine-shadow-lg)',
        pointerEvents: 'none',
        display: 'flex',
      }}
    >
      <PlannerStatus {...props} variant="chip" />
    </Box>
  )
}
