import { forwardRef } from 'react'
import { createPortal } from 'react-dom'
import { useControl } from 'react-map-gl/maplibre'
import type { ControlPosition } from 'react-map-gl/maplibre'
import type { IControl } from 'maplibre-gl'
import { Tooltip } from '@mantine/core'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useFullscreenElement } from './useFullscreenElement'

/**
 * A MapLibre control whose element React renders into. Lets a button join the native control
 * stack — same box, same position rules as the zoom controls — while staying an ordinary React
 * subtree (Mantine tooltips, Tabler icons, router links).
 */
class PortalControl implements IControl {
  private readonly container = document.createElement('div')

  onAdd() {
    this.container.className = 'maplibregl-ctrl maplibregl-ctrl-group'
    return this.container
  }

  onRemove() {
    this.container.remove()
  }

  getElement() {
    return this.container
  }
}

interface MapControlGroupProps {
  children: React.ReactNode
  /**
   * Corner of the map. Every control in this app sits top-left, under the zoom buttons — don't
   * scatter them per page.
   */
  position?: ControlPosition
}

/** One rounded box in the control column, holding one or more {@link MapControlButton}. */
export function MapControlGroup({ children, position = 'top-left' }: MapControlGroupProps) {
  const control = useControl(() => new PortalControl(), { position })
  return createPortal(children, control.getElement())
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
  /** Toggled on: rendered in the accent colour, like MapLibre's own stateful controls. */
  active?: boolean
  disabled?: boolean
}

/**
 * A single control button. Sizing, borders and hover states come from maplibre-theme's
 * `.maplibregl-ctrl-group button` rules (and their anchor mirror in index.css), so these look
 * exactly like the zoom buttons above them on every map.
 */
export const MapControlButton = forwardRef<
  HTMLButtonElement & HTMLAnchorElement,
  MapControlButtonProps
>(function MapControlButton(
  { label, icon, onClick, to, active = false, disabled = false, ...rest },
  ref
) {
  const fullscreenElement = useFullscreenElement()
  return (
    <Tooltip label={label} position="right" withArrow portalProps={{ target: fullscreenElement }}>
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
