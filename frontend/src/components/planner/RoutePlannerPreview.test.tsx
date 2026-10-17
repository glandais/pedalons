import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'

vi.mock('@/hooks/useUnits', () => ({
  useUnits: () => ({
    distance: (m: number) => `${m / 1000} km`,
    elevation: (m: number) => `${m} m`,
  }),
}))

import { RoutePlannerPreview } from './RoutePlannerPreview'

describe('RoutePlannerPreview', () => {
  afterEach(cleanup)

  it('shows the empty state and invites to draw', () => {
    const onOpen = vi.fn()
    render(
      <MantineProvider>
        <RoutePlannerPreview
          routeGeoJson={null}
          pointCount={0}
          distance={0}
          ascend={0}
          onOpen={onOpen}
        />
      </MantineProvider>
    )
    expect(screen.queryByTestId('planner-silhouette')).toBeNull()
    fireEvent.click(screen.getByRole('button', { name: 'planner.draw' }))
    expect(onOpen).toHaveBeenCalledTimes(1)
  })

  it('draws the silhouette with the figures, and opens from the button', () => {
    const onOpen = vi.fn()
    render(
      <MantineProvider>
        <RoutePlannerPreview
          routeGeoJson={{
            type: 'LineString',
            coordinates: [
              [2, 45],
              [2.1, 45.1],
              [2.2, 45.05],
            ],
          }}
          pointCount={3}
          distance={12300}
          ascend={450}
          onOpen={onOpen}
        />
      </MantineProvider>
    )
    expect(screen.getByTestId('planner-silhouette')).toBeTruthy()
    expect(screen.getByText('12.3 km')).toBeTruthy()
    expect(screen.getByText('450 m')).toBeTruthy()
    expect(screen.getByRole('button', { name: 'planner.edit' })).toBeTruthy()
    fireEvent.click(screen.getByRole('button'))
    expect(onOpen).toHaveBeenCalledTimes(1)
  })
})
