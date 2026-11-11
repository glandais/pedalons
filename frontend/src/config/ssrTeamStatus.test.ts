import { describe, expect, it } from 'vitest'
import { QueryClient } from '@tanstack/react-query'
import type { RideDto, TeamDetailDto, TeamPublicationDto } from '@/api/dto'
import { getGetRideQueryKey } from '@/api/endpoints/rides/rides'
import { ApiClientError } from '@/lib/apiError'
import { readEntity, teamPageStatus } from './ssrTeamStatus'

const closedTeam: TeamPublicationDto = {
  id: 't1',
  slug: 'np',
  name: 'N Peloton',
  visibility: 'TEAM',
  accessible: false,
}
const notFound = new ApiClientError(404, { code: 'TEAM_NOT_FOUND' } as never)

/**
 * The status a crawler sees on a team-scoped page (entry-server, docs/LEDGER_*.md WEB-166): the
 * 404 of a closed team must no longer cover an entity read successfully by link, and a private
 * team opened directly still answers 404.
 */
describe('teamPageStatus', () => {
  it("serves a private team's public ride, read by link, as a page that is there", () => {
    expect(
      teamPageStatus({
        teamSlug: 'np',
        team: undefined,
        // Even had something asked for the team: the entity was read, its page is there.
        teamError: notFound,
        entity: { team: closedTeam, error: null },
        sessionKnown: true,
      })
    ).toEqual({ kind: 'ok' })
  })

  it('still answers 404 for a private team opened directly', () => {
    expect(
      teamPageStatus({
        teamSlug: 'np',
        team: undefined,
        teamError: notFound,
        entity: undefined,
        sessionKnown: true,
      })
    ).toEqual({ kind: 'notFound' })
  })

  it("answers 404 for a private team's members-only ride: the entity is refused, the team never asked", () => {
    expect(
      teamPageStatus({
        teamSlug: 'np',
        team: undefined,
        teamError: undefined,
        entity: { team: undefined, error: new ApiClientError(404, { code: 'NOT_FOUND' } as never) },
        sessionKnown: true,
      })
    ).toEqual({ kind: 'notFound' })
  })

  it('leaves the answer to the client while the session is unknown (WEB-39)', () => {
    expect(
      teamPageStatus({
        teamSlug: 'np',
        team: undefined,
        teamError: notFound,
        entity: undefined,
        sessionKnown: false,
      })
    ).toEqual({ kind: 'ok' })
  })

  it('moves a team reached through a former slug', () => {
    expect(
      teamPageStatus({
        teamSlug: 'ancien',
        team: { slug: 'np' } as TeamDetailDto,
        teamError: undefined,
        entity: undefined,
        sessionKnown: true,
      })
    ).toEqual({ kind: 'moved', slug: 'np' })
  })

  it('treats a failure that is not a refusal as a page to retry, not a 404', () => {
    expect(
      teamPageStatus({
        teamSlug: 'np',
        team: undefined,
        teamError: new ApiClientError(500, { code: 'INTERNAL_ERROR' } as never),
        entity: undefined,
        sessionKnown: true,
      })
    ).toEqual({ kind: 'ok' })
  })
})

describe('readEntity', () => {
  it("reads the page's entity off the cache: its team summary, or why it failed", () => {
    const queryClient = new QueryClient()
    queryClient.setQueryData(getGetRideQueryKey('np', 'sortie'), {
      slug: 'sortie',
      team: closedTeam,
    } as unknown as RideDto)
    expect(readEntity(queryClient, { teamSlug: 'np', rideSlug: 'sortie' })?.team).toEqual(
      closedTeam
    )
    // A group's page and a ride's map read the ride too.
    expect(
      readEntity(queryClient, { teamSlug: 'np', rideSlug: 'sortie', groupId: 'g1' })?.team
    ).toEqual(closedTeam)
    // A page never read: no team, no error either.
    expect(readEntity(queryClient, { teamSlug: 'np', pageSlug: 'charte' })).toEqual({
      team: undefined,
      error: undefined,
    })
  })

  it('is undefined on a page of the team itself', () => {
    expect(readEntity(new QueryClient(), { teamSlug: 'np' })).toBeUndefined()
  })
})
