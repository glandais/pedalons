import { useCallback, useEffect, useState } from 'react'
import { isEditableTarget } from '@/lib/editableTarget'

/**
 * Toggles a "hidden" boolean each time the user presses the "h" key, letting map
 * views hide the GPX trace and its markers to reveal the underlying basemap.
 *
 * Ignores the key when a modifier is held or when focus is in an editable field
 * (input/textarea/select/contenteditable), so it never clashes with typing or
 * browser/OS shortcuts.
 *
 * `enabled` (default true) switches the shortcut off for a planner that stays mounted while it
 * is not on screen, so a key press never edits what nobody sees.
 *
 * Returns the state and the same toggle, so a map control (`HideTrackControl`)
 * and the shortcut drive one shared state instead of two competing ones.
 */
export function useHideTrackKey(enabled = true): [hidden: boolean, toggle: () => void] {
  const [hidden, setHidden] = useState(false)

  const toggle = useCallback(() => setHidden((prev) => !prev), [])

  useEffect(() => {
    if (!enabled) return
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key !== 'h' && e.key !== 'H') return
      if (e.ctrlKey || e.metaKey || e.altKey) return
      if (isEditableTarget(e.target)) return
      toggle()
    }
    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [toggle, enabled])

  return [hidden, toggle]
}
