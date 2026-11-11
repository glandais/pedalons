import { useMemo } from 'react'
import { useLocation } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { findMatchingRoute, buildBreadcrumbChain, buildRoutePath } from '../config/routeUtils'
import { useBreadcrumbData } from './useBreadcrumbData'
import { useHomeNavItems, useTeamNavItems } from './useNavItems'
import type { BreadcrumbItemType, BreadcrumbSubItemType } from '../components/common/Breadcrumb'
import { BreadcrumbLabel } from '@/config/routes.types'
import { isSingleTeam } from '@/config/appConfig'

export interface UseBreadcrumbResult {
  items: BreadcrumbItemType[]
  showBackLink: boolean
}

/**
 * Generate breadcrumb items from route configuration
 * Single source of truth: uses route config for hierarchy, fetches entity names for dynamic labels
 */
export function useBreadcrumb(): UseBreadcrumbResult {
  const location = useLocation()
  const { t } = useTranslation()

  // Find current route and extract params
  const matchResult = useMemo(() => findMatchingRoute(location.pathname), [location.pathname])

  // Fetch entity data for dynamic labels
  const entityData = useBreadcrumbData(matchResult?.params ?? {})

  // Shared nav-item groups feed the per-level dropdowns, so they mirror the actual tab bar
  // (auth/feature/membership gated, including dynamic pages) instead of a static list.
  // The team the breadcrumb data read — not for a team the page's entity says is closed.
  const team = entityData.teamDetail
  const homeNavItems = useHomeNavItems()
  const teamNavItems = useTeamNavItems(team)

  // Build breadcrumb items
  const items = useMemo<BreadcrumbItemType[]>(() => {
    if (!matchResult) {
      return []
    }

    const { route, params } = matchResult
    // On a single-team site the "Teams" crumb points at a page that redirects away — drop it.
    const singleTeam = isSingleTeam()
    const chain = buildBreadcrumbChain(route.id).filter(
      (rc) => !(singleTeam && rc.hideWhenSingleTeam)
    )

    function resolveLabel(bc: BreadcrumbLabel): string {
      if (bc.type === 'static') {
        return t(bc.i18nKey)
      } else {
        // Dynamic label from entity
        const data = entityData[bc.entity]
        return data.name ?? '...'
      }
    }

    return chain.map((routeConfig, index) => {
      const isLast = index === chain.length - 1
      const breadcrumb = routeConfig.breadcrumb!

      // Resolve label
      const label = resolveLabel(breadcrumb)

      // Build path (undefined for last item = current page). A closed team's own crumbs (the team,
      // its agenda…) are named but lead nowhere: they would only answer 404 (docs/LEDGER_*.md WEB-166).
      const leadsIntoClosedTeam = entityData.teamClosed && isTeamPage(routeConfig.paths)
      const path = isLast || leadsIntoClosedTeam ? undefined : buildRoutePath(routeConfig, params)

      // Dropdown items mirror the actual tab bar for this level, sourced from the shared nav groups.
      const navItems =
        routeConfig.navGroup === 'home'
          ? homeNavItems
          : routeConfig.navGroup === 'team'
            ? teamNavItems
            : undefined
      const subItems: BreadcrumbSubItemType[] | undefined = navItems?.length
        ? navItems.map((item) => ({ label: item.label, path: item.path }))
        : undefined

      return { label, path, subItems }
    })
  }, [matchResult, entityData, homeNavItems, teamNavItems, t])

  const showBackLink = matchResult?.route.showBackLink ?? false

  return { items, showBackLink }
}

/**
 * A page of the team itself (`/equipes/:teamSlug`, its agenda, its routes…): under the team and
 * naming nothing else, so it reads the team — unlike an entity's page (`…/sorties/:rideSlug`),
 * which a reader of a closed team may still open by link.
 */
export function isTeamPage(paths: Record<string, string>): boolean {
  return Object.values(paths).some(
    (path) => path.includes(':teamSlug') && (path.match(/:/g) ?? []).length === 1
  )
}
