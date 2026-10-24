import { useState } from 'react'
import { useParams, useNavigate, Navigate } from 'react-router-dom'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { Trans, useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import i18next from 'i18next'
import { paths } from '../../config/paths'
import { Box, Button, Center, Stack, Text, Title } from '@mantine/core'
import {
  useDeleteTeam,
  useChangeTeamSlug,
  getListTeamsQueryKey,
  getGetTeamQueryKey,
} from '@/api/endpoints/teams/teams'
import { useTeamSettingsData } from './teamSettingsData'
import { LoadingPage } from '../../components/common/LoadingSpinner'
import { ConfirmDialog } from '../../components/common/ConfirmDialog'
import { TeamForm } from '../../components/team/TeamForm'
import { TeamAdminLayout } from '../../components/team/TeamAdminLayout'
import { TeamWebhookSettings } from '../../components/team/TeamWebhookSettings'
import { TeamDetailDto } from '@/api/dto'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'

export function TeamSettingsPage() {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const { teamSlug } = useParams<{ teamSlug: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const { data: team, isLoading, error } = useTeamSettingsData(teamSlug)
  const deleteMutation = useDeleteTeam()
  const changeSlugMutation = useChangeTeamSlug()

  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)

  useCanonicalPath(team ? paths.teamSettings(team.slug) : undefined)

  if (isLoading) {
    return <LoadingPage message={t('loading')} />
  }

  if (error || !team) {
    return (
      <Box maw={672} mx="auto" px={{ base: 'md', sm: 'lg' }} py="xl">
        <Center py="xl">
          <Stack align="center">
            <Title order={1}>{t('error.loading')}</Title>
            <Text c="dimmed" mb="lg">
              {t('teams.settings.error.loadFailed')}
            </Text>
            <Button component="a" href={paths.teams()}>
              {t('teams.detail.notFound.backToTeams')}
            </Button>
          </Stack>
        </Center>
      </Box>
    )
  }

  if (!teamAccess(team, isPlatformAdmin).isAdmin) {
    return <Navigate to={paths.team(teamSlug!)} replace />
  }

  const handleSuccess = (updatedTeam: TeamDetailDto) => {
    navigate(paths.team(updatedTeam.slug))
  }

  const handleSlugChange = async (newSlug: string) => {
    await changeSlugMutation.mutateAsync(
      { teamSlug: teamSlug!, data: { slug: newSlug } },
      {
        onSuccess: (updatedTeam) => {
          queryClient.invalidateQueries({ queryKey: getListTeamsQueryKey() })
          queryClient.invalidateQueries({ queryKey: getGetTeamQueryKey(teamSlug!) })
          navigate(paths.teamSettings(updatedTeam.slug), { replace: true })
        },
      }
    )
  }

  const handleDelete = () => {
    if (!teamSlug) return
    deleteMutation.mutate(
      { teamSlug },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: getListTeamsQueryKey() })
          queryClient.removeQueries({ queryKey: getGetTeamQueryKey(teamSlug) })
          notifications.show({ message: i18next.t('teams.notifications.deleted'), color: 'green' })
          navigate(paths.teams())
        },
      }
    )
  }

  return (
    <TeamAdminLayout team={team} currentTab="settings">
      <Box py="md" maw={672}>
        <Box>
          <Title order={2}>{t('teams.settings.title')}</Title>
          <Text c="dimmed" mt="xs">
            {t('teams.settings.subtitle')}
          </Text>
        </Box>

        <TeamForm
          teamSlug={teamSlug}
          teamId={team.id}
          initialValues={{ ...team, media: team.about }}
          onSuccess={handleSuccess}
          create={false}
          onSlugChange={handleSlugChange}
        />

        <TeamWebhookSettings teamSlug={team.slug} />

        {/* Danger Zone */}
        <Box mt="xl" pt="xl" style={{ borderTop: '1px solid var(--mantine-color-default-border)' }}>
          <Title order={2} size="lg" c="red">
            {t('teams.settings.dangerZone.title')}
          </Title>
          <Text size="sm" c="dimmed" mt="xs">
            {t('teams.settings.dangerZone.description')}
          </Text>

          <Button
            variant="outline"
            color="danger"
            mt="md"
            onClick={() => setShowDeleteConfirm(true)}
          >
            {t('teams.settings.dangerZone.deleteTeam')}
          </Button>
        </Box>

        <ConfirmDialog
          isOpen={showDeleteConfirm}
          onClose={() => setShowDeleteConfirm(false)}
          onConfirm={handleDelete}
          title={t('teams.settings.dangerZone.title')}
          message={
            <Trans
              i18nKey="teams.settings.dangerZone.deleteWarning"
              values={{ teamName: team?.name }}
              components={{ strong: <strong /> }}
            />
          }
          confirmText={t('teams.settings.dangerZone.confirmDelete')}
          variant="danger"
          isLoading={deleteMutation.isPending}
        />
      </Box>
    </TeamAdminLayout>
  )
}
