import { describe, it, expect, vi } from 'vitest'
import { act, render, screen } from '@testing-library/react'
import { renderToString } from 'react-dom/server'
import { QueryClientProvider, useQuery } from '@tanstack/react-query'
import { makeQueryClient } from './queryClient'

function Probe() {
  const { status } = useQuery({
    queryKey: ['ad', 'refused'],
    queryFn: () => Promise.reject(new Error('403')),
  })
  return <span>{status}</span>
}

/**
 * A query the loader failed to read is not dehydrated: the client starts without it, pending. The
 * server render has to agree, or React throws #418 on hydration.
 */
describe('server render of a query the loader failed to read', () => {
  it('renders it pending, as the client will', async () => {
    const queryClient = makeQueryClient({ isServer: true })
    await queryClient.prefetchQuery({
      queryKey: ['ad', 'refused'],
      queryFn: () => Promise.reject(new Error('403')),
    })
    expect(queryClient.getQueryState(['ad', 'refused'])?.status).toBe('error')

    const html = renderToString(
      <QueryClientProvider client={queryClient}>
        <Probe />
      </QueryClientProvider>
    )
    expect(html).toContain('pending')
  })
})

/**
 * entry-server reads the config and the version before the route's prefetch, and renders them only
 * after it: nothing observes them in between. Collected then, the page rendered without the site
 * name or the version, and did not dehydrate them — React #418 once the client had them.
 */
describe('a server query nothing observes yet', () => {
  it('outlives a slow prefetch, up to the render', async () => {
    vi.useFakeTimers()
    try {
      const queryClient = makeQueryClient({ isServer: true })
      await queryClient.fetchQuery({ queryKey: ['config'], queryFn: () => ({ appName: 'P' }) })

      await vi.advanceTimersByTimeAsync(30_000)

      expect(queryClient.getQueryData(['config'])).toEqual({ appName: 'P' })
    } finally {
      vi.useRealTimers()
    }
  })
})

/**
 * The client forgets a failed query nothing displays, so that a later visit reads it again — but not
 * between the page that leaves and the page that enters: they swap in one commit, and the entering
 * page would mount on a fresh query and run the whole retry cycle again (docs/LEDGER_*.md WEB-217,
 * e2e/error-states.e2e.ts).
 */
describe('a failed client query', () => {
  const key = ['team', 'down']
  const failing = vi.fn(() => Promise.reject(new Error('500')))

  function Reader({ label }: { label: string }) {
    const { status } = useQuery({ queryKey: key, queryFn: failing, retry: false })
    return <span>{`${label} ${status}`}</span>
  }

  async function failedClient() {
    failing.mockClear()
    const queryClient = makeQueryClient()
    await queryClient.prefetchQuery({ queryKey: key, queryFn: failing, retry: false })
    expect(failing).toHaveBeenCalledTimes(1)
    return queryClient
  }

  it('survives the swap of the page that observed it for the page that shows it', async () => {
    const queryClient = await failedClient()
    const view = render(
      <QueryClientProvider client={queryClient}>
        <Reader label="leaving" />
      </QueryClientProvider>
    )
    expect(await screen.findByText('leaving error')).toBeInTheDocument()

    view.rerender(
      <QueryClientProvider client={queryClient}>
        <Reader key="entering" label="entering" />
      </QueryClientProvider>
    )
    await act(() => new Promise((resolve) => setTimeout(resolve, 10)))

    expect(screen.getByText('entering error')).toBeInTheDocument()
    expect(failing).toHaveBeenCalledTimes(1)
  })

  it('is forgotten once nothing shows it', async () => {
    const queryClient = await failedClient()
    const view = render(
      <QueryClientProvider client={queryClient}>
        <Reader label="only" />
      </QueryClientProvider>
    )
    expect(await screen.findByText('only error')).toBeInTheDocument()

    view.unmount()
    await new Promise((resolve) => setTimeout(resolve, 10))

    expect(queryClient.getQueryState(key)).toBeUndefined()
  })
})
