import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { AxiosError, AxiosHeaders, type InternalAxiosRequestConfig } from 'axios'
import type { ReactNode } from 'react'
import { ApiClientError } from '@/lib/apiError'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})
vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))

import { QueryStateBoundary } from './QueryStateBoundary'

/**
 * The one error form of the site's lists (docs/LEDGER_*.md WEB-175, RL11): a server failure and a
 * lost connection say different things, a refusal is not an error, and a list being replaced stays
 * on screen, dimmed.
 */

afterEach(cleanup)

const config = { headers: new AxiosHeaders() } as InternalAxiosRequestConfig

/** A request that never got an answer, as axios reports it. */
const networkError = () => new AxiosError('Network Error', AxiosError.ERR_NETWORK, config)
const serverError = () => new ApiClientError(500, { code: 'INTERNAL_ERROR', message: 'x' } as never)
const refusal = () => new ApiClientError(403, { code: 'FORBIDDEN', message: 'x' } as never)

function renderIt(node: ReactNode) {
  return render(
    <MantineProvider>
      <MemoryRouter>{node}</MemoryRouter>
    </MantineProvider>
  )
}

describe('QueryStateBoundary — errors (RL11)', () => {
  it('a server failure: « Chargement impossible », the server named, « Réessayer »', () => {
    const onRetry = vi.fn()
    renderIt(
      <QueryStateBoundary isLoading={false} isError error={serverError()} onRetry={onRetry}>
        liste
      </QueryStateBoundary>
    )
    expect(screen.getByRole('alert').textContent).toContain('Chargement impossible')
    expect(
      screen.getByText("Le serveur n'a pas pu répondre. Réessayez dans un instant.")
    ).toBeTruthy()
    fireEvent.click(screen.getByRole('button', { name: 'Réessayer' }))
    expect(onRetry).toHaveBeenCalled()
    expect(screen.queryByText('liste')).toBeNull()
  })

  it('no answer at all: « Pas de connexion », not a server failure', () => {
    renderIt(
      <QueryStateBoundary isLoading={false} isError error={networkError()} onRetry={() => {}}>
        liste
      </QueryStateBoundary>
    )
    expect(screen.getByRole('alert').textContent).toContain('Pas de connexion')
    expect(screen.getByText('Vérifiez votre connexion internet, puis réessayez.')).toBeTruthy()
    expect(screen.queryByText('Chargement impossible')).toBeNull()
    expect(screen.getByRole('button', { name: 'Réessayer' })).toBeTruthy()
  })

  it('a refusal (403) is no error: its own words, no alert, no « Réessayer », a way out', () => {
    renderIt(
      <QueryStateBoundary
        isLoading={false}
        isError
        error={refusal()}
        onRetry={() => {}}
        forbidden={{
          title: 'Liste des membres non partagée',
          message: 'Cette équipe ne partage pas la liste de ses membres avec vous.',
          action: <button type="button">À propos de l’équipe</button>,
        }}
      >
        liste
      </QueryStateBoundary>
    )
    expect(screen.getByRole('heading', { name: 'Liste des membres non partagée' })).toBeTruthy()
    expect(screen.getByRole('button', { name: 'À propos de l’équipe' })).toBeTruthy()
    expect(screen.queryByRole('alert')).toBeNull()
    expect(screen.queryByRole('button', { name: 'Réessayer' })).toBeNull()
  })

  it('a refusal without words of its own still is no error', () => {
    renderIt(
      <QueryStateBoundary isLoading={false} isError error={refusal()} onRetry={() => {}}>
        liste
      </QueryStateBoundary>
    )
    expect(screen.getByRole('heading', { name: 'Contenu réservé' })).toBeTruthy()
    expect(screen.queryByRole('alert')).toBeNull()
  })
})

describe('QueryStateBoundary — a list being replaced (RL11)', () => {
  it('keeps the previous list on screen, dimmed and busy, then shows it plainly', () => {
    const { rerender } = renderIt(
      <QueryStateBoundary isLoading={false} isRefreshing>
        <p>Sortie récupération</p>
      </QueryStateBoundary>
    )
    const box = screen.getByText('Sortie récupération').parentElement!
    expect(box.getAttribute('aria-busy')).toBe('true')
    expect(box.style.opacity).toBe('0.5')

    rerender(
      <MantineProvider>
        <MemoryRouter>
          <QueryStateBoundary isLoading={false} isRefreshing={false}>
            <p>Sortie récupération</p>
          </QueryStateBoundary>
        </MemoryRouter>
      </MantineProvider>
    )
    const settled = screen.getByText('Sortie récupération').parentElement!
    expect(settled.getAttribute('aria-busy')).toBe('false')
    expect(settled.style.opacity).toBe('1')
  })
})
