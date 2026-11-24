import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen, within } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import { RouterEngine, RouterProfile } from '@/api/dto'
import type { EngineChoice } from '@/lib/routerEngine'
import { MapPanelContext, useMapPanelState } from '@/components/map/mapPanelState'
import { RouteSettingsButton, RouteSettingsContent, RouteSettingsDock } from './RouteSettings'
import type { RouteSettingsModel } from './routeSettingsModel'

vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (k: string) => k }),
}))
vi.mock('@/hooks/useUnits', () => ({
  useUnits: () => ({ distance: (m: number) => `${(m / 1000).toFixed(1)} km` }),
}))
// jsdom has no pointer media queries: the tests say which pointer they run under.
let coarse = false
vi.mock('@/hooks/useResponsive', () => ({
  useMediaMatch: () => coarse,
}))
beforeEach(() => {
  coarse = false
})

const choice = (over: Partial<EngineChoice> = {}): EngineChoice => ({
  value: RouterEngine.STADIA,
  onChange: vi.fn(),
  team: true,
  ...over,
})

function modelOf(over: Partial<RouteSettingsModel> = {}): RouteSettingsModel {
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

function setup(over: Partial<RouteSettingsModel> = {}) {
  const settings = modelOf(over)
  render(
    <MantineProvider>
      <RouteSettingsContent settings={settings} />
    </MantineProvider>
  )
  return settings
}

/** One open-panel state per map, as RoutePlannerField provides it. */
function Panels({ children }: { children: React.ReactNode }) {
  return <MapPanelContext.Provider value={useMapPanelState()}>{children}</MapPanelContext.Provider>
}

function setupButton(trigger: 'toolbar' | 'bar', over: Partial<RouteSettingsModel> = {}) {
  const settings = modelOf(over)
  render(
    <MantineProvider>
      <Panels>
        <RouteSettingsButton settings={settings} trigger={trigger} />
        <RouteSettingsDock settings={settings} inset={10} />
      </Panels>
    </MantineProvider>
  )
  return settings
}

const triggerName = () =>
  screen
    .getAllByRole('button')
    .map((b) => b.getAttribute('aria-label'))
    .find((n) => n?.startsWith('planner.settings.button'))

const group = (name: string) => screen.getByRole('radiogroup', { name })
const checkedOf = (name: string) =>
  within(group(name))
    .getAllByRole('radio')
    .find((r) => (r as HTMLInputElement).checked || r.getAttribute('aria-checked') === 'true')

describe('RouteSettings: practice', () => {
  afterEach(cleanup)

  it('offers the six practices as radios, the current one checked, and reports a click', () => {
    const settings = setup({ profile: RouterProfile.GRAVEL })
    const radios = within(group('planner.profile.label')).getAllByRole('radio')
    expect(radios).toHaveLength(6)
    expect(checkedOf('planner.profile.label')).toBe(
      within(group('planner.profile.label')).getByRole('radio', { name: 'planner.profile.GRAVEL' })
    )
    fireEvent.click(
      within(group('planner.profile.label')).getByRole('radio', { name: 'planner.profile.MTB' })
    )
    expect(settings.onProfileChange).toHaveBeenCalledWith(RouterProfile.MTB)
  })
})

describe('RouteSettings: circulation and hills', () => {
  afterEach(cleanup)

  it('reads a stored value at the nearest step (0.75 gives Direct)', () => {
    setup({ tuning: { useRoads: 0.75 } })
    const checked = checkedOf('planner.tuning.traffic.label') as HTMLInputElement
    expect(checked.value).toBe('direct')
    expect(checkedOf('planner.tuning.hills.label')).toBeTruthy()
  })

  it('commits the numeric value of a picked step', () => {
    const settings = setup()
    fireEvent.click(
      within(group('planner.tuning.traffic.label')).getByLabelText('planner.tuning.traffic.direct')
    )
    expect(settings.onTuningChange).toHaveBeenCalledWith('useRoads', 1)
    fireEvent.click(
      within(group('planner.tuning.hills.label')).getByLabelText('planner.tuning.hills.avoid')
    )
    expect(settings.onTuningChange).toHaveBeenCalledWith('useHills', 0)
  })

  it('says « adjusted » only when a step differs from the practice default', () => {
    setup({ profile: RouterProfile.BIKE })
    expect(screen.queryByText('planner.tuning.adjusted')).toBeNull()
    expect(screen.queryByText('planner.tuning.reset')).toBeNull()
    cleanup()
    setup({ profile: RouterProfile.BIKE, tuning: { useRoads: 1 } })
    expect(screen.getByText('planner.tuning.adjusted')).toBeTruthy()
    expect(screen.getByText('planner.tuning.reset')).toBeTruthy()
  })

  it('FASTBIKE at Direct is its default: nothing adjusted', () => {
    setup({ profile: RouterProfile.FASTBIKE, tuning: { useRoads: 1 } })
    expect(screen.queryByText('planner.tuning.adjusted')).toBeNull()
    cleanup()
    setupButton('toolbar', { profile: RouterProfile.FASTBIKE, tuning: { useRoads: 1 } })
    expect(triggerName()).toBe('planner.settings.button')
  })

  it('offers the way back and reports it', () => {
    const settings = setup({ tuning: { useHills: 0 } })
    fireEvent.click(screen.getByText('planner.tuning.reset'))
    expect(settings.onTuningReset).toHaveBeenCalledTimes(1)
  })
})

describe('RouteSettings: calculation', () => {
  afterEach(cleanup)

  it('with the team engine: no Côtes, a line saying so, and « switch to standard »', () => {
    const engineChoice = choice({ value: RouterEngine.PEDALONS })
    setup({ profile: RouterProfile.GRAVEL, engineChoice })
    expect(screen.queryByRole('radiogroup', { name: 'planner.tuning.hills.label' })).toBeNull()
    expect(screen.getByText('planner.tuning.hillsIgnored')).toBeTruthy()
    expect(screen.getByRole('radiogroup', { name: 'planner.tuning.traffic.label' })).toBeTruthy()
    fireEvent.click(screen.getByText('planner.tuning.useStandard'))
    expect(engineChoice.onChange).toHaveBeenCalledWith('STADIA')
  })

  it('a hills value hidden under the team engine lights nothing', () => {
    setup({
      profile: RouterProfile.FASTBIKE,
      tuning: { useHills: 1 },
      engineChoice: choice({ value: RouterEngine.PEDALONS }),
    })
    expect(screen.queryByText('planner.tuning.adjusted')).toBeNull()
    expect(screen.queryByText('planner.tuning.reset')).toBeNull()
    cleanup()
    setup({
      profile: RouterProfile.FASTBIKE,
      tuning: { useHills: 1 },
      engineChoice: choice({ value: RouterEngine.STADIA }),
    })
    expect(screen.getByText('planner.tuning.adjusted')).toBeTruthy()
  })

  it('offers the two positions, words the second one for a planner without a team', () => {
    const engineChoice = choice({ team: false, value: RouterEngine.PEDALONS })
    setup({ engineChoice })
    const calc = group('planner.engine.label')
    expect(within(calc).getByLabelText('planner.engine.shared')).toBeTruthy()
    expect(within(calc).getByLabelText('planner.engine.standard')).toBeTruthy()
    expect(screen.getByText('planner.engine.help.shared')).toBeTruthy()
    fireEvent.click(within(calc).getByLabelText('planner.engine.standard'))
    expect(engineChoice.onChange).toHaveBeenCalledWith(RouterEngine.STADIA)
  })

  it('describes the standard calculation, and the « ? » opens the long text', () => {
    setup({ engineChoice: choice({ value: RouterEngine.STADIA }) })
    expect(screen.getByText('planner.engine.help.standard')).toBeTruthy()
    expect(screen.queryByText('planner.engine.more.team')).toBeNull()
    const help = screen.getByRole('button', { name: 'planner.engine.helpLabel' })
    expect(help.getAttribute('aria-expanded')).toBe('false')
    fireEvent.click(help)
    expect(help.getAttribute('aria-expanded')).toBe('true')
    expect(screen.getByText('planner.engine.more.team')).toBeTruthy()
  })

  it('says so where there is no choice of calculation', () => {
    setup({ profile: RouterProfile.BIKE })
    expect(screen.getByText('planner.engine.standardOnly')).toBeTruthy()
    expect(screen.queryByRole('radiogroup', { name: 'planner.engine.label' })).toBeNull()
    expect(screen.getByRole('radiogroup', { name: 'planner.tuning.traffic.label' })).toBeTruthy()
    expect(screen.getByRole('radiogroup', { name: 'planner.tuning.hills.label' })).toBeTruthy()
  })

  it.each([RouterProfile.RUN_HIKE, RouterProfile.MOTORCYCLE])(
    '%s: neither calculation nor circulation, and the reason',
    (profile) => {
      setup({ profile })
      expect(screen.getByText('planner.engine.standardOnlyNoTuning')).toBeTruthy()
      expect(screen.queryByRole('radiogroup', { name: 'planner.engine.label' })).toBeNull()
      expect(screen.queryByRole('radiogroup', { name: 'planner.tuning.traffic.label' })).toBeNull()
      expect(screen.queryByRole('radiogroup', { name: 'planner.tuning.hills.label' })).toBeNull()
    }
  )
})

describe('RouteSettings: footer', () => {
  afterEach(cleanup)

  const scope = { legs: 3, distance: 42_000, keeps: false }

  it('has no button below two points, only the note', () => {
    setup({ pointCount: 1, recalcScope: scope })
    expect(screen.getByText('planner.recalc.note')).toBeTruthy()
    expect(screen.queryByRole('button', { name: 'planner.recalc.button' })).toBeNull()
  })

  it('recalculates on click and is disabled while a calculation runs', () => {
    const settings = setup({ pointCount: 4, recalcScope: scope })
    const button = screen.getByRole('button', { name: 'planner.recalc.button' })
    expect(screen.getByText('planner.recalc.noteKept')).toBeTruthy()
    expect(screen.queryByText('planner.recalc.keeps')).toBeNull()
    fireEvent.click(button)
    expect(settings.onRecalculate).toHaveBeenCalledTimes(1)
    cleanup()
    setup({ pointCount: 4, recalcScope: scope, isLoading: true })
    expect(
      (screen.getByRole('button', { name: 'planner.recalc.button' }) as HTMLButtonElement).disabled
    ).toBe(true)
  })

  it('says what stays as it is when the route has straight or imported pieces', () => {
    setup({ pointCount: 4, recalcScope: { ...scope, keeps: true } })
    expect(screen.getByText('planner.recalc.keeps')).toBeTruthy()
  })

  it('says there is nothing to recalculate without a routed leg', () => {
    setup({ pointCount: 3, recalcScope: { legs: 0, distance: 0, keeps: true } })
    expect(screen.getByText('planner.recalc.nothing')).toBeTruthy()
    expect(screen.queryByRole('button', { name: 'planner.recalc.button' })).toBeNull()
  })

  it('after a recalculation, announces it and hides the button', () => {
    setup({ pointCount: 4, recalcScope: scope, recalculated: true })
    expect(screen.getByRole('status').textContent).toBe('planner.recalc.done')
    expect(screen.queryByRole('button', { name: 'planner.recalc.button' })).toBeNull()
  })
})

describe('RouteSettingsContent', () => {
  afterEach(cleanup)

  it('renders on its own, for the docked panel', () => {
    render(
      <MantineProvider>
        <RouteSettingsContent settings={modelOf()} />
      </MantineProvider>
    )
    expect(screen.getByRole('radiogroup', { name: 'planner.profile.label' })).toBeTruthy()
  })
})

describe('RouteSettingsButton', () => {
  afterEach(cleanup)

  it('toolbar: shows the practice in words, named « Réglages du tracé : … »', () => {
    setupButton('toolbar', { profile: RouterProfile.GRAVEL })
    const button = screen.getByRole('button', { name: 'planner.settings.button' })
    expect(button.textContent).toContain('planner.profile.GRAVEL')
    expect(button.textContent).not.toContain('planner.settings.adjusted')
    cleanup()
    setupButton('toolbar', { profile: RouterProfile.GRAVEL, tuning: { useRoads: 1 } })
    const adjusted = screen.getByRole('button', { name: 'planner.settings.buttonAdjusted' })
    expect(adjusted.textContent).toContain('planner.settings.adjusted')
  })

  it('bar: the same words under the icon, aria-pressed follows the open state', () => {
    setupButton('bar', { profile: RouterProfile.GRAVEL, tuning: { useRoads: 1 } })
    const button = screen.getByRole('button', { name: 'planner.settings.buttonAdjusted' })
    expect(button.textContent).toBe('planner.profile.GRAVEL planner.settings.adjusted')
    expect(button.getAttribute('aria-pressed')).toBe('false')
    fireEvent.click(button)
    expect(button.getAttribute('aria-pressed')).toBe('true')
    fireEvent.click(button)
    expect(button.getAttribute('aria-pressed')).toBe('false')
  })

  it('on a mouse the button opens no sheet: the dock is the panel', () => {
    setupButton('toolbar')
    fireEvent.click(screen.getByRole('button', { name: 'planner.settings.button' }))
    expect(screen.queryByRole('dialog')).toBeNull()
    expect(screen.getByRole('region', { name: 'planner.settings.title' })).toBeTruthy()
  })

  it('on a finger it opens a bottom sheet, and choosing a practice leaves it open', async () => {
    coarse = true
    const settings = setupButton('bar')
    fireEvent.click(screen.getByRole('button', { name: 'planner.settings.button' }))
    const dialog = await screen.findByRole('dialog', { name: 'planner.settings.title' })
    const practices = within(dialog).getByRole('radiogroup', { name: 'planner.profile.label' })
    fireEvent.click(within(practices).getByRole('radio', { name: 'planner.profile.MTB' }))
    expect(settings.onProfileChange).toHaveBeenCalledWith(RouterProfile.MTB)
    expect(screen.getByRole('dialog', { name: 'planner.settings.title' })).toBeTruthy()
  })
})

describe('RouteSettingsDock', () => {
  afterEach(cleanup)

  const open = () =>
    fireEvent.click(screen.getByRole('button', { name: 'planner.settings.button' }))

  it('renders nothing while closed', () => {
    setupButton('toolbar')
    expect(screen.queryByRole('region')).toBeNull()
    expect(screen.queryByRole('radiogroup', { name: 'planner.profile.label' })).toBeNull()
  })

  it('opens as a section named by its title; choosing a practice keeps it open', () => {
    const settings = setupButton('toolbar')
    open()
    const dock = screen.getByRole('region', { name: 'planner.settings.title' })
    fireEvent.click(
      within(within(dock).getByRole('radiogroup', { name: 'planner.profile.label' })).getByRole(
        'radio',
        { name: 'planner.profile.MTB' }
      )
    )
    expect(settings.onProfileChange).toHaveBeenCalledWith(RouterProfile.MTB)
    expect(screen.getByRole('region', { name: 'planner.settings.title' })).toBeTruthy()
  })

  it('closes with its X, with its button and with Escape, not with a press outside', () => {
    setupButton('toolbar')
    open()
    fireEvent.pointerDown(document.body)
    fireEvent.click(document.body)
    expect(screen.getByRole('region')).toBeTruthy()

    fireEvent.click(screen.getByRole('button', { name: 'actions.close' }))
    expect(screen.queryByRole('region')).toBeNull()
    // The X hands the focus back to the toolbar's button
    expect(document.activeElement).toBe(
      screen.getByRole('button', { name: 'planner.settings.button' })
    )

    open()
    fireEvent.keyDown(window, { key: 'Escape' })
    expect(screen.queryByRole('region')).toBeNull()

    open()
    open()
    expect(screen.queryByRole('region')).toBeNull()
  })

  it('pins the recalculation footer under the body', () => {
    setupButton('toolbar', {
      pointCount: 3,
      recalcScope: { legs: 2, distance: 5000, keeps: false },
    })
    open()
    expect(screen.getByRole('button', { name: 'planner.recalc.button' })).toBeTruthy()
  })
})
