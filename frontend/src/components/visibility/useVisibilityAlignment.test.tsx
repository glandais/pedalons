import { afterEach, describe, expect, it, vi } from 'vitest'
import {
  act,
  cleanup,
  fireEvent,
  render,
  renderHook,
  screen,
  waitFor,
} from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import { MemoryRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { ReactNode } from 'react'
import type { IncompatibleVisibilityDetails } from '@/api/dto'
import { ApiClientError, CALLER_RENDERED_ERROR_CODES } from '@/lib/apiError'
import { paths } from '@/config/paths'

vi.mock('react-i18next', async () => {
  const { frenchT } = await import('@/test/frenchT')
  return { useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }) }
})
const notify = vi.hoisted(() => vi.fn())
vi.mock('@mantine/notifications', () => ({ notifications: { show: notify } }))

import {
  useRestoreRefusal,
  useRouteUsagesRefusal,
  useVisibilityAlignment,
  type VisibilityRefusalHandler,
} from './useVisibilityAlignment'
import { incompatibleVisibilityOf } from './incompatibleVisibility'

const refusal = (details: Partial<IncompatibleVisibilityDetails>) =>
  new ApiClientError(400, {
    code: 'INCOMPATIBLE_VISIBILITY',
    errorDetails: { type: 'INCOMPATIBLE_VISIBILITY', routes: [], usages: [], ...details },
  })

const teamRoute = {
  slug: 'col-du-coq',
  name: 'Col du Coq',
  visibility: 'TEAM' as const,
  proposedVisibility: 'PUBLIC_UNLISTED' as const,
}

/** Mounts a handler hook and renders its dialog, as a page does. */
function mount(useHandler: () => VisibilityRefusalHandler) {
  let handler!: VisibilityRefusalHandler
  function Host() {
    handler = useHandler()
    return <>{handler.dialog}</>
  }
  const wrapper = ({ children }: { children: ReactNode }) => (
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>{children}</MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
  render(<Host />, { wrapper })
  return () => handler
}

afterEach(() => {
  cleanup()
  notify.mockReset()
})

describe('the generic toast', () => {
  it('stays quiet for INCOMPATIBLE_VISIBILITY: its screen says it in a dialog', () => {
    expect(CALLER_RENDERED_ERROR_CODES.has('INCOMPATIBLE_VISIBILITY')).toBe(true)
    expect(CALLER_RENDERED_ERROR_CODES.has('INVALID_VISIBILITY')).toBe(false)
  })
})

describe('incompatibleVisibilityOf', () => {
  it('reads the refusal, both lists always present', () => {
    expect(incompatibleVisibilityOf(refusal({ routes: [teamRoute] }))).toEqual({
      type: 'INCOMPATIBLE_VISIBILITY',
      routes: [teamRoute],
      usages: [],
    })
  })

  it('is undefined for any other failure', () => {
    expect(incompatibleVisibilityOf(new ApiClientError(400, { code: 'INVALID_VISIBILITY' }))).toBe(
      undefined
    )
    expect(incompatibleVisibilityOf(new Error('network'))).toBeUndefined()
  })
})

/** Decision D5 (docs/LEDGER_*.md WEB-166): confirm, then replay with alignVisibility. */
describe('useVisibilityAlignment', () => {
  it('lists the routes and the visibility they will take, then replays with them', async () => {
    const handler = mount(() => useVisibilityAlignment('ride'))
    const replay = vi.fn()
    let handled = false
    act(() => {
      handled = handler().offer(refusal({ routes: [teamRoute] }), replay)
    })
    expect(handled).toBe(true)
    const dialog = await screen.findByTestId('visibility-align-dialog')
    expect(dialog.textContent).toContain('Cette sortie sera visible hors de l')
    expect(screen.getByTestId('visibility-align-route').textContent).toBe(
      'Col du Coq : Équipe uniquement → Non répertorié'
    )
    expect(replay).not.toHaveBeenCalled()

    fireEvent.click(screen.getByRole('button', { name: 'Ouvrir les parcours et enregistrer' }))
    expect(replay).toHaveBeenCalledWith([teamRoute])
    await waitFor(() => expect(screen.queryByTestId('visibility-align-dialog')).toBeNull())
  })

  it('replays nothing when the person cancels', async () => {
    const handler = mount(() => useVisibilityAlignment('trip'))
    const replay = vi.fn()
    act(() => {
      handler().offer(refusal({ routes: [teamRoute] }), replay)
    })
    expect((await screen.findByTestId('visibility-align-dialog')).textContent).toContain(
      'Ce voyage sera visible hors de l'
    )
    fireEvent.click(screen.getByRole('button', { name: 'Annuler' }))
    expect(replay).not.toHaveBeenCalled()
  })

  it('leaves any other failure to the caller', () => {
    const { result } = renderHook(() => useVisibilityAlignment('ride'))
    expect(result.current.offer(new ApiClientError(400, { code: 'VALIDATION' }), vi.fn())).toBe(
      false
    )
  })

  it('still says something when the refusal lists no route', () => {
    const { result } = renderHook(() => useVisibilityAlignment('ride'))
    act(() => {
      result.current.offer(refusal({}), vi.fn())
    })
    expect(notify).toHaveBeenCalledWith(
      expect.objectContaining({ message: expect.stringContaining('Visibilités incompatibles') })
    )
  })
})

describe('useRestoreRefusal', () => {
  it('lists the routes to open first, each linked to its page — nothing to align', async () => {
    const handler = mount(() => useRestoreRefusal('np', 'ride'))
    act(() => {
      handler().offer(refusal({ routes: [teamRoute] }), vi.fn())
    })
    const dialog = await screen.findByTestId('visibility-restore-blocked')
    expect(dialog.textContent).toContain('puis restaurez la sortie')
    expect(screen.getByRole('link', { name: 'Col du Coq' }).getAttribute('href')).toBe(
      paths.route('np', 'col-du-coq')
    )
    expect(screen.queryByRole('button', { name: 'Ouvrir les parcours et enregistrer' })).toBeNull()
  })
})

/** Decision D6: a route used publicly cannot go « Équipe »; the refusal lists the usages. */
describe('useRouteUsagesRefusal', () => {
  it('lists each ride and trip in the way, with a link to it', async () => {
    const handler = mount(() => useRouteUsagesRefusal('np'))
    act(() => {
      handler().offer(
        refusal({
          usages: [
            { type: 'RIDE', slug: 'sortie', name: 'Sortie du samedi', visibility: 'PUBLIC' },
            { type: 'TRIP', slug: 'voyage', name: 'Grand tour', visibility: 'PUBLIC_UNLISTED' },
          ],
        }),
        () => {}
      )
    })
    expect(await screen.findByTestId('visibility-route-in-use')).toBeTruthy()
    expect(
      screen
        .getByRole('link', { name: 'Sortie « Sortie du samedi » (Public)' })
        .getAttribute('href')
    ).toBe(paths.ride('np', 'sortie'))
    expect(
      screen
        .getByRole('link', { name: 'Voyage « Grand tour » (Non répertorié)' })
        .getAttribute('href')
    ).toBe(paths.trip('np', 'voyage'))
  })
})
