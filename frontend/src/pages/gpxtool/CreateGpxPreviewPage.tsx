import { useTranslation } from 'react-i18next'
import { Navigate, useNavigate } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { Stack, Text, Title } from '@mantine/core'
import { notifications } from '@mantine/notifications'
import type { GeoPoint, PlannerState } from '@/api/dto'
import {
  getListMyPreviewsQueryKey,
  useCreatePreviewFromPoints,
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

  const handleSubmit = async (
    name: string,
    track?: { points?: GeoPoint[]; plannerState?: PlannerState }
  ) => {
    if (!track?.plannerState && (!track?.points || track.points.length < 2)) return

    const preview = await createMutation.mutateAsync(
      { data: { name, points: track.points, plannerState: track.plannerState } },
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
        isPending={createMutation.isPending}
      />
    </Stack>
  )
}
