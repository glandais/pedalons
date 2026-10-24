import { useMemo } from 'react'
import { useLocation } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import {
  IconNews,
  IconCalendar,
  IconCalendarEvent,
  IconArticle,
  IconRoute,
  IconUsers,
  IconTag,
  IconInfoCircle,
  IconFileText,
  IconSparkles,
  IconLayoutDashboard,
  IconMapSearch,
  IconCompass,
} from '@tabler/icons-react'
import { paths } from '@/config/paths'
import { findMatchingRoute, getRouteById } from '@/config/routeUtils'
import { isSingleTeam } from '@/config/appConfig'
import { useAuth } from './useAuth'
import type { NavButtonItem } from '../components/common/NavButtons'
import type { TeamDetailDto } from '@/api/dto'

/** A main-navigation entry, tied to the route (routes.config.ts id) that its section starts at. */
export interface MainNavItem extends NavButtonItem {
  routeId: string
}

/**
 * Navigation items for the top-level (home) section: calendar requires auth, team browsing is
 * dropped on single-team sites. Single source of truth shared by the header's main navigation
 * (useMainNavItems) and the breadcrumb dropdown.
 */
export function useHomeNavItems(): MainNavItem[] {
  const { t } = useTranslation()
  const { isAuthenticated } = useAuth()
  const singleTeam = isSingleTeam()

  return useMemo(() => {
    const allTabs: (MainNavItem & { requiresAuth?: boolean; hideWhenSingleTeam?: boolean })[] = [
      {
        id: 'feed',
        routeId: 'home',
        path: paths.home(),
        label: t('home.tabs.feed'),
        icon: IconNews,
      },
      {
        id: 'teams',
        routeId: 'teams',
        path: paths.teams(),
        label: t('teams.title'),
        icon: IconUsers,
        // A single-team site has nothing to browse.
        hideWhenSingleTeam: true,
      },
      {
        id: 'calendar',
        routeId: 'calendar',
        path: paths.calendar(),
        label: t('calendar.title'),
        icon: IconCalendar,
        requiresAuth: true,
      },
      // « Explorer » opens the routes map, the list being one switch away (docs/LEDGER_*.md
      // WEB-114); its routeId stays the list's, the map's parent, so both light it up.
      {
        id: 'explore',
        routeId: 'all-routes',
        path: paths.allRoutesMap(),
        label: t('nav.explore'),
        icon: IconCompass,
      },
    ]
    return allTabs.filter(
      (tab) => (!tab.requiresAuth || isAuthenticated) && !(tab.hideWhenSingleTeam && singleTeam)
    )
  }, [t, isAuthenticated, singleTeam])
}

/**
 * The site's main navigation, shown in the header (and the mobile drawer): the home section's
 * entries, then one last entry that depends on the session. A visitor gets the features page — a
 * member is already sold, and the home's promo card points them to what they can still connect
 * (docs/LEDGER_*.md WEB-50); a member gets the GPX tools in its place, which need a session
 * (docs/LEDGER_*.md WEB-72). The breadcrumb dropdown keeps to useHomeNavItems — neither page is a
 * sibling of the feed in the route tree.
 */
export function useMainNavItems(): MainNavItem[] {
  const { t } = useTranslation()
  const homeItems = useHomeNavItems()
  const { isAuthenticated } = useAuth()

  return useMemo(
    () => [
      ...homeItems,
      isAuthenticated
        ? {
            id: 'gpxTools',
            routeId: 'gpx-tools',
            path: paths.gpxTools(),
            label: t('gpxTools.title'),
            icon: IconMapSearch,
          }
        : {
            id: 'features',
            routeId: 'features',
            path: paths.features(),
            label: t('nav.features'),
            icon: IconSparkles,
          },
    ],
    [homeItems, isAuthenticated, t]
  )
}

/**
 * The main-navigation entry the given path belongs to: the nearest ancestor of its route (itself
 * included) that starts a section — so the routes map lights « Explorer » and a team page
 * « Équipes », as their parent chain in routes.config.ts says. Undefined off any section (profile,
 * notifications…), where no entry is current.
 */
