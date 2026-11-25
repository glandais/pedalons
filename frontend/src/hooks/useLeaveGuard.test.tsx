import { afterEach, describe, expect, it, vi } from 'vitest'
import { act, cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import { createMemoryRouter, RouterProvider, useNavigate } from 'react-router-dom'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

import { useLeaveGuard } from './useLeaveGuard'

const state = { dirty: true }

function Form() {
  const navigate = useNavigate()
  const guard = useLeaveGuard(() => state.dirty)
  return (
    <>
      <p>formulaire</p>
      <button onClick={() => navigate('/ailleurs')}>partir</button>
      <button onClick={() => navigate('/form', { state: { overlay: 1 } })}>même page</button>
      <button
        onClick={() => {
          guard.release()
          navigate('/ailleurs')
        }}
      >
        enregistrer
      </button>
      {guard.dialog}
    </>
  )
}

function show() {
  const router = createMemoryRouter(
    [
      { path: '/form', element: <Form /> },
      { path: '/ailleurs', element: <p>ailleurs</p> },
    ],
    { initialEntries: ['/form'] }
  )
  render(
    <MantineProvider>
      <RouterProvider router={router} />
    </MantineProvider>
  )
  return router
}

describe('useLeaveGuard (WEB-213)', () => {
  afterEach(() => {
    cleanup()
    state.dirty = true
  })

  it('asks before leaving a form with work in it: « Rester » stays, « Quitter » leaves', async () => {
    show()
    fireEvent.click(screen.getByText('partir'))
    expect(await screen.findByText('Quitter sans enregistrer ?')).toBeTruthy()

    fireEvent.click(screen.getByRole('button', { name: 'Rester' }))
    expect(screen.getByText('formulaire')).toBeTruthy()

    fireEvent.click(screen.getByText('partir'))
    fireEvent.click(await screen.findByRole('button', { name: 'Quitter' }))
    expect(await screen.findByText('ailleurs')).toBeTruthy()
  })

  it('lets a clean form go without asking', async () => {
    state.dirty = false
    show()
    fireEvent.click(screen.getByText('partir'))
    expect(await screen.findByText('ailleurs')).toBeTruthy()
  })

  it('lets the navigation after a save through, once', async () => {
    const router = show()
    fireEvent.click(screen.getByText('enregistrer'))
    expect(await screen.findByText('ailleurs')).toBeTruthy()
    expect(router.state.location.pathname).toBe('/ailleurs')
  })

  it('does not take an entry on the same page (the planner fullscreen) for leaving', async () => {
    const router = show()
    await act(async () => {
      fireEvent.click(screen.getByText('même page'))
    })
    expect(router.state.location.state).toEqual({ overlay: 1 })
    expect(screen.queryByText('Quitter sans enregistrer ?')).toBeNull()
  })

  it('asks the browser too, on a reload or a closed tab', () => {
    show()
    const event = new Event('beforeunload', { cancelable: true })
    window.dispatchEvent(event)
    expect(event.defaultPrevented).toBe(true)

    state.dirty = false
    const clean = new Event('beforeunload', { cancelable: true })
    window.dispatchEvent(clean)
    expect(clean.defaultPrevented).toBe(false)
  })
})
