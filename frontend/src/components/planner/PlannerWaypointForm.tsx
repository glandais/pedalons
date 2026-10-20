import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  Button,
  Group,
  Modal,
  Radio,
  SimpleGrid,
  Stack,
  Text,
  Textarea,
  TextInput,
  ThemeIcon,
} from '@mantine/core'
import { WaypointType } from '@/api/dto'
import { useUnits } from '@/hooks/useUnits'
import { WAYPOINT_TYPE_COLORS } from '@/lib/badgeColors.generated'
import { WAYPOINT_DESCRIPTION_MAX, WAYPOINT_NAME_MAX } from '@/lib/plannerWaypoints'
import { waypointTypeOf } from '@/lib/waypoints'
import { WAYPOINT_ICONS } from '../map/waypointIcons'

export interface WaypointFormFields {
  type: WaypointType
  name: string
  description: string
}

interface PlannerWaypointFormProps {
  opened: boolean
  mode: 'create' | 'edit'
  /** The point being edited; absent when creating (REGROUP is then the type pre-selected). */
  initial?: WaypointFormFields
  /** Metres along the route; null: off the track; undefined: not known. */
  distance?: number | null
  /** Edit only, off the track, with a route to put it back on. */
  onSnap?: () => void
  /** Edit only. */
  onDelete?: () => void
  onSubmit: (fields: WaypointFormFields) => void
  onClose: () => void
  /** A calculation is in flight: the operations are refused until it lands. */
  busy?: boolean
}

const TYPES = Object.values(WaypointType)

/**
 * The form of a route point of the planner (WEB-100, C3e): type, name, description. A Mantine modal
 * (a popover would sit under a virtual keyboard); the inner `<form>` stops its submit event, which
 * would otherwise cross the portal up to the `<form>` of the route editor and save the route.
 */
export function PlannerWaypointForm(props: PlannerWaypointFormProps) {
  const { t } = useTranslation()
  return (
    <Modal
      opened={props.opened}
      onClose={props.onClose}
      title={t(
        props.mode === 'create'
          ? 'planner.waypoint.form.titleAdd'
          : 'planner.waypoint.form.titleEdit'
      )}
      zIndex={400}
      size="sm"
      centered
    >
      <FormBody {...props} />
    </Modal>
  )
}

function FormBody({
  mode,
  initial,
  distance,
  onSnap,
  onDelete,
  onSubmit,
  onClose,
  busy,
}: PlannerWaypointFormProps) {
  const { t } = useTranslation()
  const { distance: formatDistance } = useUnits()
  const [type, setType] = useState<WaypointType>(initial?.type ?? WaypointType.REGROUP)
  const [name, setName] = useState(initial?.name ?? '')
  const [description, setDescription] = useState(initial?.description ?? '')
  // A name brought by an import may be longer than the editor's bound: it is not cut by force
  const nameMax = Math.max(WAYPOINT_NAME_MAX, initial?.name.length ?? 0)

  return (
    <form
      onSubmit={(event) => {
        // A React event crosses portals: without this the route editor's <form> would be
        // submitted too, and save the route
        event.preventDefault()
        event.stopPropagation()
        if (busy) return
        onSubmit({ type, name: name.trim(), description: description.trim() })
      }}
    >
      <Stack gap="md">
        <Radio.Group
          value={type}
          onChange={(value) => setType(waypointTypeOf(value))}
          label={t('planner.waypoint.form.type')}
        >
          <SimpleGrid cols={{ base: 3, xs: 4 }} spacing={6} mt={6}>
            {TYPES.map((candidate) => {
              const { Icon } = WAYPOINT_ICONS[candidate]
              return (
                <Radio.Card
                  key={candidate}
                  value={candidate}
                  radius="sm"
                  p={6}
                  aria-label={t(`routes.waypoints.type.${candidate}`)}
                  // Radio.Card has no checked look of its own: the picked type must show
                  style={
                    candidate === type
                      ? {
                          borderColor: 'var(--mantine-primary-color-filled)',
                          backgroundColor: 'var(--mantine-primary-color-light)',
                        }
                      : undefined
                  }
                >
                  <Stack align="center" gap={2}>
                    <ThemeIcon
                      variant="filled"
                      color={WAYPOINT_TYPE_COLORS[candidate]}
                      radius="xl"
                      size={28}
                      aria-hidden
                    >
                      <Icon size={16} />
                    </ThemeIcon>
                    <Text size="xs" ta="center" lh={1.2}>
                      {t(`routes.waypoints.type.${candidate}`)}
                    </Text>
                  </Stack>
                </Radio.Card>
              )
            })}
          </SimpleGrid>
        </Radio.Group>

        <Stack gap={4}>
          <TextInput
            label={t('planner.waypoint.form.name')}
            value={name}
            onChange={(event) => setName(event.currentTarget.value)}
            maxLength={nameMax}
            description={t('planner.waypoint.form.counter', { length: name.length, max: nameMax })}
            data-autofocus
          />
          <Text size="xs" c="dimmed">
            {t('planner.waypoint.form.nameHint')}
          </Text>
        </Stack>

        <Textarea
          label={t('planner.waypoint.form.description')}
          value={description}
          onChange={(event) => setDescription(event.currentTarget.value)}
          maxLength={WAYPOINT_DESCRIPTION_MAX}
          autosize
          minRows={2}
          maxRows={6}
          description={t('planner.waypoint.form.counter', {
            length: description.length,
            max: WAYPOINT_DESCRIPTION_MAX,
          })}
        />

        {distance !== undefined && (
          <Stack gap={4}>
            <Text size="xs" c="dimmed">
              {distance !== null
                ? t('routes.waypoints.fromStart', { distance: formatDistance(distance) })
                : t('planner.waypoint.offTrack.hint')}
            </Text>
            {distance === null && onSnap && (
              <Button size="compact-sm" variant="light" onClick={onSnap} disabled={busy}>
                {t('planner.waypoint.snap')}
              </Button>
            )}
          </Stack>
        )}

        {/* Wraps on a narrow screen rather than cutting « Supprimer le point de parcours » */}
        <Group justify={mode === 'edit' && onDelete ? 'space-between' : 'flex-end'} gap="xs">
          {mode === 'edit' && onDelete && (
            <Button variant="light" color="red" onClick={onDelete} disabled={busy}>
              {t('planner.waypoint.form.delete')}
            </Button>
          )}
          <Group gap="xs" wrap="nowrap" ml="auto">
            <Button variant="default" onClick={onClose}>
              {t('actions.cancelAction')}
            </Button>
            <Button type="submit" disabled={busy}>
              {mode === 'create' ? t('planner.waypoint.form.add') : t('actions.save')}
            </Button>
          </Group>
        </Group>
      </Stack>
    </form>
  )
}
