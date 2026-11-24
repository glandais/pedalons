import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen, within } from '@testing-library/react'
import { I18nextProvider } from 'react-i18next'
import type { i18n as I18n } from 'i18next'
import { MantineProvider } from '@mantine/core'
import { RouterProfile } from '@/api/dto'
import type { RouteSettingsModel } from './routeSettingsModel'
import { createServerI18n } from '@/i18n'
import { MapPanelContext, useMapPanelState } from '@/components/map/mapPanelState'
import { PlannerToolbar } from './PlannerToolbar'

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

function settingsOf(over: Partial<RouteSettingsModel> = {}): RouteSettingsModel {
  return {
    profile: RouterProfile.BIKE,
    onProfileChange: vi.fn(),
    tuning: {},
    onTuningChange: vi.fn(),
    onTuningReset: vi.fn(),
    pointCount: 0,
    isLoading: false,
    recalcScope: { legs: 0, distance: 0, keeps: false },
    recalculated: false,
    onRecalculate: vi.fn(),
    ...over,
  }
}

type Props = React.ComponentProps<typeof PlannerToolbar>

function Panels({ children }: { children: React.ReactNode }) {
  // One open panel per map, as RoutePlannerField provides it around the planner.
  return <MapPanelContext.Provider value={useMapPanelState()}>{children}</MapPanelContext.Provider>
}

function setup(over: Partial<Props> = {}) {
  const props: Props = {
    pointCount: 0,
    isLoading: false,
    error: null,
    canUndo: false,
    canRedo: false,
    onUndo: vi.fn(),
    onRedo: vi.fn(),
    directMode: false,
    onDirectModeChange: vi.fn(),
    settings: settingsOf(),
    ...over,
  }
  render(
    <I18nextProvider i18n={i18n}>
      <MantineProvider>
        <Panels>
          <PlannerToolbar {...props} />
        </Panels>
      </MantineProvider>
    </I18nextProvider>
  )
  return { props, toolbar: screen.getByRole('toolbar', { name: 'Outils du tracé' }) }
}

const names = (toolbar: HTMLElement) =>
  within(toolbar)
    .getAllByRole('button')
    .map((b) => b.getAttribute('aria-label'))