export function activeMainNavId(pathname: string, items: MainNavItem[]): string | undefined {
  let routeId: string | null | undefined = findMatchingRoute(pathname)?.route.id
  while (routeId) {
    const id: string = routeId
    const item = items.find((candidate) => candidate.routeId === id)
    if (item) return item.id
    routeId = getRouteById(id)?.parentId
  }
  return undefined
}

/** The current entry of useMainNavItems' list, from the location. */
export function useActiveMainNavId(items: MainNavItem[]): string | undefined {
  const { pathname } = useLocation()
  return useMemo(() => activeMainNavId(pathname, items), [pathname, items])
}

/**
 * Navigation items for a team section, in the order of the plan (2026-10-06 §2): « Tableau de
 * bord » (for everyone, API-86), « Agenda » (rides and trips — their calendar view is reached
 * from it, for a member), « Publications », « Parcours », « Annonces » (members), « Membres »
 * (whoever may read the directory), « À propos », then each visible custom page. Each section
 * only when the team has its module — a ride or a trip needs the routes too. The icons are the brand's
 * (docs/BRANDING.md §6, ledger BRAND-6); custom pages all share one. Single source of truth shared
 * by TeamLayout and the breadcrumb dropdown. Returns [] until the team is loaded.
 */
export function useTeamNavItems(team: TeamDetailDto | undefined): NavButtonItem[] {
  const { t } = useTranslation()

  return useMemo(() => {
    if (!team) return []

    const isMember = !!team.role
    const canSeeMembers =
      team.role === 'ADMIN' ||
      team.role === 'ORGANIZER' ||
      (isMember && !!team.enableMemberDirectory)
    const hasAgenda = (!!team.enableRides || !!team.enableTrips) && !!team.enableRoutes
    const baseTabs: NavButtonItem[] = [
      {
        id: 'dashboard',
        path: paths.team(team.slug),
        label: t('teams.dashboard.title'),
        icon: IconLayoutDashboard,
      },
      ...(hasAgenda
        ? [
            {
              id: 'agenda',
              path: paths.teamAgenda(team.slug),
              label: t('teams.detail.tabs.agenda'),
              icon: IconCalendarEvent,
            },
          ]
        : []),
      ...(team.enablePosts
        ? [
            {
              id: 'posts',
              path: paths.teamPosts(team.slug),
              label: t('teams.detail.tabs.posts'),
              icon: IconArticle,
            },
          ]
        : []),
      ...(team.enableRoutes
        ? [
            {
              id: 'routes',
              path: paths.routes(team.slug),
              label: t('teams.detail.tabs.routes'),
              icon: IconRoute,
            },
          ]
        : []),
      ...(isMember && team.enableAds
        ? [
            {
              id: 'ads',
              path: paths.ads(team.slug),
              label: t('ads.title'),
              icon: IconTag,
            },
          ]
        : []),
      // Whoever may read the directory (WEB-112, API-39): an organiser or an administrator whatever
      // the team decided, a member once the team has opened it. The mobile's members chip
      // (team_sections.dart) and the « À propos » link apply the same rule: a tab that always
      // leads to a 403 is worse than no tab.
      ...(canSeeMembers
        ? [
            {
              id: 'members',
              path: paths.teamMembers(team.slug),
              label: t('teams.detail.members.title'),
              icon: IconUsers,
            },
          ]
        : []),
      {
        id: 'about',
        path: paths.teamAbout(team.slug),
        label: t('teams.detail.tabs.about'),
        icon: IconInfoCircle,
      },
    ]

    // Add dynamic pages - filter by visibility (PUBLIC pages or member can see TEAM pages)
    const visiblePages = (team.pages ?? []).filter((page) => page.visibility !== 'TEAM' || isMember)

    const pageTabs: NavButtonItem[] = visiblePages.map((page) => ({
      id: page.slug,
      path: paths.teamPage(team.slug, page.slug),
      label: page.title,
      icon: IconFileText,
    }))

    return [...baseTabs, ...pageTabs]
  }, [team, t])
}
