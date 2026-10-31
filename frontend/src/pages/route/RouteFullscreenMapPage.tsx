import { useEffect } from 'react'
import { Navigate, useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { useRouteMapData } from './routeDetailData'
import { MapColorFullscreenView } from '@/components/route/MapColorFullscreenView'
import { LoadingPage } from '@/components/common/LoadingSpinner'
import { paths } from '@/config/paths'
import { useAppName } from '@/hooks/useAppName'
import { useCanonicalPath } from '@/hooks/useCanonicalPath'

/**
 * Fullscreen map for a team route (`.../map`). Bare layout (no AppShell), so it owns its own
 * `document.title`. Mirrors {@link RouteDetailPage}'s data flow; a missing route falls back to the
 * regular detail page, which renders the not-found UI.
 */
export function RouteFullscreenMapPage() {
  const { teamSlug, routeSlug } = useParams<{ teamSlug: string; routeSlug: string }>()
  const { t } = useTranslation()
  const appName = useAppName()

  const { team: teamQuery, route: routeQuery } = useRouteMapData(teamSlug, routeSlug)
  const { data: team } = teamQuery
  const { data: route, isLoading } = routeQuery

  useCanonicalPath(team && route ? paths.routeMap(team.slug, route.slug) : undefined)

  useEffect(() => {
    if (route) {
      document.title = appName ? `${route.name} — ${appName}` : route.name
    }
  }, [route, appName])

  if (isLoading) {
    return <LoadingPage message={t('loading')} />
  }

  if (!route || !team) {
    return <Navigate to={paths.route(teamSlug!, routeSlug!)} replace />
  }

  return (
    <MapColorFullscreenView
      route={route}
      title={route.name}
      backTo={paths.route(team.slug, route.slug)}
    />
  )
}
