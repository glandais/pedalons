import { Group, Skeleton, Stack } from '@mantine/core'
import type { TeamDetailDto } from '@/api/dto'
import { TeamLayout } from '@/components/team/TeamLayout'
import { QueryStateBoundary } from '@/components/common/QueryStateBoundary'
import { TeamDashboard } from '@/components/team/dashboard/TeamDashboard'
import {
  DashboardHeaderActions,
  DashboardHeaderMeta,
} from '@/components/team/dashboard/DashboardHeader'
import { useCanonicalPath } from '@/hooks/useCanonicalPath'
import { paths } from '@/config/paths'
import { useFirstSteps, useTeamDashboardData } from './teamHomeData'

/**
 * « Tableau de bord »: the team page, for everyone (see `TeamHomePage`). The header and the tabs
 * come from the team, already in the cache; the sections from the one dashboard call — its public
 * part for a visitor, whose `role` is null (API-86).
 */
export function TeamDashboardPage({ team }: { team: TeamDetailDto }) {
  const { dashboard } = useTeamDashboardData(team.slug, true)
  const firstSteps = useFirstSteps(team.slug, dashboard.data)

  useCanonicalPath(paths.team(team.slug))

  // The role the sections were built for; the team's own until the response is there. None for a
  // visitor.
  const role = dashboard.data ? (dashboard.data.role ?? undefined) : team.role

  return (
    <TeamLayout
      team={team}
      currentTab="dashboard"
      meta={<DashboardHeaderMeta team={team} role={role} />}
      actions={<DashboardHeaderActions team={team} role={role} />}
    >
      <QueryStateBoundary
        isLoading={dashboard.isLoading}
        isError={dashboard.isError}
        error={dashboard.error}
        onRetry={() => void dashboard.refetch()}
        skeleton={<DashboardSkeleton />}
      >
        {dashboard.data && (
          <TeamDashboard dashboard={dashboard.data} team={team} firstSteps={firstSteps} />
        )}
      </QueryStateBoundary>
    </TeamLayout>
  )
}

function DashboardSkeleton() {
  return (
    <Stack gap="xl">
      <Skeleton height={28} width={240} />
      <Group grow>
        <Skeleton height={96} />
        <Skeleton height={96} />
      </Group>
      <Skeleton height={28} width={200} />
      <Group grow>
        <Skeleton height={220} />
        <Skeleton height={220} />
        <Skeleton height={220} />
      </Group>
    </Stack>
  )
}
