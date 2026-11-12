import { describe, it, expect } from 'vitest'
import { QueryClient } from '@tanstack/react-query'
import { invalidateTeamPublications } from './teamDashboardCache'

describe('invalidateTeamPublications (DL17)', () => {
  it('refreshes the home feed and the calendars too, not only the team list', () => {
    const queryClient = new QueryClient()
    const keys = [
      ['/api/teams/vc/publications', { page: 0 }],
      ['/api/publications', { page: 0, when: 'UPCOMING' }],
      ['/api/calendar/events', { from: 'a', to: 'b' }],
      ['/api/teams/vc/calendar/events', { from: 'a', to: 'b' }],
      ['/api/teams/vc/dashboard'],
      ['/api/teams/other/calendar/events', { from: 'a', to: 'b' }],
    ]
    for (const key of keys) queryClient.setQueryData(key, {})

    invalidateTeamPublications(queryClient, 'vc')

    const invalidated = (key: unknown[]) => queryClient.getQueryState(key)?.isInvalidated
    expect(keys.slice(0, 5).map(invalidated)).toEqual([true, true, true, true, true])
    expect(invalidated(keys[5])).toBe(false)
  })
})
