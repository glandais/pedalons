import { useParams, Navigate, useNavigate } from 'react-router-dom'
import { invalidateTeamDashboard } from '@/lib/teamDashboardCache'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import { Container, Stack, Text, Title } from '@mantine/core'
import {
  useCreateTemplate,
  getListTemplatesQueryKey,
} from '@/api/endpoints/ride-templates/ride-templates'
import { LoadingPage } from '../../components/common/LoadingSpinner'
import { RideTemplateEditor } from '../../components/ridetemplate/RideTemplateEditor'
import { Status, RideTemplateRequest } from '@/api/dto'
import { paths } from '@/config/paths'
import { useCreateRideTemplateFormData } from './rideTemplateFormData'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'

export function CreateRideTemplatePage() {
  const { teamSlug } = useParams<{ teamSlug: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { data: team, isLoading: isLoadingTeam } = useCreateRideTemplateFormData(teamSlug)

  const createMutation = useCreateTemplate()
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)

  useCanonicalPath(team ? paths.rideTemplateNew(team.slug) : undefined)

  if (isLoadingTeam) {
    return <LoadingPage message={t('loading')} />
  }

  if (!team) {
    return <Navigate to={paths.teams()} replace />
  }

  const canCreate = teamAccess(team, isPlatformAdmin).isOrganizer

  if (!canCreate) {
    return <Navigate to={paths.rideTemplates(teamSlug!)} replace />
  }

  const initialValues = {
    name: '',
    markdown: '',
    visibility: team.visibility,
    status: Status.PUBLISHED,
    groups: [
      {
        name: t('rideTemplates.form.groups.defaultName', { number: 1 }),
      },
    ],
  }

  const handleSubmit = (data: RideTemplateRequest) => {
    createMutation.mutate(
      {
        teamSlug: teamSlug!,
        data,
      },
      {
        onSuccess: () => {
          navigate(paths.rideTemplates(teamSlug!))
          queryClient.invalidateQueries({ queryKey: getListTemplatesQueryKey(teamSlug!) })
          invalidateTeamDashboard(queryClient, teamSlug!)
          notifications.show({ message: t('rideTemplates.notifications.created'), color: 'green' })
        },
      }
    )
  }

  return (
    <Container size="sm" py="xl">
      <Stack gap="xs">
        <Title order={1}>{t('rideTemplates.create.title')}</Title>
        <Text c="dimmed">{t('rideTemplates.create.subtitle', { teamName: team.name })}</Text>
      </Stack>

      <RideTemplateEditor
        team={team}
        teamSlug={teamSlug!}
        initialValues={initialValues}
        onSubmit={handleSubmit}
        onCancel={() => navigate(paths.rideTemplates(teamSlug!))}
        isPending={createMutation.isPending}
        submitButtonText={t('rideTemplates.create.button')}
      />
    </Container>
  )
}
