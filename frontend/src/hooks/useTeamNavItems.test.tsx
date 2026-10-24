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

import { teamSwitchPath, useTeamNavItems } from './useNavItems'
import type { TFunction } from 'i18next'
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

describe('team switcher landing (WEB-111)', () => {
  const t = ((key: string) => key) as unknown as TFunction
  const target = (role?: TeamRole, overrides: Partial<TeamDetailDto> = {}) =>
    team(role, { slug: 'b-team', ...overrides })

  it('keeps the section when the other team has it', () => {
    expect(teamSwitchPath(target('MEMBER'), 'agenda', t)).toBe(paths.teamAgenda('b-team'))
    expect(teamSwitchPath(target('MEMBER'), 'posts', t)).toBe(paths.teamPosts('b-team'))
    expect(teamSwitchPath(target('MEMBER'), 'routes', t)).toBe(paths.routes('b-team'))
    expect(teamSwitchPath(target('MEMBER'), 'ads', t)).toBe(paths.ads('b-team'))
    expect(teamSwitchPath(target('MEMBER'), 'about', t)).toBe(paths.teamAbout('b-team'))
    expect(teamSwitchPath(target('MEMBER'), 'dashboard', t)).toBe(paths.team('b-team'))
  })

  it('falls back to the dashboard when the other team lacks the section', () => {
    const dashboard = paths.team('b-team')
    expect(teamSwitchPath(target('MEMBER', { enableRides: false }), 'agenda', t)).toBe(dashboard)
    expect(teamSwitchPath(target('MEMBER', { enableRoutes: false }), 'agenda', t)).toBe(dashboard)
    expect(teamSwitchPath(target('MEMBER', { enablePosts: false }), 'posts', t)).toBe(dashboard)
    expect(teamSwitchPath(target('MEMBER', { enableAds: false }), 'ads', t)).toBe(dashboard)
  })

  it('follows the directory rule for « Membres »', () => {
    expect(teamSwitchPath(target('MEMBER'), 'members', t)).toBe(paths.team('b-team'))
    expect(teamSwitchPath(target('ORGANIZER'), 'members', t)).toBe(paths.teamMembers('b-team'))
  })

  it('never carries a custom page over, even to a page of the same slug', () => {
    // From a custom page TeamLayout passes no section, whatever the page's slug.
    expect(teamSwitchPath(target('MEMBER'), undefined, t)).toBe(paths.team('b-team'))
    // A tab that is no section, and a section id the target only has as a page.
    expect(teamSwitchPath(target('MEMBER'), 'histoire', t)).toBe(paths.team('b-team'))
    const pageOnly = target('MEMBER', {
      enablePosts: false,
      pages: [{ slug: 'posts', title: 'Posts', visibility: 'PUBLIC' }],
    } as Partial<TeamDetailDto>)
    expect(teamSwitchPath(pageOnly, 'posts', t)).toBe(paths.team('b-team'))
  })
})
