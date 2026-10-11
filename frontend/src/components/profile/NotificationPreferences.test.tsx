import { describe, it, expect, vi, afterEach, beforeEach } from 'vitest'
import { render, screen, cleanup, within } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MantineProvider } from '@mantine/core'
import type { NotificationPreferencesDto } from '@/api/dto'

vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))

// Keys, not wording: the assertions read which rows and columns are shown.
vi.mock('react-i18next', () => ({
  useTranslation: () => ({
    t: (key: string, options?: Record<string, string>) =>
      options && 'type' in options ? `${options.type}/${options.channel}` : key,
    i18n: { language: 'fr' },
  }),
}))

const state = vi.hoisted(() => ({ data: undefined as NotificationPreferencesDto | undefined }))

vi.mock('@/api/endpoints/notifications/notifications', () => ({
  getGetMyNotificationPreferencesQueryKey: () => ['/api/notifications/preferences'],
  useGetMyNotificationPreferences: () => ({ data: state.data, isLoading: false }),
  useUpdateMyNotificationPreferences: () => ({ mutate: vi.fn(), isPending: false }),
}))
// The browser part of « Sur cet appareil » is not under test here.
vi.mock('./WebPushSettings', () => ({ WebPushSettings: () => <div data-testid="web-push" /> }))

import { NotificationPreferences } from './NotificationPreferences'

function renderPreferences() {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>
          <NotificationPreferences />
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

function preferences(overrides: Partial<NotificationPreferencesDto>): NotificationPreferencesDto {
  return { channels: [], preferences: [], emailDigest: false, teams: [], ...overrides }
}

describe('NotificationPreferences', () => {
  beforeEach(() => {
    state.data = undefined
  })
  afterEach(cleanup)

  it('groups the types by family, and leaves out a type the server lists no cell for', () => {
    state.data = preferences({
      channels: ['EMAIL', 'PUSH'],
      preferences: [
        { type: 'RIDE_PUBLISHED', channel: 'EMAIL', enabled: true, enabledByDefault: true },
        { type: 'RIDE_PUBLISHED', channel: 'PUSH', enabled: false, enabledByDefault: true },
        { type: 'COMMENT_REPLY', channel: 'PUSH', enabled: true, enabledByDefault: true },
      ],
    })
    renderPreferences()

    const table = screen.getByRole('table')
    const families = within(table)
      .getAllByRole('columnheader')
      .map((cell) => cell.textContent)
    expect(families).toEqual([
      'notifications.preferences.columnType',
      'notifications.channel.EMAIL',
      'notifications.channel.PUSH',
      'notifications.family.rides',
      'notifications.family.posts',
    ])
    expect(
      screen.getByRole('checkbox', {
        name: 'notifications.typeLabel.RIDE_PUBLISHED/notifications.channel.EMAIL',
      })
    ).toHaveProperty('checked', true)
    expect(
      screen.getByRole('checkbox', {
        name: 'notifications.typeLabel.RIDE_PUBLISHED/notifications.channel.PUSH',
      })
    ).toHaveProperty('checked', false)
    // No cell, no checkbox: the e-mail column of a reply is empty.
    expect(screen.getAllByRole('checkbox')).toHaveLength(3)
    expect(screen.queryByText('notifications.typeLabel.TRIP_PUBLISHED')).toBeNull()
    expect(screen.getByTestId('web-push')).toBeTruthy()
    expect(screen.getByText('notifications.preferences.digest.label')).toBeTruthy()
  })

  it('without e-mail on the server, shows neither its column nor the daily digest', () => {
    state.data = preferences({
      channels: ['PUSH'],
      emailDigest: true,
      preferences: [
        { type: 'RIDE_PUBLISHED', channel: 'PUSH', enabled: true, enabledByDefault: true },
      ],
    })
    renderPreferences()

    expect(screen.queryByText('notifications.channel.EMAIL')).toBeNull()
    expect(screen.queryByText('notifications.preferences.digest.label')).toBeNull()
  })

  it('with no channel, keeps the team mutes alone', () => {
    state.data = preferences({
      teams: [{ teamSlug: 'a', teamName: 'Équipe A', muted: false }],
    })
    renderPreferences()

    expect(screen.queryByRole('table')).toBeNull()
    expect(screen.queryByTestId('web-push')).toBeNull()
    expect(
      screen.getByRole('heading', { name: 'notifications.preferences.teams.title' })
    ).toBeTruthy()
  })

  it('says there is nothing to set when there is neither a channel nor a team', () => {
    state.data = preferences({})
    renderPreferences()

    expect(screen.getByText('notifications.preferences.nothingToSet')).toBeTruthy()
  })
})
