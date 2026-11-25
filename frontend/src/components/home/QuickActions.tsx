import { useTranslation } from 'react-i18next'
import { Group, Select } from '@mantine/core'
import { useLocalStorage } from '@mantine/hooks'
import type { TeamDetailDto } from '@/api/dto'
import { CreateSplitButton } from '@/components/common/CreateSplitButton'
import { useTeamCreateActions } from '@/components/team/dashboard/useTeamCreateActions'
import { canOrganize } from './memberHomeHelpers'
import { useGetTeam } from '@/api/endpoints/teams/teams'
import { CLIENT_ONLY_QUERY } from '@/lib/prefetchAudit'

interface QuickActionsProps {
  /** The member's teams (« Mes équipes »). Only those they organize or administer count. */
  teams: TeamDetailDto[] | undefined
}

/** The last team picked, per browser: the next visit starts there. */
const CREATE_TEAM_STORAGE_KEY = 'pedalons.home.createTeam'

/**
 * The organizer's create button on the member home: the team's dashboard button (« Créer une
 * sortie ▾ », same actions, same sections — `useTeamCreateActions`), preceded by a team picker when
 * they organize several teams. Nothing for a plain member, nor for a team with no module to create
 * in. A team listing carries no planner quota: the selected team's own detail is read for it, so
 * « Tracer sur la carte » and « Générer un parcours » are disabled with their reason here as on the
 * team's pages (docs/LEDGER_*.md WEB-217). One team read, the selected one; until it answers, the
 * listing's copy is used.
 */
export function QuickActions({ teams }: QuickActionsProps) {
  const { t } = useTranslation()
  // Read in an effect (the default): the server renders the first team, as the client's first pass.
  const [storedSlug, setStoredSlug] = useLocalStorage<string | null>({
    key: CREATE_TEAM_STORAGE_KEY,
    defaultValue: null,
  })
  const organized = (teams ?? []).filter(
    (team) => canOrganize(team) && (team.enableRoutes || team.enablePosts)
  )
  if (organized.length === 0) return null

  const selected = organized.find((team) => team.slug === storedSlug) ?? organized[0]

  return (
    <Group gap="xs" role="group" aria-label={t('home.actions.label')}>
      {organized.length > 1 && (
        <Select
          aria-label={t('home.actions.pickTeam')}
          data={organized.map((team) => ({ value: team.slug, label: team.name }))}
          value={selected.slug}
          onChange={(slug) => slug && setStoredSlug(slug)}
          allowDeselect={false}
          comboboxProps={{ withinPortal: true }}
          w={200}
        />
      )}
      <TeamCreateButton team={selected} />
    </Group>
  )
}

function TeamCreateButton({ team }: { team: TeamDetailDto }) {
  const { data: detail } = useGetTeam(team.slug, {
    query: { enabled: team.enableRoutes, meta: { [CLIENT_ONLY_QUERY]: true } },
  })
  const actions = useTeamCreateActions(detail ?? team)
  return <CreateSplitButton actions={actions} />
}
