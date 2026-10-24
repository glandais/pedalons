import { describe, it, expect, vi } from 'vitest'
import { renderHook } from '@testing-library/react'
import {
  IconArticle,
  IconCalendarEvent,
  IconFileText,
  IconLayoutDashboard,
  IconRoute,
  IconTag,
} from '@tabler/icons-react'
import type { TeamDetailDto, TeamRole } from '@/api/dto'

vi.mock('@/config/appConfig', () => ({ isSingleTeam: () => false }))
vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (key: string) => key, i18n: { language: 'fr' } }),
}))

import { useTeamNavItems } from './useNavItems'
import { paths } from '@/config/paths'

function team(role?: TeamRole, overrides: Partial<TeamDetailDto> = {}): TeamDetailDto {
  return {
    id: 't1',
    name: 'VC Craponne',
    slug: 'vc-craponne',
    visibility: 'PUBLIC',
    enableRides: true,
    enableRoutes: true,
    enableTrips: false,
    enablePosts: true,
    enableAds: true,
    pages: [{ slug: 'histoire', title: 'Histoire', visibility: 'PUBLIC' }],
    role,
    ...overrides,
  } as unknown as TeamDetailDto
}

const ids = (t: TeamDetailDto) =>
  renderHook(() => useTeamNavItems(t)).result.current.map((i) => i.id)

describe('team tabs (WEB-68, BRAND-6)', () => {
  it('opens on the dashboard for everyone, then the agenda and the posts', () => {
    expect(ids(team())).toEqual(['dashboard', 'agenda', 'posts', 'routes', 'about', 'histoire'])
    expect(ids(team('ADMIN'))).toEqual([
      'dashboard',
      'agenda',
      'posts',
      'routes',
      'ads',
      'members',
      'about',
      'histoire',
    ])
  })

  it('leads each section to its own route, with no feed and no calendar tab', () => {
    const items = renderHook(() => useTeamNavItems(team('MEMBER'))).result.current
    const path = (id: string) => items.find((i) => i.id === id)?.path
    expect(path('dashboard')).toBe(paths.team('vc-craponne'))
    expect(path('agenda')).toBe(paths.teamAgenda('vc-craponne'))
    expect(path('posts')).toBe(paths.teamPosts('vc-craponne'))
    expect(items.map((i) => i.id)).not.toContain('calendar')
    expect(items.map((i) => i.id)).not.toContain('publications')
    expect(items.map((i) => i.id)).not.toContain('members')
  })

  it('gates the agenda on rides or trips with the routes, the posts on their module', () => {
    expect(ids(team('MEMBER', { enableRoutes: false }))).not.toContain('agenda')
    expect(ids(team('MEMBER', { enableRides: false }))).not.toContain('agenda')
    expect(ids(team('MEMBER', { enableRides: false, enableTrips: true }))).toContain('agenda')
    expect(ids(team('MEMBER', { enablePosts: false }))).not.toContain('posts')
  })

  it('shows « Membres » to whoever may read the directory, as the mobile does (WEB-112, MOB-89)', () => {
    // Closed directory: organisers and admins only.
    expect(ids(team('ADMIN'))).toContain('members')
    expect(ids(team('ORGANIZER'))).toContain('members')
    expect(ids(team('MEMBER'))).not.toContain('members')
    // Open directory: every member, and still never a visitor.
    expect(ids(team('MEMBER', { enableMemberDirectory: true }))).toContain('members')
    expect(ids(team(undefined, { enableMemberDirectory: true }))).not.toContain('members')
    // Between « Annonces » and « À propos », the mobile's order.
    const order = ids(team('MEMBER', { enableMemberDirectory: true }))
    expect(order.slice(order.indexOf('ads'), order.indexOf('about') + 1)).toEqual([
      'ads',
      'members',
      'about',
    ])
  })

  it('wears the brand icons (docs/BRANDING.md §6)', () => {
    const items = renderHook(() => useTeamNavItems(team('MEMBER'))).result.current
    const icon = (id: string) => items.find((i) => i.id === id)?.icon
    expect(icon('dashboard')).toBe(IconLayoutDashboard)
    expect(icon('agenda')).toBe(IconCalendarEvent)
    expect(icon('posts')).toBe(IconArticle)
    expect(icon('routes')).toBe(IconRoute)
    expect(icon('ads')).toBe(IconTag)
    expect(icon('histoire')).toBe(IconFileText)
  })
})
