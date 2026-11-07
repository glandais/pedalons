import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import { weatherLeg } from '@/test/weatherFixtures'

vi.mock('react-i18next', async () => {
  const { frenchT } = await import('@/test/frenchT')
  return { useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }) }
})

import { WindMapLegend } from './WindMapLegend'

afterEach(cleanup)

const legend = (leg = weatherLeg(undefined), subject?: 'group' | 'track') =>
  render(
    <MantineProvider>
      <WindMapLegend leg={leg} subject={subject} />
    </MantineProvider>
  )

describe('WindMapLegend default speed', () => {
  it('speaks of the group by default', () => {
    legend()
    expect(screen.getByTestId('wind-map-legend').textContent).toMatch(/groupe/)
  })

  it('speaks of the track for a GPX preview, without the word group', () => {
    legend(weatherLeg(undefined), 'track')
    const text = screen.getByTestId('wind-map-legend').textContent ?? ''
    expect(text).toMatch(/vitesse par défaut/)
    expect(text).not.toMatch(/groupe/)
  })

  it('says nothing about the speed once it was given', () => {
    legend(weatherLeg(undefined, { speedIsDefault: false, averageSpeed: 30 }), 'track')
    expect(screen.getByTestId('wind-map-legend').textContent).not.toMatch(/par défaut/)
  })
})
