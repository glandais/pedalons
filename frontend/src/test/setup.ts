import { vi } from 'vitest'
import '@testing-library/jest-dom'

// The window mocks only where there is a window: server.js's modules (server/*.test.js) are tested
// in the node environment.
if (typeof window !== 'undefined') {
  // Mock matchMedia
  Object.defineProperty(window, 'matchMedia', {
    writable: true,
    value: vi.fn().mockImplementation((query: string) => ({
      matches: false,
      media: query,
      onchange: null,
      addListener: vi.fn(),
      removeListener: vi.fn(),
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
      dispatchEvent: vi.fn(),
    })),
  })

  // Mock localStorage
  const localStorageMock = {
    getItem: vi.fn(),
    setItem: vi.fn(),
    removeItem: vi.fn(),
    clear: vi.fn(),
  }
  Object.defineProperty(window, 'localStorage', {
    value: localStorageMock,
  })
}

// Mock ResizeObserver — a class, since Mantine calls it with `new` (SegmentedControl's floating
// indicator) and an arrow-function `vi.fn` implementation is not a constructor.
class ResizeObserverMock {
  observe = vi.fn()
  unobserve = vi.fn()
  disconnect = vi.fn()
}
;(globalThis as typeof globalThis & { ResizeObserver: unknown }).ResizeObserver = ResizeObserverMock

// Mock IntersectionObserver
;(globalThis as typeof globalThis & { IntersectionObserver: unknown }).IntersectionObserver = vi
  .fn()
  .mockImplementation(() => ({
    observe: vi.fn(),
    unobserve: vi.fn(),
    disconnect: vi.fn(),
  }))
