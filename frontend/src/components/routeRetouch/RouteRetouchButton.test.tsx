import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { RouteRetouchOfferDto } from '@/api/dto'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

import { RouteRetouchButton } from './RouteRetouchButton'

const offer = (over: Partial<RouteRetouchOfferDto> = {}): RouteRetouchOfferDto => ({
  available: true,
  operations: ['RESIZE', 'MOVE_END'],
  ...over,
})

function renderButton(o: RouteRetouchOfferDto | undefined) {
  const onChoose = vi.fn()
  render(
    <MantineProvider>
      <RouteRetouchButton offer={o} onChoose={onChoose} />
    </MantineProvider>
  )
  return { onChoose }
}

afterEach(cleanup)

describe('RouteRetouchButton', () => {
  it('shows nothing without an offer', () => {
    renderButton(undefined)
    expect(screen.queryByRole('button')).toBeNull()
  })

  it.each(['NOT_ALLOWED', 'ENGINE_UNAVAILABLE', 'UNSUPPORTED'] as const)(
    'shows nothing for %s',
    (unavailableReason) => {
      renderButton(offer({ available: false, operations: [], unavailableReason }))
      expect(screen.queryByRole('button')).toBeNull()
    }
  )

  it('shows the action disabled, with its reason, while the route is analysed', () => {
    renderButton(offer({ available: false, operations: [], unavailableReason: 'NOT_READY' }))
    const button = screen.getByRole('button', { name: 'Retoucher' }) as HTMLButtonElement
    expect(button.disabled).toBe(true)
    expect(screen.getByLabelText(/en cours d'analyse/)).toBeTruthy()
  })

  it('offers both operations and reports the choice', async () => {
    const { onChoose } = renderButton(offer())
    fireEvent.click(screen.getByRole('button', { name: 'Retoucher' }))
    expect(
      await screen.findByRole('menuitem', { name: 'Ajuster la distance', hidden: true })
    ).toBeTruthy()
    fireEvent.click(screen.getByRole('menuitem', { name: "Déplacer l'arrivée", hidden: true }))
    expect(onChoose).toHaveBeenCalledWith('moveEnd')
  })

  it('lists only the operations the engine offers', async () => {
    renderButton(offer({ operations: ['MOVE_END'] }))
    fireEvent.click(screen.getByRole('button', { name: 'Retoucher' }))
    expect(
      await screen.findByRole('menuitem', { name: "Déplacer l'arrivée", hidden: true })
    ).toBeTruthy()
    expect(screen.queryByRole('menuitem', { name: 'Ajuster la distance', hidden: true })).toBeNull()
  })

  it('shows nothing when no operation is offered', () => {
    renderButton(offer({ operations: [] }))
    expect(screen.queryByRole('button')).toBeNull()
  })
})
