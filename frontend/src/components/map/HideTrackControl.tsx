import { useTranslation } from 'react-i18next'
import { IconRoute, IconRouteOff } from '@tabler/icons-react'
import { MapControlButton, MapControlGroup } from './MapControl'

interface HideTrackControlProps {
  hidden: boolean
  onToggle: () => void
}

/**
 * Toggles the GPX trace and its markers from the map itself — the same state the "h" shortcut
 * drives (`useHideTrackKey`), which the tooltip advertises.
 */
export function HideTrackControl({ hidden, onToggle }: HideTrackControlProps) {
  const { t } = useTranslation()
  const label = hidden ? t('map.hideTrack.show') : t('map.hideTrack.hide')

  return (
    <MapControlGroup zone="display" slot="hide-track">
      <MapControlButton
        label={label}
        icon={hidden ? <IconRouteOff size={20} /> : <IconRoute size={20} />}
        onClick={onToggle}
        active={hidden}
      />
    </MapControlGroup>
  )
}
