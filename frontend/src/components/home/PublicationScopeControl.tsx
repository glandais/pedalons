import { SegmentedControl } from '@mantine/core'
import { useTranslation } from 'react-i18next'
import type { PublicationScopeValue } from '@/hooks/filters/publicationFilters'
import { useAuth } from '@/hooks/useAuth'

interface PublicationScopeControlProps {
  value: PublicationScopeValue
  onChange: (value: PublicationScopeValue) => void
}

/**
 * « Tout / Je participe / Plus tôt » over a publication feed (RL15): « Tout » is read in two
 * sections, « À venir » then « Plus tôt », so there is no « À venir » to pick; « Plus tôt » is the
 * second section alone, reached in one gesture however long the first one runs. Its label is the
 * section's heading, the same word.
 *
 * « Je participe » is for a signed-in reader only: the contract states that `participating` yields
 * nothing for an anonymous visitor, who gets « Tout / Plus tôt ».
 */
export function PublicationScopeControl({ value, onChange }: PublicationScopeControlProps) {
  const { t } = useTranslation()
  const { isAuthenticated } = useAuth()

  return (
    <SegmentedControl
      value={value}
      onChange={(next) => onChange(next as PublicationScopeValue)}
      data={[
        { value: 'all', label: t('publications.scope.all') },
        ...(isAuthenticated ? [{ value: 'me', label: t('publications.scope.me') }] : []),
        { value: 'earlier', label: t('list.sections.earlier') },
      ]}
      aria-label={t('publications.scope.label')}
    />
  )
}
