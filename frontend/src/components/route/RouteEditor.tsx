import { useState, useCallback } from 'react'
import { useForm } from '@mantine/form'
import { zodFormValidator } from '@/lib/formUtils'
import { useTranslation } from 'react-i18next'
import { useMediaMatch } from '@/hooks/useResponsive'
import {
  TextInput,
  Radio,
  Stack,
  Group,
  Button,
  Text,
  Select,
  Alert,
  FileInput,
  Box,
} from '@mantine/core'
import { RouteRequest, SurfaceType } from '@/api/dto'
import type { TeamDetailDto, GeoPoint } from '@/api/dto'
import { MediaEditor } from '../common/MediaEditor'
import { SlugEditor } from '../common/SlugEditor'
import { paths } from '@/config/paths'
import { RoutePlannerField } from '../planner/RoutePlannerField'
import { CreateRouteBody } from '@/api/zod/routes/routes.zod'
import { TagPicker } from '@/components/tag'

export type RouteSourceMode = 'gpx' | 'planner'

const routeSchema = CreateRouteBody.shape.route.unwrap()

interface RouteEditorProps {
  team: TeamDetailDto
  teamSlug: string
  initialValues: RouteRequest
  onSubmit: (data: RouteRequest, gpxFile?: File) => void | Promise<void>
  onCancel: () => void
  isPending: boolean
  error?: Error | null
  isCreateMode?: boolean
  initialTrack?: number[][]
  submitButtonText?: string
  cancelButtonText?: string
  showCancelButton?: boolean
  currentSlug?: string
  onSlugChange?: (newSlug: string) => Promise<void>
  canEditSlug?: boolean
  /** Tells the host dialog whether the planner's fullscreen editor is open (its Escape must wait). */
  onPlannerFullscreenChange?: (opened: boolean) => void
}

