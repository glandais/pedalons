import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'

vi.mock('react-i18next', () => ({
  useTranslation: () => ({
    t: (key: string, o?: Record<string, unknown>) => (o ? `${key} ${JSON.stringify(o)}` : key),
    i18n: { language: 'fr' },
  }),
}))
vi.mock('@/hooks/useUnits', () => ({
  useUnits: () => ({ elevation: (m: number) => `${m} m` }),
}))
const chartProps = vi.hoisted(() => ({ last: null as null | Record<string, unknown> }))
vi.mock('../route/ElevationChart', () => ({
  ElevationChart: (props: Record<string, unknown>) => {
    chartProps.last = props
    return <div data-testid="chart" />
  },
}))

import { PlannerElevationStrip } from './PlannerElevationStrip'
import type { PlannerMappable, Route } from '@/lib/planner'

const route = { points: [], dist: 1000, ascend: 10 } as unknown as Route
const mappable = {
  surface: ['unpaved', 'paved', 'paved'],
  dashed: [false, false, false],
} as unknown as PlannerMappable
const stats = { paved: 600, unpaved: 300, unknown: 100, offNetwork: 0, total: 1000 }

function strip(extra: Partial<Parameters<typeof PlannerElevationStrip>[0]> = {}) {
  return render(
    <MantineProvider>
      <PlannerElevationStrip
        route={route}
        mappable={mappable}
        hoveredIndex={-1}
        onHoverIndex={() => {}}
        height={100}
        surfaceStats={stats}
        {...extra}
      />
    </MantineProvider>
  )
}

describe('PlannerElevationStrip surface mode', () => {
  afterEach(cleanup)

  it('offers the grade / surface switch and reports the choice', () => {
    const onColorByChange = vi.fn()
    strip({ colorBy: 'grade', onColorByChange })
    expect(screen.queryByTestId('planner-surface-legend')).toBeNull()
    fireEvent.click(screen.getByText('planner.colorBy.surface'))
    expect(onColorByChange).toHaveBeenCalledWith('surface')
  })

  it('shows the legend and the summary in surface mode, and colours the chart by surface', () => {
    strip({ colorBy: 'surface', onColorByChange: () => {} })
    expect(screen.getByTestId('planner-surface-legend')).toBeTruthy()
    for (const k of ['paved', 'unpaved', 'unknown', 'offNetwork']) {
      expect(screen.getByText(`planner.surface.${k}`)).toBeTruthy()
    }
    expect(screen.getByTestId('planner-surface-summary').textContent).toContain(
      '{"unpaved":30,"unknown":10}'
    )
    expect(chartProps.last?.colorBy).toBe('surface')
    const surfaceAt = chartProps.last?.surfaceAt as (i: number) => string
    expect(surfaceAt(0)).not.toBe(surfaceAt(1))
  })

  it('has no switch when nobody listens to it', () => {
    strip({})
    expect(screen.queryByTestId('planner-color-by')).toBeNull()
  })
})
