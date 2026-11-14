import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

import { FoundPlaceOverlay } from './FoundPlaceOverlay'

const PLACE = { lat: 45.1, lng: 5.2, label: 'Grenoble' }

function renderOverlay(endElsewhere: boolean) {
  const onPick = vi.fn()
  render(
    <MantineProvider>
      <FoundPlaceOverlay place={PLACE} endElsewhere={endElsewhere} onPick={onPick} />
    </MantineProvider>
  )
  return onPick
}

describe('FoundPlaceOverlay (WEB-179)', () => {
  afterEach(cleanup)

  it('offers only the start with an end at the start', () => {
    const onPick = renderOverlay(false)
    expect(screen.queryByRole('button', { name: 'Arriver ici' })).toBeNull()
    fireEvent.click(screen.getByRole('button', { name: "Partir d'ici" }))
    expect(onPick).toHaveBeenCalledWith('start', { lat: 45.1, lng: 5.2 })
  })

  it('sets the end through the search result when the end is « Ailleurs »', () => {
    const onPick = renderOverlay(true)
    fireEvent.click(screen.getByRole('button', { name: 'Arriver ici' }))
    expect(onPick).toHaveBeenCalledWith('end', { lat: 45.1, lng: 5.2 })
  })
})
