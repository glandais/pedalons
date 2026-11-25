import { useTranslation } from 'react-i18next'
import { Group, Text, Title } from '@mantine/core'
import { IconUpload } from '@tabler/icons-react'
import type { TeamDetailDto } from '@/api/dto'
import { teamAccess } from '@/lib/teamAccess'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { CreateSplitButton, type CreateAction } from '@/components/common/CreateSplitButton'
import { useRouteCreateActions } from '@/components/team/dashboard/useTeamCreateActions'
import { useGpxUpload } from './useGpxUpload'

/**
 * The head of a team's routes, list and map alike (RL13): the title, and for whoever may create a
 * route — an organizer, or a platform admin — « Créer un parcours ▾ », the button of the team's
 * dashboard: the form first, then the import of several GPX and the generator behind the chevron,
 * as in the app. One component, so the two views of the same list cannot drift apart again.
 */
export function RoutesListHeader({ team }: { team: TeamDetailDto }) {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const canCreateRoute = teamAccess(team, isPlatformAdmin).isOrganizer
  const routeActions = useRouteCreateActions(team)
  const upload = useGpxUpload(team)
  const progress = upload.progress
    ? t('routes.upload.progress', {
        current: upload.progress.current,
        total: upload.progress.total,
      })
    : null

  const importAction: CreateAction = {
    key: 'route-import',
    label: t('routes.upload.button'),
    icon: IconUpload,
    color: 'indigo',
    onClick: upload.open,
    description: t('routes.upload.hint'),
    disabledReason: progress ?? undefined,
  }
  const [create, ...others] = routeActions
  const actions = create ? [create, importAction, ...others] : []

  return (
    <Group justify="space-between">
      <Title order={2}>{t('routes.list.title')}</Title>
      {canCreateRoute && actions.length > 0 && (
        <Group gap="sm" wrap="wrap">
          {upload.input}
          {progress && (
            <Text size="sm" c="dimmed" aria-live="polite">
              {progress}
            </Text>
          )}
          {upload.error && (
            <Text size="sm" c="red">
              {upload.error}
            </Text>
          )}
          <CreateSplitButton actions={actions} />
        </Group>
      )}
    </Group>
  )
}
