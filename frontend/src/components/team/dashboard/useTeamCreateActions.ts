import { useTranslation } from 'react-i18next'
import {
  IconArticle,
  IconBike,
  IconFileUpload,
  IconLuggage,
  IconMap,
  IconSparkles,
} from '@tabler/icons-react'
import type { CreateAction } from '@/components/common/CreateSplitButton'
import { PUBLICATION_TYPE_COLORS } from '@/lib/badgeColors.generated'
import { isPlannerQuotaSpent } from '@/lib/plannerQuota'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import type { TeamDetailDto } from '@/api/dto'
import { paths } from '@/config/paths'
import type { RouteEditorHandoff } from '@/lib/routeHandoff'
import { useGpxUpload } from '@/components/route/useGpxUpload'

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
      icon: IconLuggage,
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
      icon: IconArticle,
      color: PUBLICATION_TYPE_COLORS.POST,
      to: paths.postNew(team.slug),
      group: t('teams.detail.tabs.posts'),
    })
  }

  return actions
}

/**
 * A team's route creations, in the app's order (`routeCreateActions`): draw on the map (with the
 * planner), import GPX files (`useGpxUpload`: one file opens the form, several become routes), and
 * generate (with the planner). The dashboard's « Parcours » section, the member home's button and
 * the routes list's alike; same labels, icons and colour (indigo) as the app.
 */
export function useRouteCreateActions(team: TeamDetailDto): CreateAction[] {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const upload = useGpxUpload(team)
  if (!team.enableRoutes) return []
  // The planner and the generator keep their result through a planner save: a spent quota closes
  // both, with the reason (BILL-10).
  const quotaSpent = isPlannerQuotaSpent(team.plannerQuota, isPlatformAdmin)
    ? t('routeGenerator.quotaSpent')
    : undefined
  const draw: RouteEditorHandoff = { draw: true }
  const actions: CreateAction[] = []
  if (team.enableRoutePlanner) {
    // An SPA link like the other actions: the full page load came from the switch to Mantine with
    // no reason (docs/LEDGER_*.md WEB-206, D8).
    actions.push({
      key: 'route',
      label: t('routes.create.form.sourceModePlanner'),
      icon: IconMap,
      color: 'indigo',
      to: paths.routeNew(team.slug),
      state: draw,
      disabledReason: quotaSpent,
    })
  }
  actions.push({
    key: 'route-import',
    label: t('routes.upload.button'),
    icon: IconFileUpload,
    color: 'indigo',
    onClick: upload.open,
    description: t('routes.upload.hint'),
    disabledReason: upload.progress
      ? t('routes.upload.progress', {
          current: upload.progress.current,
          total: upload.progress.total,
        })
      : undefined,
  })
  if (team.enableRoutePlanner) {
    actions.push({
      key: 'route-generate',
      label: t('routeGenerator.title'),
      icon: IconSparkles,
      color: 'indigo',
      to: paths.routeGenerate(team.slug),
      description: t('routeGenerator.subtitle'),
      disabledReason: quotaSpent,
    })
  }
  return actions
}
