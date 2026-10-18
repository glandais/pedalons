import { useTranslation } from 'react-i18next'
import { IconLineDashed } from '@tabler/icons-react'
import { MapControlButton, MapControlGroup } from '@/components/map/MapControl'
import { directShortcut } from '@/lib/plannerErrors'

interface DirectModeControlProps {
  directMode: boolean
  onToggle: (on: boolean) => void
}

/**
 * The "Straight line" toggle, in the map's control column (mouse). Its name is constant: the
 * pressed state says whether it is on; the modifier key, held at the moment of a gesture, is not
 * reflected here.
 */
export function DirectModeControl({ directMode, onToggle }: DirectModeControlProps) {
  const { t } = useTranslation()

  return (
    <MapControlGroup>
      <MapControlButton
        label={t('planner.direct.toggle.mouse', { shortcut: directShortcut(t) })}
        icon={<IconLineDashed size={20} />}
        onClick={() => onToggle(!directMode)}
        active={directMode}
      />
    </MapControlGroup>
  )
}
