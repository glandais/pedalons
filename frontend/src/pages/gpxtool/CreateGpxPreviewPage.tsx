import { useTranslation } from 'react-i18next'
import { Navigate, useNavigate } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { Stack, Text, Title } from '@mantine/core'
import { notifications } from '@mantine/notifications'
import type { GeoPoint, PlannerState, WaypointRequest } from '@/api/dto'
import {
  getListMyPreviewsQueryKey,
  useCreatePreview,
  useCreatePreviewFromPoints,
  useUpdatePreview,
} from '@/api/endpoints/gpx-previews/gpx-previews'
import { GpxPreviewEditor } from '@/components/gpxtool/GpxPreviewEditor'
import { paths } from '@/config/paths'
import { isGpxPlannerEnabled } from '@/config/appConfig'

/**
 * Draws a GPX preview from scratch: an empty planner map, a name, and nothing else. On submit the
 * planner's editing state (already routed on the frontend) is sent to the backend, which runs the same
 * elevation/climb pipeline as an uploaded file and returns a shareable preview.
 */
export function CreateGpxPreviewPage() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const createMutation = useCreatePreviewFromPoints()
  // A file imported in the planner and saved untouched goes through the upload, like any file
  const createFromFileMutation = useCreatePreview()
  const renameMutation = useUpdatePreview()

  const handleSubmit = async (
    name: string,
    track?: { points?: GeoPoint[]; plannerState?: PlannerState },
    gpxFile?: File,
    waypoints?: WaypointRequest[]
  ) => {
    if (gpxFile) {
      const created = await createFromFileMutation.mutateAsync({ data: { gpxFile } })
      // The upload names the preview after the file: the name typed in the form wins
      // (the two calls are not atomic: if the rename fails the preview exists, so go to it
      // rather than leave the form open for a submit that would create a second one). The route
      // points the user edited ride the same call: the upload takes no list.
      let renamed = true
      if (name !== created.name || waypoints) {
        try {
          await renameMutation.mutateAsync({
            previewId: created.id,
            data: { preview: { name, waypoints } },
          })
        } catch {
          renamed = false
        }
      }
      queryClient.invalidateQueries({ queryKey: getListMyPreviewsQueryKey() })
      notifications.show(
        renamed
          ? { message: t('gpxTools.createFromScratch.created'), color: 'green' }
          : { message: t('gpxTools.createFromScratch.renameFailed'), color: 'yellow' }
      )
      navigate(paths.gpxToolsView(created.id))
      return
    }
    if (!track?.plannerState && (!track?.points || track.points.length < 2)) return

    const preview = await createMutation.mutateAsync(
      { data: { name, points: track.points, plannerState: track.plannerState, waypoints } },
      {
        onSuccess: () => {
          // Refresh "my files": the key prefix matches every paginated variant.
          queryClient.invalidateQueries({ queryKey: getListMyPreviewsQueryKey() })
          notifications.show({ message: t('gpxTools.createFromScratch.created'), color: 'green' })
        },
      }
    )
    navigate(paths.gpxToolsView(preview.id))
  }

  // The card that leads here is hidden when the domain closes the planner, but the URL stays
  // reachable — send it back to the hub rather than rendering an editor that cannot submit.
  if (!isGpxPlannerEnabled()) {
    return <Navigate to={paths.gpxTools()} replace />
  }

  return (
    <Stack>
      <Stack gap="xs">
        <Title order={1}>{t('gpxTools.createFromScratch.title')}</Title>
        <Text c="dimmed">{t('gpxTools.createFromScratch.subtitle')}</Text>
      </Stack>

      <GpxPreviewEditor
        create
        initialName=""
        onSubmit={handleSubmit}
        onCancel={() => navigate(paths.gpxTools())}
        isPending={
          createMutation.isPending || createFromFileMutation.isPending || renameMutation.isPending
        }
      />
    </Stack>
  )
}
