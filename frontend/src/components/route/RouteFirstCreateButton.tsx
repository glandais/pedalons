import { Button } from '@mantine/core'
import type { TeamDetailDto } from '@/api/dto'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useRouteCreateActions } from '@/components/team/dashboard/useTeamCreateActions'

/**
 * The empty route list's button: the first of the team's route creations that is open — the main
 * action of the list's « Créer ▾ » (`RoutesListHeader`), with its label: « Tracer sur la carte »
 * when the planner has room, « Importer des GPX » otherwise. The same rule as the app's empty state
 * (`firstRouteCreateLocation`, docs/LEDGER_*.md WEB-215).
 */
export function RouteFirstCreateButton({ team }: { team: TeamDetailDto }) {
  const actions = useRouteCreateActions(team)
  const first = actions.find((action) => !action.disabledReason)
  if (!first) return null
  const Icon = first.icon
  const common = {
    variant: 'light' as const,
    color: first.color,
    leftSection: <Icon size={16} aria-hidden />,
  }
  return first.to ? (
    <Button {...common} component={PrefetchLink} to={first.to} state={first.state}>
      {first.label}
    </Button>
  ) : (
    <Button {...common} onClick={first.onClick}>
      {first.label}
    </Button>
  )
}
