import { useCallback, useRef } from 'react'
import { ElevationState } from '@/api/dto'

/** How often the server is asked whether the precise (HD) elevation has landed. */
const POLL_MS = 30_000
/** The server re-computes within ~10 min of the last save; give up a little later than that. */
const GIVE_UP_MS = 15 * 60_000

/**
 * `refetchInterval` for a route or GPX preview query: while the server still reports the HD
 * recomputation as scheduled (`elevationState === 'PENDING'`, ledger `WEB-102`), refetch every 30 s,
 * and stop after 15 minutes or as soon as it turns HD (or FAST: given up, nothing left to wait for). Same shape as the poll in `useDataExport`.
 *
 * The 15 minutes count from the first time this component saw a PENDING payload, which is enough: a
 * page left open that long no longer needs the refresh, and a reload starts a fresh window.
 */
export function useElevationRefetchInterval() {
  // One window per query: a page that stays mounted while its key changes (trip stages) restarts it
  const started = useRef<{ hash: string; at: number } | null>(null)
  return useCallback((query: { queryHash: string; state: { data: unknown } }): number | false => {
    const state = (query.state.data as { elevationState?: string } | undefined)?.elevationState
    if (state !== ElevationState.PENDING) {
      started.current = null
      return false
    }
    if (started.current?.hash !== query.queryHash) {
      started.current = { hash: query.queryHash, at: Date.now() }
    }
    return Date.now() - started.current.at < GIVE_UP_MS ? POLL_MS : false
  }, [])
}
