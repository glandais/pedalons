import { useTranslation } from 'react-i18next'
import { Button, Group, Title } from '@mantine/core'
import { IconPlus } from '@tabler/icons-react'
import type { TeamDetailDto } from '@/api/dto'
import { paths } from '@/config/paths'
import { teamAccess } from '@/lib/teamAccess'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { UploadGpxFiles } from './UploadGpxFiles'

/**
 * The head of a team's routes, list and map alike (RL13): the title, and for whoever may create a
 * route — an organizer, or a platform admin — « Importer GPX » and « Créer un parcours ». One
 * component, so the two views of the same list cannot drift apart again.
 */
export function RoutesListHeader({ team }: { team: TeamDetailDto }) {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const canCreateRoute = teamAccess(team, isPlatformAdmin).isOrganizer

  return (
    <Group justify="space-between">
      <Title order={2}>{t('routes.list.title')}</Title>
      {canCreateRoute && (
        <Group gap="sm">
          <UploadGpxFiles team={team} />
          <Button
            component="a"
            href={paths.routeNew(team.slug)}
            leftSection={<IconPlus size={16} />}
          >
            {t('list.create.route')}
          </Button>
        </Group>
      )}
    </Group>
  )
}
