import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { WaypointDto } from '@/api/dto'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

import { WaypointDetails } from './WaypointDetails'

function renderDetails(over: Partial<WaypointDto>) {
  render(
    <MantineProvider>
      <WaypointDetails
        waypoint={
          {
            name: 'Café du Port',
            type: 'CAFE',
            origin: 'AUTHOR',
            geometry: { type: 'Point', coordinates: [3, 45] },
            ...over,
          } as WaypointDto
        }
      />
    </MantineProvider>
  )
}

describe('WaypointDetails', () => {
  afterEach(cleanup)

  it('says what the point is, what it is called, and where it is', () => {
    renderDetails({ description: 'Ouvert le dimanche', distance: 12400 })
    expect(screen.getByText('Café, pause')).toBeTruthy()
    expect(screen.getByText('Café du Port')).toBeTruthy()
    expect(screen.getByText('Ouvert le dimanche')).toBeTruthy()
    expect(screen.getByText(/^À .*du départ$/)).toBeTruthy()
  })

  it('says « Hors tracé » for a point away from the route', () => {
    renderDetails({ name: '', distance: undefined })
    expect(screen.getByText('Hors tracé')).toBeTruthy()
    expect(screen.queryByText(/du départ/)).toBeNull()
  })
})
