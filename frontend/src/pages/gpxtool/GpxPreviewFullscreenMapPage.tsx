import { useEffect } from 'react'
import { Navigate, useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { MapColorFullscreenView } from '@/components/route/MapColorFullscreenView'
import { LoadingPage } from '@/components/common/LoadingSpinner'
import { paths } from '@/config/paths'
import { useAppName } from '@/hooks/useAppName'
import { useCanonicalPath } from '@/hooks/useCanonicalPath'
import { useGpxPreviewData } from '@/pages/gpxtool/gpxPreviewData'

/**
 * Fullscreen map for an analysed GPX preview (`.../map`). Bare layout (no AppShell), so it owns its
 * own `document.title`. Mirrors {@link GpxPreviewPage}'s data flow; a missing preview falls back to
 * the GPX tools landing page.
 */
export function GpxPreviewFullscreenMapPage() {
  const { previewId } = useParams<{ previewId: string }>()
  const { t } = useTranslation()
  const appName = useAppName()

  const { data: preview, isLoading } = useGpxPreviewData(previewId)

  useCanonicalPath(preview ? paths.gpxToolsMap(preview.id) : undefined)

  useEffect(() => {
    if (preview) {
      document.title = appName ? `${preview.name} — ${appName}` : preview.name
    }
  }, [preview, appName])

  if (isLoading) {
    return <LoadingPage message={t('gpxTools.title')} />
  }

  if (!preview) {
    return <Navigate to={paths.gpxTools()} replace />
  }

  return (
    <MapColorFullscreenView
      route={preview}
      title={preview.name}
      backTo={paths.gpxToolsView(preview.id)}
    />
  )
}
