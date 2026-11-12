import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

import { FilterPanelToggle } from './FilterPanelToggle'

afterEach(cleanup)

const renderIt = (activeCount: number, onClear = vi.fn()) =>
  render(
    <MantineProvider>
      <FilterPanelToggle
        activeCount={activeCount}
        open={false}
        onToggle={() => {}}
        controls="panel"
        onClear={onClear}
      />
    </MantineProvider>
  )

describe('FilterPanelToggle (RL4)', () => {
  it('at rest: « Filtres », no badge, no « Effacer les filtres »', () => {
    renderIt(0)
    expect(screen.getByRole('button', { name: 'Filtres' })).toBeTruthy()
    expect(screen.queryByRole('button', { name: 'Effacer les filtres' })).toBeNull()
  })

  it('filtered: the count on the button, and the one way to lift it all', () => {
    const onClear = vi.fn()
    renderIt(2, onClear)
    const toggle = screen.getByRole('button', { name: 'Filtres, 2 actifs' })
    expect(toggle.textContent).toContain('2')
    fireEvent.click(screen.getByRole('button', { name: 'Effacer les filtres' }))
    expect(onClear).toHaveBeenCalled()
  })
})
