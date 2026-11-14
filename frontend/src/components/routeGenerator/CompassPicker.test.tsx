import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'

vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (key: string) => key, i18n: { language: 'fr' } }),
}))

import { CompassPicker } from './CompassPicker'

function renderPicker(props: Partial<React.ComponentProps<typeof CompassPicker>> = {}) {
  const onChange = vi.fn()
  render(
    <MantineProvider>
      <CompassPicker value={undefined} onChange={onChange} {...props} />
    </MantineProvider>
  )
  return onChange
}

describe('CompassPicker', () => {
  afterEach(cleanup)

  it('has eight bearings and « Peu importe », each with an accessible name', () => {
    renderPicker()
    const buttons = screen.getAllByRole('button')
    expect(buttons).toHaveLength(9)
    expect(screen.getByRole('button', { name: 'routeGenerator.bearing.NE' })).toBeTruthy()
    expect(screen.getByRole('button', { name: 'routeGenerator.bearing.any' })).toBeTruthy()
  })

  it('marks the chosen bearing pressed, « Peu importe » when none', () => {
    renderPicker({ value: 'SE' })
    expect(
      screen.getByRole('button', { name: 'routeGenerator.bearing.SE' }).getAttribute('aria-pressed')
    ).toBe('true')
    expect(
      screen
        .getByRole('button', { name: 'routeGenerator.bearing.any' })
        .getAttribute('aria-pressed')
    ).toBe('false')
    cleanup()
    renderPicker()
    expect(
      screen
        .getByRole('button', { name: 'routeGenerator.bearing.any' })
        .getAttribute('aria-pressed')
    ).toBe('true')
  })

  it('reports a click, and « Peu importe » as no bearing', () => {
    const onChange = renderPicker({ value: 'N' })
    fireEvent.click(screen.getByRole('button', { name: 'routeGenerator.bearing.W' }))
    expect(onChange).toHaveBeenLastCalledWith('W')
    fireEvent.click(screen.getByRole('button', { name: 'routeGenerator.bearing.any' }))
    expect(onChange).toHaveBeenLastCalledWith(undefined)
  })

  it('is disabled with its hint when the end is far, showing « Peu importe »', () => {
    renderPicker({ value: 'N', far: true })
    for (const button of screen.getAllByRole('button')) {
      expect((button as HTMLButtonElement).disabled).toBe(true)
    }
    expect(screen.getByText('routeGenerator.bearing.farHint')).toBeTruthy()
    expect(
      screen
        .getByRole('button', { name: 'routeGenerator.bearing.any' })
        .getAttribute('aria-pressed')
    ).toBe('true')
    expect(
      screen.getByRole('button', { name: 'routeGenerator.bearing.N' }).getAttribute('aria-pressed')
    ).toBe('false')
  })
})
