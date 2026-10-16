import { describe, expect, it } from 'vitest'
import type { TFunction } from 'i18next'
import type { ProfileSummaryDto, UserDto } from '@/api/dto'
import { profileStatusLines } from './profileStatus'

// Keys and their parameters, not wording: what is asserted is which line is chosen.
const t = ((key: string, options?: Record<string, unknown>) =>
  options
    ? `${key}(${Object.entries(options)
        .map(([name, value]) => `${name}=${String(value)}`)
        .join(',')})`
    : key) as unknown as TFunction

function user(overrides: Partial<UserDto> = {}): UserDto {
  return {
    id: 'u1',
    email: 'camille@example.org',
    displayName: 'Camille',
    contactableByMembers: true,
    emailVerified: true,
    ...overrides,
  }
}

function summary(overrides: Partial<ProfileSummaryDto> = {}): ProfileSummaryDto {
  return {
    participations: { upcomingCount: 3, pastCount: 12, next: [] },
    teams: [],
    passkeyCount: 0,
    pairedDevices: [],
    blockedUserCount: 0,
    notifications: { channels: [], enabledChannels: [], emailDigest: false },
    ...overrides,
  }
}

describe('profileStatusLines', () => {
  it('sums up the display preferences, the timezone only when chosen', () => {
    expect(profileStatusLines(t, user(), undefined, 'fr').preferences).toBe(
      'profile.status.unit.METRIC · profile.status.theme.SYSTEM · Français'
    )
    expect(
      profileStatusLines(
        t,
        user({ unitSystem: 'IMPERIAL', timezone: 'Europe/Paris', theme: 'DARK' }),
        undefined,
        'en'
      ).preferences
    ).toBe('profile.status.unit.IMPERIAL · Europe/Paris · profile.status.theme.DARK · English')
  })

  it('shows no line for what the summary carries until it lands', () => {
    const lines = profileStatusLines(t, user(), undefined, 'fr')
    expect(lines.rides).toBeUndefined()
    expect(lines.notifications).toBeUndefined()
    expect(lines.security).toBeUndefined()
    expect(lines.devices).toBeUndefined()
  })

  it('says where notifications go, the digest only with e-mail', () => {
    const line = (notifications: ProfileSummaryDto['notifications']) =>
      profileStatusLines(t, user(), summary({ notifications }), 'fr').notifications
    expect(line({ channels: [], enabledChannels: [], emailDigest: false })).toBe(
      'profile.status.notifications.inAppOnly'
    )
    expect(
      line({ channels: ['EMAIL', 'PUSH'], enabledChannels: ['EMAIL', 'PUSH'], emailDigest: true })
    ).toBe('profile.status.notifications.emailAndPush · profile.status.notifications.digest')
    expect(
      line({ channels: ['EMAIL', 'PUSH'], enabledChannels: ['PUSH'], emailDigest: true })
    ).toBe('profile.status.notifications.push')
  })

  it('counts paired devices per kind, after the connected services', () => {
    const lines = profileStatusLines(
      t,
      user({
        connectedServices: [
          {
            serviceType: 'GARMIN',
            displayName: 'Garmin Connect',
            connectedAt: '2026-01-01T00:00:00Z',
            autoSync: false,
            autoSyncState: 'OFF',
            autoSyncRouteCount: 0,
          },
        ],
      }),
      summary({
        pairedDevices: [
          { id: 'd1', type: 'KAROO', pairedAt: '2026-01-01T00:00:00Z' },
          { id: 'd2', type: 'KAROO', pairedAt: '2026-01-02T00:00:00Z' },
        ],
      }),
      'fr'
    )
    expect(lines.devices).toBe(
      'profile.status.serviceConnected(service=gps.services.garmin) · ' +
        'profile.status.devicePaired(count=2,device=gps.devices.types.karoo)'
    )
    expect(profileStatusLines(t, user(), summary(), 'fr').devices).toBe('profile.status.noDevice')
  })

  it('says which connected service receives the routes on its own', () => {
    const lines = profileStatusLines(
      t,
      user({
        connectedServices: [
          {
            serviceType: 'WAHOO',
            displayName: 'Wahoo',
            connectedAt: '2026-01-01T00:00:00Z',
            autoSync: true,
            autoSyncState: 'UP_TO_DATE',
            autoSyncRouteCount: 2,
          },
          {
            serviceType: 'GARMIN',
            displayName: 'Garmin Connect',
            connectedAt: '2026-01-01T00:00:00Z',
            autoSync: false,
            autoSyncState: 'OFF',
            autoSyncRouteCount: 0,
          },
        ],
      }),
      summary(),
      'fr'
    )
    expect(lines.devices).toBe(
      'profile.status.serviceAutoSync(service=gps.services.wahoo) · ' +
        'profile.status.serviceConnected(service=gps.services.garmin)'
    )
  })

  it('names the blocked count only when someone is blocked', () => {
    expect(profileStatusLines(t, user(), summary(), 'fr').privacy).toBe(
      'profile.status.contactable'
    )
    expect(
      profileStatusLines(
        t,
        user({ contactableByMembers: false }),
        summary({ blockedUserCount: 2 }),
        'fr'
      ).privacy
    ).toBe('profile.status.notContactable · profile.status.blocked(count=2)')
  })

  it('counts passkeys and teams, with their own empty wording', () => {
    const empty = profileStatusLines(t, user(), summary(), 'fr')
    expect(empty.security).toBe('profile.status.noPasskey')
    expect(empty.teams).toBe('profile.status.noTeam')
    const some = profileStatusLines(
      t,
      user(),
      summary({ passkeyCount: 2, teams: [{ slug: 'a', name: 'A', role: 'ADMIN' }] }),
      'fr'
    )
    expect(some.security).toBe('profile.status.passkeys(count=2)')
    expect(some.teams).toBe('profile.status.teams(count=1)')
    expect(some.rides).toBe('profile.status.upcoming(count=3)')
  })
})
