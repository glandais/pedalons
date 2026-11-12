import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

import { ResultCount } from './ResultCount'

afterEach(cleanup)

const renderIt = (node: React.ReactNode) => render(<MantineProvider>{node}</MantineProvider>)

describe('ResultCount (RL8, RL5)', () => {
  it('formats the number and agrees the noun', () => {
    renderIt(<ResultCount total={2585} resource="ads" />)
    expect(screen.getByText(/^2\s585 annonces$/)).toBeTruthy()
  })

  it('is masked at zero: the empty state says it', () => {
    renderIt(<ResultCount total={0} resource="templates" />)
    expect(screen.queryByText(/modèle/)).toBeNull()
  })

  it('says the order beside the count', () => {
    renderIt(<ResultCount total={2} resource="teams" order="triées par nom" />)
    expect(screen.getByText('2 équipes · triées par nom')).toBeTruthy()
  })

  it('counts the ride templates', () => {
    renderIt(<ResultCount total={1} resource="templates" />)
    expect(screen.getByText('1 modèle')).toBeTruthy()
  })
})
