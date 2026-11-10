import { useTranslation } from 'react-i18next'
import { Group, Loader, Stack, Text, Tooltip } from '@mantine/core'
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
   * `bar` (default): one line that never wraps, the toolbar holding it (`PlannerToolbar`, on a
   * mouse) keeps one height; the figures come first, then the point count, the calculation and
   * the error. `summary`: the summary line of the touch bottom bar (`PlannerBottomBar`), whose
   * height is fixed at 48 px: the figures, the count and a spinner on a first line, the error under
   * them on at most two lines (it is the only place a finger can read it: no tooltip on a touch
   * screen, docs/LEDGER_*.md WEB-157).
   */
  variant?: 'bar' | 'summary'
  /** Given in the summary: the bottom bar's button points its description at it. */
  id?: string
}

/**
 * What the planner has to say about the trace: distance and ascent, point count, a calculation in
 * progress, a routing error. In the bar, one line that never wraps (a long error is truncated, its
 * full text in a tooltip), so the toolbar holding it keeps one height whatever it shows.
 */
export function PlannerStatus({
  pointCount,
  isLoading,
  error,
  stats,
  variant = 'bar',
  id,
}: PlannerStatusProps) {
  const { t } = useTranslation()
  const { distance, elevation } = useUnits()

  const figures = stats && (
    <Group gap="xs" wrap="nowrap" style={{ flexShrink: 0 }}>
      <Text size="sm" fw={500}>
        {distance(stats.distance)}
      </Text>
      <Text size="sm" c="green">
        +{elevation(stats.ascend)}
      </Text>
    </Group>
  )
  const count = pointCount > 0 && (
    <Text size="sm" c="dimmed" style={{ flexShrink: 0 }}>
      {t('planner.pointCount', { count: pointCount })}
    </Text>
  )

  if (variant === 'summary') {
    return (
      <Stack id={id} gap={0} justify="center" style={{ flex: 1, minWidth: 0, overflow: 'hidden' }}>
        <Group gap="sm" wrap="nowrap" style={{ minWidth: 0 }}>
          {figures}
          {count}
          {isLoading && (
            // The spinner alone: the map shows the calculation too, and the line has no room.
            <Loader size="xs" role="status" aria-label={t('planner.calculating')} />
          )}
        </Group>
        {error && (
          <Text size="xs" lh={1.25} c="red" lineClamp={2}>
            {error}
          </Text>
        )}
      </Stack>
    )
  }

  return (
    // overflow hidden: whatever does not fit is clipped inside the group, it never pushes the
    // toolbar's buttons next to it out of the map.
    <Group gap="md" wrap="nowrap" style={{ flex: 1, minWidth: 0, overflow: 'hidden' }}>
      {figures}
      {count}
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
      {error && (
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
      )}
    </Group>
  )
}
