import { useParams, Navigate, useNavigate } from 'react-router-dom'
import { invalidateTeamDashboard } from '@/lib/teamDashboardCache'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import { Container, Stack, Text, Title } from '@mantine/core'
import { paths } from '../../config/paths'
import {
  useUpdateTemplate,
  getGetTemplateQueryKey,
  getListTemplatesQueryKey,
} from '@/api/endpoints/ride-templates/ride-templates'
import { LoadingPage } from '../../components/common/LoadingSpinner'
import { RideTemplateEditor } from '../../components/ridetemplate/RideTemplateEditor'
import { RideTemplateRequest } from '@/api/dto'
import { useEditRideTemplateFormData } from './rideTemplateFormData'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'

export function EditRideTemplatePage() {
  const { teamSlug, templateSlug } = useParams<{ teamSlug: string; templateSlug: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { team: teamQuery, template: templateQuery } = useEditRideTemplateFormData(
    teamSlug,
    templateSlug
  )
  const { data: team, isLoading: isLoadingTeam } = teamQuery
  const { data: template, isLoading: isLoadingTemplate } = templateQuery

  const updateMutation = useUpdateTemplate()
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)

  useCanonicalPath(team && template ? paths.rideTemplateEdit(team.slug, template.slug) : undefined)

  if (isLoadingTeam || isLoadingTemplate) {
    return <LoadingPage message={t('loading')} />
  }

  if (!team) {
    return <Navigate to={paths.teams()} replace />
  }

  if (!template) {
    return <Navigate to={paths.rideTemplates(teamSlug!)} replace />
  }

  const canEdit = teamAccess(team, isPlatformAdmin).isOrganizer

  if (!canEdit) {
    return <Navigate to={paths.rideTemplates(teamSlug!)} replace />
  }

  const initialValues = { ...template, tagIds: template.tags.map((tag) => tag.id) }

  const handleSubmit = (data: RideTemplateRequest) => {
    updateMutation.mutate(
      {
        teamSlug: teamSlug!,
        templateSlug: templateSlug!,
        data,
      },
      {
        onSuccess: () => {
          navigate(paths.rideTemplates(teamSlug!))
          queryClient.invalidateQueries({
            queryKey: getGetTemplateQueryKey(teamSlug!, templateSlug!),
          })
          queryClient.invalidateQueries({ queryKey: getListTemplatesQueryKey(teamSlug!) })
          invalidateTeamDashboard(queryClient, teamSlug!)
          notifications.show({ message: t('rideTemplates.notifications.updated'), color: 'green' })
        },
      }
    )
  }

  return (
    <Container size="sm" py="xl">
      <Stack gap="xs">
        <Title order={1}>{t('rideTemplates.edit.title')}</Title>
        <Text c="dimmed">{t('rideTemplates.edit.subtitle')}</Text>
      </Stack>

      <RideTemplateEditor
        key={template.id}
        team={team}
        teamSlug={teamSlug!}
        initialValues={initialValues}
        onSubmit={handleSubmit}
        onCancel={() => navigate(paths.rideTemplates(teamSlug!))}
        isPending={updateMutation.isPending}
        submitButtonText={t('actions.save')}
      />
    </Container>
  )
}
