import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import { Visibility } from '@/api/dto'
import type { TeamDetailDto } from '@/api/dto'

vi.mock('react-i18next', async () => {
  const { frenchT } = await import('@/test/frenchT')
  return { useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }) }
})

import { VisibilitySelector } from './VisibilitySelector'
import { allowedVisibilitiesFor } from './visibilityLabels'

function renderSelector(props: Partial<React.ComponentProps<typeof VisibilitySelector>> = {}) {
  const onChange = vi.fn()
  render(
    <MantineProvider>
      <VisibilitySelector
        allowed={[Visibility.TEAM, Visibility.PUBLIC_UNLISTED, Visibility.PUBLIC]}
        value={Visibility.TEAM}
        onChange={onChange}
        teamPrivate={false}
        {...props}
      />
    </MantineProvider>
  )
  return { onChange }
}

const radio = (name: string) => screen.queryByRole('radio', { name })

/** The shared field of every editor (docs/LEDGER_*.md WEB-166): what the backend allows, nothing else. */
describe('VisibilitySelector', () => {
  afterEach(cleanup)

  it('offers every value the backend allows, in the order of the enum', () => {
    const { onChange } = renderSelector({
      allowed: [Visibility.PUBLIC, Visibility.TEAM, Visibility.PUBLIC_UNLISTED],
    })
    const labels = screen.getAllByRole('radio').map((r) => r.closest('label')?.textContent ?? '')
    expect(labels.length).toBe(3)
    expect(screen.getAllByRole('radio').map((r) => (r as HTMLInputElement).value)).toEqual([
      'TEAM',
      'PUBLIC_UNLISTED',
      'PUBLIC',
    ])
    fireEvent.click(radio('Public')!)
    expect(onChange).toHaveBeenCalledWith('PUBLIC')
  })

  // A team page offering « Non répertorié » (plan A2) is checked on CreateTeamPagePage itself.

  it('ties its warning and its private-team hint to the group, for a screen reader', () => {
    renderSelector({
      allowed: [Visibility.TEAM, Visibility.PUBLIC_UNLISTED],
      value: Visibility.PUBLIC,
      teamPrivate: true,
    })
    const describedBy = (screen.getByRole('radiogroup').getAttribute('aria-describedby') ?? '')
      .split(' ')
      .filter(Boolean)
    const described = describedBy.map((id) => document.getElementById(id)?.textContent ?? '')
    expect(described.join(' ')).toContain(screen.getByTestId('visibility-not-allowed').textContent)
    expect(described.join(' ')).toContain(
      screen.getByTestId('visibility-private-team-hint').textContent
    )
  })

  it('is absent when there is a single value to take', () => {
    renderSelector({ allowed: [Visibility.TEAM] })
    expect(screen.queryByTestId('visibility-selector')).toBeNull()
    expect(screen.queryByRole('radio')).toBeNull()
  })

  it('explains instead of showing an empty control when nothing is allowed', () => {
    renderSelector({ allowed: [] })
    expect(screen.queryByRole('radio')).toBeNull()
    expect(screen.getByTestId('visibility-none-allowed').textContent).toContain(
      'Aucune visibilité ne peut être enregistrée'
    )
  })

  it('takes the editor’s own explanation when it has one', () => {
    renderSelector({ allowed: [], emptyMessage: 'Rien à choisir ici.' })
    expect(screen.getByTestId('visibility-none-allowed').textContent).toContain(
      'Rien à choisir ici.'
    )
  })

  it('shows a value no longer allowed, disabled, so the person sees why the save is refused', () => {
    // A private team whose platform admin withdrew the right: its public ride stays public.
    renderSelector({ allowed: [Visibility.TEAM], value: Visibility.PUBLIC, teamPrivate: true })
    expect(radio('Public')).toBeDisabled()
    expect(radio('Équipe uniquement')).not.toBeDisabled()
    expect(screen.getByTestId('visibility-not-allowed')).toBeTruthy()
  })

  it('tells a private team what « Public » means there: by link, out of every list', () => {
    renderSelector({ teamPrivate: true })
    expect(screen.getByTestId('visibility-private-team-hint').textContent).toContain(
      'toute personne qui a le lien'
    )
    cleanup()
    renderSelector({ teamPrivate: false })
    expect(screen.queryByTestId('visibility-private-team-hint')).toBeNull()
  })
})

describe('allowedVisibilitiesFor', () => {
  const team = {
    allowedContentVisibilities: {
      ride: ['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC'],
      route: ['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC'],
      rideTemplate: ['TEAM'],
      post: ['TEAM'],
      trip: ['TEAM'],
      teamPage: ['TEAM'],
      ad: ['TEAM'],
    },
  } as unknown as TeamDetailDto

  it("reads the team's list on creation", () => {
    expect(allowedVisibilitiesFor(team, 'ride')).toEqual(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC'])
    expect(allowedVisibilitiesFor(team, 'post')).toEqual(['TEAM'])
  })

  it("prefers the entity's own list on an edit: a route used publicly loses TEAM", () => {
    expect(
      allowedVisibilitiesFor(team, 'route', {
        allowedVisibilities: [Visibility.PUBLIC_UNLISTED, Visibility.PUBLIC],
      })
    ).toEqual(['PUBLIC_UNLISTED', 'PUBLIC'])
    expect(allowedVisibilitiesFor(team, 'route', { allowedVisibilities: [] })).toEqual([])
  })

  it("falls back on the team's list when the entity carries none", () => {
    expect(allowedVisibilitiesFor(team, 'route', {})).toEqual(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC'])
  })
})
