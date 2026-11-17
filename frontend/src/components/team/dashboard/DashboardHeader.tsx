import { useTeamAccess } from '@/lib/teamAccess'
import { useTranslation } from 'react-i18next'
import { Group, Text } from '@mantine/core'
import { IconBike, IconMapPlus, IconPencilPlus, IconRoute, IconWand } from '@tabler/icons-react'
import { CreateSplitButton, type CreateAction } from '@/components/common/CreateSplitButton'
import { PUBLICATION_TYPE_COLORS } from '@/lib/badgeColors.generated'
import { isPlannerQuotaSpent } from '@/lib/plannerQuota'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { RoleBadge } from '@/components/card/common'
import type { TeamDetailDto, TeamRole } from '@/api/dto'
import { paths } from '@/config/paths'
import { useResponsive } from '@/hooks/useResponsive'

/**
 * Under the team's name on the dashboard: the reader's role — a member's only — and the member
 * count.
 */
export function DashboardHeaderMeta({ team, role }: { team: TeamDetailDto; role?: TeamRole }) {
  const { t } = useTranslation()
  return (
    <Group gap="xs" mt={4}>
      {role && (
        <RoleBadge role={role}>
          {t(`roles.${role satisfies 'ADMIN' | 'ORGANIZER' | 'MEMBER'}`)}
        </RoleBadge>
      )}
      <Text size="sm" c="dimmed">
        {t('memberCount', { count: team.memberCount })}
      </Text>
    </Group>
  )
}

/**
 * The dashboard's create button in the team header, shaped like the agenda's: « Créer une sortie »
 * with every other creation behind the chevron — the agenda's (ride, trip), the routes' (create,
 * generate) and a publication — each only when the team has that module. Subscribing to the
 * calendar is not one of them: it lives on the agenda and on a trip. Below `sm` it collapses to one
 * `+` icon opening the menu, so it doesn't crowd the team's name in TeamLayout's header.
 */
export function DashboardHeaderActions({ team, role }: { team: TeamDetailDto; role?: TeamRole }) {
  const { t } = useTranslation()
  const { isMobile } = useResponsive()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  // A right, not the badge: a platform admin creates in any team (docs/LEDGER_*.md API-137).
  const { isOrganizer } = useTeamAccess({ role })
  if (!isOrganizer) return null

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
    // A full page load, as on the routes list (RoutesListHeader).
    actions.push({
      key: 'route',
      label: t('list.create.route'),
      icon: IconMapPlus,
      color: 'indigo',
      to: paths.routeNew(team.slug),
      reloadDocument: true,
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
    })
  }

  return <CreateSplitButton actions={actions} compact={isMobile} />
}
