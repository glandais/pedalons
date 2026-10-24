import { describe, it, expect } from 'vitest'
import type { TeamRole } from '@/api/dto'
import { teamAccess } from './teamAccess'

const team = (role?: TeamRole | null) => ({ role })

describe('teamAccess (docs/LEDGER_*.md API-137)', () => {
  it('a visitor holds nothing', () => {
    expect(teamAccess(team(undefined), false)).toEqual({
      isMember: false,
      isOrganizer: false,
      isAdmin: false,
    })
    expect(teamAccess(undefined, false).isMember).toBe(false)
  })

  it('a member is a member, nothing more', () => {
    expect(teamAccess(team('MEMBER'), false)).toEqual({
      isMember: true,
      isOrganizer: false,
      isAdmin: false,
    })
  })

  it('an organizer organizes, an administrator does both', () => {
    expect(teamAccess(team('ORGANIZER'), false)).toEqual({
      isMember: true,
      isOrganizer: true,
      isAdmin: false,
    })
    expect(teamAccess(team('ADMIN'), false)).toEqual({
      isMember: true,
      isOrganizer: true,
      isAdmin: true,
    })
  })

  it('a platform admin who is not a member holds the rights, not the membership', () => {
    expect(teamAccess(team(null), true)).toEqual({
      isMember: false,
      isOrganizer: true,
      isAdmin: true,
    })
  })

  it('a platform admin who is a member keeps the membership and gains the rights', () => {
    expect(teamAccess(team('MEMBER'), true)).toEqual({
      isMember: true,
      isOrganizer: true,
      isAdmin: true,
    })
  })
})
