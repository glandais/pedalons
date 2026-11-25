import { useTranslation } from 'react-i18next'
import { IconBike, IconMapPlus, IconPencilPlus, IconRoute, IconWand } from '@tabler/icons-react'
import type { CreateAction } from '@/components/common/CreateSplitButton'
import { PUBLICATION_TYPE_COLORS } from '@/lib/badgeColors.generated'
import { isPlannerQuotaSpent } from '@/lib/plannerQuota'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import type { TeamDetailDto } from '@/api/dto'
import { paths } from '@/config/paths'

/**
 * What an organizer creates in a team, in the menu's order: the agenda's (ride, trip), the routes'
 * (create, generate) and the publications' — each only when the team has that module. Subscribing
 * to the calendar is not one of them: it lives on the agenda and on a trip. The dashboard header
 * and the member home's button (`QuickActions`) share it, so both offer the same thing.
 */
export function useTeamCreateActions(team: TeamDetailDto): CreateAction[] {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const agenda = t('teams.detail.tabs.agenda')
  const routes = t('routes.list.title')
  const actions: CreateAction[] = []
  if (team.enableRides && team.enableRoutes) {
    actions.push({
      key: 'ride',
      label: t('list.create.ride'),
      icon: IconBike,
      color: PUBLICATION_TYPE_COLORS.RIDE,
      to: paths.rideNew(team.slug),
      group: agenda,
    })
  }
  if (team.enableTrips && team.enableRoutes) {
    actions.push({
      key: 'trip',
      label: t('list.create.trip'),
      icon: IconRoute,
      color: PUBLICATION_TYPE_COLORS.TRIP,
      to: paths.tripNew(team.slug),
      group: agenda,
    })
  }
  if (team.enableRoutes) {
    // An SPA link like the other actions: the full page load came from the switch to Mantine with
    // no reason (docs/LEDGER_*.md WEB-206, D8).
    actions.push({
      key: 'route',
      label: t('list.create.route'),
      icon: IconMapPlus,
      color: 'indigo',
      to: paths.routeNew(team.slug),
      description: team.enableRoutePlanner ? t('teams.dashboard.create.routeHint') : undefined,
      group: routes,
    })
    // The generator needs the planner (PlannerAccess.check); a spent quota disables it, with the
    // reason (BILL-10) — same rule as RoutesListHeader.
    if (team.enableRoutePlanner) {
      actions.push({
        key: 'route-generate',
        label: t('routeGenerator.title'),
        icon: IconWand,
        color: 'indigo',
        to: paths.routeGenerate(team.slug),
        disabledReason: isPlannerQuotaSpent(team.plannerQuota, isPlatformAdmin)
          ? t('routeGenerator.quotaSpent')
          : undefined,
        group: routes,
      })
    }
  }
  if (team.enablePosts) {
    actions.push({
      key: 'post',
      label: t('list.create.post'),
      icon: IconPencilPlus,
      color: PUBLICATION_TYPE_COLORS.POST,
      to: paths.postNew(team.slug),
      group: t('teams.detail.tabs.posts'),
    })
  }

  return actions
}