export function RouteEditor({
  team,
  teamSlug,
  initialValues,
  onSubmit,
  onCancel,
  isPending,
  error: _error,
  isCreateMode = false,
  initialTrack,
  submitButtonText,
  cancelButtonText,
  showCancelButton = true,
  currentSlug,
  onSlugChange,
  canEditSlug = false,
  onPlannerFullscreenChange,
}: RouteEditorProps) {
  const { t } = useTranslation()
  // On a finger the preview card already says how many points there are.
  const isCoarse = useMediaMatch('(pointer: coarse)')

  const form = useForm<RouteRequest>({
    validate: zodFormValidator<RouteRequest>(routeSchema),
    initialValues,
    validateInputOnChange: true,
  })

  // Drawing is a per-team feature the platform admin opens; when it is closed the GPX file input
  // is the only source, and the backend refuses a payload carrying planner points anyway.
  const canUsePlanner = team.enableRoutePlanner && (isCreateMode || !!initialTrack)
  const [sourceMode, setSourceMode] = useState<RouteSourceMode>(
    canUsePlanner && !isCreateMode ? 'planner' : 'gpx'
  )

  const name = form.values.name
  // Bumped by the « draw on the map » button: on a finger it opens the fullscreen editor.
  const [drawRequest, setDrawRequest] = useState(0)

  const [gpxFile, setGpxFile] = useState<File | null>(null)
  const [plannerPoints, setPlannerPoints] = useState<GeoPoint[]>([])
  const [error, setError] = useState<string | null>(null)

  const handleFileChange = useCallback(
    (file: File | null) => {
      if (!name && file?.name) {
        const defaultName = file.name.replace(/\.gpx$/i, '')
        form.setFieldValue('name', defaultName)
      }
      if (file) {
        if (!/\.gpx$/i.test(file.name)) {
          setError(t('routes.create.validation.invalidFileType'))
          setGpxFile(null)
          return
        }
        setError(null)
        setGpxFile(file)
      } else {
        setGpxFile(null)
      }
    },
    [t, form, name]
  )

  const handleSubmit = async (values: RouteRequest) => {
    if (isCreateMode) {
      if (sourceMode === 'gpx' && !gpxFile) {
        setError(t('routes.create.validation.fileRequired'))
        return
      }
      if (sourceMode === 'planner' && plannerPoints.length < 2) {
        setError(t('routes.create.validation.pointsRequired'))
        return
      }
    }

    setError(null)

    onSubmit(
      {
        ...values,
        points: sourceMode === 'planner' ? plannerPoints : undefined,
      },
      sourceMode === 'gpx' ? gpxFile || undefined : undefined
    )
  }

  const showPlanner = canUsePlanner && sourceMode === 'planner'

  return (
    <form
      onSubmit={(event) => {
        // A React event bubbles through portals: in CreateRouteModal, this form sits inside the
        // ride's or the trip's own <form>, which would be submitted too — creating the ride.
        event.stopPropagation()
        form.onSubmit(handleSubmit)(event)
      }}
    >
      <Stack>
        {error && <Alert color="red">{error}</Alert>}

        {/* Route Source - Mode selector */}
        {canUsePlanner && (
          <Stack gap="xs">
            <Text size="sm" fw={500}>
              {t('routes.create.form.sourceMode')}{' '}
              {isCreateMode && (
                <Text span c="red">
                  *
                </Text>
              )}
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

        {/* GPX File Upload */}
        {(sourceMode === 'gpx' || !canUsePlanner) && (
          <FileInput
            label={
              <>
                {t('routes.create.form.gpxFile')}{' '}
                {isCreateMode && sourceMode === 'gpx' && (
                  <Text span c="red">
                    *
                  </Text>
                )}
              </>
            }
            description={t('routes.create.form.gpxFileHint')}
            accept=".gpx"
            value={gpxFile}
            onChange={handleFileChange}
          />
        )}

        {/* Route Planner */}
        {showPlanner && (
          <Box>
            <Text size="sm" fw={500} mb="xs" px="md">
              {t('routes.create.form.plannerLabel')}{' '}
              {isCreateMode && (
                <Text span c="red">
                  *
                </Text>
              )}
            </Text>
            <RoutePlannerField
              onPointsChange={setPlannerPoints}
              initialTrack={initialTrack}
              teamSlug={team.slug}
              teamLocation={team.geometry?.coordinates as [number, number] | undefined}
              title={name}
              onFullscreenChange={onPlannerFullscreenChange}
              openRequest={drawRequest}
            />
            {plannerPoints.length > 0 && !isCoarse && (
              <Text size="sm" c="dimmed" mt="xs" px="md">
                {t('routes.create.form.pointCount', { count: plannerPoints.length })}
              </Text>
            )}
          </Box>
        )}

        {/* Name */}
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
          {...form.getInputProps('name')}
        />

        {/* Slug Editor (only in edit mode) */}
        {currentSlug && onSlugChange && (
          <SlugEditor
            currentSlug={currentSlug}
            baseUrl={paths.route(teamSlug, '')}
            onSlugChange={onSlugChange}
            disabled={!canEditSlug}
          />
        )}

        {/* Description */}
        <Stack gap="xs">
          <Text size="sm" fw={500}>
            {t('form.description')}
          </Text>
          <MediaEditor
            value={form.values.media}
            onChange={(val) => form.setFieldValue('media', val)}
            placeholder={t('form.description')}
            minHeight="150px"
            disabled={isPending}
            ariaLabel={t('form.description')}
            teamSlug={teamSlug}
          />
        </Stack>

        {/* Surface Type */}
        <Select
          label={t('routes.create.form.surfaceType')}
          value={form.values.surfaceType}
          onChange={(val) => form.setFieldValue('surfaceType', val as SurfaceType)}
          data={[
            { value: SurfaceType.ROAD, label: t('routes.surfaceType.ROAD') },
            { value: SurfaceType.GRAVEL, label: t('routes.surfaceType.GRAVEL') },
            { value: SurfaceType.MTB, label: t('routes.surfaceType.MTB') },
            { value: SurfaceType.MIXED, label: t('routes.surfaceType.MIXED') },
          ]}
        />

        {/* Visibility */}
        <TagPicker
          teamSlug={teamSlug}
          type="ROUTE"
          value={form.values.tagIds}
          onChange={(ids) => form.setFieldValue('tagIds', ids)}
          disabled={isPending}
        />

        {team.visibility !== 'TEAM' && (
          <Radio.Group label={t('visibility.label')} {...form.getInputProps('visibility')}>
            <Stack gap="xs" mt="xs">
              <Radio value="TEAM" label={t('visibility.team')} />
              <Radio value="PUBLIC_UNLISTED" label={t('visibility.public_unlisted')} />
              <Radio value="PUBLIC" label={t('visibility.public')} />
            </Stack>
          </Radio.Group>
        )}

        {/* Submit Buttons */}
        <Group justify="flex-end" pt="md">
          {showCancelButton && (
            <Button variant="default" onClick={onCancel} disabled={isPending}>
              {cancelButtonText || t('actions.cancelAction')}
            </Button>
          )}
          <Button
            type="submit"
            disabled={
              isPending ||
              !form.isValid() ||
              (isCreateMode && sourceMode === 'gpx' && !gpxFile) ||
              (isCreateMode && sourceMode === 'planner' && plannerPoints.length < 2)
            }
            loading={isPending}
          >
            {submitButtonText || t('routes.create.submit')}
          </Button>
        </Group>
      </Stack>
    </form>
  )
}
