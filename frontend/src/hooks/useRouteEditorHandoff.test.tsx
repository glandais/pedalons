import { afterEach, describe, expect, it } from 'vitest'
import { cleanup, render, screen, waitFor } from '@testing-library/react'
import { createMemoryRouter, RouterProvider } from 'react-router-dom'
import { useRouteEditorHandoff } from './useRouteEditorHandoff'

function Page() {
  const { generated, draw } = useRouteEditorHandoff()
  return (
    <p>
      {generated?.polyline ?? 'rien'} {draw ? 'tracer' : 'fichier'}
    </p>
  )
}

describe('useRouteEditorHandoff (WEB-214)', () => {
  afterEach(cleanup)

  it('keeps what it was handed and takes it out of the history entry', async () => {
    const router = createMemoryRouter([{ path: '/nouveau', element: <Page /> }], {
      initialEntries: [
        {
          pathname: '/nouveau',
          search: '?x=1',
          state: {
            generated: { polyline: 'POLY', type: 'GRAVEL', distanceM: 42000 },
            draw: true,
          },
        },
      ],
    })
    render(<RouterProvider router={router} />)

    expect(screen.getByText('POLY tracer')).toBeTruthy()
    await waitFor(() => expect(router.state.location.state).toBeNull())
    // Same page, same query: only the state went
    expect(router.state.location.pathname).toBe('/nouveau')
    expect(router.state.location.search).toBe('?x=1')
    expect(screen.getByText('POLY tracer')).toBeTruthy()
  })

  it('leaves an entry without state alone', () => {
    const router = createMemoryRouter([{ path: '/nouveau', element: <Page /> }], {
      initialEntries: ['/nouveau'],
    })
    render(<RouterProvider router={router} />)
    expect(screen.getByText('rien fichier')).toBeTruthy()
    expect(router.state.historyAction).toBe('POP')
  })
})
