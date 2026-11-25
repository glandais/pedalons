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
 * (`useRouteCreateActions`) and the publications' — each only when the team has that module. Subscribing
 * to the calendar is not one of them: it lives on the agenda and on a trip. The dashboard header
 * and the member home's button (`QuickActions`) share it, so both offer the same thing.
 */
export function useTeamCreateActions(team: TeamDetailDto): CreateAction[] {
  const { t } = useTranslation()
  const routeActions = useRouteCreateActions(team)
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
  for (const action of routeActions) actions.push({ ...action, group: routes })
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

/**
 * A team's route creations: the form (import a GPX or draw on the map) and, when the team has the
 * planner, the generator — the dashboard's « Parcours » section and the routes list's button
 * (`RoutesListHeader`, which adds the import of several GPX) alike.
 */
export function useRouteCreateActions(team: TeamDetailDto): CreateAction[] {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  if (!team.enableRoutes) return []
  // An SPA link like the other actions: the full page load came from the switch to Mantine with no
  // reason (docs/LEDGER_*.md WEB-206, D8).
  const actions: CreateAction[] = [
    {
      key: 'route',
      label: t('list.create.route'),
      icon: IconMapPlus,
      color: 'indigo',
      to: paths.routeNew(team.slug),
      description: team.enableRoutePlanner ? t('teams.dashboard.create.routeHint') : undefined,
    },
  ]
  // The generator needs the planner (PlannerAccess.check). Its only way to keep a result is a
  // planner save, so a spent quota disables it, with the reason (BILL-10).
  if (team.enableRoutePlanner) {
    actions.push({
      key: 'route-generate',
      label: t('routeGenerator.title'),
      icon: IconWand,
      color: 'indigo',
      to: paths.routeGenerate(team.slug),
      description: t('routeGenerator.subtitle'),
      disabledReason: isPlannerQuotaSpent(team.plannerQuota, isPlatformAdmin)
        ? t('routeGenerator.quotaSpent')
        : undefined,
    })
  }
  return actions
}
