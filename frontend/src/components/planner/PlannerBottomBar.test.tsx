import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { I18nextProvider } from 'react-i18next'
import type { i18n as I18n } from 'i18next'
import { MantineProvider } from '@mantine/core'
import { RouterProfile } from '@/api/dto'
import { createServerI18n } from '@/i18n'
import { MapPanelContext, useMapPanelState } from '@/components/map/mapPanelState'
import { PlannerBottomBar } from './PlannerBottomBar'

vi.mock('@/hooks/useUnits', () => ({
  useUnits: () => ({
    distance: (m: number) => `${(m / 1000).toFixed(1)} km`,
    elevation: (m: number) => `${m} m`,
  }),
}))

let i18n: I18n
beforeAll(async () => {
  // The real French catalogue: the end-to-end tests find these buttons by these very names.
  i18n = await createServerI18n('fr')
})

type Props = React.ComponentProps<typeof PlannerBottomBar>

function Panels({ children }: { children: React.ReactNode }) {
  return <MapPanelContext.Provider value={useMapPanelState()}>{children}</MapPanelContext.Provider>
}

function setup(over: Partial<Props> = {}) {
  const props: Props = {
    pointCount: 0,
    isLoading: false,
    error: null,
    profileOpen: true,
    onProfileToggle: vi.fn(),
    profileId: 'strip-holder',
    canUndo: false,
    canRedo: false,
    onUndo: vi.fn(),
    onRedo: vi.fn(),
    routerProfile: RouterProfile.BIKE,
    onProfileChange: vi.fn(),
    routerTuning: {},
    onTuningChange: vi.fn(),
    onTuningReset: vi.fn(),
    directMode: false,
    onDirectModeChange: vi.fn(),
    onDone: vi.fn(),
    ...over,
  }
  const view = render(
    <I18nextProvider i18n={i18n}>
      <MantineProvider>
        <Panels>
          <PlannerBottomBar {...props} />
        </Panels>
      </MantineProvider>
    </I18nextProvider>
  )
  return { props, ...view }
}

const summaryButton = () =>
  screen.getByRole('button', { name: /^(Afficher|Masquer) le profil altimétrique$/ })

describe('PlannerBottomBar', () => {
  afterEach(cleanup)

  it('line 1: one button with the summary, named after what a tap does, controlling the strip', () => {
    setup({ pointCount: 3, stats: { distance: 42600, ascend: 640 } })
    const summary = summaryButton()
    expect(summary.tagName).toBe('BUTTON')
    expect(summary.getAttribute('aria-label')).toBe('Masquer le profil altimétrique')
    expect(summary.getAttribute('aria-expanded')).toBe('true')
    expect(summary.getAttribute('aria-controls')).toBe('strip-holder')
    expect(summary.textContent).toContain('42.6 km')
    expect(summary.textContent).toContain('+640 m')
    expect(summary.textContent).toContain('3 points')
    expect(summary.textContent).toContain('Profil')
    // The figures are its description
    const description = document.getElementById(summary.getAttribute('aria-describedby')!)
    expect(description?.textContent).toContain('42.6 km')
    // 48 px, whatever it shows: the map is not resized at the first point
    expect(summary.style.height).toBe('calc(3rem * var(--mantine-scale))')
  })

  it('folds and unfolds the profile, and says so', () => {
    const { props, rerender } = setup()
    fireEvent.click(summaryButton())
    expect(props.onProfileToggle).toHaveBeenCalledTimes(1)

    rerender(
      <I18nextProvider i18n={i18n}>
        <MantineProvider>
          <Panels>
            <PlannerBottomBar {...props} profileOpen={false} />
          </Panels>
        </MantineProvider>
      </I18nextProvider>
    )
    const summary = summaryButton()
    expect(summary.getAttribute('aria-label')).toBe('Afficher le profil altimétrique')
    expect(summary.getAttribute('aria-expanded')).toBe('false')
  })

  it('carries the calculation and the routing error', () => {
    setup({
      pointCount: 2,
      isLoading: true,
      error: "Le service d'itinéraires a atteint son quota mensuel. Réessayez plus tard.",
    })
    const summary = summaryButton()
    expect(screen.getByRole('status', { name: "Calcul de l'itinéraire..." })).toBeTruthy()
    expect(summary.textContent).toContain('a atteint son quota mensuel')
    expect(summary.textContent).toContain('2 points')
    // The error takes the room of the word « Profil »
    expect(summary.textContent).not.toContain('Profil')
  })

  it('says nothing of a route not started: no count, no figures', () => {
    setup()
    expect(summaryButton().textContent).toBe('Profil')
    expect(screen.queryByRole('status')).toBeNull()
  })

  it('line 2: the tools under their names, and « Terminer »', () => {
    const { props } = setup({ canUndo: true, canRedo: true })
    fireEvent.click(screen.getByRole('button', { name: 'Annuler' }))
    expect(props.onUndo).toHaveBeenCalledTimes(1)
    fireEvent.click(screen.getByRole('button', { name: 'Rétablir' }))
    expect(props.onRedo).toHaveBeenCalledTimes(1)
    const direct = screen.getByRole('button', { name: 'Ligne droite' })
    expect(direct.getAttribute('aria-pressed')).toBe('false')
    fireEvent.click(direct)
    expect(props.onDirectModeChange).toHaveBeenCalledWith(true)
    expect(screen.getByRole('button', { name: 'Profil' })).toBeTruthy()
    expect(screen.getByRole('button', { name: 'Aide : gestes' })).toBeTruthy()
    fireEvent.click(screen.getByRole('button', { name: 'Terminer' }))
    expect(props.onDone).toHaveBeenCalledTimes(1)
  })

  it('disables undo and redo with nothing to take back', () => {
    setup()
    expect((screen.getByRole('button', { name: 'Annuler' }) as HTMLButtonElement).disabled).toBe(
      true
    )
    expect((screen.getByRole('button', { name: 'Rétablir' }) as HTMLButtonElement).disabled).toBe(
      true
    )
  })
})
