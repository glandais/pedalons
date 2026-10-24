import { useParams, Navigate } from 'react-router-dom'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useTranslation } from 'react-i18next'
import { paths } from '../../config/paths'
import { Box, Paper, Title } from '@mantine/core'
import { LoadingPage } from '../../components/common/LoadingSpinner'
import { TeamAdminLayout } from '../../components/team/TeamAdminLayout'
import { TeamPageForm } from '../../components/team/TeamPageForm'
import { useEditTeamPageFormData } from './teamPageFormData'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'

export function EditTeamPagePage() {
  const { teamSlug, pageSlug } = useParams<{ teamSlug: string; pageSlug: string }>()

  const { team: teamQuery, page: pageQuery } = useEditTeamPageFormData(teamSlug, pageSlug)
  const { data: team, isLoading: isTeamLoading } = teamQuery
  const { data: page, isLoading: isPageLoading } = pageQuery
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)

  useCanonicalPath(team && page ? paths.teamAdminPageEdit(team.slug, page.slug) : undefined)

  if (isTeamLoading || isPageLoading) {
    return <LoadingPage message={t('loading')} />
  }

  if (!team) {
    return <Navigate to={paths.teams()} replace />
  }

  const isAdmin = teamAccess(team, isPlatformAdmin).isAdmin
  if (!isAdmin) {
    return <Navigate to={paths.team(team.slug)} replace />
  }

  if (!page) {
    return <Navigate to={paths.teamAdminPages(team.slug)} replace />
  }

  return (
    <TeamAdminLayout team={team} currentTab="pages">
      <Box py="md">
        <Box maw={672}>
          <Title order={2} mb="lg">
            {t('teams.pages.edit.title', { name: page.title })}
          </Title>
          <Paper p="lg" withBorder>
            <TeamPageForm
              teamSlug={team.slug}
              pageSlug={page.slug}
              initialValues={page}
              isCreate={false}
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
