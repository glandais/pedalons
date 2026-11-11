import { useParams, Navigate } from 'react-router-dom'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useTranslation } from 'react-i18next'
import { paths } from '../../config/paths'
import { Box, Paper, Title } from '@mantine/core'
import { LoadingPage } from '../../components/common/LoadingSpinner'
import { TeamAdminLayout } from '../../components/team/TeamAdminLayout'
import { TeamPageForm } from '../../components/team/TeamPageForm'
import { defaultMedia } from '@/lib/apiUtils'
import { Visibility } from '@/api/dto'
import { useCreateTeamPageFormData } from './teamPageFormData'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'
import { allowedVisibilitiesFor } from '@/components/visibility/visibilityLabels'

export function CreateTeamPagePage() {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const { teamSlug } = useParams<{ teamSlug: string }>()

  const { team: teamQuery } = useCreateTeamPageFormData(teamSlug)
  const { data: team, isLoading } = teamQuery

  useCanonicalPath(team ? paths.teamAdminPageNew(team.slug) : undefined)

  if (isLoading) {
    return <LoadingPage message={t('loading')} />
  }

  if (!team) {
    return <Navigate to={paths.teams()} replace />
  }

  const isAdmin = teamAccess(team, isPlatformAdmin).isAdmin
  if (!isAdmin) {
    return <Navigate to={paths.team(team.slug)} replace />
  }

  // « Équipe » whatever the team, as before: a page is the team's own text, opened on purpose. Only
  // changed to the first value offered when the team no longer accepts TEAM (it always does).
  const allowed = allowedVisibilitiesFor(team, 'teamPage')
  const initialValues = {
    title: '',
    visibility: allowed.includes(Visibility.TEAM)
      ? Visibility.TEAM
      : (allowed[0] ?? Visibility.TEAM),
    media: defaultMedia(),
  }

  return (
    <TeamAdminLayout team={team} currentTab="pages">
      <Box py="md">
        <Box maw={672}>
          <Title order={2} mb="lg">
            {t('teams.pages.create.title')}
          </Title>
          <Paper p="lg" withBorder>
            <TeamPageForm
              teamSlug={team.slug}
              isCreate={true}
              allowedVisibilities={allowed}
              teamPrivate={team.visibility === Visibility.TEAM}
              initialValues={initialValues}
              onSuccess={() => {
                // Navigation is handled by the hook
              }}
            />
          </Paper>
        </Box>
      </Box>
    </TeamAdminLayout>
  )
}
