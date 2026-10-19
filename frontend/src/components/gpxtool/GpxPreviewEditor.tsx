import { useCallback, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useMediaMatch } from '@/hooks/useResponsive'
import { Alert, Box, Button, FileInput, Group, Stack, Text, TextInput } from '@mantine/core'
import type { GeoPoint, PlannerState } from '@/api/dto'
import { notifications } from '@mantine/notifications'
import { plannerPayload } from '@/lib/plannerSubmit'
import { RoutePlannerField, type RoutePlannerHandle } from '../planner/RoutePlannerField'
import { isGpxPlannerEnabled } from '@/config/appConfig'

type SourceMode = 'gpx' | 'planner'

interface GpxPreviewEditorProps {
  initialName: string
  /** Existing track ([lng, lat, ele, dist][]); enables the planner when the preview has one track. */
  initialTrack?: number[][]
  /** D+ (m) stored for `initialTrack`. */
  initialAscend?: number
  /** The saved editing state of the preview (control points, pieces): the planner opens on it. */
  initialPlannerState?: PlannerState
  /** Create-from-scratch: planner on an empty map, no GPX upload, no source toggle. */
  create?: boolean
  /**
   * `track` is set when the planner's route is to be saved: its editing state, or its points past
   * the bounds of the state. Absent for a rename, which leaves the track as it is.
   */
  onSubmit: (
    name: string,
    track?: { points?: GeoPoint[]; plannerState?: PlannerState },
    gpxFile?: File
  ) => void | Promise<void>
  onCancel: () => void
  isPending: boolean
}

/**
 * Editor for a GPX preview: rename it and, optionally, redraw its track with the planner or replace
 * it with a fresh GPX upload. A lighter cousin of {@link RouteEditor} — a preview has no team, media,
 * surface type or visibility, so only the name and the track are editable.
 *
 * <p>In {@code create} mode there is no existing preview: the planner starts on an empty map and is
 * the only source (no GPX upload, no toggle), so the caller gets planner points back.
 */
export function GpxPreviewEditor({
  initialName,
  initialTrack,
  initialAscend,
  initialPlannerState,
  create = false,
  onSubmit,
  onCancel,
  isPending,
}: GpxPreviewEditorProps) {
  const { t } = useTranslation()
  // On a finger the preview card already says how many points there are.
  const isCoarse = useMediaMatch('(pointer: coarse)')

  const [name, setName] = useState(initialName)
  // Same rule as RouteEditor, one level up: the domain decides whether drawing is open at all.
  const canUsePlanner = isGpxPlannerEnabled() && (create || !!initialTrack)
  const [sourceMode, setSourceMode] = useState<SourceMode>(canUsePlanner ? 'planner' : 'gpx')
  const [gpxFile, setGpxFile] = useState<File | null>(null)
  const [plannerPoints, setPlannerPoints] = useState<GeoPoint[]>([])
  const [error, setError] = useState<string | null>(null)
  const plannerRef = useRef<RoutePlannerHandle>(null)
  // Bumped by the « draw on the map » button: on a finger it opens the fullscreen editor.
  const [drawRequest, setDrawRequest] = useState(0)

  const handleFileChange = useCallback(
    (file: File | null) => {
      if (file && !/\.gpx$/i.test(file.name)) {
        setError(t('routes.create.validation.invalidFileType'))
        setGpxFile(null)
        return
      }
      setError(null)
      setGpxFile(file)
    },
    [t]
  )

  // The planner read a file: it names the track when the name is still empty.
  const handleImportName = useCallback((importedName: string) => {
    setName((current) => (current.trim() ? current : importedName.trim()))
  }, [])

  const nameValid = name.trim().length >= 3

  const handleSubmit = async () => {
    if (!nameValid) return
    if (create && plannerPoints.length < 2) {
      setError(t('routes.create.validation.pointsRequired'))
      return
    }
    setError(null)
    const payload =
      sourceMode === 'planner' && canUsePlanner
        ? plannerPayload(plannerRef.current?.snapshot(), create)
        : {}
    // The file chosen in the GPX tab, or the one imported in the planner and left untouched
    const file = payload.file ?? (sourceMode === 'gpx' ? gpxFile || undefined : undefined)
    const track =
      payload.plannerState || payload.points
        ? { points: payload.points, plannerState: payload.plannerState }
        : undefined
    await onSubmit(name.trim(), track, file)
    // Only once the save went through: a failed save did not drop anything
    if (payload.tooLarge) {
      notifications.show({ message: t('planner.state.tooLarge'), color: 'yellow' })
    }
  }

  const showPlanner = canUsePlanner && sourceMode === 'planner'

  return (
    <Stack>
      {error && <Alert color="red">{error}</Alert>}

      {/* Track source selector — only when editing a single-track preview; hidden when creating
          from scratch, where the planner is the only source. */}
      {canUsePlanner && !create && (
        <Stack gap="xs">
          <Text size="sm" fw={500}>
            {t('routes.create.form.sourceMode')}
          </Text>
          <Group gap="xs">
            <Button
              variant={sourceMode === 'gpx' ? 'filled' : 'default'}
              onClick={() => setSourceMode('gpx')}
            >
              {t('routes.create.form.sourceModeGpx')}
            </Button>
            <Button
              variant={sourceMode === 'planner' ? 'filled' : 'default'}
              onClick={() => {
                setSourceMode('planner')
                setDrawRequest((n) => n + 1)
              }}
            >
              {t('routes.create.form.sourceModePlanner')}
            </Button>
          </Group>
        </Stack>
      )}

      {/* GPX upload — replaces the track when a file is provided; leave empty to rename only. */}
      {(sourceMode === 'gpx' || !canUsePlanner) && (
        <FileInput
          label={t('routes.create.form.gpxFile')}
          description={t('gpxTools.edit.gpxFileHint')}
          accept=".gpx"
          value={gpxFile}
          onChange={handleFileChange}
        />
      )}

      {showPlanner && (
        <Box>
          <Text size="sm" fw={500} mb="xs" px="md">
            {t('routes.create.form.plannerLabel')}
          </Text>
          <RoutePlannerField
            plannerRef={plannerRef}
            initialState={initialPlannerState}
            onPointsChange={setPlannerPoints}
            initialTrack={initialTrack}
            initialAscend={initialAscend}
            title={name}
            onImportName={handleImportName}
            openRequest={drawRequest}
          />
          {plannerPoints.length > 0 && !isCoarse && (
            <Text size="sm" c="dimmed" mt="xs" px="md">
              {t('routes.create.form.pointCount', { count: plannerPoints.length })}
            </Text>
          )}
        </Box>
      )}

      <TextInput
        label={
          <>
            {t('routes.create.form.name')}{' '}
            <Text span c="red">
              *
            </Text>
          </>
        }
        placeholder={t('routes.create.form.name')}
        value={name}
        onChange={(event) => setName(event.currentTarget.value)}
        error={name.length > 0 && !nameValid ? t('gpxTools.edit.nameTooShort') : undefined}
      />

      <Group justify="flex-end" pt="md">
        <Button variant="default" onClick={onCancel} disabled={isPending}>
          {t('actions.cancelAction')}
        </Button>
        <Button onClick={handleSubmit} disabled={isPending || !nameValid} loading={isPending}>
          {t('actions.save')}
        </Button>
      </Group>
    </Stack>
  )
}
