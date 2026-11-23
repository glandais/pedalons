import { describe, it, expect } from 'vitest'
import type { TeamDashboardDto, TeamDetailDto } from '@/api/dto'
import { firstStepsReads } from './teamHomeData'

/**
 * Which extra queries « Premières étapes » needs (docs/LEDGER_*.md WEB-195): the page and the
 * route's prefetch both derive them from the dashboard, so they must agree — and stay at none for
 * anyone who does not administer the team, or once the team already says enough.
 */
function dashboard(team: Partial<TeamDetailDto>, admin: boolean): TeamDashboardDto {
  return {
    team: {
      addMemberAllowed: true,
      enableRides: true,
      enableRoutes: true,
      memberCount: 1,
      upcomingRideCount: 0,
      routeCount: 0,
      ...team,
    } as TeamDetailDto,
    admin: admin ? ({} as TeamDashboardDto['admin']) : undefined,
  } as TeamDashboardDto
}

describe('firstStepsReads', () => {
  it('a new team, for its administrator: a pending invitation and any ride are asked', () => {
    expect(firstStepsReads(dashboard({}, true))).toEqual({
      admin: true,
      invitations: true,
      rides: true,
    })
  })

  it('nothing for someone who does not administer the team, nor before the dashboard', () => {
    expect(firstStepsReads(dashboard({}, false))).toEqual({
      admin: false,
      invitations: false,
      rides: false,
    })
    expect(firstStepsReads(undefined).admin).toBe(false)
  })

  it('nothing the team already answers: a second member, an upcoming ride, no rides module', () => {
    expect(firstStepsReads(dashboard({ memberCount: 2, upcomingRideCount: 1 }, true))).toEqual({
      admin: true,
      invitations: false,
      rides: false,
    })
    expect(
      firstStepsReads(dashboard({ enableRides: false, addMemberAllowed: false }, true))
    ).toEqual({ admin: true, invitations: false, rides: false })
  })
})
