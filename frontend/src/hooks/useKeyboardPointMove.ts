import { useCallback, useEffect, useMemo, useRef } from 'react'

const STEP_PX = 10
const SHIFT_STEP_PX = 50
const DEFAULT_COMMIT_DELAY_MS = 500

const ARROWS: Record<string, [number, number]> = {
  ArrowLeft: [-1, 0],
  ArrowRight: [1, 0],
  ArrowUp: [0, -1],
  ArrowDown: [0, 1],
}

/** The slice of a keyboard event the hook reads (DOM or React). */
interface KeyLike {
  key: string
  shiftKey: boolean
  ctrlKey: boolean
  altKey: boolean
  metaKey: boolean
  preventDefault: () => void
  stopPropagation: () => void
}

interface Options {
  /** Wait after the last arrow is released before the burst is committed. */
  commitDelayMs?: number
  /** One step in screen axes (px): `dy` negative is up. */
  onStep: (dx: number, dy: number) => void
  /** The burst is over: the point stays where the steps put it. */
  onCommit: () => void
  /** Escape: back to where the burst started. */
  onCancel: () => void
}

export interface KeyboardPointMove {
  onKeyDown: (e: KeyLike) => void
  onKeyUp: (e: Pick<KeyLike, 'key'>) => void
  onBlur: () => void
  /** Drops a burst from outside (route changed, pointer gesture, unmount); calls nothing back. */
  cancel: () => void
  /** A burst is in progress (not yet committed or cancelled). */
  pending: () => boolean
}

/**
 * The timing of moving a point with the arrow keys. The map is routed once per burst, never per
 * key: a burst ends 500 ms after the last arrow is released (none held), at once on Enter or when
 * the focus leaves, and Escape abandons it. Everything the burst touches is injected.
 */
export function useKeyboardPointMove(options: Options): KeyboardPointMove {
  const optionsRef = useRef(options)
  useEffect(() => {
    optionsRef.current = options
  })

  const held = useRef(new Set<string>())
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null)
  const burst = useRef(false)

  const clearTimer = useCallback(() => {
    if (timer.current !== null) clearTimeout(timer.current)
    timer.current = null
  }, [])

  const commit = useCallback(() => {
    clearTimer()
    if (!burst.current) return
    burst.current = false
    optionsRef.current.onCommit()
  }, [clearTimer])

  const cancel = useCallback(() => {
    clearTimer()
    held.current.clear()
    burst.current = false
  }, [clearTimer])

  const onKeyDown = useCallback(
    (e: KeyLike) => {
      const arrow = ARROWS[e.key]
      if (arrow) {
        // Alt+Left is the browser's « Back »: a modified arrow is not ours (Shift apart)
        if (e.ctrlKey || e.altKey || e.metaKey) return
        e.preventDefault()
        e.stopPropagation()
        clearTimer()
        held.current.add(e.key)
        burst.current = true
        const step = e.shiftKey ? SHIFT_STEP_PX : STEP_PX
        optionsRef.current.onStep(arrow[0] * step, arrow[1] * step)
        return
      }
      if (!burst.current) return
      if (e.key === 'Enter') {
        e.preventDefault()
        e.stopPropagation()
        held.current.clear()
        commit()
      } else if (e.key === 'Escape') {
        e.preventDefault()
        e.stopPropagation()
        cancel()
        optionsRef.current.onCancel()
      }
    },
    [clearTimer, commit, cancel]
  )

  const onKeyUp = useCallback(
    (e: Pick<KeyLike, 'key'>) => {
      if (!ARROWS[e.key]) return
      held.current.delete(e.key)
      if (!burst.current || held.current.size > 0) return
      clearTimer()
      timer.current = setTimeout(
        commit,
        optionsRef.current.commitDelayMs ?? DEFAULT_COMMIT_DELAY_MS
      )
    },
    [clearTimer, commit]
  )

  const onBlur = useCallback(() => {
    // No keyup comes to an element that lost the focus
    held.current.clear()
    commit()
  }, [commit])

  useEffect(() => cancel, [cancel])

  const pending = useCallback(() => burst.current, [])

  return useMemo(
    () => ({ onKeyDown, onKeyUp, onBlur, cancel, pending }),
    [onKeyDown, onKeyUp, onBlur, cancel, pending]
  )
}
