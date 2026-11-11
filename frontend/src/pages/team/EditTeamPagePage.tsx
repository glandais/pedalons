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
import { allowedVisibilitiesFor } from '@/components/visibility/visibilityLabels'
import { Visibility } from '@/api/dto'

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

  if (!page) {
    // Not a page the reader may open: an administrator is sent back to the list, anyone else to
    // the team, as before.
    const isAdmin = teamAccess(team, isPlatformAdmin).isAdmin
    return (
      <Navigate to={isAdmin ? paths.teamAdminPages(team.slug) : paths.team(team.slug)} replace />
    )
  }

  // Whether the page may be edited is the backend's answer (docs/LEDGER_*.md WEB-166, D7).
  if (!page.permissions.canEdit) {
    return <Navigate to={paths.team(team.slug)} replace />
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
              allowedVisibilities={allowedVisibilitiesFor(team, 'teamPage', page.permissions)}
              teamPrivate={team.visibility === Visibility.TEAM}
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
