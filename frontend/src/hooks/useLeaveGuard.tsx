import { useCallback, useEffect, useRef } from 'react'
import { useBlocker, type BlockerFunction } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { ConfirmDialog } from '@/components/common/ConfirmDialog'

/**
 * Asks before leaving a form whose work would be lost (docs/LEDGER_*.md WEB-213): a navigation
 * inside the site (Annuler, a breadcrumb, a link, the browser's back button) opens a confirmation,
 * a reload or a closed tab the browser's own one.
 *
 * `isDirty` is read when the navigation happens, never while rendering: an editor answers it from
 * its form and its planner at that moment. A navigation to the same path and query is not leaving
 * — the planner's fullscreen editor pushes and pops such an entry (`useHistoryOverlay`).
 *
 * `release()` lets the next navigation through without asking: call it right before the
 * navigation that follows a save, or one that keeps the form (a slug change).
 *
 * Needs a data router (`createBrowserRouter`): use it in a page, never in a component a test mounts
 * without one.
 */
export function useLeaveGuard(isDirty: () => boolean) {
  const { t } = useTranslation()
  const dirtyProbe = useRef(isDirty)
  useEffect(() => {
    dirtyProbe.current = isDirty
  }, [isDirty])
  const released = useRef(false)

  const shouldBlock = useCallback<BlockerFunction>(({ currentLocation, nextLocation }) => {
    if (released.current) {
      released.current = false
      return false
    }
    const leaving =
      currentLocation.pathname !== nextLocation.pathname ||
      currentLocation.search !== nextLocation.search
    return leaving && dirtyProbe.current()
  }, [])
  const blocker = useBlocker(shouldBlock)

  useEffect(() => {
    const onBeforeUnload = (event: BeforeUnloadEvent) => {
      if (released.current || !dirtyProbe.current()) return
      event.preventDefault()
      // Older browsers read the return value; its text is never shown.
      event.returnValue = ''
    }
    window.addEventListener('beforeunload', onBeforeUnload)
    return () => window.removeEventListener('beforeunload', onBeforeUnload)
  }, [])

  const release = useCallback(() => {
    released.current = true
  }, [])

  const dialog = (
    <ConfirmDialog
      isOpen={blocker.state === 'blocked'}
      onClose={() => blocker.reset?.()}
      onConfirm={() => blocker.proceed?.()}
      title={t('leaveGuard.title')}
      message={t('leaveGuard.message')}
      confirmText={t('leaveGuard.leave')}
      cancelText={t('leaveGuard.stay')}
      variant="warning"
    />
  )

  return { dialog, release }
}
