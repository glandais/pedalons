import { useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { IconX } from '@tabler/icons-react'
import { ActionIcon, Box, Drawer, Group, Popover, Text } from '@mantine/core'
import { useMediaMatch } from '@/hooks/useResponsive'
import { MapControlButton, MapControlGroup } from './MapControl'
import { markPanelDismissed, useMapPanel } from './mapPanelState'
import { useFullscreenElement } from './useFullscreenElement'

/** Above the elevation profile overlaid on compact maps (zIndex 1000 in RouteMapView). */
const PANEL_Z_INDEX = 1001

interface MapPanelProps {
  /** Unique within a map: two panels with the same id would open together. */
  id: string
  /** Tooltip and accessible name of the button. */
  label: string
  icon: React.ReactNode
  /** Heading inside the panel. */
  title: string
  /** Panel width in px on a fine pointer. */
  width?: number
  /**
   * Where the button lives: `'map'` (default) in the map's control column; `'bar'` as a 44 px
   * button in a toolbar outside the map. The panel is then always the bottom sheet.
   */
  trigger?: 'map' | 'bar'
  /** Receives a function closing the panel, for content that picks a value and is done. */
  children: React.ReactNode | ((close: () => void) => React.ReactNode)
}

/**
 * A button of the control column that opens a panel anchored to it. One panel at a time per map
 * (see {@link useMapPanel}); closes on outside click and Escape. On a coarse pointer the panel is a
 * bottom sheet, within thumb reach, as the button sits at the top of the map.
 */
export function MapPanel({
  id,
  label,
  icon,
  title,
  width = 200,
  trigger = 'map',
  children,
}: MapPanelProps) {
  const { t } = useTranslation()
  const { opened, toggle, close, setOpened } = useMapPanel(id)
  const isCoarsePointer = useMediaMatch('(pointer: coarse)')
  // In browser fullscreen, a portal into <body> is never on screen: render into the map instead.
  // Mantine's Portal reads its target only when it mounts, hence the key remounting it on a switch
  // while the panel is open.
  const fullscreenElement = useFullscreenElement()
  const portalKey = fullscreenElement ? 'fullscreen' : 'page'

  const fromBar = trigger === 'bar'
  const isPopover = !isCoarsePointer && !fromBar

  // Mantine closes a Popover on Escape only while focus is inside it; the focus stays on the button
  // of the control column, so listen on the window while the panel is open. In the capture phase:
  // the button's tooltip (Floating UI's useDismiss) stops Escape's propagation while it shows, which
  // it does as long as the pointer rests on the button — a bubbling listener would need a second
  // Escape.
  useEffect(() => {
    if (!opened || !isPopover) return
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') close()
    }
    window.addEventListener('keydown', onKeyDown, true)
    return () => window.removeEventListener('keydown', onKeyDown, true)
  }, [opened, isPopover, close])

  const content = typeof children === 'function' ? children(close) : children

  const header = (
    <Group
      justify="space-between"
      align="center"
      wrap="nowrap"
      mb="sm"
      pb="sm"
      style={{ borderBottom: '1px solid var(--mantine-color-default-border)' }}
    >
      <Text size="sm" fw={500} c="dimmed">
        {title}
      </Text>
      <ActionIcon
        variant="subtle"
        color="gray"
        size="sm"
        onClick={close}
        aria-label={t('actions.cancelAction')}
      >
        <IconX size={16} />
      </ActionIcon>
    </Group>
  )

  if (!isPopover) {
    return (
      <>
        {fromBar ? (
          <ActionIcon
            variant={opened ? 'light' : 'subtle'}
            color="gray"
            size="xl"
            onClick={toggle}
            aria-label={label}
            aria-pressed={opened}
          >
            {icon}
          </ActionIcon>
        ) : (
          <MapControlGroup>
            <MapControlButton label={label} icon={icon} onClick={toggle} active={opened} />
          </MapControlGroup>
        )}
        <Drawer
          key={portalKey}
          opened={opened}
          onClose={close}
          position="bottom"
          size="auto"
          zIndex={PANEL_Z_INDEX}
          portalProps={{ target: fullscreenElement }}
          title={title}
          closeButtonProps={{ 'aria-label': t('actions.cancelAction') }}
        >
          {content}
        </Drawer>
      </>
    )
  }

  return (
    <MapControlGroup>
      <Popover
        opened={opened}
        onChange={(value) => {
          // Only an outside press (or Escape) reaches here: the button toggles on its own.
          if (!value) markPanelDismissed()
          setOpened(value)
        }}
        zIndex={PANEL_Z_INDEX}
        position="right-start"
        offset={8}
        shadow="lg"
        radius="md"
        width={width}
        withinPortal
        portalProps={{ target: fullscreenElement }}
        closeOnClickOutside
        closeOnEscape
        trapFocus={false}
        middlewares={{ flip: true, shift: true }}
      >
        <Popover.Target>
          <MapControlButton label={label} icon={icon} onClick={toggle} active={opened} />
        </Popover.Target>
        <Popover.Dropdown key={portalKey} p="sm">
          {header}
          <Box style={{ maxHeight: 'min(70dvh, 480px)', overflowY: 'auto' }}>{content}</Box>
        </Popover.Dropdown>
      </Popover>
    </MapControlGroup>
  )
}
