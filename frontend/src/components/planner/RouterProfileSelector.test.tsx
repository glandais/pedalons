import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import { RouterEngine, RouterProfile } from '@/api/dto'
import type { EngineChoice } from '@/lib/routerEngine'
import { RouterProfileSelector } from './RouterProfileSelector'

vi.mock('react-i18next', () => ({ useTranslation: () => ({ t: (k: string) => k }) }))
// The real panel lives in a map control; what is under test is its content.
vi.mock('@/components/map/MapPanel', () => ({
  MapPanel: ({ children }: { children: (close: () => void) => React.ReactNode }) => (
    <div>{children(() => {})}</div>
  ),
}))

function setup(profile: RouterProfile, tuning = {}, engineChoice?: EngineChoice) {
  const onTuningChange = vi.fn()
  const onTuningReset = vi.fn()
  render(
    <MantineProvider>
      <RouterProfileSelector
        currentProfile={profile}
        onProfileChange={vi.fn()}
        tuning={tuning}
        onTuningChange={onTuningChange}
        onTuningReset={onTuningReset}
        engineChoice={engineChoice}
      />
    </MantineProvider>
  )
  return { onTuningChange, onTuningReset }
}

describe('RouterProfileSelector tuning', () => {
  afterEach(cleanup)

  it('shows both sliders for a bicycle profile', () => {
    setup(RouterProfile.GRAVEL)
    expect(screen.getByRole('slider', { name: 'planner.tuning.hills.label' })).toBeTruthy()
    expect(screen.getByRole('slider', { name: 'planner.tuning.roads.label' })).toBeTruthy()
  })

  it.each([RouterProfile.RUN_HIKE, RouterProfile.MOTORCYCLE])('hides them for %s', (profile) => {
    setup(profile)
    expect(screen.queryAllByRole('slider')).toHaveLength(0)
  })

  it('offers the way back only once a setting differs', () => {
    setup(RouterProfile.BIKE)
    expect(screen.queryByText('planner.tuning.reset')).toBeNull()
    cleanup()
    const { onTuningReset } = setup(RouterProfile.BIKE, { useHills: 0 })
    fireEvent.click(screen.getByText('planner.tuning.reset'))
    expect(onTuningReset).toHaveBeenCalledTimes(1)
  })

  it('commits a keyboard change', () => {
    const { onTuningChange } = setup(RouterProfile.BIKE)
    const hills = screen.getByRole('slider', { name: 'planner.tuning.hills.label' })
    fireEvent.keyDown(hills, { key: 'Home' })
    expect(onTuningChange).toHaveBeenCalledWith('useHills', 0)
  })

  it('announces words, not numbers', () => {
    setup(RouterProfile.BIKE)
    const hills = screen.getByRole('slider', { name: 'planner.tuning.hills.label' })
    expect(hills.getAttribute('aria-valuetext')).toBe('planner.tuning.hills.1')
  })
})

describe('RouterProfileSelector engine choice', () => {
  afterEach(cleanup)

  const choice = (over: Partial<EngineChoice> = {}): EngineChoice => ({
    value: RouterEngine.PEDALONS,
    onChange: vi.fn(),
    team: true,
    ...over,
  })

  it('is absent when the engine is not on offer', () => {
    setup(RouterProfile.BIKE)
    expect(screen.queryByText('planner.engine.label')).toBeNull()
    expect(screen.queryByRole('radiogroup')).toBeNull()
  })

  it('offers two labelled positions, the team one first, above the sliders', () => {
    setup(RouterProfile.GRAVEL, {}, choice({ value: RouterEngine.STADIA }))
    const group = screen.getByRole('radiogroup', { name: 'planner.engine.label' })
    const radios = screen.getAllByRole('radio')
    expect(radios.map((r) => r.getAttribute('value'))).toEqual([
      RouterEngine.PEDALONS,
      RouterEngine.STADIA,
    ])
    expect(screen.getByRole('radio', { name: 'planner.engine.standard' })).toBeTruthy()
    expect(screen.getByRole('radio', { name: 'planner.engine.team' })).toBeTruthy()
    const sliders = screen.getAllByRole('slider')
    expect(sliders).toHaveLength(2)
    expect(
      group.compareDocumentPosition(sliders[0]) & Node.DOCUMENT_POSITION_FOLLOWING
    ).toBeTruthy()
    expect(screen.queryByText('planner.engine.help.team')).toBeNull()
  })

  it('words the second position for a planner without a team', () => {
    setup(RouterProfile.BIKE, {}, choice({ team: false, value: RouterEngine.PEDALONS }))
    expect(screen.getByRole('radio', { name: 'planner.engine.shared' })).toBeTruthy()
    expect(screen.getByText('planner.engine.help.shared')).toBeTruthy()
  })

  it('says what the team engine does once chosen, and reports a change', () => {
    const onChange = vi.fn()
    setup(RouterProfile.BIKE, {}, choice({ onChange, value: RouterEngine.STADIA }))
    fireEvent.click(screen.getByRole('radio', { name: 'planner.engine.team' }))
    expect(onChange).toHaveBeenCalledWith(RouterEngine.PEDALONS)
    cleanup()
    setup(RouterProfile.BIKE, {}, choice({ value: RouterEngine.PEDALONS }))
    expect(screen.getByText('planner.engine.help.team')).toBeTruthy()
  })
})
