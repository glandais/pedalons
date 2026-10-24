import { Navigate, useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { Box } from '@mantine/core'
import { paths } from '@/config/paths'
import { useGetTeam } from '@/api/endpoints/teams/teams'
import {
  useResolveTeamReports,
  getListTeamReportsQueryKey,
} from '@/api/endpoints/moderation/moderation'
import { getListAdminReportsQueryKey } from '@/api/endpoints/admin-reports/admin-reports'
import { LoadingPage } from '@/components/common/LoadingSpinner'
import { TeamAdminLayout } from '@/components/team/TeamAdminLayout'
import { ModerationQueue } from '@/components/moderation/ModerationQueue'
import { useCanonicalPath } from '@/hooks/useCanonicalPath'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { invalidateModeratedContent } from '@/lib/moderationCacheInvalidation'
import { useTeamReportsData } from './teamReportsData'
import { teamAccess } from '@/lib/teamAccess'

/**
 * The team's moderation queue — its organizers and admins, and the platform admins, who reach it
 * from a `CONTENT_REPORTED` notification without having to be members.
 */
export function TeamReportsPage() {
  const { t } = useTranslation()
  const { teamSlug } = useParams<{ teamSlug: string }>()
  const queryClient = useQueryClient()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)

  const { data: team, isLoading } = useGetTeam(teamSlug!, {
    query: { enabled: !!teamSlug },
  })
  const canModerate = teamAccess(team, isPlatformAdmin).isOrganizer

  const { filters, setFilters, reports } = useTeamReportsData(teamSlug, canModerate)
  const resolveMutation = useResolveTeamReports()

  useCanonicalPath(team ? paths.teamAdminReports(team.slug) : undefined)

  if (isLoading) {
    return <LoadingPage message={t('loading')} />
  }

  if (!team) {
    return <Navigate to={paths.teams()} replace />
  }

  return (
    <TeamAdminLayout team={team} currentTab="reports">
      <Box py="lg">
        <ModerationQueue
          scope="team"
          status={filters.status}
          onStatusChange={(status) => setFilters({ status })}
          data={reports.data}
          isLoading={reports.isLoading}
          error={reports.error}
          onRetry={() => void reports.refetch()}
          resolve={(decision) =>
            resolveMutation.mutateAsync(
              { teamSlug: team.slug, data: decision },
              {
                onSuccess: () => {
                  void queryClient.invalidateQueries({
                    queryKey: getListTeamReportsQueryKey(team.slug),
                  })
                  void queryClient.invalidateQueries({ queryKey: getListAdminReportsQueryKey() })
                  void invalidateModeratedContent(queryClient)
                },
              }
            )
          }
        />
      </Box>
    </TeamAdminLayout>
  )
}
