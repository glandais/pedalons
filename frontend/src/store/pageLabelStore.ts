import { useEffect } from 'react'
import { create } from 'zustand'

interface PageLabelState {
  label: string | undefined
  setLabel: (label: string | undefined) => void
}

/**
 * A page whose content changes without its route changing (the sign-in card's steps) names the step
 * it shows: the Layout reads this label for the tab's title instead of the route's. Client only —
 * the server always renders the route's first step, whose label is the route's.
 */
export const usePageLabelStore = create<PageLabelState>((set) => ({
  label: undefined,
  setLabel: (label) => set({ label }),
}))

/** Names the tab after `label` while the calling page is mounted; `undefined` keeps the route's. */
export function usePageLabel(label: string | undefined): void {
  const setLabel = usePageLabelStore((state) => state.setLabel)
  useEffect(() => {
    setLabel(label)
    return () => setLabel(undefined)
  }, [label, setLabel])
}
