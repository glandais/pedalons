import { Navigate, useNavigate, useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { Stack, Text, Title } from '@mantine/core'
import { paths } from '@/config/paths'
import { LoadingPage } from '@/components/common/LoadingSpinner'
import { TeamLayout } from '@/components/team/TeamLayout'
import { TeamUnavailable } from '@/components/team/TeamUnavailable'
import {
  RouteGeneratorPanel,
  type GeneratorParamPatch,
} from '@/components/routeGenerator/RouteGeneratorPanel'
import { useCanonicalPath } from '@/hooks/useCanonicalPath'
import { useUrlFilters } from '@/hooks/useUrlFilters'
import {
  generatorParamPatch,
  routeGeneratorFiltersAlias,
  routeGeneratorFiltersSchema,
} from '@/hooks/filters/routeGeneratorFilters'
import { teamAccess } from '@/lib/teamAccess'
import { selectIsPlatformAdmin, useAuthStore } from '@/store/authStore'
import { useRouteGeneratorData } from './routeGeneratorData'

/**
 * The route generator (ledger `WEB-179`): proposals that favour the roads the team's routes
 * already ride, and link them by other roads as the discovery cursor allows (the engine is
 * osm-route-details, ledger `API-206`). The parameters live in the query string; nothing is requested until
 * « Générer » is pressed, and changing a parameter clears the results.
 */
export function RouteGeneratorPage() {
  const { teamSlug } = useParams<{ teamSlug: string }>()
  const { t } = useTranslation()
  const navigate = useNavigate()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const { team: teamQuery } = useRouteGeneratorData(teamSlug)
  const { data: team, isLoading } = teamQuery
  const { filters, setFilters } = useUrlFilters({
    schema: routeGeneratorFiltersSchema,
    alias: routeGeneratorFiltersAlias,
  })

  useCanonicalPath(team ? paths.routeGenerate(team.slug) : undefined)

  if (isLoading) return <LoadingPage message={t('routeGenerator.title')} />

  if (!team) {
    return (
      <TeamUnavailable
        error={teamQuery.error}
        isError={teamQuery.isError}
        onRetry={() => void teamQuery.refetch()}
      />
    )
  }
  if (!team.enableRoutes) return <Navigate to={paths.team(team.slug)} replace />
  if (!team.enableRoutePlanner || !teamAccess(team, isPlatformAdmin).isOrganizer) {
    return <Navigate to={paths.routes(team.slug)} replace />
  }

  const change = (patch: GeneratorParamPatch) => setFilters(generatorParamPatch(patch))
  const more = () => setFilters({ seed: filters.seed + 1, selected: 0, go: true })

  return (
    <TeamLayout team={team} currentTab="routes">
      <Stack py="lg">
        <Stack gap="xs">
          {/* An h2 under the team's h1 (TeamLayout), at the size it had (docs/LEDGER_*.md WEB-207). */}
          <Title order={2} size="h1">
            {t('routeGenerator.title')}
          </Title>
          <Text c="dimmed">{t('routeGenerator.subtitle')}</Text>
        </Stack>
        <RouteGeneratorPanel
          team={team}
          layout="page"
          params={filters}
          onParamsChange={change}
          // A second press, on results already shown, asks for others: the same request would only
          // come back from the cache
          onGenerate={() => (filters.go ? more() : setFilters({ go: true }))}
          onMoreProposals={more}
          onSelect={(selected) => setFilters({ selected })}
          onOpen={(candidate, type) =>
            navigate(paths.routeNew(team.slug), {
              state: {
                generated: { polyline: candidate.polyline, type, distanceM: candidate.distanceM },
              },
            })
          }
        />
      </Stack>
    </TeamLayout>
  )
}
