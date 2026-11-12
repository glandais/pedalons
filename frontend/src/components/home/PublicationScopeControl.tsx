import { SegmentedControl } from '@mantine/core'
import { useTranslation } from 'react-i18next'
import type { PublicationScopeValue } from '@/hooks/filters/publicationFilters'
import { useAuth } from '@/hooks/useAuth'

interface PublicationScopeControlProps {
  value: PublicationScopeValue
  onChange: (value: PublicationScopeValue) => void
}

/**
 * « Tout / Je participe » over a publication feed (RL15): « Tout » is read in two sections,
 * « À venir » then « Plus tôt », so there is no « À venir » to pick any more.
 *
 * Hidden from anonymous visitors: the contract states that `participating` yields nothing for
 * them, so « Je participe » would be a dead end, and « Tout » alone is no choice.
 */
export function PublicationScopeControl({ value, onChange }: PublicationScopeControlProps) {
  const { t } = useTranslation()
  const { isAuthenticated } = useAuth()

  if (!isAuthenticated) return null

  return (
    <SegmentedControl
      value={value}
      onChange={(next) => onChange(next as PublicationScopeValue)}
      data={[
        { value: 'all', label: t('publications.scope.all') },
        { value: 'me', label: t('publications.scope.me') },
      ]}
      aria-label={t('publications.scope.label')}
    />
  )
}
