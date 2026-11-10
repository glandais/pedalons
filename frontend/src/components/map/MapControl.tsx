import { createContext, forwardRef, useContext } from 'react'
import { createPortal } from 'react-dom'
import { useControl } from 'react-map-gl/maplibre'
import type { IControl } from 'maplibre-gl'
import { Tooltip } from '@mantine/core'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useFullscreenElement } from './useFullscreenElement'
import { useMapZones, type MapControlSide, type MapControlSlot, type MapZone } from './mapZones'

/**
 * A MapLibre control whose element React renders into. Lets a button join the native control
 * stack — same box, same position rules as the zoom controls — while staying an ordinary React
 * subtree (Mantine tooltips, Tabler icons, router links).
 */
class PortalControl implements IControl {
  private readonly container = document.createElement('div')

  constructor(private readonly slot: MapControlSlot) {}

  onAdd() {
    // `pdl-ctrl-<slot>`: index.css gives the box its `order` in the corner from it.
    this.container.className = `maplibregl-ctrl maplibregl-ctrl-group pdl-ctrl-${this.slot}`
    return this.container
  }

  onRemove() {
    this.container.remove()
  }

  getElement() {
    return this.container
  }
}

/** The side the tooltips of a group open towards, given by its {@link MapControlGroup}. */
const MapControlSideContext = createContext<MapControlSide>('right')

interface MapControlGroupProps {
  children: React.ReactNode
  /**
   * The family the control belongs to, which decides its corner (`mapZones.ts`). There is
   * deliberately no corner prop: a control that moves between pages is one the visitor has to
   * look for. docs/LEDGER_*.md WEB-157.
   */
  zone: MapZone
  /** Its place within the corner, fixed by index.css whatever the mounting order. */
  slot: MapControlSlot
}

/** One rounded box in a control column, holding one or more {@link MapControlButton}. */
export function MapControlGroup({ children, zone, slot }: MapControlGroupProps) {
  const zones = useMapZones()
  const control = useControl(() => new PortalControl(slot), { position: zones[zone] })
  return (
    <MapControlSideContext.Provider value={zones.side[zone]}>
      {createPortal(children, control.getElement())}
    </MapControlSideContext.Provider>
  )
}

interface MapControlButtonProps extends Omit<
  React.ComponentPropsWithoutRef<'button'>,
  'children' | 'onClick' | 'disabled' | 'type'
> {
  /** Tooltip and accessible name — mention the keyboard shortcut here when there is one. */
  label: string
  icon: React.ReactNode
  onClick?: () => void
  /** Renders a link instead of a button (fullscreen, back…), styled identically. */
  to?: string
  /** Toggled on: a soft accent background and an accent icon (index.css, `.active`). */
  active?: boolean
  disabled?: boolean
}

/**
 * A single control button. Sizing, borders and hover states come from maplibre-theme's
 * `.maplibregl-ctrl-group button` rules (resized, and mirrored for links, in index.css), so these
 * look exactly like the zoom buttons on every map. The tooltip opens away from the column's edge,
 * towards the map.
 */
export const MapControlButton = forwardRef<
  HTMLButtonElement & HTMLAnchorElement,
  MapControlButtonProps
>(function MapControlButton(
  { label, icon, onClick, to, active = false, disabled = false, ...rest },
  ref
) {
  const fullscreenElement = useFullscreenElement()
  const side = useContext(MapControlSideContext)
  return (
    <Tooltip label={label} position={side} withArrow portalProps={{ target: fullscreenElement }}>
      {to ? (
        <PrefetchLink
          ref={ref as React.Ref<HTMLAnchorElement>}
          to={to}
          aria-label={label}
          className={active ? 'active' : undefined}
        >
          {icon}
        </PrefetchLink>
      ) : (
        <button
          {...rest}
          ref={ref}
          type="button"
          className={active ? 'active' : undefined}
          onClick={onClick}
          disabled={disabled}
          aria-label={label}
          aria-pressed={active}
        >
          {icon}
        </button>
      )}
    </Tooltip>
  )
})
