import { forwardRef } from 'react'
import { Tooltip, UnstyledButton } from '@mantine/core'
import { useFullscreenElement } from './useFullscreenElement'

interface MapToolbarButtonProps extends Omit<
  React.ComponentPropsWithoutRef<'button'>,
  'children' | 'onClick' | 'disabled' | 'type'
> {
  /** Tooltip and accessible name — mention the keyboard shortcut here when there is one. */
  label: string
  icon: React.ReactNode
  onClick?: () => void
  /**
   * A toggle's state, as `aria-pressed` and a soft accent background (index.css,
   * `.map-toolbar-button`). Left out for a plain action, which then announces no pressed state.
   */
  active?: boolean
  disabled?: boolean
}

/**
 * A 36 px button of a toolbar laid over a map on a fine pointer (the planner's, docs/LEDGER_*.md
 * WEB-157). It looks like the buttons of the map's control columns — same surface, icon colour,
 * hover and toggled-on state, from the `--ml-*` variables, so it follows the `.dark` scheme of the
 * map's wrapper — and its tooltip opens upwards, the toolbar standing at the bottom of the map.
 */
export const MapToolbarButton = forwardRef<HTMLButtonElement, MapToolbarButtonProps>(
  function MapToolbarButton(
    { label, icon, onClick, active, disabled = false, className, ...rest },
    ref
  ) {
    const fullscreenElement = useFullscreenElement()
    return (
      <Tooltip label={label} position="top" withArrow portalProps={{ target: fullscreenElement }}>
        <UnstyledButton
          {...rest}
          ref={ref}
          type="button"
          className={className ? `map-toolbar-button ${className}` : 'map-toolbar-button'}
          onClick={onClick}
          disabled={disabled}
          aria-label={label}
          aria-pressed={active}
        >
          {icon}
        </UnstyledButton>
      </Tooltip>
    )
  }
)
