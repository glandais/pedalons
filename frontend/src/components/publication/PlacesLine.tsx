import { useTranslation } from 'react-i18next'
import { Group, Stack, Text } from '@mantine/core'
import { IconMapPin } from '@tabler/icons-react'

interface Place {
  name: string
  address?: string
}

interface PlacesLineProps {
  /** Leave it out where the departure block already names the meeting point. */
  start?: Place | null
  end?: Place | null
}

/**
 * The start and the end of a ride, a group, a trip or a stage, in one rendering
 * (docs/LEDGER_*.md WEB-155): green pin for the start, red for the end, the name, its address
 * dimmed. Draws nothing without a place.
 */
export function PlacesLine({ start, end }: PlacesLineProps) {
  const { t } = useTranslation()
  if (!start && !end) return null
  return (
    <Stack gap={4}>
      {start && <PlaceRow place={start} label={t('startPlace')} color="green" />}
      {end && <PlaceRow place={end} label={t('endPlace')} color="red" />}
    </Stack>
  )
}

function PlaceRow({ place, label, color }: { place: Place; label: string; color: string }) {
  const { t } = useTranslation()
  return (
    <Group gap="xs" wrap="nowrap" align="flex-start">
      <IconMapPin
        size={16}
        color={`var(--mantine-color-${color}-text)`}
        aria-hidden
        style={{ flexShrink: 0, marginTop: 2 }}
      />
      <Text size="sm">
        <Text span fw={500} c={`var(--mantine-color-${color}-text)`}>
          {t('publication.places.label', { label })}
        </Text>{' '}
        {place.name}
        {place.address && (
          <Text span c="dimmed">
            {' '}
            ({place.address})
          </Text>
        )}
      </Text>
    </Group>
  )
}
