import { afterEach, describe, expect, it } from 'vitest'
import { cleanup, render, screen, waitFor } from '@testing-library/react'
import { createBrowserRouter, createMemoryRouter, RouterProvider } from 'react-router-dom'
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

  it('takes it out of the browser entry even when a save interrupts the router', async () => {
    // The router's replace runs the page's loader before writing the entry: slow here, as under
    // load, so the save's navigation interrupts it.
    let slow = false
    const router = createBrowserRouter([
      { path: '/', element: <p>départ</p> },
      {
        path: '/nouveau',
        element: <Page />,
        loader: () =>
          slow ? new Promise((resolve) => setTimeout(() => resolve(null), 5000)) : null,
      },
      { path: '/parcours', element: <p>enregistré</p> },
    ])
    render(<RouterProvider router={router} />)
    await router.navigate('/nouveau', {
      state: { generated: { polyline: 'POLY', type: 'GRAVEL', distanceM: 42000 }, draw: true },
    })
    slow = true
    expect(await screen.findByText('POLY tracer')).toBeTruthy()

    await router.navigate('/parcours')
    expect(await screen.findByText('enregistré')).toBeTruthy()
    slow = false
    await router.navigate(-1)

    expect(await screen.findByText('rien fichier')).toBeTruthy()
    router.dispose()
  })
})
