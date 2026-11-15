import { useTranslation } from 'react-i18next'
import { Button, Group, Modal, Text } from '@mantine/core'
import type { RoutePlannerState } from '@/hooks/useRoutePlanner'
import { PlannerWaypointForm } from './PlannerWaypointForm'
import type { PlannerEditing } from './usePlannerEditing'

interface PlannerEditingDialogsProps {
  planner: RoutePlannerState
  editing: PlannerEditing
}

/**
 * The dialogs of {@link usePlannerEditing}, the same in every host of the planner: what to do
 * with a GPX file chosen over an existing route (replace it, or add the file after it), and the
 * form of a route point.
 */
export function PlannerEditingDialogs({ planner, editing }: PlannerEditingDialogsProps) {
  const { t } = useTranslation()
  const { route, isLoading } = planner
  const { waypointForm, editedWaypoint, pendingFile } = editing
  return (
    <>
      <Modal
        opened={pendingFile !== null}
        onClose={editing.dismissPendingFile}
        title={t('planner.import.choice.title')}
        zIndex={400}
        centered
      >
        <Text size="sm" mb="md">
          {t('planner.import.choice.text', { name: pendingFile?.name ?? '' })}
        </Text>
        <Group justify="flex-end" gap="xs">
          <Button variant="default" onClick={editing.dismissPendingFile}>
            {t('actions.cancelAction')}
          </Button>
          <Button variant="default" onClick={() => editing.choosePendingFile('append')}>
            {t('planner.import.append')}
          </Button>
          <Button onClick={() => editing.choosePendingFile('replace')}>
            {t('planner.import.replace')}
          </Button>
        </Group>
      </Modal>

      <PlannerWaypointForm
        key={editing.waypointFormSeq}
        opened={editing.waypointFormOpen}
        mode={waypointForm?.mode ?? 'create'}
        initial={
          editedWaypoint
            ? {
                type: editedWaypoint.type,
                name: editedWaypoint.name,
                description: editedWaypoint.description,
              }
            : undefined
        }
        distance={
          waypointForm?.mode === 'create' ? waypointForm.at.distance : editedWaypoint?.distance
        }
        onSnap={
          editedWaypoint && editedWaypoint.distance === null && route.points.length >= 2
            ? editing.snapWaypoint
            : undefined
        }
        onDelete={editing.deleteWaypointFromForm}
        onSubmit={editing.submitWaypointForm}
        onClose={editing.closeWaypointForm}
        busy={isLoading}
      />
    </>
  )
}
