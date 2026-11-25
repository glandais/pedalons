import type { TFunction } from 'i18next'
import { buildBreadcrumbChain, getRouteById } from './routeUtils'
import { ENTITY_PLACEHOLDERS, type EntityNames } from './breadcrumbNames'
import type { BreadcrumbLabel, RouteParams } from './routes.types'
import { joinTitle, type PageTitleParts } from '@/lib/pageTitle'

/** A crumb's text: its i18n label, or its entity's name — the entity's type while it has none. */
export function crumbLabel(bc: BreadcrumbLabel, names: EntityNames, t: TFunction): string {
  return bc.type === 'static'
    ? t(bc.i18nKey)
    : (names[bc.entity] ?? t(ENTITY_PLACEHOLDERS[bc.entity]))
}

/**
 * The tab title's parts for a route — « Agenda · N Peloton » is `{ label: 'Agenda', context: 'N
 * Peloton' }`; `formatPageTitle` adds the site. Pure: the client (Layout, full-screen pages) and
 * the server (`entry-server`) call it with the names they have (plan 2026-11-25 D2).
 */
export function pageTitleParts(
  routeId: string | undefined,
  params: RouteParams,
  names: EntityNames,
  t: TFunction
): PageTitleParts {
  let route = routeId ? getRouteById(routeId) : undefined
  if (!route) return { label: t('notFound.pageTitle') }

  if (route.pageTitle?.type === 'parent' && route.parentId) {
    route = getRouteById(route.parentId) ?? route
  }

  const chain = buildBreadcrumbChain(route.id)
  const leaf = chain.at(-1)
  if (!leaf?.breadcrumb) return {}

  let label = crumbLabel(leaf.breadcrumb, names, t)
  const pageTitle = route.pageTitle
  if (pageTitle?.type === 'edit') {
    const entity = pageTitle.entity
    label = joinTitle(t('actions.edit'), names[entity] ?? t(ENTITY_PLACEHOLDERS[entity]))
  } else if (
    pageTitle?.type === 'withParent' ||
    (leaf.breadcrumb.type === 'dynamic' &&
      (leaf.breadcrumb.entity === 'rideGroup' || leaf.breadcrumb.entity === 'stage'))
  ) {
    const parent = chain.at(-2)
    if (parent?.breadcrumb) label = joinTitle(label, crumbLabel(parent.breadcrumb, names, t))
  }

  let context: string | undefined
  if (params.teamSlug) {
    context = names.team
  } else if (chain[0]?.id === 'admin' && route.id !== 'admin') {
    context = t('admin.pageTitleContext')
  }
  return { label, context }
}
