import { useTranslation } from 'react-i18next'
import { Group, Title } from '@mantine/core'
import type { TeamDetailDto } from '@/api/dto'
import { teamAccess } from '@/lib/teamAccess'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { CreateSplitButton } from '@/components/common/CreateSplitButton'
import { useRouteCreateActions } from '@/components/team/dashboard/useTeamCreateActions'

/**
 * The head of a team's routes, list and map alike (RL13): the title, and for whoever may create a
 * route — an organizer, or a platform admin — « Créer ▾ »: the dashboard's « Parcours » section
 * (draw on the map, import GPX files, generate), as in the app. One component, so the two views of
 * the same list cannot drift apart again.
 */
export function RoutesListHeader({ team }: { team: TeamDetailDto }) {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const canCreateRoute = teamAccess(team, isPlatformAdmin).isOrganizer
  const actions = useRouteCreateActions(team)

  return (
    <Group justify="space-between">
      <Title order={2}>{t('routes.list.title')}</Title>
      {canCreateRoute && actions.length > 0 && <CreateSplitButton actions={actions} />}
    </Group>
  )
}
