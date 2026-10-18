import { useTranslation } from 'react-i18next'
import { Navigate, useNavigate, useParams } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { Stack, Text, Title } from '@mantine/core'
import { notifications } from '@mantine/notifications'
import type { GeoPoint } from '@/api/dto'
import { getGetPreviewQueryKey, useUpdatePreview } from '@/api/endpoints/gpx-previews/gpx-previews'
import { GpxPreviewEditor } from '@/components/gpxtool/GpxPreviewEditor'
import { LoadingPage } from '@/components/common/LoadingSpinner'
import { paths } from '@/config/paths'
import { useGpxPreviewFormData } from './gpxPreviewFormData'

export function EditGpxPreviewPage() {
  const { previewId } = useParams<{ previewId: string }>()
  const { t } = useTranslation()
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const { data: preview, isLoading } = useGpxPreviewFormData(previewId)
  const updateMutation = useUpdatePreview()

  if (isLoading) {
    return <LoadingPage message={t('gpxTools.edit.title')} />
  }

  if (!preview) {
    return <Navigate to={paths.gpxTools()} replace />
  }

  // Editing is owner-only; anyone else (or an anonymous visitor) is sent back to the read view.
  if (!preview.owned) {
    return <Navigate to={paths.gpxToolsView(preview.id)} replace />
  }

  const initialTrack = preview.tracks.length === 1 ? preview.tracks[0].line.coordinates : undefined

  const handleSubmit = async (name: string, points?: GeoPoint[], gpxFile?: File) => {
    await updateMutation.mutateAsync(
      { previewId: preview.id, data: { preview: { name, points }, gpxFile } },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: getGetPreviewQueryKey(preview.id) })
          notifications.show({ message: t('gpxTools.edit.updated'), color: 'green' })
        },
      }
    )
    navigate(paths.gpxToolsView(preview.id))
  }

  return (
    <Stack>
      <Stack gap="xs">
        <Title order={1}>{t('gpxTools.edit.title')}</Title>
        <Text c="dimmed">{t('gpxTools.edit.subtitle')}</Text>
      </Stack>

      <GpxPreviewEditor
        initialName={preview.name}
        initialTrack={initialTrack}
        initialAscend={preview.elevationGain}
        onSubmit={handleSubmit}
        onCancel={() => navigate(paths.gpxToolsView(preview.id))}
        isPending={updateMutation.isPending}
      />
    </Stack>
  )
}
