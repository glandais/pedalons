import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import { RouterProfile } from '@/api/dto'
import { RouterProfileSelector } from './RouterProfileSelector'

vi.mock('react-i18next', () => ({ useTranslation: () => ({ t: (k: string) => k }) }))
// The real panel lives in a map control; what is under test is its content.
vi.mock('@/components/map/MapPanel', () => ({
  MapPanel: ({ children }: { children: (close: () => void) => React.ReactNode }) => (
    <div>{children(() => {})}</div>
  ),
}))

function setup(profile: RouterProfile, tuning = {}) {
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
