import { QueryClient, type Query } from '@tanstack/react-query'
import Axios from 'axios'
import { ApiClientError } from './apiError'

export function makeQueryClient(opts?: { isServer?: boolean }): QueryClient {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        // On server: data never goes stale during a single SSR render.
        // On client: 3 minutes before data is considered stale.
        staleTime: opts?.isServer ? Infinity : 3 * 60 * 1000,
        // Server: never collected — the client lives for one request, and entry-server clears it
        // once the page is rendered. Any finite window is a race: the config and version are read
        // first and have no observer until the render, so a request whose prefetch outlasted the
        // window (2 s, under load) rendered without them — no site name, no version — and did not
        // dehydrate them either. The client, which reads the config before hydrating, then
        // rendered the name: React #418 on every page (docs/LEDGER_*.md WEB-6).
        // Client: 10 minutes to cover tab-away / back navigation. gcTime must exceed
        // staleTime so stale-but-cached data serves instantly while a refetch completes.
        gcTime: opts?.isServer ? Infinity : 10 * 60 * 1000,
        retry: (failureCount, error) => {
          if (opts?.isServer) return false
          // Defensive retry for 401 — the axios interceptor handles token refresh,
          // but allow one retry in case the interceptor rejection races with the new token.
          // `axiosMutator` rethrows any error carrying an API code as an `ApiClientError`, which is
          // not an AxiosError — both shapes have to be read.
          const status =
            error instanceof ApiClientError
              ? error.status
              : Axios.isAxiosError(error)
                ? error.response?.status
                : undefined
          if (status === 401) return failureCount < 2
          // Any other 4xx is the server's final answer — a missing entity, a forbidden page, a bad
          // parameter. Retrying one only held the page on its skeleton for ~8 s, a toast per
          // attempt, before `QueryStateBoundary` could render its "not found". 408 and 429 are
          // the exceptions: they do mean "try again".
          if (status && status >= 400 && status < 500 && status !== 408 && status !== 429) {
            return false
          }
          return failureCount < 3
        },
        retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 5000),
        refetchOnWindowFocus: false,
        // Client: a route's loader has just run the same query and failed (after its own retries):
        // mounting the page must not start it all over — twice the requests, twice the wait, before
        // the error shows. See the cache subscription below for why a later visit still reads again.
        // Server: left on. dehydrate() does not hand failed queries over, so the client starts
        // without them and renders the page's loading branch; the server must render that same
        // branch — a failed query it will "retry on mount" is pending — or hydration breaks (#418).
        retryOnMount: !!opts?.isServer,
      },
      mutations: {
        retry: false,
      },
    },
  })

  // With retryOnMount off, a failed query would stay failed for the whole gcTime: a page visited
  // again ten minutes later would show a stale error without asking. Forgotten as soon as nothing
  // displays it, the next visit reads afresh.
  // Only once the commit is over: the page left and the page entered swap in one commit, and the
  // error the new page shows may be one the old page also observed (the home's create button reads
  // the team the loader just failed, docs/LEDGER_*.md WEB-217). Removed in between, the new page
  // mounted on a fresh query and ran the whole retry cycle again (e2e/error-states.e2e.ts).
  if (!opts?.isServer) {
    const cache = queryClient.getQueryCache()
    const forgetIfUnobserved = (query: Query) => {
      if (
        query.state.status === 'error' &&
        query.getObserversCount() === 0 &&
        cache.get(query.queryHash) === query
      ) {
        cache.remove(query)
      }
    }
    cache.subscribe((event) => {
      const { query } = event
      if (event.type === 'observerRemoved' && query.getObserversCount() === 0) {
        setTimeout(() => forgetIfUnobserved(query), 0)
      }
    })
  }

  return queryClient
}
