import { describe, expect, it } from 'vitest'
import { visibilityIsException } from './visibilityException'

// docs/LEDGER_*.md WEB-167, R1: the visibility is said only when it differs from the team's.
describe('visibilityIsException', () => {
  it('is silent on the team’s own visibility', () => {
    expect(visibilityIsException('TEAM', { visibility: 'TEAM' })).toBe(false)
    expect(visibilityIsException('PUBLIC', { visibility: 'PUBLIC' })).toBe(false)
  })

  it('speaks when the content leaves its team’s circle, or keeps to it in a public team', () => {
    expect(visibilityIsException('PUBLIC', { visibility: 'TEAM' })).toBe(true)
    expect(visibilityIsException('PUBLIC_UNLISTED', { visibility: 'TEAM' })).toBe(true)
    expect(visibilityIsException('TEAM', { visibility: 'PUBLIC' })).toBe(true)
  })

  it('says nothing without both', () => {
    expect(visibilityIsException(undefined, { visibility: 'TEAM' })).toBe(false)
    expect(visibilityIsException('PUBLIC', undefined)).toBe(false)
  })
})
