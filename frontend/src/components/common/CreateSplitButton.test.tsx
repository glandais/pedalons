import { describe, it, expect, afterEach } from 'vitest'
import { render, screen, fireEvent, cleanup, waitFor } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import { MemoryRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { IconBike, IconRoute, IconWand } from '@tabler/icons-react'
import { CreateSplitButton, type CreateAction } from './CreateSplitButton'

const ride: CreateAction = {
  key: 'ride',
  label: 'Créer une sortie',
  icon: IconBike,
  color: 'blue',
  to: '/equipes/np/sorties/nouvelle',
  group: 'Agenda',
}
const trip: CreateAction = {
  key: 'trip',
  label: 'Créer un voyage',
  icon: IconRoute,
  color: 'teal',
  to: '/equipes/np/voyages/nouveau',
  group: 'Agenda',
}
const generate: CreateAction = {
  key: 'route-generate',
  label: 'Générer un parcours',
  icon: IconWand,
  color: 'indigo',
  to: '/equipes/np/parcours/generer',
  group: 'Parcours',
  disabledReason: 'Quota atteint',
}

function renderButton(actions: CreateAction[], compact = false) {
  render(
    <QueryClientProvider client={new QueryClient()}>
      <MantineProvider>
        <MemoryRouter>
          <CreateSplitButton actions={actions} compact={compact} />
        </MemoryRouter>
      </MantineProvider>
    </QueryClientProvider>
  )
}

describe('CreateSplitButton', () => {
  afterEach(cleanup)

  it('a single action is a plain link, with no menu', () => {
    renderButton([ride])
    expect(screen.getByRole('link', { name: 'Créer une sortie' }).getAttribute('href')).toBe(
      ride.to
    )
    expect(screen.queryByRole('button', { name: 'aria.createOther' })).toBeNull()
  })

  it('the first action is the button, every action is in the menu by section', async () => {
    renderButton([ride, trip, generate])
    expect(screen.getByRole('link', { name: 'Créer une sortie' })).toBeTruthy()
    fireEvent.click(screen.getByRole('button', { name: 'aria.createOther' }))
    await waitFor(() =>
      expect(screen.getByRole('menuitem', { name: /Créer un voyage/ })).toBeTruthy()
    )
    expect(screen.getByText('Agenda')).toBeTruthy()
    expect(screen.getByText('Parcours')).toBeTruthy()
    // Disabled, with its reason.
    const disabled = screen.getByTestId('create-route-generate')
    expect(disabled.hasAttribute('disabled') || disabled.getAttribute('data-disabled')).toBeTruthy()
    expect(screen.getByText('Quota atteint')).toBeTruthy()
  })

  it('a disabled first action leaves the button to the next one', () => {
    renderButton([{ ...ride, disabledReason: 'Non' }, trip])
    expect(screen.getByRole('link', { name: 'Créer un voyage' })).toBeTruthy()
  })

  it('compact: one icon opening the whole menu', async () => {
    renderButton([ride, trip], true)
    expect(screen.queryByRole('link', { name: 'Créer une sortie' })).toBeNull()
    fireEvent.click(screen.getByRole('button', { name: 'actions.new' }))
    await waitFor(() =>
      expect(screen.getByRole('menuitem', { name: /Créer une sortie/ })).toBeTruthy()
    )
  })
})
