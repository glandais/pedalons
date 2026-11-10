import { useTranslation } from 'react-i18next'
import { IconArrowBackUp, IconArrowForwardUp } from '@tabler/icons-react'
import { MapControlButton, MapControlGroup } from '@/components/map/MapControl'

interface UndoRedoControlProps {
  canUndo: boolean
  canRedo: boolean
  onUndo: () => void
  onRedo: () => void
}

/** Planner history, in the map's camera column, after the zoom and fullscreen buttons. */
export function UndoRedoControl({ canUndo, canRedo, onUndo, onRedo }: UndoRedoControlProps) {
  const { t } = useTranslation()

  return (
    <MapControlGroup zone="camera" slot="undo-redo">
      <MapControlButton
        label={t('planner.undo')}
        icon={<IconArrowBackUp size={20} />}
        onClick={onUndo}
        disabled={!canUndo}
      />
      <MapControlButton
        label={t('planner.redo')}
        icon={<IconArrowForwardUp size={20} />}
        onClick={onRedo}
        disabled={!canRedo}
      />
    </MapControlGroup>
  )
}
