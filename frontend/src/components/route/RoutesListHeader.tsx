import { useTranslation } from 'react-i18next'
import { Button, Group, Title, Tooltip } from '@mantine/core'
import { IconPlus, IconRoute2 } from '@tabler/icons-react'
import type { TeamDetailDto } from '@/api/dto'
import { paths } from '@/config/paths'
import { teamAccess } from '@/lib/teamAccess'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { isPlannerQuotaSpent } from '@/lib/plannerQuota'
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
  // The generator needs the planner (same rule as the backend's PlannerAccess.check). Its only way
  // to keep a result is a planner save, so a spent quota disables it, with the reason (BILL-10).
  const canGenerate = canCreateRoute && team.enableRoutePlanner
  const quotaSpent = isPlannerQuotaSpent(team.plannerQuota, isPlatformAdmin)

  return (
    <Group justify="space-between">
      <Title order={2}>{t('routes.list.title')}</Title>
      {canCreateRoute && (
        <Group gap="sm" wrap="wrap">
          <UploadGpxFiles team={team} />
          {canGenerate &&
            (quotaSpent ? (
              <Tooltip label={t('routeGenerator.quotaSpent')} withArrow>
                {/* A disabled button swallows the pointer: the span carries the tooltip */}
                <span>
                  <Button
                    variant="default"
                    leftSection={<IconRoute2 size={16} />}
                    disabled
                    data-testid="route-generate-button"
                  >
                    {t('routeGenerator.title')}
                  </Button>
                </span>
              </Tooltip>
            ) : (
              <Button
                component={PrefetchLink}
                to={paths.routeGenerate(team.slug)}
                variant="default"
                leftSection={<IconRoute2 size={16} />}
                data-testid="route-generate-button"
              >
                {t('routeGenerator.title')}
              </Button>
            ))}
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
