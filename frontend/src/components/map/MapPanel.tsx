import { useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { IconX } from '@tabler/icons-react'
import { ActionIcon, Box, Drawer, Group, Popover, Text } from '@mantine/core'
import { useMediaMatch } from '@/hooks/useResponsive'
import { MapControlButton, MapControlGroup } from './MapControl'
import { MapToolbarButton } from './MapToolbarButton'
import { markPanelDismissed, useMapPanel } from './mapPanelState'
import { useMapZones, type MapControlSlot, type MapZone } from './mapZones'
import { useFullscreenElement } from './useFullscreenElement'

/** Above the elevation profile overlaid on compact maps (zIndex 1000 in RouteMapView). */
const PANEL_Z_INDEX = 1001

interface MapPanelBaseProps {
  /** Unique within a map: two panels with the same id would open together. */
  id: string
  /** Tooltip and accessible name of the button. */
  label: string
  icon: React.ReactNode
  /** Heading inside the panel. */
  title: string
  /** Panel width in px on a fine pointer. */
  width?: number
  /** Receives a function closing the panel, for content that picks a value and is done. */
  children: React.ReactNode | ((close: () => void) => React.ReactNode)
}

/**
 * Where the button lives:
 * - `'map'` (default): in the map's control column, at `zone` and `slot` (see
 *   {@link MapControlGroup}); the popover opens beside it, towards the map;
 * - `'toolbar'`: a 36 px button of a toolbar laid at the bottom of the map on a fine pointer (the
 *   planner's, docs/LEDGER_*.md WEB-157); the popover opens upwards;
 * - `'bar'`: a 44 px button of a toolbar outside the map, on a finger.
 * On a coarse pointer the panel is always the bottom sheet.
 */
type MapPanelTriggerProps =
  | { trigger?: 'map'; zone: MapZone; slot: MapControlSlot }
  | { trigger: 'toolbar' | 'bar'; zone?: undefined; slot?: undefined }

type MapPanelProps = MapPanelBaseProps & MapPanelTriggerProps

/**
 * A button that opens a panel anchored to it: in a control column, or in a toolbar (see
 * {@link MapPanelTriggerProps}). One panel at a time per map (see {@link useMapPanel}); closes on
 * outside click and Escape. On a fine pointer the panel is a popover — beside a column's button,
 * towards the map (to the left of a right-hand column), above a toolbar's; on a coarse pointer it
 * is a bottom sheet, the same for every button wherever it stands.
 */
export function MapPanel(props: MapPanelProps) {
  const { id, label, icon, title, width = 200, children } = props
  const trigger = props.trigger ?? 'map'
  // The button's place in a control column; none for a toolbar's button.
  const column =
    props.trigger === undefined || props.trigger === 'map'
      ? { zone: props.zone, slot: props.slot }
      : null
  const { t } = useTranslation()
  const { opened, toggle, close, setOpened } = useMapPanel(id)
  const isCoarsePointer = useMediaMatch('(pointer: coarse)')
  const zones = useMapZones()
  // In browser fullscreen, a portal into <body> is never on screen: render into the map instead.
  // Mantine's Portal reads its target only when it mounts, hence the key remounting it on a switch
  // while the panel is open.
  const fullscreenElement = useFullscreenElement()
  const portalKey = fullscreenElement ? 'fullscreen' : 'page'

  const isPopover = !isCoarsePointer && trigger !== 'bar'

  // Mantine closes a Popover on Escape only while focus is inside it; the focus stays on the button
  // that opened it, so listen on the window while the panel is open. In the capture phase:
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

  /** The button's box in a control column; a toolbar's button needs none. */
  const inColumn = (node: React.ReactNode) =>
    column ? (
      <MapControlGroup zone={column.zone} slot={column.slot}>
        {node}
      </MapControlGroup>
    ) : (
      node
    )

  if (!isPopover) {
    return (
      <>
        {trigger === 'bar' ? (
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
        ) : trigger === 'toolbar' ? (
          <MapToolbarButton label={label} icon={icon} onClick={toggle} active={opened} />
        ) : (
          inColumn(<MapControlButton label={label} icon={icon} onClick={toggle} active={opened} />)
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

  // Above a toolbar's button (flipped below, shifted sideways by Floating UI when there is no
  // room); beside a column's, towards the map. ('bar' never gets here: always the bottom sheet.)
  const position = !column
    ? 'top'
    : zones.side[column.zone] === 'left'
      ? 'left-start'
      : 'right-start'

  return inColumn(
    <Popover
      opened={opened}
      onChange={(value) => {
        // Only an outside press (or Escape) reaches here: the button toggles on its own.
        if (!value) markPanelDismissed()
        setOpened(value)
      }}
      zIndex={PANEL_Z_INDEX}
      position={position}
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
        {trigger === 'toolbar' ? (
          <MapToolbarButton label={label} icon={icon} onClick={toggle} active={opened} />
        ) : (
          <MapControlButton label={label} icon={icon} onClick={toggle} active={opened} />
        )}
      </Popover.Target>
      <Popover.Dropdown key={portalKey} p="sm">
        {header}
        <Box style={{ maxHeight: 'min(70dvh, 480px)', overflowY: 'auto' }}>{content}</Box>
      </Popover.Dropdown>
    </Popover>
  )
}
