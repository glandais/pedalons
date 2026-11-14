import { useTranslation } from 'react-i18next'
import { Button, Group, Paper, Text } from '@mantine/core'
import { IconFlagFilled, IconMapPinFilled } from '@tabler/icons-react'
import type { GeoPoint } from '@/api/dto'
import type { SearchedPlace } from '../map/MapSearchControl'

interface FoundPlaceOverlayProps {
  place: SearchedPlace
  /** The end is « Ailleurs »: the place can be the arrival as well as the start. */
  endElsewhere: boolean
  onPick: (mode: 'start' | 'end', point: GeoPoint) => void
}

/**
 * What a place found by the map's search offers: start here, and with an end « Ailleurs » arrive
 * here. A map canvas cannot be clicked from the keyboard, so this is the keyboard's way to place
 * both points. Ledger `WEB-179`.
 */
export function FoundPlaceOverlay({ place, endElsewhere, onPick }: FoundPlaceOverlayProps) {
  const { t } = useTranslation()
  const point = { lat: place.lat, lng: place.lng }
  return (
    <Paper
      shadow="md"
      withBorder
      px="sm"
      py={6}
      pos="absolute"
      bottom={40}
      left="50%"
      style={{ transform: 'translateX(-50%)', zIndex: 5 }}
    >
      <Group gap="sm" wrap="nowrap">
        <Text size="sm" maw={220} truncate>
          {place.label}
        </Text>
        <Button
          size="compact-sm"
          leftSection={<IconMapPinFilled size={14} />}
          onClick={() => onPick('start', point)}
        >
          {t('routeGenerator.start.here')}
        </Button>
        {endElsewhere && (
          <Button
            size="compact-sm"
            variant="default"
            leftSection={<IconFlagFilled size={14} />}
            onClick={() => onPick('end', point)}
          >
            {t('routeGenerator.end.here')}
          </Button>
        )}
      </Group>
    </Paper>
  )
}
