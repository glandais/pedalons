import { Navigate, useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { Box } from '@mantine/core'
import { paths } from '../../config/paths'
import { useGetTeam } from '@/api/endpoints/teams/teams'
import { LoadingPage } from '../../components/common/LoadingSpinner'
import { TeamAdminLayout } from '../../components/team/TeamAdminLayout'
import { PlaceList } from '../../components/team/PlaceList'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'

export function TeamPlacesPage() {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const { teamSlug } = useParams<{ teamSlug: string }>()

  const { data: team, isLoading } = useGetTeam(teamSlug!, {
    query: { enabled: !!teamSlug },
  })

  useCanonicalPath(team ? paths.teamAdminPlaces(team.slug) : undefined)

  if (isLoading) {
    return <LoadingPage message={t('loading')} />
  }

  if (!team) {
    return <Navigate to={paths.teams()} replace />
  }

  const canManage = teamAccess(team, isPlatformAdmin).isOrganizer

  return (
    <TeamAdminLayout team={team} currentTab="places">
      <Box py="lg">
        <PlaceList teamSlug={teamSlug!} canManage={canManage} />
      </Box>
    </TeamAdminLayout>
  )
}
