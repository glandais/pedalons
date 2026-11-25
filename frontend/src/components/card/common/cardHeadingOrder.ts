import { createContext, useContext } from 'react'

export type CardTitleOrder = 2 | 3 | 4
/** A card title sits one level below the nearest heading over its list: under a page's h2 by default
 * (a team tab, the home feed, « Utilisé dans »). Never an h1 (docs/LEDGER_*.md WEB-208). The empty
 * state that stands in for the cards takes the same level (`EmptyState`, docs/LEDGER_*.md WEB-210). */
export const CardTitleOrderContext = createContext<CardTitleOrder>(3)

/** The level of what a list shows: its card titles, or the empty state in their place. */
export function useCardHeadingOrder(): CardTitleOrder {
  return useContext(CardTitleOrderContext)
}
