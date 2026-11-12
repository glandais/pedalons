import { useTranslation } from 'react-i18next'
import { Select } from '@mantine/core'
import { useAuth } from '@/hooks/useAuth'
import type { MembershipFilterValue } from '@/hooks/filters/membership'
import { ALL_MY_TEAMS, membershipLabel } from './membershipLabel'

interface ScopeSelectProps<V extends string> {
  value: V
  onChange: (value: V) => void
  data: { value: V; label: string }[]
}

/**
 * The scope of a cross-team list: one selector, the same width and the same name — « Portée » —
 * on every list that has one (RL2, docs/LEDGER_*.md WEB-175).
 */
function ScopeSelect<V extends string>({ value, onChange, data }: ScopeSelectProps<V>) {
  const { t } = useTranslation()
  return (
    <Select
      value={value}
      onChange={(next) => next !== null && onChange(next as V)}
      data={data}
      aria-label={t('filters.scope.label')}
      allowDeselect={false}
      w={{ base: '100%', sm: 200 }}
    />
  )
}

const MEMBERSHIP_VALUES = ['all', 'member', 'organizer', 'admin'] as const

interface MembershipSelectProps {
  value: MembershipFilterValue
  onChange: (value: MembershipFilterValue) => void
}

/**
 * « Toutes les équipes / Membre / Organisateur / Administrateur »: the home feed, Explorer (list
 * and map) and the team list. Nothing to offer a logged-out visitor.
 */
export function MembershipSelect({ value, onChange }: MembershipSelectProps) {
  const { t } = useTranslation()
  const { isAuthenticated } = useAuth()

  if (!isAuthenticated) {
    return null
  }

  return (
    <ScopeSelect
      value={value}
      onChange={onChange}
      data={MEMBERSHIP_VALUES.map((membership) => ({
        value: membership,
        label: membershipLabel(t, membership),
      }))}
    />
  )
}

interface TeamScopeSelectProps {
  /** The reader's teams, in the order they are offered. */
  teams: { slug: string; name: string }[]
  /** A team's slug, or {@link ALL_MY_TEAMS}. */
  value: string
  onChange: (value: string) => void
}

/**
 * « Toutes mes équipes / {équipe}… »: the personal calendar only — the one cross-team list with no
 * page per team (RL2, RL3). Elsewhere the team's own page is the way to one team.
 */
export function TeamScopeSelect({ teams, value, onChange }: TeamScopeSelectProps) {
  const { t } = useTranslation()
  return (
    <ScopeSelect
      value={value}
      onChange={onChange}
      data={[
        { value: ALL_MY_TEAMS, label: t('filters.scope.allMyTeams') },
        ...teams.map((team) => ({ value: team.slug, label: team.name })),
      ]}
    />
  )
}
