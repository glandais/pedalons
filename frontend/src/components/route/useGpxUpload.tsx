import { useRef, useState, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { createRoute } from '@/api/endpoints/routes/routes'
import { SurfaceType, TeamDetailDto } from '@/api/dto'
import { defaultMedia } from '@/lib/apiUtils'
import { invalidateRouteQueries } from '@/lib/routeCacheInvalidation'
import { defaultGpxName, readGpxNames } from '@/lib/gpxNames'

export interface GpxUpload {
  /** The hidden file input: render it once, anywhere. */
  input: ReactNode
  /** Opens the browser's file picker, several files allowed. */
  open: () => void
  /** While the files are sent: how many are done. */
  progress: { current: number; total: number } | null
  /** Set when a file failed; the others were imported all the same. */
  error: string | null
}

/**
 * Imports several GPX at once, one route per file, named after the file's own name (metadata, else
 * first track, else the file name), with the team's default visibility and a road surface. The
 * routes list offers it in its « Créer un parcours ▾ » menu (`RoutesListHeader`).
 */
export function useGpxUpload(team: TeamDetailDto): GpxUpload {
  const teamSlug = team.slug
  const { t } = useTranslation()
  const queryClient = useQueryClient()
  const fileInputRef = useRef<HTMLInputElement>(null)
  const [progress, setProgress] = useState<{ current: number; total: number } | null>(null)
  const [error, setError] = useState<string | null>(null)

  const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files
    if (!files || files.length === 0) return

    setError(null)
    setProgress({ current: 0, total: files.length })

    let successCount = 0
    const fileArray = Array.from(files)

    for (let i = 0; i < fileArray.length; i++) {
      const file = fileArray[i]
      const name = defaultGpxName(await readGpxNames(file))

      try {
        await createRoute(teamSlug, {
          route: {
            name,
            visibility: team.defaultContentVisibility,
            surfaceType: SurfaceType.ROAD,
            media: defaultMedia(),
          },
          gpxFile: file,
        })
        successCount++
        setProgress({ current: i + 1, total: files.length })
      } catch {
        setError(t('error.loading'))
      }
    }

    setProgress(null)

    if (successCount > 0) {
      // Refresh every cached view of this team's routes (list, detail, bulk).
      invalidateRouteQueries(queryClient, teamSlug)
    }

    if (fileInputRef.current) {
      fileInputRef.current.value = ''
    }
  }

  return {
    input: (
      <input
        ref={fileInputRef}
        type="file"
        accept=".gpx"
        multiple
        onChange={handleFileSelect}
        disabled={progress !== null}
        hidden
        data-testid="gpx-upload-input"
      />
    ),
    open: () => fileInputRef.current?.click(),
    progress,
    error,
  }
}
