import { afterEach, describe, expect, it, vi } from 'vitest'
import { act, renderHook, waitFor } from '@testing-library/react'
import { useHistoryOverlay } from './useHistoryOverlay'

afterEach(() => {
  vi.restoreAllMocks()
  window.history.replaceState(null, '', '/')
})

describe('useHistoryOverlay', () => {
  it('pushes an entry with the same URL and the router state copied', () => {
    window.history.replaceState({ usr: { a: 1 }, key: 'k1', idx: 3 }, '', '/routes/new')
    const { result } = renderHook(() => useHistoryOverlay())

    act(() => result.current.open())

    expect(result.current.opened).toBe(true)
    expect(window.location.pathname).toBe('/routes/new')
    expect(window.history.state).toMatchObject({ usr: { a: 1 }, key: 'k1', idx: 3 })
  })

  it('is closed by the back button and reopened by forward', async () => {
    const { result } = renderHook(() => useHistoryOverlay())
    act(() => result.current.open())

    act(() => window.history.back())
    await waitFor(() => expect(result.current.opened).toBe(false))

    act(() => window.history.forward())
    await waitFor(() => expect(result.current.opened).toBe(true))
  })

  it('close() consumes its own entry', async () => {
    const { result } = renderHook(() => useHistoryOverlay())
    const push = vi.spyOn(window.history, 'pushState')
    act(() => result.current.open())
    expect(push).toHaveBeenCalledTimes(1)

    act(() => result.current.close())
    await waitFor(() => expect(result.current.opened).toBe(false))
    expect(window.history.state?.plannerFullscreen).toBeUndefined()
  })

  it('open() twice pushes a single entry', () => {
    const { result } = renderHook(() => useHistoryOverlay())
    const push = vi.spyOn(window.history, 'pushState')
    act(() => result.current.open())
    act(() => result.current.open())
    expect(push).toHaveBeenCalledTimes(1)
  })

  it('close() does not go back when the current entry is not its own', () => {
    const { result } = renderHook(() => useHistoryOverlay())
    act(() => result.current.open())
    // Navigated elsewhere while open (no popstate in this test): the entry is no longer ours.
    window.history.replaceState({ key: 'other' }, '')
    const back = vi.spyOn(window.history, 'back')
    act(() => result.current.close())
    expect(result.current.opened).toBe(false)
    expect(back).not.toHaveBeenCalled()
  })

  it('goes back on unmount while open on its own entry', async () => {
    const { result, unmount } = renderHook(() => useHistoryOverlay())
    act(() => result.current.open())
    expect(window.history.state?.plannerFullscreen).toBeDefined()

    unmount()
    await waitFor(() => expect(window.history.state?.plannerFullscreen).toBeUndefined())
  })

  it('does nothing on unmount when the overlay is closed', () => {
    const { unmount } = renderHook(() => useHistoryOverlay())
    const back = vi.spyOn(window.history, 'back')
    unmount()
    expect(back).not.toHaveBeenCalled()
  })

  it('a marker left by an earlier page load opens nothing', async () => {
    const first = renderHook(() => useHistoryOverlay())
    act(() => first.result.current.open())
    first.unmount()
    await waitFor(() => expect(window.history.state?.plannerFullscreen).toBeUndefined())

    const second = renderHook(() => useHistoryOverlay())
    act(() => window.history.forward())
    await new Promise((r) => setTimeout(r, 20))
    expect(second.result.current.opened).toBe(false)
  })
})
