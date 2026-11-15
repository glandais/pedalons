// Vitest 5 reordered `Assertion<R, T>`, and @testing-library/jest-dom 7 still augments the old
// `Assertion<T>`: its `/vitest` entry no longer type-checks and the matchers vanish. Vitest's
// documented extension point, `Matchers<R, T>`, carries them instead. Drop this file once
// jest-dom ships typings for Vitest 5.
/* oxlint-disable typescript/no-empty-object-type -- an augmentation is an empty interface */
import type { TestingLibraryMatchers } from '@testing-library/jest-dom/matchers'

declare module 'vitest' {
  interface Matchers<
    R extends void | Promise<void> = void | Promise<void>,
    T = unknown,
  > extends TestingLibraryMatchers<unknown, R> {}
}
