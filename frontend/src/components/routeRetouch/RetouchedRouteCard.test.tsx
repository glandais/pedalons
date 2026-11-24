import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { RetouchedRouteDto } from '@/api/dto'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

import { RetouchedRouteCard } from './RetouchedRouteCard'

const candidate = (over: Partial<RetouchedRouteDto> = {}): RetouchedRouteDto => ({
  polyline: '_p~iF~ps|U',
  distanceM: 70_000,
  ascentM: 900,
  descentM: 900,
  kind: 'SHORTEN',
  keptShare: 0.85,
  unmatchedM: 0,
  changed: {
    fromM: 30_000,
    toM: 42_400,
    newM: 30_000,
    startIndex: 10,
    endIndex: 20,
    teamShare: 0.5,
    unpavedShare: 0,
    crossings: 0,
  },
  bounds: { minLat: 45, minLon: 5, maxLat: 45.1, maxLon: 5.1 },
  ...over,
})

function renderCard(c: RetouchedRouteDto, over: { originalAscentM?: number } = {}) {
  const onSelect = vi.fn()
  render(
    <MantineProvider>
      <RetouchedRouteCard
        candidate={c}
        index={0}
        originalDistanceM={82_400}
        originalAscentM={'originalAscentM' in over ? over.originalAscentM : 1000}
        selected
        onHover={vi.fn()}
        onSelect={onSelect}
      />
    </MantineProvider>
  )
  return { onSelect }
}

afterEach(cleanup)

describe('RetouchedRouteCard', () => {
  it('shows distance and ascent before and after', () => {
    renderCard(candidate())
    expect(screen.getByText(/82,4.*km\s→\s70.*km/)).toBeTruthy()
    expect(screen.getByText(/D\+ 1\s?000.*m\s→\s900.*m/)).toBeTruthy()
  })

  it('shows a dash for a missing ascent', () => {
    renderCard(candidate({ ascentM: undefined }), { originalAscentM: undefined })
    expect(screen.getByText(/D\+ –\s→\s–/)).toBeTruthy()
  })

  it('says what was replaced by what, and how much is kept', () => {
    renderCard(candidate())
    expect(screen.getByText(/12,4.*km remplacés par 30.*km/)).toBeTruthy()
    expect(screen.getByText(/85.*% du parcours gardé/)).toBeTruthy()
  })

  it('says a truncation stops at the new finish', () => {
    renderCard(candidate({ kind: 'TRUNCATE', changed: { ...candidate().changed, newM: 0 } }))
    expect(screen.getByText("Le parcours s'arrête à la nouvelle arrivée")).toBeTruthy()
    expect(screen.queryByText(/remplacés par/)).toBeNull()
  })

  it.each([
    ['BEST', 'Le moins de changement'],
    ['KEEP_ALL', "Tout le parcours, puis l'arrivée"],
    ['NEAREST', "Quitter au plus près de l'arrivée"],
  ] as const)('names the variant %s', (variant, label) => {
    renderCard(candidate({ kind: 'MOVE_END', variant }))
    expect(screen.getByText(label)).toBeTruthy()
  })

  it('has no variant line without a variant', () => {
    renderCard(candidate())
    expect(screen.queryByText('Le moins de changement')).toBeNull()
  })

  it('adds a discreet note from 500 m kept without a check', () => {
    renderCard(candidate({ unmatchedM: 800 }))
    expect(screen.getByText(/n'a pas pu être vérifiée/)).toBeTruthy()
    cleanup()
    renderCard(candidate({ unmatchedM: 500 }))
    expect(screen.queryByText(/n'a pas pu être vérifiée/)).toBeNull()
  })

  it('selects on click', () => {
    const { onSelect } = renderCard(candidate())
    fireEvent.click(screen.getByTestId('retouched-route-card'))
    expect(onSelect).toHaveBeenCalledWith(0)
  })
})
