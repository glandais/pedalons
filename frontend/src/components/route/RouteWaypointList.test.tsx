import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { WaypointDto } from '@/api/dto'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

import { RouteWaypointList } from './RouteWaypointList'

function wp(name: string, distance?: number, type = 'WATER', description?: string): WaypointDto {
  return {
    name,
    type,
    description,
    distance,
    origin: 'AUTHOR',
    geometry: { type: 'Point', coordinates: [3, 45] },
  } as WaypointDto
}

function renderList(waypoints: WaypointDto[], selected: WaypointDto | null = null) {
  const onSelect = vi.fn()
  render(
    <MantineProvider>
      <RouteWaypointList waypoints={waypoints} selected={selected} onSelect={onSelect} />
    </MantineProvider>
  )
  return onSelect
}

describe('RouteWaypointList', () => {
  afterEach(cleanup)

  it('renders nothing for an empty list', () => {
    renderList([])
    expect(screen.queryByRole('region')).toBeNull()
    expect(screen.queryByRole('list')).toBeNull()
  })

  it('lists the points along the route, the off-track ones last', () => {
    renderList([wp('Loin'), wp('Fontaine', 12400), wp('Col', 3000, 'SUMMIT')])
    const rows = screen.getAllByRole('button').map((b) => b.textContent ?? '')
    expect(rows[0]).toContain('Col')
    expect(rows[1]).toContain('Fontaine')
    expect(rows[2]).toContain('Loin')
    expect(rows[2]).toContain('Hors tracé')
    expect(screen.getByText('Points du parcours (3)')).toBeTruthy()
  })

  it('shows the type when the name is empty, and the description', () => {
    renderList([wp('', 100, 'DANGER', 'Gravillons en descente')])
    expect(screen.getByText('Danger')).toBeTruthy()
    expect(screen.getByText('Gravillons en descente')).toBeTruthy()
  })

  it('selects a point on press and reports it as pressed', () => {
    const a = wp('A', 100)
    const b = wp('B', 200)
    const onSelect = renderList([a, b], b)
    fireEvent.click(screen.getByText('A'))
    expect(onSelect).toHaveBeenCalledWith(a)
    const pressed = screen.getAllByRole('button').map((x) => x.getAttribute('aria-pressed'))
    expect(pressed).toEqual(['false', 'true'])
  })

  it('folds a long list after ten rows', () => {
    renderList(Array.from({ length: 13 }, (_, i) => wp(`P${i}`, i * 100)))
    expect(screen.getAllByRole('listitem')).toHaveLength(10)
    fireEvent.click(screen.getByText('Voir les 3 autres points'))
    expect(screen.getAllByRole('listitem')).toHaveLength(13)
    fireEvent.click(screen.getByText('Réduire'))
    expect(screen.getAllByRole('listitem')).toHaveLength(10)
  })
})
