import { afterAll, afterEach, beforeAll, vi } from 'vitest'
import '@testing-library/jest-dom'
import { cleanup } from '@testing-library/react'

// With `isolate: false` a worker keeps its module cache and its globals from one file to the next.
// Re-evaluate the modules of src/ so none of them carries state (stores, singletons, injected
// transports) over from a previous file; packages outside src/ stay loaded once, which is where
// the speed comes from.
vi.resetModules()
// What a file started without waiting for must not outlive it, nor finish in the middle of its
// tests. A dynamic import still in flight when a file ends (a lazy page, a prefetch, a catalogue)
// would land after the reset above and cache a module of src/ wired to the previous file's mocks,
// which the next file then imports as is: its own `vi.mock` never applies. And the global i18n
// instance loads its catalogue by such an import: raw keys or wording in the first tests,
// depending on how warm the worker is. A fixed wait only made both rare (one run in ten still
// failed with 40 ms, 2026-11-25), so ask the module runner itself: Vitest's worker state lists the
// imports being resolved and the modules being evaluated. Internal, hence the fallback to a short
// wait if a later version renames it.
type RunnerState = {
  resolvingModules?: Set<string>
  evaluatedModules?: { idToModuleMap: Map<string, { promise?: unknown; evaluated?: boolean }> }
}
function importsInFlight(): boolean {
  const state = (globalThis as { __vitest_worker__?: RunnerState }).__vitest_worker__
  if (state?.resolvingModules?.size) return true
  for (const node of state?.evaluatedModules?.idToModuleMap.values() ?? []) {
    if (node.promise && !node.evaluated) return true
  }
  return false
}
const nextTask = () => new Promise((resolve) => setTimeout(resolve, 0))
async function importsSettled() {
  // A file that fakes the timers at its top level: the tasks below would never come.
  if (vi.isFakeTimers()) return
  const state = (globalThis as { __vitest_worker__?: RunnerState }).__vitest_worker__
  if (!state?.resolvingModules) {
    await new Promise((resolve) => setTimeout(resolve, 40))
    return
  }
  // Quiet over three tasks in a row, so that what an import's callback starts in turn is seen
  // too; and never more than two seconds, for an import that will not come back.
  const deadline = Date.now() + 2000
  for (let quiet = 0; quiet < 3 && Date.now() < deadline;) {
    await nextTask()
    quiet = importsInFlight() ? 0 : quiet + 1
  }
}
beforeAll(importsSettled)
afterAll(async () => {
  vi.useRealTimers()
  await importsSettled()
  vi.resetModules()
})
// Testing Library registers its automatic cleanup only the first time it is imported in a worker,
// so the later files would not unmount what they render: do it by hand.
//
// `screen` is bound to the <body> element that existed when Testing Library was first loaded in the
// worker, so a test that swaps the body for another one (`document.body.replaceWith`) leaves every
// later file querying an empty, detached element: put the original back after each test.
const shared = globalThis as { __testBody?: HTMLElement }
if (typeof document !== 'undefined') {
  // The global i18n instance follows <html lang>, which its own init rewrites to the detected
  // language: drop it so a file starts like the first one in a worker, whatever ran before.
  document.documentElement.removeAttribute('lang')
  if (!shared.__testBody || shared.__testBody.ownerDocument !== document) {
    shared.__testBody = document.body
  }
}
afterEach(() => {
  cleanup()
  if (typeof document !== 'undefined' && shared.__testBody && document.body !== shared.__testBody) {
    document.body = shared.__testBody
  }
})

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

  // jsdom has no font loading API: Mantine's autosize textarea listens to it
  if (!('fonts' in document)) {
    Object.defineProperty(document, 'fonts', {
      value: { addEventListener: vi.fn(), removeEventListener: vi.fn(), ready: Promise.resolve() },
    })
  }

  // jsdom has no layout, hence no scrollIntoView: Mantine's Combobox calls it on the selected
  // option from a timer, after the test that opened it may already be over.
  Element.prototype.scrollIntoView ??= () => {}

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
