import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen, within } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { DetailHeader } from './DetailHeader'
import { EditMenuButton } from './EditMenuButton'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})
vi.mock('@/components/common/ShareButton', () => ({
  ShareButton: ({ title }: { title: string }) => <button type="button">Partager {title}</button>,
}))

const wrap = (ui: React.ReactNode) =>
  render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>{ui}</MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )

describe('DetailHeader (WEB-206)', () => {
  afterEach(cleanup)

  it('has the title as the only level-1 heading', () => {
    wrap(<DetailHeader title="Sortie du samedi" badges={<span>Publiée</span>} />)
    expect(screen.getAllByRole('heading', { level: 1 })).toHaveLength(1)
    expect(screen.getByRole('heading', { level: 1, name: 'Sortie du samedi' })).toBeTruthy()
  })

  it('orders the actions primary, gps, edit, retouch, share, more whatever the props order', () => {
    wrap(
      <DetailHeader
        more={<button type="button">more</button>}
        shareTitle="T"
        retouch={<button type="button">retouch</button>}
        edit={<button type="button">edit</button>}
        gps={<button type="button">gps</button>}
        primary={<button type="button">primary</button>}
        title="T"
      />
    )
    const labels = within(screen.getByTestId('detail-header-actions'))
      .getAllByRole('button')
      .map((b) => b.textContent)
    expect(labels).toEqual(['primary', 'gps', 'edit', 'retouch', 'Partager T', 'more'])
  })

  it('renders nothing for an absent slot, and no actions group without any', () => {
    wrap(<DetailHeader title="T" gps={<button type="button">gps</button>} />)
    const actions = screen.getByTestId('detail-header-actions')
    expect(within(actions).getAllByRole('button')).toHaveLength(1)
    cleanup()
    wrap(<DetailHeader title="T" />)
    expect(screen.queryByTestId('detail-header-actions')).toBeNull()
  })

  it('shows the error as an alert, and the context and children', () => {
    wrap(
      <DetailHeader title="T" context="La sortie" error="Échec">
        <p>Départ</p>
      </DetailHeader>
    )
    expect(screen.getByRole('alert').textContent).toContain('Échec')
    expect(screen.getByText('La sortie')).toBeTruthy()
    expect(screen.getByText('Départ')).toBeTruthy()
  })
})

describe('EditMenuButton (WEB-206)', () => {
  afterEach(cleanup)

  it('links « Modifier » to the page and opens its menu on the chevron', async () => {
    wrap(
      <EditMenuButton to="/edit">
        <button type="button">Supprimer</button>
      </EditMenuButton>
    )
    expect(screen.getByRole('link', { name: 'Modifier' }).getAttribute('href')).toBe('/edit')
    fireEvent.click(screen.getByRole('button', { name: 'Options de gestion' }))
    expect(await screen.findByText('Supprimer')).toBeTruthy()
  })
})
