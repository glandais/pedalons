import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { act, cleanup, render, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { createMemoryRouter, RouterProvider } from 'react-router-dom'
import type { TeamDetailDto } from '@/api/dto'

const createRoute = vi.hoisted(() => vi.fn())
const notify = vi.hoisted(() => ({ show: vi.fn(), update: vi.fn() }))

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})
vi.mock('@/api/endpoints/routes/routes', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@/api/endpoints/routes/routes')>()),
  createRoute,
}))
vi.mock('@mantine/notifications', () => ({ notifications: notify }))
vi.mock('@/lib/gpxNames', () => ({
  readGpxNames: async (file: File) => ({ file: file.name }),
  defaultGpxName: (names: { file: string }) => names.file,
}))

import { useGpxUpload, type GpxUpload } from './useGpxUpload'
import { ApiClientError } from '@/lib/apiError'
import { paths } from '@/config/paths'

const TEAM = { slug: 'club', defaultContentVisibility: 'TEAM' } as unknown as TeamDetailDto
const file = (name: string) => new File(['<gpx/>'], name)

let uploads: GpxUpload[] = []
function Probe() {
  uploads.push(useGpxUpload(TEAM))
  return null
}

/** Two instances of the hook (the list's header and the empty state, say) on one page. */
function show() {
  const router = createMemoryRouter(
    [
      {
        path: '*',
        element: (
          <>
            <Probe />
            <Probe />
          </>
        ),
      },
    ],
    { initialEntries: ['/'] }
  )
  render(
    <QueryClientProvider client={new QueryClient()}>
      <RouterProvider router={router} />
    </QueryClientProvider>
  )
  return router
}

/** Picks `files` in the file dialog `open()` creates. */
function pick(files: File[]) {
  const click = vi.spyOn(HTMLInputElement.prototype, 'click').mockImplementation(function (
    this: HTMLInputElement
  ) {
    Object.defineProperty(this, 'files', { value: files })
    this.onchange?.(new Event('change'))
  })
  return click
}

const lastMessage = () => notify.update.mock.calls.at(-1)?.[0]?.message as string

describe('useGpxUpload (WEB-216)', () => {
  beforeEach(() => {
    uploads = []
    createRoute.mockReset()
    notify.show.mockReset()
    notify.update.mockReset()
  })
  afterEach(() => {
    cleanup()
    vi.restoreAllMocks()
    window.history.replaceState(null, '', '/')
  })

  it('says why each file was refused, then opens the routes', async () => {
    createRoute
      .mockResolvedValueOnce({ slug: 'nord' })
      .mockRejectedValueOnce(
        new ApiClientError(400, { code: 'GPX_EMPTY', message: 'empty' } as never)
      )
    const router = show()
    pick([file('nord.gpx'), file('vide.gpx')])
    await act(async () => uploads.at(-1)!.open())

    await waitFor(() =>
      expect(lastMessage()).toBe(
        '1 parcours importé. Fichier refusé : vide.gpx (Le fichier GPX ne contient aucune donnée de tracé)'
      )
    )
    expect(createRoute.mock.calls[0][2]).toEqual({ skipErrorToast: true })
    expect(router.state.location.pathname).toBe(paths.routes('club'))
  })

  it('does not pull away someone who went elsewhere meanwhile', async () => {
    createRoute.mockImplementation(async () => {
      // The person leaves the page while the files are sent
      window.history.replaceState(null, '', '/equipes/club/sorties/nouvelle')
      return { slug: 'x' }
    })
    const router = show()
    pick([file('a.gpx'), file('b.gpx')])
    await act(async () => uploads.at(-1)!.open())

    await waitFor(() => expect(lastMessage()).toBe('2 parcours importés'))
    expect(router.state.location.pathname).toBe('/')
  })

  it('shares its progress between instances and starts no second import meanwhile', async () => {
    let release: () => void = () => {}
    createRoute.mockImplementation(
      () => new Promise((resolve) => (release = () => resolve({ slug: 'x' })))
    )
    show()
    pick([file('a.gpx'), file('b.gpx')])
    await act(async () => {
      void uploads.at(-1)!.open()
    })
    await waitFor(() => expect(uploads.at(-2)!.progress).toEqual({ current: 0, total: 2 }))

    // The other instance's import is refused while this one runs
    await act(async () => uploads.at(-2)!.open())
    expect(createRoute).toHaveBeenCalledTimes(1)

    await act(async () => release())
    await act(async () => release())
    await waitFor(() => expect(uploads.at(-1)!.progress).toBeNull())
  })

  it('says when nothing was imported', async () => {
    createRoute.mockRejectedValue(new Error('boom'))
    show()
    pick([file('a.gpx'), file('b.gpx')])
    await act(async () => uploads.at(-1)!.open())
    await waitFor(() =>
      expect(lastMessage()).toBe(
        'Aucun parcours importé. Fichiers refusés : a.gpx (refusé par le serveur) ; b.gpx (refusé par le serveur)'
      )
    )
  })
})
