import { useSyncExternalStore } from 'react'
import { isAnalyticsOptedOut, subscribeAnalyticsOptOut } from './optOut'
import { browserSignalsOptOut } from './sender'

const noSubscription = () => () => {}
// The server cannot see this browser's storage or signals: it renders the neutral state, and the
// client's first (hydration) render does too — React then re-renders with the browser's own value.
const serverSnapshot = () => false

/** This browser's opposition to the measurement on this site, kept in sync across tabs. */
export function useAnalyticsOptedOut(): boolean {
  return useSyncExternalStore(subscribeAnalyticsOptOut, isAnalyticsOptedOut, serverSnapshot)
}

/** True when the browser sends Do Not Track or Global Privacy Control. */
export function useBrowserSignalsOptOut(): boolean {
  return useSyncExternalStore(noSubscription, browserSignalsOptOut, serverSnapshot)
}
