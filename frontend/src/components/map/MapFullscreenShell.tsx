import type { ReactNode } from 'react'
import { IconArrowDown, IconArrowUp, IconRoute } from '@tabler/icons-react'
import { Box, Group, Text } from '@mantine/core'
import { useUnits } from '@/hooks/useUnits'

interface MapFullscreenShellProps {
  /** Left of the toolbar: the back link or button. */
  leading: ReactNode
  /** A string is truncated in the toolbar; a node (a dialog title) is rendered as given. */
  title: ReactNode
  /** Distance and elevation readout, in metres. Gain and loss are hidden below `sm`. */
  stats?: { distance: number; gain?: number; loss?: number }
  /** Right of the toolbar, after the stats. */
  actions?: ReactNode
  /** The map: fills the space left between the toolbar and `bottom`. */
  children: ReactNode
  /** Pinned under the map (elevation strip, bottom bar). No room is reserved while it is empty. */
  bottom?: ReactNode
}

/**
 * The fullscreen map frame shared by the route viewer and the route editor: a 48 px toolbar (back,
 * title, stats), the map filling the viewport, and an optional strip pinned below it.
 */
export function MapFullscreenShell({
  leading,
  title,
  stats,
  actions,
  children,
  bottom,
}: MapFullscreenShellProps) {
  const { distance, elevation } = useUnits()

  return (
    <Box h="100dvh" style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      {/* Toolbar */}
      <Group
        h={48}
        px="sm"
        gap="sm"
        wrap="nowrap"
        style={{
          flexShrink: 0,
          borderBottom: '1px solid var(--mantine-color-default-border)',
        }}
      >
        {leading}

        {typeof title === 'string' ? (
          <Text fw={600} truncate style={{ flex: 1, minWidth: 0 }}>
            {title}
          </Text>
        ) : (
          <Box style={{ flex: 1, minWidth: 0 }}>{title}</Box>
        )}

        {stats && (
          <Group gap="xs" wrap="nowrap" c="dimmed">
            <Group gap={4} wrap="nowrap">
              <IconRoute size={16} />
              <Text size="sm">{distance(stats.distance)}</Text>
            </Group>
            {stats.gain !== undefined && (
              <Group gap={4} wrap="nowrap" visibleFrom="sm">
                <IconArrowUp size={16} />
                <Text size="sm">{elevation(stats.gain)}</Text>
              </Group>
            )}
            {stats.loss !== undefined && (
              <Group gap={4} wrap="nowrap" visibleFrom="sm">
                <IconArrowDown size={16} />
                <Text size="sm">{elevation(stats.loss)}</Text>
              </Group>
            )}
          </Group>
        )}

        {actions}
      </Group>

      {/* Map fills the remaining space above the bottom strip */}
      <Box style={{ flex: 1, minHeight: 0 }}>{children}</Box>

      {bottom}
    </Box>
  )
}
