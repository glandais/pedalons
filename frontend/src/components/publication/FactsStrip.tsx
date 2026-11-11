import { useTranslation } from 'react-i18next'
import { Group, Text } from '@mantine/core'
import { usePreferencesStore } from '@/store/preferencesStore'
import { distanceText, formatDistance, formatElevation } from '@/utils/unitFormat'
import type { PublicationKind } from './publicationKind'
import type { FactRange, PublicationFacts } from './publicationFacts'

interface FactsStripProps {
  kind: PublicationKind
  facts: PublicationFacts
}

/**
 * The facts under a ride's or a trip's departure (docs/LEDGER_*.md WEB-155): how many groups or
 * stages, how many people, how far and how much climb — a span for a ride's groups, a total for a
 * trip's stages (`rideFacts`, `tripFacts`).
 */
export function FactsStrip({ kind, facts }: FactsStripProps) {
  const { t, i18n } = useTranslation()
  const language = i18n.language
  const unitSystem = usePreferencesStore((state) => state.unitSystem)
  const imperial = unitSystem === 'IMPERIAL'

  const distance = (range: FactRange) => {
    const min = formatDistance(range.min, unitSystem, language)
    const max = formatDistance(range.max, unitSystem, language)
    if (min === max) return distanceText(range.max, unitSystem, language)
    return t(
      imperial ? 'publication.facts.distanceRange_imperial' : 'publication.facts.distanceRange',
      { min, max }
    )
  }
  const elevation = (range: FactRange) => {
    const min = formatElevation(range.min, unitSystem, language)
    const max = formatElevation(range.max, unitSystem, language)
    if (min === max) {
      return t(imperial ? 'publication.facts.elevation_imperial' : 'publication.facts.elevation', {
        elevation: max,
      })
    }
    return t(
      imperial ? 'publication.facts.elevationRange_imperial' : 'publication.facts.elevationRange',
      { min, max }
    )
  }

  return (
    <Group gap="lg" wrap="wrap" data-testid="publication-facts">
      {facts.childCount > 0 && (
        <Text size="sm" c="dimmed">
          {kind === 'ride'
            ? t('groups.groupCount', { count: facts.childCount })
            : t('trips.card.stageCount', { count: facts.childCount })}
        </Text>
      )}
      <Text size="sm" c="dimmed">
        {t('participantCount', { count: facts.participantCount })}
      </Text>
      {facts.distance && (
        <Text size="sm" c="dimmed">
          {distance(facts.distance)}
        </Text>
      )}
      {facts.elevationGain && (
        <Text size="sm" c="dimmed">
          {elevation(facts.elevationGain)}
        </Text>
      )}
    </Group>
  )
}
