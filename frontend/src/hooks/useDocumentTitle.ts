import { useEffect, useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { useParams } from 'react-router-dom'
import { useAppName } from './useAppName'
import { entityNames, type BreadcrumbEntities } from '@/config/breadcrumbNames'
import { pageTitleParts } from '@/config/pageTitleParts'
import type { RouteParams } from '@/config/routes.types'
import { formatPageTitle, type PageTitleParts } from '@/lib/pageTitle'

/** Writes the tab's title, « Libellé · Contexte — Site » (plan 2026-11-25 D2). */
export function useDocumentTitle(title: PageTitleParts): void {
  const appName = useAppName()
  useEffect(() => {
    document.title = formatPageTitle(title.label, title.context, appName)
  }, [title.label, title.context, appName])
}

/**
 * The tab's title of a page outside the Layout (`layout: 'bare'`): the route's own computation, fed
 * with the entities the page reads. `routeId` is explicit, so a page mounted on another path in a
 * test still names itself.
 */
export function useBarePageTitle(routeId: string, entities: BreadcrumbEntities): void {
  const { t } = useTranslation()
  const params = useParams() as RouteParams
  const parts = useMemo(
    () => pageTitleParts(routeId, params, entityNames(entities, params, t), t),
    [routeId, params, entities, t]
  )
  useDocumentTitle(parts)
}
