import { describe, it, expect, afterEach } from 'vitest'
import { render, screen, cleanup } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import { CardTitle, CardHeadingOrder } from './Card'

afterEach(cleanup)

describe('CardTitle level (docs/LEDGER_*.md WEB-208)', () => {
  it('is an h3 by default and follows the nearest CardHeadingOrder', () => {
    render(
      <MantineProvider>
        <CardTitle>A</CardTitle>
        <CardHeadingOrder order={2}>
          <CardTitle>B</CardTitle>
          <CardHeadingOrder order={4}>
            <CardTitle>C</CardTitle>
          </CardHeadingOrder>
        </CardHeadingOrder>
      </MantineProvider>
    )
    expect(screen.getByRole('heading', { level: 3, name: 'A' })).toBeTruthy()
    expect(screen.getByRole('heading', { level: 2, name: 'B' })).toBeTruthy()
    expect(screen.getByRole('heading', { level: 4, name: 'C' })).toBeTruthy()
  })
})
