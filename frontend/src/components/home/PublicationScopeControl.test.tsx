import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { ReactNode } from 'react'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})
const auth = vi.hoisted(() => ({ isAuthenticated: true }))
vi.mock('@/hooks/useAuth', () => ({ useAuth: () => auth }))

import { PublicationScopeControl } from './PublicationScopeControl'
import { AgendaFilterBar } from '@/components/agenda/AgendaFilterBar'

const TEAM = { enableRides: true, enableTrips: true, enableRoutes: true }

const wrap = (node: ReactNode) => render(<MantineProvider>{node}</MantineProvider>)
const values = () => screen.getAllByRole('radio').map((radio) => radio.getAttribute('value'))

afterEach(() => {
  cleanup()
  auth.isAuthenticated = true
})

/** The period gains « Plus tôt », the second section alone (RL15, complement of 12 November). */
describe('the period « Tout / Je participe / Plus tôt »', () => {
  it('home feed: three choices for a signed-in reader, « Plus tôt » is `earlier`', () => {
    const onChange = vi.fn()
    wrap(<PublicationScopeControl value="all" onChange={onChange} />)
    expect(values()).toEqual(['all', 'me', 'earlier'])
    fireEvent.click(screen.getByRole('radio', { name: 'Plus tôt' }))
    expect(onChange).toHaveBeenCalledWith('earlier')
  })

  it('home feed: « Tout / Plus tôt » for a visitor, who cannot participate', () => {
    auth.isAuthenticated = false
    wrap(<PublicationScopeControl value="earlier" onChange={vi.fn()} />)
    expect(values()).toEqual(['all', 'earlier'])
    expect(screen.getByRole('radio', { name: 'Plus tôt' })).toBeChecked()
  })

  it('agenda list: « Toutes les dates / Plus tôt » for a visitor; no period in the calendar', () => {
    auth.isAuthenticated = false
    const props = { team: TEAM, scope: 'all', onScopeChange: vi.fn(), type: 'all' } as const
    const { unmount } = wrap(<AgendaFilterBar {...props} mode="list" onTypeChange={vi.fn()} />)
    expect(screen.getByRole('radiogroup', { name: 'Période' })).toBeTruthy()
    expect(screen.getByRole('radio', { name: 'Toutes les dates' })).toBeTruthy()
    expect(screen.getByRole('radio', { name: 'Plus tôt' })).toBeTruthy()
    unmount()
    wrap(<AgendaFilterBar {...props} mode="calendar" onTypeChange={vi.fn()} />)
    expect(screen.queryByRole('radiogroup', { name: 'Période' })).toBeNull()
  })
})
