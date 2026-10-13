import { describe, it, expect } from 'vitest'
import { getGetRideParticipantsQueryKey } from '@/api/endpoints/rides/rides'
import { hashKey } from '@tanstack/react-query'
import { readUrlFilters } from '@/hooks/useUrlFilters'
import {
  PARTICIPANTS_PAGE_SIZE,
  groupParticipantFiltersAlias,
  groupParticipantFiltersSchema,
  groupParticipantsParams,
  participantsPageParams,
} from './groupParticipantFilters'

const fromUrl = (query: string) =>
  readUrlFilters(new URLSearchParams(query), {
    schema: groupParticipantFiltersSchema,
    alias: groupParticipantFiltersAlias,
  })

/** The key the group page's list reads: what ParticipantList builds from the committed search. */
const listKey = (search: string | undefined, page: number) =>
  hashKey(
    getGetRideParticipantsQueryKey('team', 'ride', {
      ...participantsPageParams(search, page),
      groupId: 'g1',
    })
  )

const prefetchKey = (query: string) =>
  hashKey(
    getGetRideParticipantsQueryKey('team', 'ride', groupParticipantsParams('g1', fromUrl(query)))
  )

describe('group participants params', () => {
  it('builds the same query key for the prefetch and the list', () => {
    expect(prefetchKey('')).toBe(listKey(undefined, 0))
    expect(prefetchKey('q=')).toBe(listKey('', 0))
    expect(prefetchKey('q=ana&p=1')).toBe(listKey('ana', 1))
  })

  it('ignores a size in the URL: the list always reads its own page size', () => {
    expect(groupParticipantsParams('g1', fromUrl('size=20')).size).toBe(PARTICIPANTS_PAGE_SIZE)
    expect(prefetchKey('size=20')).toBe(listKey(undefined, 0))
  })
})
