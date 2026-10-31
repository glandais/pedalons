import { describe, it, expect, afterEach } from 'vitest'
import { render, screen, fireEvent, cleanup, act } from '@testing-library/react'
import { createMemoryRouter, RouterProvider, useLocation } from 'react-router-dom'
import { z } from 'zod'
import { useUrlFilters } from './useUrlFilters'

const schema = z.object({
  sort: z.string().default('date'),
  maxPrice: z.coerce.number().optional(),
  page: z.coerce.number().default(0),
})

function Filters() {
  const { filters, setFilters, replaceFilters } = useUrlFilters({ schema })
  const { search } = useLocation()
  return (
    <div>
      <span data-testid="search">{search}</span>
      <span data-testid="sort">{filters.sort}</span>
      <button data-testid="set-sort" onClick={() => setFilters({ sort: 'price' })} />
      <button data-testid="set-price" onClick={() => setFilters({ maxPrice: 100 })} />
      <button data-testid="set-page" onClick={() => setFilters({ page: 2 })} />
      <button data-testid="set-replace" onClick={() => replaceFilters({ sort: 'title' })} />
    </div>
  )
}

/** A router whose loader stays pending until `release()`, like a route awaiting its prefetch. */
function renderWithSlowLoader(initialPath = '/list') {
  const pending: Array<() => void> = []
  const router = createMemoryRouter(
    [
      {
        path: '/list',
        element: <Filters />,
        loader: () => new Promise<null>((resolve) => pending.push(() => resolve(null))),
      },
    ],
    { initialEntries: [initialPath], hydrationData: { loaderData: { 0: null } } }
  )
  render(<RouterProvider router={router} />)
  const release = async () => {
    await act(async () => {
      while (pending.length) pending.shift()!()
      await new Promise((r) => setTimeout(r, 0))
    })
  }
  return { router, release }
}

const searchOf = () => new URLSearchParams(screen.getByTestId('search').textContent ?? '')

describe('useUrlFilters', () => {
  afterEach(cleanup)

  it('keeps both changes when a second one comes before the location caught up', async () => {
    const { release } = renderWithSlowLoader()

    fireEvent.click(screen.getByTestId('set-sort'))
    fireEvent.click(screen.getByTestId('set-price'))
    // Neither navigation has landed yet.
    expect(searchOf().toString()).toBe('')
    await release()

    const params = searchOf()
    expect(params.get('sort')).toBe('price')
    expect(params.get('maxPrice')).toBe('100')
    expect(screen.getByTestId('sort').textContent).toBe('price')
  })

  it('still resets the page on a filter change following a page change', async () => {
    const { release } = renderWithSlowLoader('/list?sort=price')

    fireEvent.click(screen.getByTestId('set-page'))
    fireEvent.click(screen.getByTestId('set-price'))
    await release()

    const params = searchOf()
    expect(params.get('sort')).toBe('price')
    expect(params.get('maxPrice')).toBe('100')
    expect(params.get('page')).toBeNull()
  })

  it('builds on a replace that has not landed yet', async () => {
    const { release } = renderWithSlowLoader('/list?maxPrice=50')

    fireEvent.click(screen.getByTestId('set-replace'))
    fireEvent.click(screen.getByTestId('set-page'))
    await release()

    const params = searchOf()
    expect(params.get('sort')).toBe('title')
    expect(params.get('maxPrice')).toBeNull()
    expect(params.get('page')).toBe('2')
  })

  it('follows a location it did not ask for instead of its own stale writes', async () => {
    const { router, release } = renderWithSlowLoader()

    fireEvent.click(screen.getByTestId('set-sort'))
    await release()
    expect(searchOf().get('sort')).toBe('price')

    // An external navigation (a link, back/forward) to another query string.
    await act(async () => {
      void router.navigate('/list?maxPrice=20')
    })
    await release()
    expect(searchOf().get('maxPrice')).toBe('20')

    fireEvent.click(screen.getByTestId('set-page'))
    await release()
    const params = searchOf()
    expect(params.get('maxPrice')).toBe('20')
    expect(params.get('sort')).toBeNull()
    expect(params.get('page')).toBe('2')
  })

  it("keeps the query string's other parameters, another hook's on the same page", async () => {
    const { release } = renderWithSlowLoader('/list?color=wind&maxPrice=50')

    fireEvent.click(screen.getByTestId('set-sort'))
    await release()
    expect(searchOf().get('color')).toBe('wind')
    expect(searchOf().get('maxPrice')).toBe('50')

    fireEvent.click(screen.getByTestId('set-replace'))
    await release()
    expect(searchOf().get('color')).toBe('wind')
    expect(searchOf().get('maxPrice')).toBeNull()
  })
})
