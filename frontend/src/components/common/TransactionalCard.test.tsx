import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, screen, fireEvent, cleanup, within } from '@testing-library/react'
import { MantineProvider, Button } from '@mantine/core'

vi.mock('@/components/common/PrefetchLink', () => ({
  PrefetchLink: ({ to, children, ...rest }: { to: string; children: React.ReactNode }) => (
    <a href={to} {...rest}>
      {children}
    </a>
  ),
}))

import { TransactionalCard, TransactionalCardContent } from './TransactionalCard'

function renderInMantine(node: React.ReactNode) {
  return render(<MantineProvider>{node}</MantineProvider>)
}

describe('TransactionalCard', () => {
  afterEach(cleanup)

  it('renders one h1, the sentence, the content, the actions, then the back link last', () => {
    renderInMantine(
      <TransactionalCard
        data-testid="card"
        title="Mot de passe oublié"
        description="Saisissez votre adresse."
        actions={<Button fullWidth>Envoyer</Button>}
        back={{ label: 'Retour à la connexion', to: '/connexion' }}
      >
        <p>contenu</p>
      </TransactionalCard>
    )
    const card = screen.getByTestId('card')
    const headings = within(card).getAllByRole('heading')
    expect(headings).toHaveLength(1)
    expect(headings[0].tagName).toBe('H1')
    expect(headings[0]).toHaveTextContent('Mot de passe oublié')
    expect(within(card).getByText('Saisissez votre adresse.')).toBeInTheDocument()

    const back = within(card).getByRole('link', { name: 'Retour à la connexion' })
    expect(back).toHaveAttribute('href', '/connexion')
    // The back link comes after the actions, in document order.
    const action = within(card).getByRole('button', { name: 'Envoyer' })
    expect(action.compareDocumentPosition(back) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy()
  })

  it('renders a step back as a button calling onClick', () => {
    const onClick = vi.fn()
    renderInMantine(<TransactionalCard title="Code" back={{ label: 'Retour', onClick }} />)
    fireEvent.click(screen.getByRole('button', { name: 'Retour' }))
    expect(onClick).toHaveBeenCalledOnce()
  })

  it('omits the sentence, the actions and the back link when not given', () => {
    renderInMantine(<TransactionalCard title="Terminé" />)
    expect(screen.queryByRole('link')).toBeNull()
    expect(screen.queryByRole('button')).toBeNull()
  })

  it('takes the level it is given inside another frame, at the same size', () => {
    renderInMantine(<TransactionalCardContent title="Se connecter" titleOrder={2} />)
    expect(screen.getByRole('heading', { level: 2, name: 'Se connecter' })).toBeInTheDocument()
    expect(screen.queryByRole('heading', { level: 1 })).toBeNull()
  })
})
