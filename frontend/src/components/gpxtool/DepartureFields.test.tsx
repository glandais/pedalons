import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import { speedFromDisplay, speedToDisplay } from '@/utils/unitFormat'

vi.mock('react-i18next', async () => {
  const { frenchT } = await import('@/test/frenchT')
  return { useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }) }
})

const units = vi.hoisted(() => ({ system: 'METRIC' as 'METRIC' | 'IMPERIAL' }))
vi.mock('@/hooks/useUnits', async () => {
  const unitFormat = await import('@/utils/unitFormat')
  return {
    useUnits: () => ({
      config: unitFormat.getUnitConfig(units.system),
      speedToDisplay: (kmh: number | undefined) => unitFormat.speedToDisplay(kmh, units.system),
      speedFromDisplay: (v: string | number | undefined) =>
        unitFormat.speedFromDisplay(v, units.system),
    }),
  }
})
vi.mock('@/utils/dateFormat', () => ({
  useEffectiveTimezone: () => ({
    timezone: 'Europe/Paris',
    isGuessed: false,
    isPlaceholder: false,
  }),
}))
// The picker has its own tests: a stand-in that shows what it was given and can set or clear.
vi.mock('@/components/common/WallDateTimePicker', () => ({
  WallDateTimePicker: (props: {
    label: string
    description?: string
    value?: string
    zone: string
    maxDate?: string
    onChange: (v: string | undefined) => void
  }) => (
    <div>
      <span>{props.label}</span>
      <span data-testid="description">{props.description}</span>
      <span data-testid="zone">{props.zone}</span>
      <span data-testid="max">{props.maxDate}</span>
      <button onClick={() => props.onChange('2026-11-08T09:30:00')}>pick</button>
      <button onClick={() => props.onChange(undefined)}>clear</button>
    </div>
  ),
}))

import { DepartureFields } from './DepartureFields'
import type { DepartureValue } from './departure'

afterEach(() => {
  cleanup()
  units.system = 'METRIC'
})

function renderFields(value: DepartureValue = {}, extra: Record<string, string> = {}) {
  const onChange = vi.fn()
  render(
    <MantineProvider>
      <DepartureFields value={value} onChange={onChange} {...extra} />
    </MantineProvider>
  )
  return onChange
}

describe('DepartureFields', () => {
  it('says the time is the one of the start of the track, not the device', () => {
    renderFields()
    expect(screen.getByTestId('description').textContent).toContain(
      'Heure locale au point de départ du tracé, pas celle de votre appareil'
    )
  })

  it('reads the date in the zone of the track when it is known, the reader zone otherwise', () => {
    renderFields({}, { zone: 'Asia/Tokyo' })
    expect(screen.getByTestId('zone').textContent).toBe('Asia/Tokyo')
    cleanup()
    renderFields()
    expect(screen.getByTestId('zone').textContent).toBe('Europe/Paris')
  })

  it('bounds the date at the purge, 30 days after the creation', () => {
    renderFields({}, { createdAt: '2026-10-15T08:00:00Z', zone: 'Europe/Paris' })
    expect(screen.getByTestId('max').textContent).toBe('2026-11-14T10:00:00')
  })

  it('hands the picked date over without a zone, and the clearing as undefined', () => {
    const onChange = renderFields({ averageSpeed: 20 })
    fireEvent.click(screen.getByText('pick'))
    expect(onChange).toHaveBeenLastCalledWith({
      averageSpeed: 20,
      departure: '2026-11-08T09:30:00',
    })
    fireEvent.click(screen.getByText('clear'))
    expect(onChange).toHaveBeenLastCalledWith({ averageSpeed: 20, departure: undefined })
  })

  it('types the speed in km/h', () => {
    const onChange = renderFields({ departure: '2026-11-08T09:30:00' })
    fireEvent.change(screen.getByRole('textbox', { name: /Vitesse moyenne/ }), {
      target: { value: '27.5' },
    })
    expect(onChange).toHaveBeenLastCalledWith({
      departure: '2026-11-08T09:30:00',
      averageSpeed: 27.5,
    })
  })

  it('shows and types the speed in miles, and hands it over in km/h', () => {
    units.system = 'IMPERIAL'
    const onChange = renderFields({ averageSpeed: 40 })
    const input = screen.getByRole('textbox', { name: /Vitesse moyenne/ }) as HTMLInputElement
    expect(input.value).toBe('24.85 mph')
    fireEvent.change(input, { target: { value: '20' } })
    const sent = onChange.mock.calls.at(-1)?.[0].averageSpeed as number
    expect(sent).toBeCloseTo(32.19, 1)
  })

  it('does not call back on its own: an untouched value stays as it is, in miles too', () => {
    units.system = 'IMPERIAL'
    const onChange = renderFields({ averageSpeed: 40 })
    expect(onChange).not.toHaveBeenCalled()
  })

  it('keeps the bounds of the field, once back in km/h, inside 10 to 60 km/h', () => {
    for (const system of ['METRIC', 'IMPERIAL'] as const) {
      const min = Math.ceil(speedToDisplay(10, system) ?? 10)
      const max = Math.floor(speedToDisplay(60, system) ?? 60)
      expect(speedFromDisplay(min, system)).toBeGreaterThanOrEqual(10)
      expect(speedFromDisplay(max, system)).toBeLessThanOrEqual(60)
    }
  })
})
