import { useTranslation } from 'react-i18next'
import { Group, Text } from '@mantine/core'
import { IconMapPin, IconUsers } from '@tabler/icons-react'
import { groupTitle } from '@/utils/groupTitle'

interface GroupPlaceLineProps {
  /** The name of the group the reader joined — left out when they are not registered. */
  group?: string | null
  /** The meeting place's name, never its address (MOB-136). */
  place?: string | null
}

/**
 * The line under « Départ 09:30 » (docs/LEDGER_*.md WEB-167, R11; KIT §9 « Lieu et groupe »):
 * « Groupe B · Place de la Mairie » — the group only when the reader joined one, the place only when
 * the ride has one, each said once. Nothing when neither is known.
 */
export function GroupPlaceLine({ group, place }: GroupPlaceLineProps) {
  const { t } = useTranslation()
  if (!group && !place) return null
  return (
    <Group gap={4} wrap="nowrap" align="flex-start" data-testid="group-place-line">
      {group ? (
        <IconUsers size={16} aria-hidden style={{ flexShrink: 0, marginTop: 2 }} />
      ) : (
        <IconMapPin size={16} aria-hidden style={{ flexShrink: 0, marginTop: 2 }} />
      )}
      <Text size="sm" c="dimmed" style={{ minWidth: 0 }}>
        {group && (
          <Text span inherit fw={600} c="var(--mantine-color-text)">
            {groupTitle(group, t)}
          </Text>
        )}
        {group && place && ' · '}
        {place}
      </Text>
    </Group>
  )
}