describe('PlannerToolbar', () => {
  afterEach(cleanup)

  it('holds the tools in a fixed order, under the names the column buttons had', () => {
    const { toolbar } = setup({ onImport: vi.fn() })
    expect(names(toolbar)).toEqual([
      'Annuler (Ctrl+Z)',
      'Rétablir (Ctrl+Maj+Z)',
      expect.stringMatching(/^Ligne droite \(ou /),
      'Réglages du tracé : Vélo',
      'Importer un fichier GPX',
      'Aide : gestes',
    ])
  })

  it('disables undo and redo with no history, and runs them otherwise', () => {
    const { toolbar } = setup()
    expect(within(toolbar).getByRole('button', { name: 'Annuler (Ctrl+Z)' })).toBeDisabled()
    expect(within(toolbar).getByRole('button', { name: 'Rétablir (Ctrl+Maj+Z)' })).toBeDisabled()
    cleanup()

    const { props, toolbar: again } = setup({ canUndo: true, canRedo: true })
    fireEvent.click(within(again).getByRole('button', { name: 'Annuler (Ctrl+Z)' }))
    fireEvent.click(within(again).getByRole('button', { name: 'Rétablir (Ctrl+Maj+Z)' }))
    expect(props.onUndo).toHaveBeenCalledTimes(1)
    expect(props.onRedo).toHaveBeenCalledTimes(1)
  })

  it('tells the straight-line mode by aria-pressed, and toggles it', () => {
    const { props, toolbar } = setup()
    const direct = within(toolbar).getByRole('button', { name: /^Ligne droite \(ou / })
    expect(direct).toHaveAttribute('aria-pressed', 'false')
    fireEvent.click(direct)
    expect(props.onDirectModeChange).toHaveBeenCalledWith(true)
    cleanup()

    const { toolbar: on } = setup({ directMode: true })
    expect(within(on).getByRole('button', { name: /^Ligne droite \(ou / })).toHaveAttribute(
      'aria-pressed',
      'true'
    )
  })

  it('announces no pressed state on a plain action', () => {
    const { toolbar } = setup({ canUndo: true })
    expect(within(toolbar).getByRole('button', { name: 'Annuler (Ctrl+Z)' })).not.toHaveAttribute(
      'aria-pressed'
    )
  })

  it('sums the trace up: distance, D+ and points, each in its own text', () => {
    const { toolbar } = setup({ pointCount: 3, stats: { distance: 12_400, ascend: 180 } })
    expect(within(toolbar).getByText('12.4 km', { exact: true })).toBeInTheDocument()
    expect(within(toolbar).getByText('+180 m', { exact: true })).toBeInTheDocument()
    expect(within(toolbar).getByText('3 points', { exact: true })).toBeInTheDocument()
  })

  it('shows the calculation and the routing error', () => {
    const { toolbar } = setup({ pointCount: 2, isLoading: true, error: 'Aucun itinéraire' })
    expect(within(toolbar).getByRole('status', { name: "Calcul de l'itinéraire..." })).toBeTruthy()
    expect(within(toolbar).getByText('Aucun itinéraire')).toBeInTheDocument()
  })

  it('has no summary before the first point', () => {
    const { toolbar } = setup()
    expect(within(toolbar).queryByText(/point/)).toBeNull()
    expect(within(toolbar).queryByText(/km$/)).toBeNull()
  })

  it('offers the import only when given one, and not during a calculation', () => {
    const { toolbar } = setup()
    expect(within(toolbar).queryByRole('button', { name: 'Importer un fichier GPX' })).toBeNull()
    cleanup()

    const onImport = vi.fn()
    const { toolbar: withImport } = setup({ onImport })
    fireEvent.click(within(withImport).getByRole('button', { name: 'Importer un fichier GPX' }))
    expect(onImport).toHaveBeenCalledTimes(1)
    cleanup()

    const { toolbar: busy } = setup({ onImport, isLoading: true })
    expect(within(busy).getByRole('button', { name: 'Importer un fichier GPX' })).toBeDisabled()
  })

  it('offers « Effacer » only when given one, last, and only with points to clear', () => {
    const { toolbar } = setup()
    expect(within(toolbar).queryByRole('button', { name: 'Effacer' })).toBeNull()
    cleanup()

    const onClear = vi.fn()
    const { toolbar: empty } = setup({ onClear })
    expect(within(empty).getByRole('button', { name: 'Effacer' })).toBeDisabled()
    expect(names(empty).at(-1)).toBe('Effacer')
    cleanup()

    const { toolbar: drawn } = setup({ onClear, pointCount: 2 })
    fireEvent.click(within(drawn).getByRole('button', { name: 'Effacer' }))
    expect(onClear).toHaveBeenCalledTimes(1)
  })

  it('toggles the settings and the help panels from its buttons, one at a time', async () => {
    const { toolbar } = setup()
    const profile = within(toolbar).getByRole('button', { name: 'Réglages du tracé : Vélo' })
    // The panel itself is docked by RoutePlanner: the button only tells it is open.
    fireEvent.click(profile)
    expect(profile).toHaveAttribute('aria-pressed', 'true')

    fireEvent.click(within(toolbar).getByRole('button', { name: 'Aide : gestes' }))
    expect(await screen.findByText('Gestes du planificateur')).toBeInTheDocument()
    expect(profile).toHaveAttribute('aria-pressed', 'false')
  })

  it('says on its button that a setting is adjusted', () => {
    const { toolbar } = setup({ settings: settingsOf({ tuning: { useHills: 0 } }) })
    expect(
      within(toolbar).getByRole('button', {
        name: 'Réglages du tracé : Vélo · ajusté',
      })
    ).toBeInTheDocument()
  })
})
