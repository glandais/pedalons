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
    // ErrorBoundary is a class: it translates through the render-prop.
    Translation: ({ children }: { children: (t: typeof frenchT) => ReactNode }) =>
      children(frenchT),
  }
})
vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))

import { QueryStateBoundary } from './QueryStateBoundary'
import { EmptyState } from './EmptyState'
import { ErrorBoundary } from './ErrorBoundary'
import { CardHeadingOrder } from '@/components/card/common/Card'

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

/** The heading levels of the page, in document order. */
const levels = () =>
  screen.getAllByRole('heading').map((h) => Number(h.getAttribute('aria-level') ?? h.tagName[1]))

const notFoundError = () => new ApiClientError(404, { code: 'NOT_FOUND', message: 'x' } as never)

/**
 * A state that replaces the whole page names it with the page's one h1; below a page's own h1 it
 * stays a lower level (docs/LEDGER_*.md WEB-210). `e2e/routes-render.e2e.ts` never lands on these
 * states, so this is their check, with the h1 assertions of `e2e/error-states.e2e.ts`.
 */
describe('QueryStateBoundary — the heading of a state that replaces the page (WEB-210)', () => {
  const outcomes = [
    ['a 404', notFoundError, 'Introuvable'],
    ['a 403', refusal, 'Contenu réservé'],
    ['a server failure', serverError, 'Chargement impossible'],
    ['no connection', networkError, 'Pas de connexion'],
  ] as const

  for (const [label, error, title] of outcomes) {
    it(`${label}: an h1 when it replaces the page, none otherwise`, () => {
      renderIt(
        <QueryStateBoundary isLoading={false} isError error={error()} replacesPage>
          {null}
        </QueryStateBoundary>
      )
      expect(screen.getByRole('heading', { level: 1 }).textContent).toBe(title)
      cleanup()

      renderIt(
        <QueryStateBoundary isLoading={false} isError error={error()}>
          {null}
        </QueryStateBoundary>
      )
      expect(screen.queryByRole('heading', { level: 1 })).toBeNull()
    })
  }

  it('an entity the query did not return (isNotFound) is the h1 too', () => {
    renderIt(
      <QueryStateBoundary
        isLoading={false}
        isNotFound
        replacesPage
        notFound={{ title: 'Sortie non trouvée' }}
      >
        {null}
      </QueryStateBoundary>
    )
    expect(screen.getByRole('heading', { level: 1, name: 'Sortie non trouvée' })).toBeTruthy()
  })

  it('loading shows no h1', () => {
    renderIt(
      <QueryStateBoundary isLoading replacesPage skeleton={<p>chargement</p>}>
        {null}
      </QueryStateBoundary>
    )
    expect(screen.queryAllByRole('heading')).toHaveLength(0)
  })
})

describe('EmptyState — its level follows the list it stands in (WEB-210)', () => {
  const empty = <EmptyState icon={null} title="Aucune équipe" />

  it('an h3 by default, under a page whose title is an h2', () => {
    renderIt(empty)
    expect(levels()).toEqual([3])
  })

  it('an h2 where the cards are h2s, under a page h1 (TeamListPage, AllRoutesPage)', () => {
    renderIt(<CardHeadingOrder order={2}>{empty}</CardHeadingOrder>)
    expect(levels()).toEqual([2])
  })

  it('an explicit order wins', () => {
    renderIt(
      <CardHeadingOrder order={2}>
        <EmptyState icon={null} title="Aucune équipe" order={1} />
      </CardHeadingOrder>
    )
    expect(levels()).toEqual([1])
  })
})

describe('ErrorBoundary — the page variant names the page (WEB-210)', () => {
  function Boom(): never {
    throw new Error('boom')
  }

  for (const [variant, level] of [
    ['page', 1],
    ['inline', 3],
  ] as const) {
    it(`variant ${variant}: an h${level}`, () => {
      vi.spyOn(console, 'error').mockImplementation(() => {})
      renderIt(
        <ErrorBoundary variant={variant}>
          <Boom />
        </ErrorBoundary>
      )
      expect(levels()).toEqual([level])
      vi.restoreAllMocks()
    })
  }
})
